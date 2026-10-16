package config

import (
	"reflect"
	"testing"
)

func TestDefaultDNSBootstrapIncludesHTTPSWithIPAddress(t *testing.T) {
	raw, err := UnmarshalRawConfig([]byte("dns:\n  enable: true\n  nameserver: [https://dns.alidns.com/dns-query]\n"))
	if err != nil {
		t.Fatal(err)
	}
	dns, err := parseDNS(raw, nil)
	if err != nil {
		t.Fatal(err)
	}
	for _, server := range dns.DefaultNameserver {
		if server.Net == "https" && server.Addr == "https://223.5.5.5:443/dns-query" {
			return
		}
	}
	t.Fatalf("默认引导 DNS 缺少无需域名解析的 HTTPS 通道：%v", dns.DefaultNameserver)
}

func TestExplicitDNSBootstrapIsPreserved(t *testing.T) {
	raw, err := UnmarshalRawConfig([]byte("dns:\n  default-nameserver: [10.0.0.53]\n"))
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(raw.DNS.DefaultNameserver, []string{"10.0.0.53"}) {
		t.Fatalf("不应覆盖用户显式配置的引导 DNS：%v", raw.DNS.DefaultNameserver)
	}
}
