//go:build darwin

package main

import (
	"os"
	"os/exec"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/log"
)

// BETTBOX-CUSTOM: Tailscale 节点进入 Running 后清 macOS 系统 DNS 缓存。节点掉线（包括更新 Bettbox 时
// TUN 临时关闭、系统 DNS 回落到公共 DNS）期间 *.ts.net 会解析失败，mDNSResponder 把「无记录」缓存
// 几分钟到约 20 分钟；节点恢复后 Rex 等应用仍解析不到 Tailnet 主机（实测 dns-sd 显示 No Such Record）。
// BettboxCore 在 macOS 以 root 运行，可以直接清。
//
// 节点刚 Running 时 MagicDNS 可能还有短暂失败（应用正好在这次重试），产生的否定结果会再次被缓存，
// 所以启动窗口内（+10s、+40s）各补清一次；多个节点几乎同时连上只安排一轮。
var tailscaleDNSFlushScheduled atomic.Bool

const (
	tailscaleDNSFlushRetry1 = 10 * time.Second
	tailscaleDNSFlushRetry2 = 30 * time.Second
)

func init() {
	outbound.TailscaleOnRunning = scheduleSystemDNSFlush
}

func scheduleSystemDNSFlush(name string) {
	if os.Geteuid() != 0 {
		return
	}
	if !tailscaleDNSFlushScheduled.CompareAndSwap(false, true) {
		return
	}
	go func() {
		defer tailscaleDNSFlushScheduled.Store(false)
		flushSystemDNSCache()
		log.Infoln("[Tailscale](%s) running, flushed system DNS cache", name)
		time.Sleep(tailscaleDNSFlushRetry1)
		flushSystemDNSCache()
		time.Sleep(tailscaleDNSFlushRetry2)
		flushSystemDNSCache()
		log.Infoln("[Tailscale](%s) flushed system DNS cache again after startup", name)
	}()
}

// flushSystemDNSCache 清 macOS 系统 DNS 缓存（所有解析器的缓存，不只是 Tailnet 域名）。
// 也用于「刷新 DNS 缓存」操作，用户不必再手动执行 sudo killall -HUP mDNSResponder。
func flushSystemDNSCache() {
	_ = exec.Command("/usr/bin/dscacheutil", "-flushcache").Run()
	if err := exec.Command("/usr/bin/killall", "-HUP", "mDNSResponder").Run(); err != nil {
		log.Warnln("[Tailscale] flush system DNS cache failed: %v", err)
	}
}
