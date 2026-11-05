//go:build darwin

package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

// BETTBOX-CUSTOM: 内置 Tailscale 节点连上后清理 macOS 系统 DNS 缓存。
//
// 节点掉线（包括更新 Bettbox 时 TUN 临时关闭、系统 DNS 回落到公共 DNS）期间 *.ts.net 会解析失败。
// ts.net 的 SOA 否定 TTL 是 300 秒，公共 DNS 返回的 NXDOMAIN 会被 mDNSResponder 缓存约 5 分钟；
// 节点恢复后内核对 *.ts.net 已能解析（TUN 内的 DNS 正常），但应用走系统解析仍拿到「无记录」，
// Rex 等依赖 Tailnet 的应用因此连不上，面板里也看不到它们的连接。
//
// 只在节点进入 Running 时按固定时间清几次并不可靠：否定缓存窗口内任何一次失败查询（应用重试、
// MagicDNS 刚连上时短暂失败）都会重新写入否定结果。所以这里在配置生效后持续检查：用系统解析器
// 查询本节点和其他设备的 MagicDNS 名，查不到就再清一次，直到恢复正常或窗口结束。
const (
	// 覆盖 TUN 关闭期间写入的否定缓存（300 秒）以及应用的重试。
	tailscaleDNSWatchWindow   = 10 * time.Minute
	tailscaleDNSPollInterval  = 2 * time.Second
	tailscaleDNSProbeInterval = 10 * time.Second
	tailscaleDNSProbeSlow     = 30 * time.Second
	tailscaleDNSFastUntil     = 2 * time.Minute
	tailscaleDNSProbeTimeout  = 4 * time.Second
	tailscaleDNSMaxFailures   = 10
	// 连续这么多次清理都不生效时，改为重启 mDNSResponder（launchd 会立即拉起，缓存彻底清空）。
	tailscaleDNSRestartAfter = 3
)

var (
	dnsWatchMu  sync.Mutex
	dnsWatchEnd time.Time
	dnsWatching bool
)

// startTailscaleDNSWatch 在配置生效后调用（内置节点会同时 warmup），扩展检查窗口并在需要时启动后台检查。
func startTailscaleDNSWatch() {
	if os.Geteuid() != 0 {
		dnsWatchLog(log.WARNING, "[Tailscale] 需要 root 权限才能清理系统 DNS 缓存，已跳过")
		return
	}
	if !hasTailscaleNode() {
		return
	}
	dnsWatchMu.Lock()
	if end := time.Now().Add(tailscaleDNSWatchWindow); end.After(dnsWatchEnd) {
		dnsWatchEnd = end
	}
	active := dnsWatching
	dnsWatching = true
	dnsWatchMu.Unlock()
	if !active {
		go runTailscaleDNSWatch()
	}
}

func runTailscaleDNSWatch() {
	// 等内置节点进入 Running（MagicDNS 名可用）。配置刚生效时节点还在连接。
	var names []string
	for dnsWatchAlive() {
		if names = tailnetDNSNames(); len(names) > 0 {
			break
		}
		time.Sleep(tailscaleDNSPollInterval)
	}
	if len(names) == 0 {
		return
	}

	// 进入 Running 时先无条件清一次：TUN 恢复前的否定结果一定已经写进缓存。
	err := flushSystemDNSCache()
	dnsWatchLog(log.INFO, "[Tailscale] 开始检查 macOS 系统 DNS 缓存（%d 个域名，清缓存%s）", len(names), flushResult(err))

	poisoned := false
	failures := 0
	flushes := 0
	healthy := false
	start := time.Now()
	for dnsWatchAlive() {
		// 设备列表可能随配置变化，每轮重新取；节点断开时先等它回来，避免把「没连上」当成缓存问题。
		latest := tailnetDNSNames()
		if len(latest) == 0 {
			time.Sleep(tailscaleDNSPollInterval)
			continue
		}
		names = latest
		if bad := probeSystemDNS(names); bad == "" {
			failures = 0
			if !healthy {
				healthy = true
				if poisoned {
					poisoned = false
					dnsWatchLog(log.INFO, "[Tailscale] 系统 DNS 已恢复正常（共清理 %d 次）", flushes)
				} else {
					dnsWatchLog(log.INFO, "[Tailscale] 系统 DNS 正常")
				}
			}
		} else {
			healthy = false
			err := flushSystemDNSCache()
			flushes++
			failures++
			if failures == tailscaleDNSRestartAfter {
				if err := restartMDNSResponder(); err != nil {
					dnsWatchLog(log.WARNING, "[Tailscale] 重启 mDNSResponder 失败：%v", err)
				} else {
					dnsWatchLog(log.WARNING, "[Tailscale] 清理系统 DNS 缓存未生效，已重启 mDNSResponder")
				}
			}
			if failures > tailscaleDNSMaxFailures {
				dnsWatchLog(log.WARNING, "[Tailscale] 系统 DNS 仍解析不到 %s，停止清理（可能没有开启虚拟网卡）", bad)
				dnsWatchOK()
				return
			}
			if !poisoned {
				poisoned = true
				dnsWatchLog(log.WARNING, "[Tailscale] 系统 DNS 仍解析不到 %s，再清一次系统缓存（%s）", bad, flushResult(err))
			}
		}
		wait := tailscaleDNSProbeSlow
		if time.Since(start) < tailscaleDNSFastUntil {
			wait = tailscaleDNSProbeInterval
		}
		time.Sleep(wait)
	}
}

