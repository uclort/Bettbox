//go:build darwin

package main

import (
	"os"
	"os/exec"
	"sync"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/log"
)

// BETTBOX-CUSTOM: Tailscale 节点进入 Running 后清 macOS 系统 DNS 缓存。节点掉线期间 *.ts.net 返回
// SERVFAIL，mDNSResponder 会把「无记录」缓存约 20 分钟，节点恢复后 Rex 等应用仍解析不到 Tailnet 主机
// （实测 dns-sd 显示 No Such Record、TTL 1219）。BettboxCore 在 macOS 以 root 运行，可以直接清。
// 多个节点几乎同时连上时只清一次。
var (
	tailscaleDNSFlushMu   sync.Mutex
	tailscaleDNSFlushLast time.Time
)

const tailscaleDNSFlushInterval = 5 * time.Second

func init() {
	outbound.TailscaleOnRunning = flushSystemDNSForTailscale
}

func flushSystemDNSForTailscale(name string) {
	if os.Geteuid() != 0 {
		return
	}
	tailscaleDNSFlushMu.Lock()
	if time.Since(tailscaleDNSFlushLast) < tailscaleDNSFlushInterval {
		tailscaleDNSFlushMu.Unlock()
		return
	}
	tailscaleDNSFlushLast = time.Now()
	tailscaleDNSFlushMu.Unlock()
	_ = exec.Command("/usr/bin/dscacheutil", "-flushcache").Run()
	if err := exec.Command("/usr/bin/killall", "-HUP", "mDNSResponder").Run(); err != nil {
		log.Warnln("[Tailscale](%s) flush system DNS cache failed: %v", name, err)
		return
	}
	log.Infoln("[Tailscale](%s) running, flushed system DNS cache", name)
}
