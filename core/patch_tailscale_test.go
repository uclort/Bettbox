package main

import (
	"fmt"
	"testing"
)

const tailscaleProfile = `dns:
  enable: true
  enhanced-mode: fake-ip
  fake-ip-filter:
    - "+.lan"
  nameserver-policy:
    "+.ts.net": 10.0.0.53
  nameserver:
    - 223.5.5.5
tun:
  enable: true
  route-exclude-address:
    - 100.64.0.0/10
    - 172.30.0.0/16
rules:
  - MATCH,DIRECT
`

// BETTBOX-CUSTOM: 订阅的 route-exclude-address 与 GUI 取并集，不被整体替换。
func TestPatchKeepsProfileRouteExcludeAddress(t *testing.T) {
	rawCfg := parsePatchProfile(t, tailscaleProfile)
	params := patchParams(t, `{"general":{"tun":{"enable":true,"route-exclude-address":["fd7a:115c:a1e0::/48","100.64.0.0/10"]}}}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	got := fmt.Sprint(rawCfg.Tun.RouteExcludeAddress)
	if got != "[fd7a:115c:a1e0::/48 100.64.0.0/10 172.30.0.0/16]" {
		t.Fatalf("unexpected route-exclude-address: %s", got)
	}
	if got := fmt.Sprint(params.profileRouteExclude); got != "[100.64.0.0/10 172.30.0.0/16]" {
		t.Fatalf("profile route-exclude-address must be recorded for hot update: %s", got)
	}
	if got := fmt.Sprint(mergeRouteExcludeAddress(nil, params.profileRouteExclude)); got != "[100.64.0.0/10 172.30.0.0/16]" {
		t.Fatalf("hot update must keep profile route-exclude-address: %s", got)
	}
}

func TestPatchTailscaleDnsUsesProfileDns(t *testing.T) {
	rawCfg := parsePatchProfile(t, tailscaleProfile)
	params := patchParams(t, `{"override-dns":false,"tailscale":{"dns-domains":["ts.net","+.example.ts"],"dns-server":"100.100.100.100"}}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	if got := fmt.Sprint(rawCfg.DNS.FakeIPFilter); got != "[+.lan +.ts.net +.example.ts]" {
		t.Fatalf("unexpected fake-ip-filter: %s", got)
	}
	if value, _ := rawCfg.DNS.NameServerPolicy.Get("+.ts.net"); fmt.Sprint(value) != "10.0.0.53" {
		t.Fatalf("existing policy must be kept, got %v", value)
	}
	if value, _ := rawCfg.DNS.NameServerPolicy.Get("+.example.ts"); value != "100.100.100.100" {
		t.Fatalf("missing tailscale policy, got %v", value)
	}
}

func TestPatchTailscaleDnsRuleMode(t *testing.T) {
	rawCfg := parsePatchProfile(t, `dns:
  enable: true
  fake-ip-filter-mode: rule
  fake-ip-filter:
    - MATCH,fake-ip
`)
	params := patchParams(t, `{"tailscale":{"dns-domains":["ts.net"],"dns-server":""}}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	if got := fmt.Sprint(rawCfg.DNS.FakeIPFilter); got != "[DOMAIN-SUFFIX,ts.net,real-ip MATCH,fake-ip]" {
		t.Fatalf("unexpected fake-ip-filter: %s", got)
	}
	if rawCfg.DNS.NameServerPolicy != nil && rawCfg.DNS.NameServerPolicy.Len() != 0 {
		t.Fatal("empty dns server must not add policy")
	}
}

func TestPatchWithoutTailscaleKeepsDns(t *testing.T) {
	rawCfg := parsePatchProfile(t, tailscaleProfile)
	if _, err := applyPatch(rawCfg, patchParams(t, `{}`)); err != nil {
		t.Fatal(err)
	}
	if got := fmt.Sprint(rawCfg.DNS.FakeIPFilter); got != "[+.lan]" {
		t.Fatalf("unexpected fake-ip-filter: %s", got)
	}
}
