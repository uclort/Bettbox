package main

import (
	"net/netip"
	"slices"
	"testing"

	tun "github.com/metacubex/sing-tun"
)

func mustPrefixes(t *testing.T, values ...string) []netip.Prefix {
	t.Helper()
	result := make([]netip.Prefix, 0, len(values))
	for _, value := range values {
		result = append(result, netip.MustParsePrefix(value))
	}
	return result
}

func TestWidenScopedIPv6Exclude(t *testing.T) {
	cases := []struct {
		name string
		in   []string
		want []string
	}{
		{"mDNS 组播扩大到 ff00::/8", []string{"192.168.0.0/16", "ff02::fb/128"}, []string{"192.168.0.0/16", "ff00::/8"}},
		{"链路本地扩大到 fe80::/10", []string{"fe80::1/128"}, []string{"fe80::/10"}},
		{"多个组播合并去重", []string{"ff02::fb/128", "ff02::1/128", "ff00::/8"}, []string{"ff00::/8"}},
		{"已是整段保持不变", []string{"ff00::/8", "fe80::/10"}, []string{"ff00::/8", "fe80::/10"}},
		{"包含整段的大前缀保持不变", []string{"fe00::/7"}, []string{"fe00::/7"}},
		{"普通地址不变", []string{"fd7a:115c:a1e0::/48", "10.0.0.0/8", "::ffff:224.0.0.1/128"}, []string{"fd7a:115c:a1e0::/48", "10.0.0.0/8", "::ffff:224.0.0.1/128"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := widenScopedIPv6Exclude(mustPrefixes(t, tc.in...))
			if want := mustPrefixes(t, tc.want...); !slices.Equal(got, want) {
				t.Fatalf("got %v, want %v", got, want)
			}
		})
	}
}

// macOS 会把 fe80::/10、ff00::/8 内地址的第 3、4 字节当作网卡编号，路由里这两个字节必须为 0。
func TestScopedExcludeRoutesHaveNoEmbeddedScope(t *testing.T) {
	exclude := mustPrefixes(t, "ff02::fb/128", "fe80::1234/128")
	build := func(exclude []netip.Prefix) []netip.Prefix {
		options := tun.Options{
			AutoRoute:                true,
			Inet6Address:             mustPrefixes(t, "fdfe:dcba:9876::1/126"),
			Inet6RouteExcludeAddress: exclude,
		}
		routes, err := options.BuildAutoRouteRanges(false)
		if err != nil {
			t.Fatal(err)
		}
		return routes
	}
	hasEmbeddedScope := func(routes []netip.Prefix) bool {
		for _, route := range routes {
			addr := route.Addr().As16()
			for _, scoped := range scopedIPv6Ranges {
				if scoped.Contains(route.Addr()) && (addr[2] != 0 || addr[3] != 0) {
					return true
				}
			}
		}
		return false
	}
	if before := build(exclude); !hasEmbeddedScope(before) {
		t.Skip("当前平台未按子网段生成路由，无法复现")
	}
	if after := build(widenScopedIPv6Exclude(exclude)); hasEmbeddedScope(after) {
		t.Fatalf("widened routes still embed scope: %v", after)
	}
}
