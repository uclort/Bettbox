package main

import (
	"strings"

	"github.com/metacubex/tls"
)

// BETTBOX-CUSTOM: 连 Tailscale 控制面、登录与 DERP 时不发后量子（ML-KEM）密钥交换。
// 部分网络会丢弃发往 *.tailscale.com、带 X25519MLKEM768 的 ClientHello（TCP 能连上，握手无响应），
// 内置节点表现为 fetch control key 超时、DERP 不通；只用经典曲线即可正常握手。
var tailscaleClassicCurves = []tls.CurveID{tls.X25519, tls.CurveP256, tls.CurveP384}

func tailscaleCurvePreferences(serverName string) []tls.CurveID {
	host := strings.TrimSuffix(strings.ToLower(serverName), ".")
	for _, domain := range []string{"tailscale.com", "tailscale.io"} {
		if host == domain || strings.HasSuffix(host, "."+domain) {
			return tailscaleClassicCurves
		}
	}
	return nil
}

func init() {
	tls.ClientCurvePreferencesHook = tailscaleCurvePreferences
}
