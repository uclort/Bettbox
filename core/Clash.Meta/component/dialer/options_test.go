package dialer

import (
	"net"
	"net/netip"
	"testing"

	"github.com/metacubex/mihomo/component/iface"
)

func TestInterfaceUsable(t *testing.T) {
	interfaceObj := &iface.Interface{
		Flags:     net.FlagUp | net.FlagRunning,
		Addresses: []netip.Prefix{netip.MustParsePrefix("10.0.0.2/24")},
	}
	if !isInterfaceUsable(interfaceObj, netip.MustParseAddr("10.0.0.1")) {
		t.Fatal("运行中的接口应可用")
	}

	interfaceObj.Flags = net.FlagUp
	if isInterfaceUsable(interfaceObj, netip.MustParseAddr("10.0.0.1")) {
		t.Fatal("未运行的接口应触发回退")
	}
}

func TestResolveInterfaceNameFallsBack(t *testing.T) {
	interfaces, err := iface.Interfaces()
	if err != nil {
		t.Fatal(err)
	}
	var fallback string
	for name, interfaceObj := range interfaces {
		if isInterfaceUsable(interfaceObj, netip.Addr{}) {
			fallback = name
			break
		}
	}
	if fallback == "" {
		t.Skip("没有可用于测试的默认接口")
	}

	previous := DefaultInterface.Load()
	DefaultInterface.Store(fallback)
	t.Cleanup(func() { DefaultInterface.Store(previous) })

	if actual := ResolveInterfaceName("不存在的测试接口", netip.Addr{}); actual != fallback {
		t.Fatalf("应回退到 %s，实际为 %s", fallback, actual)
	}
}
