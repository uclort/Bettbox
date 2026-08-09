package dialer

import (
	"context"
	"net"
	"net/netip"

	"github.com/metacubex/mihomo/common/atomic"
	"github.com/metacubex/mihomo/component/iface"
	"github.com/metacubex/mihomo/component/resolver"
)

var (
	DefaultInterface   = atomic.NewTypedValue[string]("")
	DefaultRoutingMark = atomic.NewInt32(0)

	DefaultInterfaceFinder = atomic.NewTypedValue[InterfaceFinder](nil)
)

type InterfaceFinder interface {
	FindInterfaceName(destination netip.Addr) string
}

type NetDialer interface {
	DialContext(ctx context.Context, network, address string) (net.Conn, error)
}

type NetDialerFunc func(ctx context.Context, network, address string) (net.Conn, error)

func (f NetDialerFunc) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	return f(ctx, network, address)
}

type option struct {
	interfaceName       string
	allowOtherInterface bool
	fallbackBind        bool
	addrReuse           bool
	routingMark         int
	network             int
	prefer              int
	tfo                 bool
	mpTcp               bool
	resolver            resolver.Resolver
	netDialer           NetDialer
}

type Option func(opt *option)

func WithInterface(name string) Option {
	return func(opt *option) {
		opt.interfaceName = name
	}
}

func WithAllowOtherInterface(allow bool) Option {
	return func(opt *option) {
		opt.allowOtherInterface = allow
	}
}

// BETTBOX-CUSTOM: ResolveInterfaceName keeps the configured interface while it is usable and
// otherwise returns the current default interface. An empty result lets the OS
// select its default route when no interface finder is available.
func ResolveInterfaceName(name string, destination netip.Addr) string {
	if interfaceUsable(name, destination) {
		return name
	}
	if name = DefaultInterface.Load(); interfaceUsable(name, destination) {
		return name
	}
	if finder := DefaultInterfaceFinder.Load(); finder != nil {
		name = finder.FindInterfaceName(destination)
		if interfaceUsable(name, destination) {
			return name
		}
		return "" // TUN 已启用时不能让系统探测再次选中 TUN 自身。
	}
	if name = systemDefaultInterfaceName(destination); interfaceUsable(name, destination) {
		return name
	}
	return ""
}

func systemDefaultInterfaceName(destination netip.Addr) string {
	network := "udp4"
	probe := netip.AddrFrom4([4]byte{192, 0, 2, 1})
	if destination.Is6() {
		network = "udp6"
		probe = netip.MustParseAddr("2001:db8::1")
	}
	conn, err := net.DialUDP(network, nil, net.UDPAddrFromAddrPort(netip.AddrPortFrom(probe, 9)))
	if err != nil {
		return ""
	}
	defer conn.Close()

	localAddr := conn.LocalAddr().(*net.UDPAddr).AddrPort().Addr().Unmap()
	interfaceObj, err := iface.ResolveInterfaceByAddr(localAddr)
	if err != nil {
		return ""
	}
	return interfaceObj.Name
}

func interfaceUsable(name string, destination netip.Addr) bool {
	if name == "" {
		return false
	}
	interfaceObj, err := iface.ResolveInterface(name)
	return err == nil && isInterfaceUsable(interfaceObj, destination)
}

func isInterfaceUsable(interfaceObj *iface.Interface, destination netip.Addr) bool {
	if interfaceObj.Flags&net.FlagUp == 0 || interfaceObj.Flags&net.FlagRunning == 0 {
		return false
	}
	if destination.Is4() {
		_, err := interfaceObj.PickIPv4Addr(destination)
		return err == nil
	}
	if destination.Is6() {
		_, err := interfaceObj.PickIPv6Addr(destination)
		return err == nil
	}
	_, ipv4Err := interfaceObj.PickIPv4Addr(destination)
	_, ipv6Err := interfaceObj.PickIPv6Addr(destination)
	return ipv4Err == nil || ipv6Err == nil
}

func WithFallbackBind(fallback bool) Option {
	return func(opt *option) {
		opt.fallbackBind = fallback
	}
}

func WithAddrReuse(reuse bool) Option {
	return func(opt *option) {
		opt.addrReuse = reuse
	}
}

func WithRoutingMark(mark int) Option {
	return func(opt *option) {
		opt.routingMark = mark
	}
}

func WithResolver(r resolver.Resolver) Option {
	return func(opt *option) {
		opt.resolver = r
	}
}

func WithPreferIPv4() Option {
	return func(opt *option) {
		opt.prefer = 4
	}
}

func WithPreferIPv6() Option {
	return func(opt *option) {
		opt.prefer = 6
	}
}

func WithOnlySingleStack(isIPv4 bool) Option {
	return func(opt *option) {
		if isIPv4 {
			opt.network = 4
		} else {
			opt.network = 6
		}
	}
}

func WithTFO(tfo bool) Option {
	return func(opt *option) {
		opt.tfo = tfo
	}
}

func WithMPTCP(mpTcp bool) Option {
	return func(opt *option) {
		opt.mpTcp = mpTcp
	}
}

func WithNetDialer(netDialer NetDialer) Option {
	return func(opt *option) {
		opt.netDialer = netDialer
	}
}

func WithOption(o option) Option {
	return func(opt *option) {
		*opt = o
	}
}

func WithOptions(options ...Option) Option {
	return func(opt *option) {
		for _, o := range options {
			o(opt)
		}
	}
}

func IsZeroOptions(opts []Option) bool {
	return applyOptions(opts...) == option{}
}

func applyOptions(options ...Option) option {
	opt := option{}
	for _, o := range options {
		o(&opt)
	}
	return opt
}
