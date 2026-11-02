package main

import (
	"net/netip"
	"strings"

	"github.com/metacubex/mihomo/common/orderedmap"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
)

// BETTBOX-CUSTOM: Tailscale 共存。DNS 段可能来自订阅（未开启覆写 DNS），只能在内核合并阶段补充。
type PatchTailscale struct {
	DnsDomains []string `json:"dns-domains"`
	DnsServer  string   `json:"dns-server"`
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
		if _, exists := raw.DNS.NameServerPolicy.Get(pattern); !exists {
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
