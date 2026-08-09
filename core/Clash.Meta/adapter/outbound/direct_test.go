package outbound

import (
	"testing"

	"github.com/metacubex/mihomo/common/structure"
)

func TestDirectDNSFollowInterface(t *testing.T) {
	t.Run("默认开启", func(t *testing.T) {
		direct := NewDirectWithOption(DirectOption{
			BasicOption: BasicOption{Interface: "en5"},
			Name:        "CC-intranet-en5",
		})
		if direct.interfaceResolver == nil {
			t.Fatal("绑定接口的 direct proxy 默认应创建接口 DNS resolver")
		}
	})

	t.Run("显式关闭", func(t *testing.T) {
		disabled := false
		direct := NewDirectWithOption(DirectOption{
			BasicOption:        BasicOption{Interface: "en5"},
			Name:               "CC-intranet-en5",
			DNSFollowInterface: &disabled,
		})
		if direct.interfaceResolver != nil {
			t.Fatal("dns-follow-interface=false 时应继续使用原有全局 DNS")
		}
	})
}

func TestDirectDNSFollowInterfaceDecode(t *testing.T) {
	option := DirectOption{}
	decoder := structure.NewDecoder(structure.Option{
		TagName:          "proxy",
		WeaklyTypedInput: true,
		KeyReplacer:      structure.DefaultKeyReplacer,
	})
	if err := decoder.Decode(map[string]any{
		"name":                 "CC-intranet-en5",
		"dns-follow-interface": false,
	}, &option); err != nil {
		t.Fatal(err)
	}
	if option.DNSFollowInterface == nil || *option.DNSFollowInterface {
		t.Fatal("dns-follow-interface=false 未正确解析")
	}
}
