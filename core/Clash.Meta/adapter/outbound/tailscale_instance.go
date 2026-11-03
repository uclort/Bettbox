//go:build with_gvisor && !no_tailscale

package outbound

import (
	"reflect"
	"sync"

	"github.com/metacubex/mihomo/log"
)

// BETTBOX-CUSTOM: 同一 state-dir 同时只允许一个 tsnet 运行，参数不变时跨配置重载复用。
//
// 配置重载会重新解析出站。参数没变时直接复用正在运行的实例，避免 tsnet 重连控制面、
// 重新拿 netmap 和打洞，期间 Tailnet 连接中断。实例按引用计数关闭：旧配置的
// autoCloseProxyAdapter 被 GC 回收时只减少计数，最后一个引用释放才真正关闭。
//
// 参数变化时新实例真正启动前先强制关掉仍在运行的旧实例，否则两者用同一份 node key，
// 控制面会把设备标成 Duplicate node key，新节点一直卡在 Starting。
var (
	tailscaleStateDirMu    sync.Mutex
	tailscaleStateDirOwner = map[string]*Tailscale{}
)

// reuseTailscale 返回同一 state-dir 下参数完全相同且仍在运行的实例，并增加引用计数。
func reuseTailscale(option TailscaleOption) *Tailscale {
	tailscaleStateDirMu.Lock()
	defer tailscaleStateDirMu.Unlock()
	prev := tailscaleStateDirOwner[option.StateDir]
	if prev == nil || prev.ctx.Err() != nil || prev.refs <= 0 || !reflect.DeepEqual(prev.option, option) {
		return nil
	}
	prev.refs++
	return prev
}

func (t *Tailscale) claimStateDir() {
	tailscaleStateDirMu.Lock()
	prev := tailscaleStateDirOwner[t.option.StateDir]
	tailscaleStateDirOwner[t.option.StateDir] = t
	tailscaleStateDirMu.Unlock()
	if prev != nil && prev != t {
		log.Infoln("[Tailscale](%s) closing previous instance sharing state dir", t.Name())
		_ = prev.shutdown()
	}
}

func (t *Tailscale) releaseStateDir() {
	tailscaleStateDirMu.Lock()
	if tailscaleStateDirOwner[t.option.StateDir] == t {
		delete(tailscaleStateDirOwner, t.option.StateDir)
	}
	tailscaleStateDirMu.Unlock()
}

// releaseRef 减少一次引用，返回是否已无引用需要真正关闭。
func (t *Tailscale) releaseRef() bool {
	tailscaleStateDirMu.Lock()
	defer tailscaleStateDirMu.Unlock()
	if t.refs > 0 {
		t.refs--
	}
	return t.refs == 0
}

// Warmup 在配置生效后后台启动节点，避免第一条 Tailnet 连接等待完整启动。
func (t *Tailscale) Warmup() {
	go func() {
		if err := t.start(); err != nil {
			log.Warnln("[Tailscale](%s) warmup failed: %v", t.Name(), err)
		}
	}()
}
