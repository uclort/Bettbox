package main

import (
	"net/netip"
	"regexp"
	"slices"
	"strings"

	"github.com/metacubex/mihomo/common/orderedmap"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
)

// BETTBOX-CUSTOM: Tailscale 共存。DNS 段可能来自订阅（未开启覆写 DNS），只能在内核合并阶段补充。
type PatchTailscale struct {
	DnsDomains []string            `json:"dns-domains"`
	DnsServer  string              `json:"dns-server"`
	Node       *PatchTailscaleNode `json:"node"`
	// BETTBOX-CUSTOM: Tailnet 网段，内置节点开启时用于清理会让流量绕开节点的配置。
	Ranges []string `json:"ranges"`
}

// BETTBOX-CUSTOM: 内置 Tailscale 节点（mihomo type: tailscale），不依赖 Tailscale App 访问 Tailnet。
type PatchTailscaleNode struct {
	Name         string `json:"name"`
	Hostname     string `json:"hostname"`
	AuthMode     string `json:"auth-mode"` // login（默认）或 auth-key
	AuthKey      string `json:"auth-key"`
	ExitNode     string `json:"exit-node"`
	AcceptRoutes bool   `json:"accept-routes"`
}

// 状态目录固定在内核 home 下，切换订阅或重载配置不会丢失登录状态。
// 两种接入方式各用一个目录：切到 Auth Key 不清空浏览器登录，切回来仍用原来的身份。
const (
	tailscaleNodeStateDir        = "tailscale/bettbox"
	tailscaleNodeAuthKeyStateDir = "tailscale/bettbox-authkey"
	tailscaleAuthModeAuthKey     = "auth-key"
)

func patchTailscaleNode(raw *config.RawConfig, node *PatchTailscaleNode) {
	if node == nil || node.Name == "" {
		return
	}
	exists := false
	for _, proxy := range raw.Proxy {
		if name, _ := proxy["name"].(string); name == node.Name {
			exists = true // 订阅里已有同名节点时尊重订阅定义
			break
		}
	}
	if !exists {
		proxy := map[string]any{
			"name":          node.Name,
			"type":          "tailscale",
			"state-dir":     node.stateDir(),
			"udp":           true,
			"accept-routes": node.AcceptRoutes,
		}
		if hostname := strings.TrimSpace(node.Hostname); hostname != "" {
			proxy["hostname"] = hostname
		}
		// 登录方式不下发 auth-key，只认浏览器登录状态。
		if authKey := strings.TrimSpace(node.AuthKey); authKey != "" && node.useAuthKey() {
			proxy["auth-key"] = authKey
		}
		if exitNode := strings.TrimSpace(node.ExitNode); exitNode != "" {
			proxy["exit-node"] = exitNode
		}
		raw.Proxy = append(raw.Proxy, proxy)
	}
	// include-all 策略组会把它当普通节点做健康检查甚至自动选中，这里排除，只由前置规则引用。
	filter := "^" + regexp.QuoteMeta(node.Name) + "$"
	for _, group := range raw.ProxyGroup {
		if group == nil {
			continue
		}
		includeAll, _ := group["include-all"].(bool)
		includeAllProxies, _ := group["include-all-proxies"].(bool)
		if !includeAll && !includeAllProxies {
			continue
		}
		if existing, _ := group["exclude-filter"].(string); strings.Contains(existing, filter) {
			continue
		}
		combineExcludeFilter(group, filter)
	}
}

func (node *PatchTailscaleNode) useAuthKey() bool {
	return node.AuthMode == tailscaleAuthModeAuthKey
}

func (node *PatchTailscaleNode) stateDir() string {
	if node.useAuthKey() {
		return tailscaleNodeAuthKeyStateDir
	}
	return tailscaleNodeStateDir
}

func normalizeTailscaleDomain(domain string) string {
	domain = strings.TrimSpace(strings.ToLower(domain))
	domain = strings.TrimPrefix(domain, "+.")
	domain = strings.TrimPrefix(domain, "*.")
	domain = strings.TrimPrefix(domain, ".")
	return strings.TrimSuffix(domain, ".")
}

