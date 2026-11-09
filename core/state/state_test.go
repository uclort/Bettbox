package state

import "testing"

// BETTBOX-CUSTOM: 关闭 IPv6 时 Android TUN 不能带 IPv6 地址，否则 IPv6 连接进 TUN 后被拒绝，应用不会回退 IPv4。
func TestTunIpv6AddressFollowsSwitch(t *testing.T) {
	if got := TunIpv6Address(false); got != "" {
		t.Fatalf("ipv6 disabled: got %q, want empty", got)
	}
	if got := TunIpv6Address(true); got != DefaultIpv6Address {
		t.Fatalf("ipv6 enabled: got %q, want %q", got, DefaultIpv6Address)
	}
}
