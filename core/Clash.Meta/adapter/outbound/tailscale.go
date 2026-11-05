//go:build with_gvisor && !no_tailscale

package outbound

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/component/ca"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/iface/anet"
	"github.com/metacubex/mihomo/component/resolver"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/mihomo/log"

	ts "github.com/metacubex/tailscale"
	"github.com/metacubex/tailscale/envknob"
	"github.com/metacubex/tailscale/hostinfo"
	"github.com/metacubex/tailscale/ipn"
	"github.com/metacubex/tailscale/net/netmon"
	"github.com/metacubex/tailscale/tailcfg"
	"github.com/metacubex/tailscale/tsnet"
	D "github.com/miekg/dns"
	"github.com/samber/lo"
)

type Tailscale struct {
	*Base
	server      *tsnet.Server
	dnsResolver *dns.Resolver
	option      TailscaleOption
	ctx         context.Context
	cancel      context.CancelFunc
	startOnce   sync.Once
	startErr    error

	backendInitOnce sync.Once
	backendInitCh   chan struct{}
	backendInitErr  error

	serverStarted bool

	// BETTBOX-CUSTOM: Close 可能被 state-dir 互斥与 finalizer 各调用一次。
	closeOnce sync.Once
	closeErr  error
	// BETTBOX-CUSTOM: 跨配置重载复用时的引用计数，受 tailscaleStateDirMu 保护。
	refs int
	// BETTBOX-CUSTOM: Auth Key 方式上次用 key 注册的时间（UnixNano，0 为未尝试）与控制面返回的错误。
	// 节点运行中被登出（后台删除设备、身份失效等）时按节流间隔自动重新注册，不再只试一次。
	authKeyLoginAt  atomic.Int64
	authKeyLoginErr atomic.Value // string

	unregisterDNSResolver func()
}

type TailscaleOption struct {
	BasicOption
	Name       string `proxy:"name"`
	Hostname   string `proxy:"hostname,omitempty"`
	AuthKey    string `proxy:"auth-key,omitempty"`
	ControlURL string `proxy:"control-url,omitempty"`
	StateDir   string `proxy:"state-dir,omitempty"`
	Ephemeral  bool   `proxy:"ephemeral,omitempty"`
	UDP        bool   `proxy:"udp,omitempty"`

	AcceptRoutes           *bool  `proxy:"accept-routes,omitempty"`
	ExitNode               string `proxy:"exit-node,omitempty"`
	ExitNodeAllowLANAccess *bool  `proxy:"exit-node-allow-lan-access,omitempty"`
}

func init() {
	hostinfo.RegisterHostinfoNewHook(func(hi *tailcfg.Hostinfo) {
		versionDotTxt := strings.TrimSpace(ts.VersionDotTxt)
		hi.IPNVersion = fmt.Sprintf("%s-%s-%s", versionDotTxt, C.MihomoName, C.Version)
	})
	envknob.SetNoLogsNoSupport()
	if runtime.GOOS == "android" { // Android SDK 30 no longer permits Go's net.Interfaces to work (Issue 2293)
		netmon.RegisterInterfaceGetter(func() (nif []netmon.Interface, err error) {
			log.Debugln("[Tailscale] InterfaceGetter: start, IsForceAnet: %v", anet.IsForceAnet())
			ifaces, err := anet.Interfaces()
			if err != nil {
				log.Warnln("[Tailscale] anet.Interfaces failed: %v", err)
				return nil, err
			}
			for _, iff := range ifaces {
				addrs, err := anet.InterfaceAddrsByInterface(&iff)
				if err != nil {
					log.Warnln("[Tailscale] anet.InterfaceAddrsByInterface(%v) failed: %v", iff.Name, err)
					continue
				}
				nif = append(nif, netmon.Interface{
					Interface: &net.Interface{
						Index:        iff.Index,
						MTU:          iff.MTU,
						Name:         iff.Name,
						HardwareAddr: iff.HardwareAddr,
						Flags:        iff.Flags,
					},
					AltAddrs: addrs,
				})
			}

			log.Debugln("[Tailscale] InterfaceGetter: %v", lo.Map(nif, func(item netmon.Interface, index int) string {
				var addrs any
				addrs, err := item.Addrs()
				if err != nil {
					addrs = err
				}
				return fmt.Sprintf("{Name: %s, Addrs: %v, IsUp: %v, IsLoopback: %v}", item.Name, addrs, item.IsUp(), item.IsLoopback())
			}))
			return
		})
	}
}