// BETTBOX-CUSTOM: Tailscale 控制面、登录、日志与 DERP 域名。tsnet（如 Rex 内嵌节点）与 Tailscale 客户端
// 会把连接绑定到物理网卡绕过 TUN，拿到 Fake-IP 时请求从物理网卡发出成为黑洞，登录卡在 fetch control key。
// 这些域名只返回真实 IP，不改 DNS 服务器：Tailscale 未连接时 100.100.100.100 不可用，不能交给 MagicDNS。
var tailscaleServiceDomains = []string{"tailscale.com", "tailscale.io"}

func addTailscaleRealIPDomain(raw *config.RawConfig, domain string) {
	pattern := "+." + domain
	switch raw.DNS.FakeIPFilterMode {
	case C.FilterBlackList:
		if !containsString(raw.DNS.FakeIPFilter, pattern) {
			raw.DNS.FakeIPFilter = append(raw.DNS.FakeIPFilter, pattern)
		}
	case C.FilterRule:
		rule := "DOMAIN-SUFFIX," + domain + ",real-ip"
		if !containsString(raw.DNS.FakeIPFilter, rule) {
			raw.DNS.FakeIPFilter = append([]string{rule}, raw.DNS.FakeIPFilter...)
		}
	}
	// FilterWhiteList 下未列出的域名本来就返回真实 IP，无需处理。
}

func patchTailscaleDns(raw *config.RawConfig, tailscale *PatchTailscale) {
	if tailscale == nil {
		return
	}
	for _, domain := range tailscaleServiceDomains {
		addTailscaleRealIPDomain(raw, domain)
	}
	server := strings.TrimSpace(tailscale.DnsServer)
	// 内置节点模式：MagicDNS 交给节点自身解析，并覆盖订阅里同域名的 nameserver-policy
	// （订阅通常指向 100.100.100.100，App 未运行时不可用）。
	override := false
	if node := tailscale.Node; node != nil && node.Name != "" {
		server = "tailscale://" + node.Name
		override = true
	}
	for _, item := range tailscale.DnsDomains {
		domain := normalizeTailscaleDomain(item)
		if domain == "" {
			continue
		}
		pattern := "+." + domain
		addTailscaleRealIPDomain(raw, domain)
		if server == "" {
			continue
		}
		if raw.DNS.NameServerPolicy == nil {
			raw.DNS.NameServerPolicy = orderedmap.New[string, any]()
		}
		if _, exists := raw.DNS.NameServerPolicy.Get(pattern); override || !exists {
			raw.DNS.NameServerPolicy.Set(pattern, server)
		}
	}
}

// BETTBOX-CUSTOM: GUI 的 tun 设置会整体替换订阅的 route-exclude-address，这里与订阅原值取并集。
func mergeRouteExcludeAddress(current, profile []netip.Prefix) []netip.Prefix {
	if len(profile) == 0 {
		return current
	}
	merged := make([]netip.Prefix, 0, len(current)+len(profile))
	seen := make(map[netip.Prefix]bool, len(current)+len(profile))
	for _, list := range [][]netip.Prefix{current, profile} {
		for _, prefix := range list {
			prefix = prefix.Masked()
			if !prefix.IsValid() || seen[prefix] {
				continue
			}
			seen[prefix] = true
			merged = append(merged, prefix)
		}
	}
	return merged
}

func containsString(list []string, value string) bool {
	for _, item := range list {
		if item == value {
			return true
		}
	}
	return false
}

// BETTBOX-CUSTOM: 内置节点开启时，自动清理订阅/覆写里会让 Tailnet 流量绕开内置节点的配置，
// 只在本次生成的运行配置中生效，不改订阅文件；关闭内置节点后恢复原样。
//   - tun 排除路由里与 Tailnet 网段重叠的条目：这些流量不进 TUN，内核里的节点收不到；
//   - DNS 服务器列表里的 MagicDNS 100.100.100.100：没有 Tailscale App 时不可用，查询会超时；
//   - nameserver-policy 指向 100.100.100.100 的条目：改为交给内置节点解析；
//   - hosts 里写死的 Tailnet 域名：设备 IP 变化后会解析到旧地址。
const tailscaleMagicDNS = "100.100.100.100"

