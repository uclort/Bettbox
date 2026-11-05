//go:build with_gvisor && !no_tailscale

package main

import (
	"testing"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
)

// BETTBOX-CUSTOM: 内置 Tailscale 节点补丁后的完整配置必须能被 mihomo 解析（节点、tailscale:// DNS、前置规则）。
func TestPatchTailscaleNodeParses(t *testing.T) {
	C.SetHomeDir(t.TempDir())
	rawCfg := parsePatchProfile(t, tailscaleNodeProfile)
	params := patchParams(t, `{
		"tailscale":{"dns-domains":["ts.net"],"dns-server":"100.100.100.100","default-node":"Bettbox-Tailscale","nodes":[{"name":"Bettbox-Tailscale","hostname":"m1-bettbox","accept-routes":true}]},
		"prepend-rules":["DOMAIN-SUFFIX,ts.net,Bettbox-Tailscale","IP-CIDR,100.64.0.0/10,Bettbox-Tailscale,no-resolve"]
	}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	cfg, err := config.ParseRawConfig(rawCfg)
	if err != nil {
		t.Fatal(err)
	}
	proxy, ok := cfg.Proxies["Bettbox-Tailscale"]
	if !ok || proxy.Type() != C.Tailscale {
		t.Fatalf("missing tailscale node: %v", proxy)
	}
	if _, ok := outbound.AsTailscaleNode(proxy.Adapter()); !ok {
		t.Fatal("tailscale node must expose status for GUI login")
	}
	for _, p := range cfg.Proxies["auto"].Adapter().(interface{ GetProxies(bool) []C.Proxy }).GetProxies(false) {
		if p.Name() == "Bettbox-Tailscale" {
			t.Fatal("include-all group must not contain tailscale node")
		}
	}
	_ = proxy.Close()
}

// BETTBOX-CUSTOM: 代理通道节点与按设备的前置规则能被 mihomo 解析。
func TestPatchTailscaleProxyNodeParses(t *testing.T) {
	C.SetHomeDir(t.TempDir())
	rawCfg := parsePatchProfile(t, tailscaleNodeProfile)
	params := patchParams(t, `{
		"tailscale":{"dns-domains":["ts.net"],"default-node":"Bettbox-Tailscale","nodes":[{"name":"Bettbox-Tailscale"},
			{"name":"Bettbox-Tailscale-Proxy","state-id":"proxy","dialer-proxy":"manual"}]},
		"prepend-rules":["DOMAIN,rex.tail1.ts.net,Bettbox-Tailscale-Proxy","IP-CIDR,100.121.3.59/32,Bettbox-Tailscale-Proxy,no-resolve",
			"DOMAIN-SUFFIX,ts.net,Bettbox-Tailscale","IP-CIDR,100.64.0.0/10,Bettbox-Tailscale,no-resolve"]
	}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	cfg, err := config.ParseRawConfig(rawCfg)
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"Bettbox-Tailscale", "Bettbox-Tailscale-Proxy"} {
		proxy, ok := cfg.Proxies[name]
		if !ok || proxy.Type() != C.Tailscale {
			t.Fatalf("missing tailscale node %s", name)
		}
		_ = proxy.Close()
	}
	if got := cfg.Rules[0].Adapter(); got != "Bettbox-Tailscale-Proxy" {
		t.Fatalf("device rule must come first, got %s", got)
	}
}
