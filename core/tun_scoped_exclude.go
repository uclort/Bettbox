package main

import (
	"net/netip"
	"runtime"
	"slices"

	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/log"
)

// BETTBOX-CUSTOM: macOS 内核（KAME）把链路本地单播与链路/接口本地组播地址的第 3、4 字节
// 当作网卡编号。TUN 的 IPv6 排除地址落在这些网段时，sing-tun 用补集计算出的路由
// （例如排除 ff02::fb 得到 ff02:1::/32）会被当成发往其他网卡，添加失败并报
// `network is unreachable`，TUN 无法启动。上游 1.19.8 起检测到公网 IPv6 就自动给 TUN
// 加 IPv6 地址，原本只在 IPv4 生效的订阅（常见 `ff02::fb/128` mDNS 排除）因此断网。
// 这里把落在这些网段内的排除扩大到整个网段；这两类流量本就不应进入 TUN。
var scopedIPv6Ranges = []netip.Prefix{
	netip.MustParsePrefix("fe80::/10"),
	netip.MustParsePrefix("ff00::/8"),
}

// widenScopedIPv6Exclude 返回扩大后的排除列表；无需改动时原样返回。
func widenScopedIPv6Exclude(prefixes []netip.Prefix) []netip.Prefix {
	var result []netip.Prefix
	changed := false
	for _, prefix := range prefixes {
		widened := prefix
		if prefix.Addr().Is6() && !prefix.Addr().Is4In6() {
			for _, scoped := range scopedIPv6Ranges {
				if prefix.Bits() > scoped.Bits() && scoped.Contains(prefix.Addr()) {
					widened = scoped
					break
				}
			}
		}
		if widened != prefix {
			changed = true
		}
		if !slices.Contains(result, widened) {
			result = append(result, widened)
		} else {
			changed = true
		}
	}
	if !changed {
		return prefixes
	}
	return result
}

func sanitizeTunScopedExclude(tun *LC.Tun) {
	if runtime.GOOS != "darwin" || tun == nil {
		return
	}
	for _, field := range []*[]netip.Prefix{&tun.RouteExcludeAddress, &tun.Inet6RouteExcludeAddress} {
		widened := widenScopedIPv6Exclude(*field)
		if !slices.Equal(widened, *field) {
			log.Infoln("[APP] macOS TUN IPv6 exclude widened to scoped ranges: %v -> %v", *field, widened)
			*field = widened
		}
	}
}