func removeTailscaleConflicts(raw *config.RawConfig, params *PatchParams) {
	tailscale := params.Tailscale
	if tailscale == nil || tailscale.Node == nil || tailscale.Node.Name == "" {
		return
	}
	var ranges []netip.Prefix
	for _, item := range tailscale.Ranges {
		if prefix, err := netip.ParsePrefix(strings.TrimSpace(item)); err == nil {
			ranges = append(ranges, prefix.Masked())
		}
	}
	overlaps := func(prefix netip.Prefix) bool {
		return slices.ContainsFunc(ranges, prefix.Overlaps)
	}
	filterPrefixes := func(field string, list []netip.Prefix) []netip.Prefix {
		kept := list[:0:0]
		for _, prefix := range list {
			if overlaps(prefix) {
				log.Infoln("[Tailscale] built-in node: ignore tun.%s %s", field, prefix)
				continue
			}
			kept = append(kept, prefix)
		}
		return kept
	}
	raw.Tun.RouteExcludeAddress = filterPrefixes("route-exclude-address", raw.Tun.RouteExcludeAddress)
	raw.Tun.Inet4RouteExcludeAddress = filterPrefixes("inet4-route-exclude-address", raw.Tun.Inet4RouteExcludeAddress)
	raw.Tun.Inet6RouteExcludeAddress = filterPrefixes("inet6-route-exclude-address", raw.Tun.Inet6RouteExcludeAddress)
	params.profileRouteExclude = filterPrefixes("route-exclude-address", params.profileRouteExclude)

	isMagicDNS := func(server string) bool { return strings.Contains(server, tailscaleMagicDNS) }
	filterServers := func(field string, list []string, keepNonEmpty bool) []string {
		kept := slices.DeleteFunc(slices.Clone(list), isMagicDNS)
		if len(kept) == len(list) || (keepNonEmpty && len(kept) == 0) {
			return list
		}
		log.Infoln("[Tailscale] built-in node: ignore %s in dns.%s", tailscaleMagicDNS, field)
		return kept
	}
	raw.DNS.NameServer = filterServers("nameserver", raw.DNS.NameServer, true)
	raw.DNS.DefaultNameserver = filterServers("default-nameserver", raw.DNS.DefaultNameserver, true)
	raw.DNS.Fallback = filterServers("fallback", raw.DNS.Fallback, false)
	raw.DNS.ProxyServerNameserver = filterServers("proxy-server-nameserver", raw.DNS.ProxyServerNameserver, false)
	raw.DNS.DirectNameServer = filterServers("direct-nameserver", raw.DNS.DirectNameServer, false)

	if policy := raw.DNS.NameServerPolicy; policy != nil {
		nodeServer := "tailscale://" + tailscale.Node.Name
		for pair := policy.Oldest(); pair != nil; pair = pair.Next() {
			if policyUsesMagicDNS(pair.Value) {
				log.Infoln("[Tailscale] built-in node: dns.nameserver-policy %s -> %s", pair.Key, nodeServer)
				policy.Set(pair.Key, nodeServer)
			}
		}
	}

	var domains []string
	for _, item := range tailscale.DnsDomains {
		if domain := normalizeTailscaleDomain(item); domain != "" {
			domains = append(domains, domain)
		}
	}
	for host := range raw.Hosts {
		name := normalizeTailscaleDomain(host)
		if slices.ContainsFunc(domains, func(d string) bool { return name == d || strings.HasSuffix(name, "."+d) }) {
			log.Infoln("[Tailscale] built-in node: ignore hosts %s", host)
			delete(raw.Hosts, host)
		}
	}
}

func policyUsesMagicDNS(value any) bool {
	switch v := value.(type) {
	case string:
		return strings.Contains(v, tailscaleMagicDNS)
	case []string:
		return slices.ContainsFunc(v, func(s string) bool { return strings.Contains(s, tailscaleMagicDNS) })
	case []any:
		return slices.ContainsFunc(v, func(item any) bool { s, _ := item.(string); return strings.Contains(s, tailscaleMagicDNS) })
	}
	return false
}
