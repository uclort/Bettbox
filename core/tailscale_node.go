package main

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/tunnel"
)

// BETTBOX-CUSTOM: GUI 查询内置 Tailscale 节点状态、获取浏览器登录链接、退出登录。
const tailscaleNodeTimeout = 30 * time.Second

func findTailscaleNode(name string) (outbound.TailscaleNode, error) {
	if !isInit {
		return nil, fmt.Errorf("core not initialized")
	}
	proxy, ok := tunnel.Proxies()[name]
	if !ok {
		return nil, fmt.Errorf("Tailscale node %q not found", name)
	}
	node, ok := outbound.AsTailscaleNode(proxy.Adapter())
	if !ok {
		return nil, fmt.Errorf("%q is not a Tailscale node", name)
	}
	return node, nil
}

func handleGetTailscaleStatus(name string) string {
	var status outbound.TailscaleStatus
	if node, err := findTailscaleNode(name); err != nil {
		status = outbound.TailscaleStatus{State: "NoState", Error: err.Error()}
	} else {
		ctx, cancel := context.WithTimeout(context.Background(), tailscaleNodeTimeout)
		defer cancel()
		status = node.Status(ctx)
	}
	data, _ := json.Marshal(status)
	return string(data)
}

func handleTailscaleLogout(name string) string {
	node, err := findTailscaleNode(name)
	if err != nil {
		return err.Error()
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleNodeTimeout)
	defer cancel()
	if err := node.Logout(ctx); err != nil {
		return err.Error()
	}
	return ""
}