func dnsWatchAlive() bool {
	dnsWatchMu.Lock()
	defer dnsWatchMu.Unlock()
	if time.Now().Before(dnsWatchEnd) {
		return true
	}
	dnsWatching = false
	return false
}

func dnsWatchOK() {
	dnsWatchMu.Lock()
	dnsWatching = false
	dnsWatchMu.Unlock()
}

func hasTailscaleNode() bool {
	for _, proxy := range tunnel.Proxies() {
		if _, ok := outbound.AsTailscaleNode(proxy.Adapter()); ok {
			return true
		}
	}
	return false
}

// tailnetDNSNames 返回一个已连上的内置节点的本机与其他设备 MagicDNS 名。
func tailnetDNSNames() []string {
	for _, proxy := range tunnel.Proxies() {
		node, ok := outbound.AsTailscaleNode(proxy.Adapter())
		if !ok {
			continue
		}
		ctx, cancel := context.WithTimeout(context.Background(), tailscaleDNSProbeTimeout)
		names := node.DNSNames(ctx)
		cancel()
		if len(names) > 0 {
			return names
		}
	}
	return nil
}

// probeSystemDNS 用系统解析器（mDNSResponder）查询 MagicDNS 名，返回第一个查不到的名字。
// dscacheutil 走的是和普通应用相同的系统解析路径，查到时输出 ip_address 行。
func probeSystemDNS(names []string) string {
	for _, name := range names {
		ctx, cancel := context.WithTimeout(context.Background(), tailscaleDNSProbeTimeout)
		out, err := exec.CommandContext(ctx, "/usr/bin/dscacheutil", "-q", "host", "-a", "name", name).Output()
		cancel()
		if err == nil && strings.Contains(string(out), "ip_address") {
			continue
		}
		return name
	}
	return ""
}

// flushSystemDNSCache 清 macOS 系统 DNS 缓存（所有解析器的缓存，不只是 Tailnet 域名）。
// 也用于「刷新 DNS 缓存」操作，用户不必再手动执行 sudo killall -HUP mDNSResponder。
func flushSystemDNSCache() error {
	if os.Geteuid() != 0 {
		return fmt.Errorf("not running as root")
	}
	_ = exec.Command("/usr/bin/dscacheutil", "-flushcache").Run()
	return signalMDNSResponder(syscall.SIGHUP)
}

// signalMDNSResponder 给 mDNSResponder 发信号。用 pgrep 找 pid、由本进程（setuid root）直接发信号，
// 而不是执行 killall：killall 作为子进程不一定继承 root 权限，失败时也没有任何可见结果。
func signalMDNSResponder(sig syscall.Signal) error {
	out, err := exec.Command("/usr/bin/pgrep", "-x", "mDNSResponder").Output()
	if err != nil {
		return fmt.Errorf("pgrep mDNSResponder: %w", err)
	}
	signaled := false
	for _, field := range strings.Fields(string(out)) {
		pid, err := strconv.Atoi(field)
		if err != nil || pid <= 1 {
			continue
		}
		if err := syscall.Kill(pid, sig); err != nil {
			return fmt.Errorf("kill %d: %w", pid, err)
		}
		signaled = true
	}
	if !signaled {
		return fmt.Errorf("mDNSResponder not found")
	}
	return nil
}

func restartMDNSResponder() error {
	if err := signalMDNSResponder(syscall.SIGTERM); err != nil {
		return err
	}
	return nil
}

func flushResult(err error) string {
	if err != nil {
		return "失败：" + err.Error()
	}
	return "成功"
}

// dnsWatchLog 同时写日志历史和日志流：只有打开「日志」页时才有人订阅日志流，
// 写进历史可以让用户之后在日志页看到清理过程。
func dnsWatchLog(level log.LogLevel, format string, args ...any) {
	msg := fmt.Sprintf(format, args...)
	recordLogHistory(logEntry{
		Event: log.Event{LogLevel: level, Payload: msg},
		Time:  time.Now().UnixMilli(),
	})
	if level >= log.WARNING {
		log.Warnln("%s", msg)
	} else {
		log.Infoln("%s", msg)
	}
}
