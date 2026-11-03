package outbound

import (
	"context"

	C "github.com/metacubex/mihomo/constant"
)

// BETTBOX-CUSTOM: 给 GUI 查询内置 Tailscale 节点状态与浏览器登录链接。
// tsnet 未填 auth-key 时会进入交互式登录，但登录链接只写在 Debug 日志里，这里直接读出来。
type TailscaleStatus struct {
	State     string   `json:"state"`
	AuthURL   string   `json:"auth-url,omitempty"`
	DNSName   string   `json:"dns-name,omitempty"`
	LoginName string   `json:"login-name,omitempty"`
	IPs       []string `json:"ips,omitempty"`
	Error     string   `json:"error,omitempty"`
}

type TailscaleNode interface {
	Status(ctx context.Context) TailscaleStatus
	Logout(ctx context.Context) error
}

// AsTailscaleNode 解开 parser 外层的 autoCloseProxyAdapter，取出内置 Tailscale 节点。
func AsTailscaleNode(adapter C.ProxyAdapter) (TailscaleNode, bool) {
	if wrapped, ok := adapter.(*autoCloseProxyAdapter); ok {
		adapter = wrapped.ProxyAdapter
	}
	node, ok := adapter.(TailscaleNode)
	return node, ok
}
