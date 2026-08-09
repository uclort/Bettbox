package dns

import (
	"context"
	"net"
	"net/netip"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/mihomo/component/dhcp"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/iface"
	D "github.com/miekg/dns"
)

const (
	IfaceTTL    = time.Second * 20
	DHCPTTL     = time.Hour
	DHCPTimeout = time.Minute
)

type dhcpClient struct {
	ifaceName           string
	activeIfaceName     string
	allowOtherInterface bool

	lock            sync.Mutex
	ifaceInvalidate time.Time
	dnsInvalidate   time.Time

	ifaceAddr netip.Prefix
	done      chan struct{}
	clients   []dnsClient
	err       error
}

var _ dnsClient = (*dhcpClient)(nil)

// Address implements dnsClient
func (d *dhcpClient) Address() string {
	addrs := make([]string, 0)
	for _, c := range d.clients {
		addrs = append(addrs, c.Address())
	}
	return strings.Join(addrs, ",")
}

func (d *dhcpClient) ExchangeContext(ctx context.Context, m *D.Msg) (msg *D.Msg, err error) {
	clients, err := d.resolve(ctx)
	if err != nil {
		return nil, err
	}

	msg, _, err = batchExchange(ctx, clients, m)
	if err == nil {
		return msg, nil
	}

	// BETTBOX-CUSTOM: 接口 DNS 请求失败时按需刷新系统状态并重试，不轮询 macOS Scoped Resolver。
	d.invalidateDNS()
	clients, refreshErr := d.resolve(ctx)
	if refreshErr != nil {
		return nil, err
	}
	msg, _, err = batchExchange(ctx, clients, m)
	return msg, err
}

func (d *dhcpClient) ResetConnection() {
	d.invalidateDNS()
}

func (d *dhcpClient) invalidateDNS() {
	d.lock.Lock()
	defer d.lock.Unlock()

	if d.done != nil {
		return
	}
	for _, client := range d.clients {
		client.ResetConnection()
	}
	d.ifaceInvalidate = time.Time{}
	d.dnsInvalidate = time.Time{}
	d.ifaceAddr = netip.Prefix{}
	d.activeIfaceName = ""
	d.clients = nil
	d.err = nil
	iface.FlushCache()
}

func (d *dhcpClient) resolve(ctx context.Context) ([]dnsClient, error) {
	d.lock.Lock()

	invalidated, err := d.invalidate()
	if err != nil {
		d.err = err
	} else if invalidated {
		done := make(chan struct{})
		ifaceName := d.activeIfaceName

		d.done = done

		go func(ifaceName string) {
			ctx, cancel := context.WithTimeout(context.Background(), DHCPTimeout)
			defer cancel()

			var res []dnsClient
			dns, err := dhcp.ResolveDNSFromDHCP(ctx, ifaceName)
			// dns never empty if err is nil
			if err == nil {
				nameserver := make([]NameServer, 0, len(dns))
				for _, item := range dns {
					nameserver = append(nameserver, NameServer{
						Addr:      net.JoinHostPort(item.String(), "53"),
						ProxyName: ifaceName,
					})
				}

				res = transform(nameserver, nil)
			}

			d.lock.Lock()
			defer d.lock.Unlock()

			close(done)

			d.done = nil
			d.clients = res
			d.err = err
		}(ifaceName)
	}

	d.lock.Unlock()

	for {
		d.lock.Lock()

		res, err, done := d.clients, d.err, d.done

		d.lock.Unlock()

		// initializing
		if res == nil && err == nil {
			select {
			case <-done:
				continue
			case <-ctx.Done():
				return nil, ctx.Err()
			}
		}

		// dirty return
		return res, err
	}
}

func (d *dhcpClient) invalidate() (bool, error) {
	if time.Now().Before(d.ifaceInvalidate) {
		return false, nil
	}

	d.ifaceInvalidate = time.Now().Add(IfaceTTL)

	ifaceName := d.ifaceName
	if d.allowOtherInterface {
		ifaceName = dialer.ResolveInterfaceName(ifaceName, netip.Addr{})
	}
	ifaceObj, err := iface.ResolveInterface(ifaceName)
	if err != nil {
		return false, err
	}

	addr, err := ifaceObj.PickIPv4Addr(netip.Addr{})
	if err != nil {
		return false, err
	}

	if d.activeIfaceName == ifaceName && d.ifaceAddr == addr && (runtime.GOOS == "darwin" || time.Now().Before(d.dnsInvalidate)) {
		return false, nil
	}

	if runtime.GOOS != "darwin" {
		d.dnsInvalidate = time.Now().Add(DHCPTTL)
	}
	d.activeIfaceName = ifaceName
	d.ifaceAddr = addr

	return d.done == nil, nil
}

func newDHCPClient(ifaceName string, allowOtherInterface bool) *dhcpClient {
	return &dhcpClient{ifaceName: ifaceName, allowOtherInterface: allowOtherInterface}
}
