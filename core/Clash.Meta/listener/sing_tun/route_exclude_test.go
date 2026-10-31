package sing_tun

import (
	"net/netip"
	"testing"
)

// BETTBOX-CUSTOM: 被 route-exclude-address 排除的目标不能被绑定到默认网卡。
func TestDialerInterfaceFinderSkipsRouteExcludedDestination(t *testing.T) {
	finder := &cDialerInterfaceFinder{
		tunName: "utun-test",
		routeExcludeAddress: []netip.Prefix{
			netip.MustParsePrefix("100.64.0.0/10"),
			netip.MustParsePrefix("fd7a:115c:a1e0::/48"),
		},
	}
	for _, addr := range []string{"100.100.100.100", "100.121.3.59", "::ffff:100.64.0.1", "fd7a:115c:a1e0::53"} {
		if !finder.isRouteExcluded(netip.MustParseAddr(addr)) {
			t.Fatalf("%s should be route excluded", addr)
		}
		if name := finder.FindInterfaceName(netip.MustParseAddr(addr)); name != "" {
			t.Fatalf("%s should follow system routing, got %q", addr, name)
		}
	}
	for _, addr := range []string{"10.35.131.67", "8.8.8.8", "100.128.0.1", "0.0.0.0", "::"} {
		if finder.isRouteExcluded(netip.MustParseAddr(addr)) {
			t.Fatalf("%s should not be route excluded", addr)
		}
	}
	if finder.isRouteExcluded(netip.Addr{}) {
		t.Fatal("invalid address should not be route excluded")
	}
}