func NewTailscale(option TailscaleOption) (*Tailscale, error) {
	if _, err := buildTailscaleMaskedPrefs(option); err != nil {
		return nil, err
	}
	if option.StateDir == "" {
		option.StateDir = "tailscale"
	}
	option.StateDir = C.Path.Resolve(option.StateDir)
	if !C.Path.IsSafePath(option.StateDir) {
		return nil, C.Path.ErrNotSafePath(option.StateDir)
	}
	// BETTBOX-CUSTOM: 参数未变时复用正在运行的实例，配置重载不打断 Tailnet。
	if prev := reuseTailscale(option); prev != nil {
		log.Debugln("[Tailscale](%s) reusing running instance", option.Name)
		return prev, nil
	}

	addr := option.ControlURL
	if addr == "" {
		addr = "tailscale"
	}
	ctx, cancel := context.WithCancel(context.Background())
	outbound := &Tailscale{
		Base: NewBase(BaseOption{
			Name:         option.Name,
			Addr:         addr,
			Type:         C.Tailscale,
			ProviderName: option.ProviderName,
			UDP:          option.UDP,
			Interface:    option.Interface,
			RoutingMark:  option.RoutingMark,
			Prefer:       option.IPVersion,
		}),
		option:        option,
		ctx:           ctx,
		cancel:        cancel,
		backendInitCh: make(chan struct{}),
		refs:          1,
	}
	outbound.dialer = option.NewDialer(outbound.DialOptions())
	outbound.server = &tsnet.Server{
		Dir:        option.StateDir,
		Hostname:   option.Hostname,
		AuthKey:    option.AuthKey,
		ControlURL: option.ControlURL,
		Ephemeral:  option.Ephemeral,
		SystemDialer: func(ctx context.Context, network, address string) (net.Conn, error) {
			log.Debugln("[Tailscale](%s) SystemDialer: start dial %s %s", option.Name, network, address)
			conn, err := outbound.dialer.DialContext(ctx, network, address)
			log.Debugln("[Tailscale](%s) SystemDialer: finish dial %s %s, err: %v", option.Name, network, address, err)
			return conn, err
		},
		SystemPacketListener: func(ctx context.Context, network, address string) (net.PacketConn, error) {
			log.Debugln("[Tailscale](%s) SystemPacketListener: start listen %s %s", option.Name, network, address)
			pc, err := outbound.dialer.ListenPacket(ctx, network, address, netip.AddrPort{})
			log.Debugln("[Tailscale](%s) SystemPacketListener: finish listen %s %s, err: %v", option.Name, network, address, err)
			// BETTBOX-CUSTOM: 代理建不了 UDP 时退回仅 DERP 中继，节点仍能启动（见 tailscale_noudp.go）。
			if err != nil && option.DialerProxy != "" {
				log.Warnln("[Tailscale](%s) dialer-proxy %s 无法建立 UDP（%v），改为仅经 DERP 中继", option.Name, option.DialerProxy, err)
				return newTailscaleNoUDPConn(network), nil
			}
			return pc, err
		},
		ExtraRootCAs: ca.GetCertPool(),
		LookupHook: func(ctx context.Context, host string) ([]netip.Addr, error) {
			log.Debugln("[Tailscale](%s) LookupHook: start lookup %s", option.Name, host)
			ips, err := resolver.LookupIPWithResolver(ctx, host, resolver.ProxyServerHostResolver)
			log.Debugln("[Tailscale](%s) LookupHook: finish lookup %s, ips: %v, err: %v", option.Name, host, ips, err)
			return ips, err
		},
		UserLogf: func(format string, args ...any) {
			log.Infoln("[Tailscale](%s) %s", option.Name, fmt.Sprintf(format, args...))
		},
		Logf: func(format string, args ...any) {
			log.Debugln("[Tailscale](%s) %s", option.Name, fmt.Sprintf(format, args...))
		},
	}
	dnsTransport := tailscaleDNSTransport{tailscale: outbound}
	outbound.dnsResolver = dns.NewResolverFromClient(dnsTransport)
	outbound.unregisterDNSResolver = dns.RegisterTailscaleDnsClient(option.Name, dnsTransport)
	return outbound, nil
}

func (t *Tailscale) start() error {
	t.startOnce.Do(func() {
		t.claimStateDir()       // BETTBOX-CUSTOM
		t.prepareAuthKeyState() // BETTBOX-CUSTOM
		// BETTBOX-CUSTOM: 启动时 tsnet 已用 auth-key 尝试注册，节流间隔内不再重复尝试。
		if t.option.AuthKey != "" {
			t.authKeyLoginAt.Store(time.Now().UnixNano())
		}
		if err := t.server.Start(); err != nil {
			t.startErr = err
			t.setBackendInitialized(err)
			return
		}
		t.serverStarted = true
		ctx, cancel := context.WithTimeout(t.ctx, 30*time.Second)
		defer cancel()
		if err := t.applyPrefs(ctx); err != nil {
			t.startErr = err
			t.setBackendInitialized(err)
			return
		}
		go t.watchBackendState()
	})
	return t.startErr
}

