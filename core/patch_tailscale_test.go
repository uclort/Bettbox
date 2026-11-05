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
	if got := fmt.Sprint(rawCfg.DNS.FakeIPFilter); got != "[+.lan +.tailscale.com +.tailscale.io +.ts.net +.example.ts]" {
		t.Fatalf("unexpected fake-ip-filter: %s", got)
	}
	if value, _ := rawCfg.DNS.NameServerPolicy.Get("+.ts.net"); fmt.Sprint(value) != "10.0.0.53" {
		t.Fatalf("existing policy must be kept, got %v", value)
	}
	if value, _ := rawCfg.DNS.NameServerPolicy.Get("+.example.ts"); value != "100.100.100.100" {
		t.Fatalf("missing tailscale policy, got %v", value)
	}
	// Tailscale 服务域名只返回真实 IP，不能交给 MagicDNS（未连接时不可用）。
	if _, exists := rawCfg.DNS.NameServerPolicy.Get("+.tailscale.com"); exists {
		t.Fatal("tailscale service domains must not use magic dns policy")
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
	if got := fmt.Sprint(rawCfg.DNS.FakeIPFilter); got != "[DOMAIN-SUFFIX,ts.net,real-ip DOMAIN-SUFFIX,tailscale.io,real-ip DOMAIN-SUFFIX,tailscale.com,real-ip MATCH,fake-ip]" {
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

const tailscaleNodeProfile = tailscaleProfile + `proxies:
  - {name: hk, type: socks5, server: 127.0.0.1, port: 1080}
proxy-groups:
  - {name: auto, type: url-test, include-all: true, exclude-filter: "过期"}
  - {name: manual, type: select, proxies: [hk]}
`

// BETTBOX-CUSTOM: 内置 Tailscale 节点注入、MagicDNS 交给节点解析、排除出 include-all 策略组。
func TestPatchTailscaleNode(t *testing.T) {
	rawCfg := parsePatchProfile(t, tailscaleNodeProfile)
	params := patchParams(t, `{"tailscale":{"dns-domains":["ts.net"],"dns-server":"100.100.100.100","default-node":"Bettbox-Tailscale","nodes":[{"name":"Bettbox-Tailscale","hostname":"m1-bettbox","auth-key":" ","exit-node":"","accept-routes":true}]}}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	node := rawCfg.Proxy[len(rawCfg.Proxy)-1]
	if node["name"] != "Bettbox-Tailscale" || node["type"] != "tailscale" || node["hostname"] != "m1-bettbox" ||
		node["state-dir"] != tailscaleNodeStateDir || node["accept-routes"] != true {
		t.Fatalf("unexpected node: %v", node)
	}
	if _, ok := node["auth-key"]; ok {
		t.Fatal("blank auth-key must be omitted for browser login")
	}
	if value, _ := rawCfg.DNS.NameServerPolicy.Get("+.ts.net"); fmt.Sprint(value) != "[tailscale://Bettbox-Tailscale]" {
		t.Fatalf("node mode must override MagicDNS policy, got %v", value)
	}
	if got := rawCfg.ProxyGroup[0]["exclude-filter"]; got != "过期|^Bettbox-Tailscale$" {
		t.Fatalf("include-all group must exclude node, got %v", got)
	}
	if _, ok := rawCfg.ProxyGroup[1]["exclude-filter"]; ok {
		t.Fatal("explicit group must not be touched")
	}
	// 重复打补丁（热更新）不重复注入
	patchTailscaleNodes(rawCfg, params.Tailscale)
	count := 0
	for _, proxy := range rawCfg.Proxy {
		if proxy["name"] == "Bettbox-Tailscale" {
			count++
		}
	}
	if count != 1 || rawCfg.ProxyGroup[0]["exclude-filter"] != "过期|^Bettbox-Tailscale$" {
		t.Fatalf("patch must be idempotent: count=%d filter=%v", count, rawCfg.ProxyGroup[0]["exclude-filter"])
	}
}

func TestPatchTailscaleNodeKeepsProfileProxy(t *testing.T) {
	rawCfg := parsePatchProfile(t, tailscaleProfile+`proxies:
  - {name: Bettbox-Tailscale, type: tailscale, hostname: from-profile}
`)
	params := patchParams(t, `{"tailscale":{"dns-domains":["ts.net"],"default-node":"Bettbox-Tailscale","nodes":[{"name":"Bettbox-Tailscale","hostname":"gui"}]}}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	if len(rawCfg.Proxy) != 1 || rawCfg.Proxy[0]["hostname"] != "from-profile" {
		t.Fatalf("profile proxy must be kept: %v", rawCfg.Proxy)
	}
}

// BETTBOX-CUSTOM: 开启覆写的配置文件节点运行时整体替换为 GUI 参数，策略组引用不变；
// 当前配置文件没有该节点时不注入，指向它的前置规则一并去掉。
func TestPatchTailscaleOverrideProfileNode(t *testing.T) {
	profile := tailscaleProfile + `proxies:
  - {name: hk, type: socks5, server: 127.0.0.1, port: 1080}
  - {name: Tailscale-Proxy, type: tailscale, hostname: from-profile, state-dir: ./ts, auth-key: tskey-file}
proxy-groups:
  - {name: auto, type: url-test, include-all: true}
  - {name: manual, type: select, proxies: [hk, Tailscale-Proxy]}
`
	rawCfg := parsePatchProfile(t, profile)
	params := patchParams(t, `{"tailscale":{"dns-domains":["ts.net"],"default-node":"Bettbox-Tailscale","nodes":[
		{"name":"Bettbox-Tailscale"},
		{"name":"Tailscale-Proxy","override":true,"state-id":"p-tailscale-proxy","hostname":"gui-proxy","auth-mode":"auth-key","auth-key":"tskey-gui","dialer-proxy":"hk"},
		{"name":"Missing-Node","override":true,"state-id":"p-missing"}]},
		"prepend-rules":["DOMAIN,rex.tail1.ts.net,Tailscale-Proxy","DOMAIN,vps.tail1.ts.net,Missing-Node","DOMAIN-SUFFIX,ts.net,Bettbox-Tailscale"]}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	if len(rawCfg.Proxy) != 3 {
		t.Fatalf("override must replace in place and skip missing node: %v", rawCfg.Proxy)
	}
	node := rawCfg.Proxy[1]
	if node["name"] != "Tailscale-Proxy" || node["hostname"] != "gui-proxy" || node["auth-key"] != "tskey-gui" ||
		node["dialer-proxy"] != "hk" || node["state-dir"] != "tailscale/bettbox-p-tailscale-proxy-authkey" {
		t.Fatalf("unexpected overridden node: %v", node)
	}
	if got := fmt.Sprint(rawCfg.Rule[:2]); got != "[DOMAIN,rex.tail1.ts.net,Tailscale-Proxy DOMAIN-SUFFIX,ts.net,Bettbox-Tailscale]" {
		t.Fatalf("rules to missing node must be dropped: %s", got)
	}
	if value, _ := rawCfg.DNS.NameServerPolicy.Get("+.ts.net"); fmt.Sprint(value) != "[tailscale://Bettbox-Tailscale tailscale://Tailscale-Proxy]" {
		t.Fatalf("MagicDNS must skip missing override node, got %v", value)
	}
	if got := rawCfg.ProxyGroup[0]["exclude-filter"]; got != "^Bettbox-Tailscale$" {
		t.Fatalf("only injected node is excluded from include-all, got %v", got)
	}
}

// BETTBOX-CUSTOM: Auth Key 方式用独立 state-dir 并下发 key；登录方式即使填了 key 也不下发。
func TestPatchTailscaleNodeAuthMode(t *testing.T) {
	for _, tc := range []struct {
		mode, dir string
		withKey   bool
	}{
		{"login", "tailscale/bettbox", false},
		{"auth-key", "tailscale/bettbox-authkey", true},
	} {
		rawCfg := parsePatchProfile(t, tailscaleNodeProfile)
		params := patchParams(t, `{"tailscale":{"dns-domains":["ts.net"],"default-node":"Bettbox-Tailscale","nodes":[{"name":"Bettbox-Tailscale","auth-mode":"`+tc.mode+`","auth-key":"tskey-auth-x"}]}}`)
		if _, err := applyPatch(rawCfg, params); err != nil {
			t.Fatal(err)
		}
		node := rawCfg.Proxy[len(rawCfg.Proxy)-1]
		_, hasKey := node["auth-key"]
		if node["state-dir"] != tc.dir || hasKey != tc.withKey {
			t.Fatalf("%s: unexpected node %v", tc.mode, node)
		}
	}
}

// BETTBOX-CUSTOM: 经代理的策略组带 dialer-proxy、按 state-id 使用独立 state-dir（旧版代理通道 proxy 目录不变），
// 同样排除出 include-all 策略组。
func TestPatchTailscaleProxyNode(t *testing.T) {
	for _, tc := range []struct{ mode, dir string }{
		{"login", "tailscale/bettbox-proxy"},
		{"auth-key", "tailscale/bettbox-proxy-authkey"},
	} {
		rawCfg := parsePatchProfile(t, tailscaleNodeProfile)
		params := patchParams(t, `{"tailscale":{"dns-domains":["ts.net"],"default-node":"Bettbox-Tailscale","nodes":[
			{"name":"Bettbox-Tailscale","auth-mode":"`+tc.mode+`","auth-key":"k"},
			{"name":"Bettbox-Tailscale-Proxy","state-id":"proxy","hostname":"m1-bettbox-proxy","auth-mode":"`+tc.mode+`","auth-key":"k","dialer-proxy":"manual","accept-routes":true}]}}`)
		if _, err := applyPatch(rawCfg, params); err != nil {
			t.Fatal(err)
		}
		direct, proxy := rawCfg.Proxy[len(rawCfg.Proxy)-2], rawCfg.Proxy[len(rawCfg.Proxy)-1]
		if _, ok := direct["dialer-proxy"]; ok || direct["state-dir"] == tc.dir {
			t.Fatalf("%s: direct node must stay direct: %v", tc.mode, direct)
		}
		if proxy["name"] != "Bettbox-Tailscale-Proxy" || proxy["dialer-proxy"] != "manual" ||
			proxy["state-dir"] != tc.dir || proxy["hostname"] != "m1-bettbox-proxy" {
			t.Fatalf("%s: unexpected proxy node: %v", tc.mode, proxy)
		}
		if got := rawCfg.ProxyGroup[0]["exclude-filter"]; got != "过期|^Bettbox-Tailscale$|^Bettbox-Tailscale-Proxy$" {
			t.Fatalf("include-all group must exclude both nodes, got %v", got)
		}
		// MagicDNS 交给所有节点并行解析，默认组在前：默认组掉线时其他组仍能解析
		if value, _ := rawCfg.DNS.NameServerPolicy.Get("+.ts.net"); fmt.Sprint(value) != "[tailscale://Bettbox-Tailscale tailscale://Bettbox-Tailscale-Proxy]" {
			t.Fatalf("MagicDNS must use every node, default first, got %v", value)
		}
	}
}

// BETTBOX-CUSTOM: 内置节点开启时清理让 Tailnet 绕开节点的配置；只开 App 共存时不动。
func TestPatchTailscaleNodeRemovesConflicts(t *testing.T) {
	profile := `dns:
  enable: true
  enhanced-mode: fake-ip
  nameserver-policy:
    "+.corp.example": 100.100.100.100
    "+.cn": 223.5.5.5
  nameserver:
    - 223.5.5.5
    - 100.100.100.100
  fallback:
    - 100.100.100.100
hosts:
  vps.tail1234.ts.net: 100.64.1.2
  example.com: 1.2.3.4
tun:
  enable: true
  route-exclude-address:
    - 100.64.0.0/10
    - 100.100.0.0/16
    - 172.30.0.0/16
rules:
  - MATCH,DIRECT
`
	node := `"default-node":"Bettbox-Tailscale","nodes":[{"name":"Bettbox-Tailscale"}],`
	for _, withNode := range []bool{true, false} {
		rawCfg := parsePatchProfile(t, profile)
		n := ""
		if withNode {
			n = node
		}
		params := patchParams(t, `{"general":{"tun":{"enable":true,"route-exclude-address":["fd7a:115c:a1e0::/48"]}},"tailscale":{`+n+`"dns-domains":["ts.net"],"dns-server":"100.100.100.100","ranges":["100.64.0.0/10","fd7a:115c:a1e0::/48"]}}`)
		if _, err := applyPatch(rawCfg, params); err != nil {
			t.Fatal(err)
		}
		routes := fmt.Sprint(rawCfg.Tun.RouteExcludeAddress)
		policy, _ := rawCfg.DNS.NameServerPolicy.Get("+.corp.example")
		_, hasHost := rawCfg.Hosts["vps.tail1234.ts.net"]
		if !withNode {
			if routes != "[fd7a:115c:a1e0::/48 100.64.0.0/10 100.100.0.0/16 172.30.0.0/16]" || policy != "100.100.100.100" || !hasHost {
				t.Fatalf("app mode must not touch profile: routes=%s policy=%v host=%v", routes, policy, hasHost)
			}
			continue
		}
		if routes != "[172.30.0.0/16]" || fmt.Sprint(params.profileRouteExclude) != "[172.30.0.0/16]" {
			t.Fatalf("tailnet ranges must leave tun exclusion: %s / %v", routes, params.profileRouteExclude)
		}
		if fmt.Sprint(rawCfg.DNS.NameServer) != "[223.5.5.5]" || len(rawCfg.DNS.Fallback) != 0 {
			t.Fatalf("MagicDNS must leave server lists: %v %v", rawCfg.DNS.NameServer, rawCfg.DNS.Fallback)
		}
		if fmt.Sprint(policy) != "[tailscale://Bettbox-Tailscale]" {
			t.Fatalf("MagicDNS policy must go to the node, got %v", policy)
		}
		if other, _ := rawCfg.DNS.NameServerPolicy.Get("+.cn"); other != "223.5.5.5" {
			t.Fatalf("unrelated policy must stay, got %v", other)
		}
		if _, ok := rawCfg.Hosts["example.com"]; hasHost || !ok {
			t.Fatalf("only tailnet hosts must be removed: %v", rawCfg.Hosts)
		}
	}
}

// BETTBOX-CUSTOM: 默认组自动取配置文件里第一个 Tailscale 节点（未手动指定时），
// 兜底规则的占位目标换成它；配置文件与 GUI 都没有节点时兜底规则被去掉。
func TestPatchTailscaleAutoDefault(t *testing.T) {
	profile := tailscaleProfile + `proxies:
  - {name: hk, type: socks5, server: 127.0.0.1, port: 1080}
  - {name: Profile-TS, type: tailscale, hostname: from-profile}
`
	prepend := `"prepend-rules":["DOMAIN-SUFFIX,ts.net,BETTBOX-TAILSCALE-DEFAULT","IP-CIDR,100.64.0.0/10,BETTBOX-TAILSCALE-DEFAULT,no-resolve","DOMAIN,gui.tail.ts.net,GUI-TS","DOMAIN,gone.tail.ts.net,Gone"]`
	rawCfg := parsePatchProfile(t, profile)
	params := patchParams(t, `{"tailscale":{"dns-domains":["ts.net"],"groups":["GUI-TS","Gone"],"nodes":[{"name":"GUI-TS"}]},`+prepend+`}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	if params.Tailscale.resolved != "Profile-TS" {
		t.Fatalf("default must be the profile's first tailscale node, got %q", params.Tailscale.resolved)
	}
	want := "[DOMAIN-SUFFIX,ts.net,Profile-TS IP-CIDR,100.64.0.0/10,Profile-TS,no-resolve DOMAIN,gui.tail.ts.net,GUI-TS MATCH,DIRECT]"
	if got := fmt.Sprint(rawCfg.Rule); got != want {
		t.Fatalf("unexpected rules:\n got %s\nwant %s", got, want)
	}
	if value, _ := rawCfg.DNS.NameServerPolicy.Get("+.ts.net"); fmt.Sprint(value) != "[tailscale://Profile-TS tailscale://GUI-TS]" {
		t.Fatalf("MagicDNS must use every node, default first, got %v", value)
	}

	// 手动指定优先于自动选择。
	rawCfg = parsePatchProfile(t, profile)
	params = patchParams(t, `{"tailscale":{"dns-domains":["ts.net"],"default-node":"GUI-TS","groups":["GUI-TS"],"nodes":[{"name":"GUI-TS"}]},`+prepend+`}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	if params.Tailscale.resolved != "GUI-TS" || rawCfg.Rule[0] != "DOMAIN-SUFFIX,ts.net,GUI-TS" {
		t.Fatalf("manual default must win: resolved=%q rules=%v", params.Tailscale.resolved, rawCfg.Rule)
	}

	// 没有任何 Tailscale 节点：占位规则被去掉，不引用不存在的出站。
	rawCfg = parsePatchProfile(t, tailscaleProfile)
	params = patchParams(t, `{"tailscale":{"dns-domains":["ts.net"],"groups":["GUI-TS","Gone"],"nodes":[]},`+prepend+`}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	if params.Tailscale.resolved != "" || fmt.Sprint(rawCfg.Rule) != "[MATCH,DIRECT]" {
		t.Fatalf("placeholder rules must be dropped: resolved=%q rules=%v", params.Tailscale.resolved, rawCfg.Rule)
	}
}

// BETTBOX-CUSTOM: 内置节点模式但一个节点都没有时，MagicDNS 不能退回 100.100.100.100（没有 App 时不可用）。
func TestPatchTailscaleNodeModeWithoutNodesKeepsDns(t *testing.T) {
	rawCfg := parsePatchProfile(t, tailscaleProfile)
	params := patchParams(t, `{"tailscale":{"dns-domains":["ts.net","corp.example"],"dns-server":"100.100.100.100","node-mode":true,"groups":[],"nodes":[]}}`)
	if _, err := applyPatch(rawCfg, params); err != nil {
		t.Fatal(err)
	}
	if value, _ := rawCfg.DNS.NameServerPolicy.Get("+.ts.net"); fmt.Sprint(value) != "10.0.0.53" {
		t.Fatalf("profile policy must be kept, got %v", value)
	}
	if _, exists := rawCfg.DNS.NameServerPolicy.Get("+.corp.example"); exists {
		t.Fatal("no node means no magic dns policy")
	}
}
