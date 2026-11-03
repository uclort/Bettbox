//go:build with_gvisor && !no_tailscale

package outbound

import (
	"sync"

	"github.com/metacubex/mihomo/log"
)

// BETTBOX-CUSTOM: 同一 state-dir 同时只允许一个 tsnet 运行。
// 配置重载后旧出站要等 GC 触发 autoCloseProxyAdapter 的 finalizer 才会关闭，
// 期间新出站用同一份 node key 启动，控制面会把设备标成 Duplicate node key，新节点一直卡在 Starting。
// 新实例真正启动前先关掉仍在运行的旧实例。
var (
	tailscaleStateDirMu    sync.Mutex
	tailscaleStateDirOwner = map[string]*Tailscale{}
)

func (t *Tailscale) claimStateDir() {
	tailscaleStateDirMu.Lock()
	prev := tailscaleStateDirOwner[t.option.StateDir]
	tailscaleStateDirOwner[t.option.StateDir] = t
	tailscaleStateDirMu.Unlock()
	if prev != nil && prev != t {
		log.Infoln("[Tailscale](%s) closing previous instance sharing state dir", t.Name())
		_ = prev.Close()
	}
}

func (t *Tailscale) releaseStateDir() {
	tailscaleStateDirMu.Lock()
	if tailscaleStateDirOwner[t.option.StateDir] == t {
		delete(tailscaleStateDirOwner, t.option.StateDir)
	}
	tailscaleStateDirMu.Unlock()
}