func (t *Tailscale) ensureStarted(ctx context.Context) error {
	if err := t.start(); err != nil {
		return err
	}
	return t.waitBackendInitialized(ctx)
}

func (t *Tailscale) watchBackendState() {
	lc, err := t.server.LocalClient()
	if err != nil {
		t.setBackendInitialized(err)
		return
	}
	watcher, err := lc.WatchIPNBus(t.ctx, ipn.NotifyInitialState)
	if err != nil {
		t.setBackendInitialized(err)
		return
	}
	defer watcher.Close()

	backendInitialized := false
	exitNodeNeedsStatus := tailscaleExitNodeNeedsStatus(t.option)
	// BETTBOX-CUSTOM: Auth Key 方式一直监听：记录控制面错误，运行中被登出时自动用 key 重新注册。
	useAuthKey := t.option.AuthKey != ""
	for {
		n, err := watcher.Next()
		if err != nil {
			t.setBackendInitialized(err)
			return
		}
		if useAuthKey && n.ErrMessage != nil && *n.ErrMessage != "" {
			t.authKeyLoginErr.Store(*n.ErrMessage)
			log.Warnln("[Tailscale](%s) %s", t.Name(), *n.ErrMessage)
		}
		if n.State == nil {
			continue
		}

		if *n.State != ipn.NoState && !backendInitialized {
			t.setBackendInitialized(nil)
			backendInitialized = true
			if !exitNodeNeedsStatus && !useAuthKey {
				return
			}
		}
		if exitNodeNeedsStatus && *n.State == ipn.Running {
			if err := t.applyExitNodePrefs(t.ctx); err != nil {
				log.Warnln("[Tailscale](%s) set exit node failed: %v", t.Name(), err)
			}
			exitNodeNeedsStatus = false
			if !useAuthKey {
				return
			}
		}
		if useAuthKey && *n.State == ipn.Running {
			t.authKeyLoginErr.Store("")
		}
		if useAuthKey && *n.State == ipn.NeedsLogin {
			go t.retryAuthKeyLogin()
		}
	}
}

func (t *Tailscale) setBackendInitialized(err error) {
	t.backendInitOnce.Do(func() {
		t.backendInitErr = err
		close(t.backendInitCh)
	})
}

func (t *Tailscale) waitBackendInitialized(ctx context.Context) error {
	select {
	case <-t.backendInitCh:
		return t.backendInitErr
	case <-ctx.Done():
		return ctx.Err()
	case <-t.ctx.Done():
		return t.ctx.Err()
	}
}

func (t *Tailscale) applyPrefs(ctx context.Context) error {
	mp, err := buildTailscaleMaskedPrefs(t.option)
	if err != nil {
		return err
	}
	if mp == nil {
		return nil
	}
	lc, err := t.server.LocalClient()
	if err != nil {
		return err
	}
	_, err = lc.EditPrefs(ctx, mp)
	return err
}

func (t *Tailscale) applyExitNodePrefs(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	lc, err := t.server.LocalClient()
	if err != nil {
		return err
	}
	status, err := lc.Status(ctx)
	if err != nil {
		return err
	}
	mp := &ipn.MaskedPrefs{
		ExitNodeIPSet: true,
	}
	if t.option.ExitNodeAllowLANAccess != nil {
		mp.ExitNodeAllowLANAccess = *t.option.ExitNodeAllowLANAccess
		mp.ExitNodeAllowLANAccessSet = true
	}
	if err = mp.SetExitNodeIP(t.option.ExitNode, status); err != nil {
		return err
	}
	_, err = lc.EditPrefs(ctx, mp)
	return err
}

func buildTailscaleMaskedPrefs(option TailscaleOption) (*ipn.MaskedPrefs, error) {
	var mp ipn.MaskedPrefs
	changed := false

	if option.AcceptRoutes != nil {
		mp.RouteAll = *option.AcceptRoutes
		mp.RouteAllSet = true
		changed = true
	}
	if option.ExitNode != "" {
		if autoExitNode, ok := ipn.ParseAutoExitNodeString(option.ExitNode); ok {
			mp.AutoExitNode = autoExitNode
			mp.AutoExitNodeSet = true
			changed = true
		}
	}
	if option.ExitNodeAllowLANAccess != nil && !tailscaleExitNodeNeedsStatus(option) {
		mp.ExitNodeAllowLANAccess = *option.ExitNodeAllowLANAccess
		mp.ExitNodeAllowLANAccessSet = true
		changed = true
	}
	if !changed {
		return nil, nil
	}
	return &mp, nil
}

func tailscaleExitNodeNeedsStatus(option TailscaleOption) bool {
	if option.ExitNode == "" {
		return false
	}
	_, ok := ipn.ParseAutoExitNodeString(option.ExitNode)
	return !ok
}

