//go:build with_gvisor && !no_tailscale

package outbound

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"reflect"
	"strings"
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

// claimStateDir 关掉共用同一 state-dir 的旧实例；同名节点换了 state-dir（如登录方式与
// Auth Key 方式切换）也关掉旧实例，避免等 GC 期间两台设备同时在线。
func (t *Tailscale) claimStateDir() {
	tailscaleStateDirMu.Lock()
	var prevs []*Tailscale
	for dir, prev := range tailscaleStateDirOwner {
		if prev == t || (dir != t.option.StateDir && prev.option.Name != t.option.Name) {
			continue
		}
		prevs = append(prevs, prev)
	}
	tailscaleStateDirOwner[t.option.StateDir] = t
	tailscaleStateDirMu.Unlock()
	for _, prev := range prevs {
		log.Infoln("[Tailscale](%s) closing previous instance (state dir %s)", t.Name(), prev.option.StateDir)
		_ = prev.shutdown()
	}
}

// prepareAuthKeyState 在 Auth Key 方式下保证节点身份与当前 key 对应：key 变了就清掉旧身份，
// 启动时用新 key 重新注册。tsnet 已登录时会忽略 auth-key，不清理的话改 key 不生效。
// 只记录 key 的哈希，不落明文。
func (t *Tailscale) prepareAuthKeyState() {
	if t.option.AuthKey == "" {
		return
	}
	sum := sha256.Sum256([]byte(t.option.AuthKey))
	want := hex.EncodeToString(sum[:])
	marker := filepath.Join(t.option.StateDir, tailscaleAuthKeyMarker)
	if got, err := os.ReadFile(marker); err == nil && strings.TrimSpace(string(got)) == want {
		return
	}
	for _, name := range []string{"tailscaled.state", "profile-data"} {
		path := filepath.Join(t.option.StateDir, name)
		if _, err := os.Stat(path); err == nil {
			log.Infoln("[Tailscale](%s) auth-key changed, clearing previous identity", t.Name())
			_ = os.RemoveAll(path)
		}
	}
	if err := os.MkdirAll(t.option.StateDir, 0o700); err == nil {
		_ = os.WriteFile(marker, []byte(want), 0o600)
	}
}

const tailscaleAuthKeyMarker = "bettbox-auth-key.sha256"

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
