package outbound

import (
	"context"
	"fmt"

	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/loopback"
	"github.com/metacubex/mihomo/component/resolver"
	C "github.com/metacubex/mihomo/constant"
	D "github.com/metacubex/mihomo/dns"
)

type Direct struct {
	*Base
	loopBack            *loopback.Detector
	interfaceResolver   resolver.Resolver
	allowOtherInterface bool
}

type DirectOption struct {
	BasicOption
	Name                string `proxy:"name"`
	DNSFollowInterface  *bool  `proxy:"dns-follow-interface,omitempty"`
	AllowOtherInterface *bool  `proxy:"allow-other-interface,omitempty"`
}

func (d *Direct) hostResolver() resolver.Resolver {
	if d.interfaceResolver != nil {
		return d.interfaceResolver
	}
	return resolver.DirectHostResolver
}

func (d *Direct) dialOptions() []dialer.Option {
	return append(d.DialOptions(), dialer.WithAllowOtherInterface(d.allowOtherInterface))
}

// DialContext implements C.ProxyAdapter
func (d *Direct) DialContext(ctx context.Context, metadata *C.Metadata) (C.Conn, error) {
	if err := d.loopBack.CheckConn(metadata); err != nil {
		return nil, err
	}
	opts := d.dialOptions()
	opts = append(opts, dialer.WithResolver(d.hostResolver()))
	c, err := dialer.DialContext(ctx, "tcp", metadata.RemoteAddress(), opts...)
	if err != nil {
		return nil, err
	}
	return d.loopBack.NewConn(NewConn(c, d)), nil
}

// ListenPacketContext implements C.ProxyAdapter
func (d *Direct) ListenPacketContext(ctx context.Context, metadata *C.Metadata) (C.PacketConn, error) {
	if err := d.loopBack.CheckPacketConn(metadata); err != nil {
		return nil, err
	}
	if err := d.ResolveUDP(ctx, metadata); err != nil {
		return nil, err
	}
	pc, err := dialer.NewDialer(d.dialOptions()...).ListenPacket(ctx, "udp", "", metadata.AddrPort())
	if err != nil {
		return nil, err
	}
	return d.loopBack.NewPacketConn(NewPacketConn(pc, d)), nil
}

func (d *Direct) ResolveUDP(ctx context.Context, metadata *C.Metadata) error {
	if (!metadata.Resolved() || d.interfaceResolver != nil || resolver.DirectHostResolver != resolver.DefaultResolver) && metadata.Host != "" {
		ip, err := resolveIPWithResolver(ctx, metadata.Host, d.prefer, d.hostResolver())
		if err != nil {
			return fmt.Errorf("can't resolve ip: %w", err)
		}
		metadata.DstIP = ip
	}
	return nil
}

func (d *Direct) IsL3Protocol(metadata *C.Metadata) bool {
	return true // tell DNSDialer don't send domain to DialContext, avoid lookback to DefaultResolver
}

func NewDirectWithOption(option DirectOption) *Direct {
	allowOtherInterface := option.AllowOtherInterface == nil || *option.AllowOtherInterface
	direct := &Direct{
		Base: NewBase(BaseOption{
			Name:         option.Name,
			Type:         C.Direct,
			ProviderName: option.ProviderName,
			UDP:          true,
			TFO:          option.TFO,
			MPTCP:        option.MPTCP,
			Interface:    option.Interface,
			RoutingMark:  option.RoutingMark,
			Prefer:       option.IPVersion,
		}),
		loopBack:            loopback.NewDetector(),
		allowOtherInterface: allowOtherInterface,
	}

	// BETTBOX-CUSTOM: 绑定接口的直连代理默认使用该接口（含不可用回退接口）的 DHCP DNS 解析目标域名。
	if option.Interface != "" && (option.DNSFollowInterface == nil || *option.DNSFollowInterface) {
		direct.interfaceResolver = D.NewResolver(D.Config{
			Main: []D.NameServer{{
				Net:    "dhcp",
				Addr:   option.Interface,
				Params: map[string]string{"allow-other-interface": fmt.Sprint(allowOtherInterface)},
			}},
			IPv6: true,
		}).Resolver
	}

	return direct
}

func NewDirect() *Direct {
	return &Direct{
		Base: NewBase(BaseOption{
			Name:   "DIRECT",
			Type:   C.Direct,
			UDP:    true,
			Prefer: C.DualStack,
		}),
		loopBack: loopback.NewDetector(),
	}
}

func NewCompatible() *Direct {
	return &Direct{
		Base: NewBase(BaseOption{
			Name:   "COMPATIBLE",
			Type:   C.Compatible,
			UDP:    true,
			Prefer: C.DualStack,
		}),
		loopBack: loopback.NewDetector(),
	}
}