func (t *Tailscale) DialContext(ctx context.Context, metadata *C.Metadata) (_ C.Conn, err error) {
	if err = t.ensureStarted(ctx); err != nil {
		return nil, err
	}
	netStack, err := t.server.Netstack(ctx)
	if err != nil {
		return nil, err
	}
	v4, v6 := t.server.TailscaleIPs()
	options := t.DialOptions()
	options = append(options, dialer.WithResolver(t.dnsResolver))
	options = append(options, dialer.WithNetDialer(dialer.NetDialerFunc(func(ctx context.Context, network, address string) (net.Conn, error) {
		dst, err := netip.ParseAddrPort(address) // the dialer will resolve the domain to ip
		if err != nil {
			return nil, err
		}
		src := v4
		if dst.Addr().Is6() {
			src = v6
		}
		tcpConn, err := netStack.DialContextTCPWithBind(ctx, src, dst)
		if err != nil {
			return nil, err
		}
		return tcpConn, nil
	})))
	var conn net.Conn
	conn, err = dialer.NewDialer(options...).DialContext(ctx, "tcp", metadata.RemoteAddress())
	if err != nil {
		return nil, err
	}
	if conn == nil {
		return nil, errors.New("conn is nil")
	}
	return NewConn(conn, t), nil
}

func (t *Tailscale) ListenPacketContext(ctx context.Context, metadata *C.Metadata) (_ C.PacketConn, err error) {
	if err = t.ensureStarted(ctx); err != nil {
		return nil, err
	}
	if err = t.ResolveUDP(ctx, metadata); err != nil {
		return nil, err
	}
	v4, v6 := t.server.TailscaleIPs()
	src := v4
	if metadata.DstIP.Is6() {
		src = v6
	}
	pc, err := t.server.ListenPacket("udp", net.JoinHostPort(src.String(), "0"))
	if err != nil {
		return nil, err
	}
	if pc == nil {
		return nil, errors.New("packetConn is nil")
	}
	return NewPacketConn(pc, t), nil
}

func (t *Tailscale) ResolveUDP(ctx context.Context, metadata *C.Metadata) error {
	if metadata.Host != "" {
		ip, err := resolveIPWithResolver(ctx, metadata.Host, t.prefer, t.dnsResolver)
		if err != nil {
			return fmt.Errorf("can't resolve ip: %w", err)
		}
		metadata.DstIP = ip
	}
	return nil
}

type tailscaleDNSTransport struct {
	tailscale *Tailscale
}

func (t tailscaleDNSTransport) Address() string {
	return "tailscale://" + t.tailscale.Name()
}

func (t tailscaleDNSTransport) ResetConnection() {}

func (t tailscaleDNSTransport) ExchangeContext(ctx context.Context, msg *D.Msg) (*D.Msg, error) {
	if len(msg.Question) == 0 {
		return nil, errors.New("should have one question at least")
	}
	if err := t.tailscale.ensureStarted(ctx); err != nil {
		return nil, err
	}
	q := msg.Question[0]
	qtypeName, ok := D.TypeToString[q.Qtype]
	if !ok {
		return nil, fmt.Errorf("unsupported query type: %d", q.Qtype)
	}
	lc, err := t.tailscale.server.LocalClient()
	if err != nil {
		return nil, err
	}
	response, _, err := lc.QueryDNS(ctx, q.Name, qtypeName)
	if err != nil {
		return nil, err
	}
	var responseMsg D.Msg
	if err = responseMsg.Unpack(response); err != nil {
		return nil, err
	}
	responseMsg.Id = msg.Id
	return &responseMsg, nil
}

func (t *Tailscale) ProxyInfo() C.ProxyInfo {
	info := t.Base.ProxyInfo()
	info.DialerProxy = t.option.DialerProxy
	return info
}

func (t *Tailscale) IsL3Protocol(metadata *C.Metadata) bool {
	return true
}

// Close 释放一次引用；复用中的实例要等最后一个引用释放才真正关闭。BETTBOX-CUSTOM
func (t *Tailscale) Close() error {
	if !t.releaseRef() {
		return nil
	}
	return t.shutdown()
}

// shutdown 无视引用计数立即关闭，用于参数变化时让出 state-dir。
func (t *Tailscale) shutdown() error {
	t.closeOnce.Do(func() { // BETTBOX-CUSTOM
		t.cancel()
		if t.unregisterDNSResolver != nil {
			t.unregisterDNSResolver()
		}
		t.startOnce.Do(func() {
			t.startErr = errors.New("tailscale outbound closed")
		})
		if t.server != nil && t.serverStarted { // tsnet.Server.Close() must not be called before or concurrently with Start.
			t.closeErr = t.server.Close()
		}
		t.releaseStateDir() // BETTBOX-CUSTOM
	})
	return t.closeErr
}
