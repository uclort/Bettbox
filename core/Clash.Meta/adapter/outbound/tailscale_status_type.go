package outbound

import (
	"context"

	C "github.com/metacubex/mihomo/constant"
)

// BETTBOX-CUSTOM: 给 GUI 查询内置 Tailscale 节点状态与浏览器登录链接。
// tsnet 未填 auth-key 时会进入交互式登录，但登录链接只写在 Debug 日志里，这里直接读出来。
// BETTBOX-CUSTOM: Tailscale 节点每次进入 Running 时调用（参数为节点名），由 Bettbox 内核设置。
// 放在无构建标签的文件里，不带 with_gvisor 编译时内核也能设置。
var TailscaleOnRunning func(name string)

type TailscaleStatus struct {
	State     string   `json:"state"`
	AuthURL   string   `json:"auth-url,omitempty"`
	DNSName   string   `json:"dns-name,omitempty"`
	LoginName string   `json:"login-name,omitempty"`
	IPs       []string `json:"ips,omitempty"`
	Error     string   `json:"error,omitempty"`

	Peers []TailscalePeer `json:"peers,omitempty"`
}

// TailscalePeer 是 Tailnet 中其他设备的概要，供 GUI 展示设备列表。
type TailscalePeer struct {
	HostName string   `json:"host-name"`
	DNSName  string   `json:"dns-name,omitempty"`
	OS       string   `json:"os,omitempty"`
	IPs      []string `json:"ips,omitempty"`
	Online   bool     `json:"online"`
	Active   bool     `json:"active,omitempty"`
	ExitNode bool     `json:"exit-node,omitempty"`
	CurAddr  string   `json:"cur-addr,omitempty"`
	Relay    string   `json:"relay,omitempty"`
}

type TailscaleNode interface {
	Status(ctx context.Context) TailscaleStatus
	Logout(ctx context.Context) error
	// Warmup 后台启动节点，配置生效后调用，不阻塞。
	Warmup()
	// DNSNames 在节点 Running 时返回本节点与其他设备的 MagicDNS 名，否则返回 nil。
	// BETTBOX-CUSTOM: 内核 macOS 版用它检查系统 DNS 缓存，没有登录等副作用。
	DNSNames(ctx context.Context) []string
}

// AsTailscaleNode 解开 parser 外层的 autoCloseProxyAdapter，取出内置 Tailscale 节点。
func AsTailscaleNode(adapter C.ProxyAdapter) (TailscaleNode, bool) {
	if wrapped, ok := adapter.(*autoCloseProxyAdapter); ok {
		adapter = wrapped.ProxyAdapter
	}
	node, ok := adapter.(TailscaleNode)
	return node, ok
}
