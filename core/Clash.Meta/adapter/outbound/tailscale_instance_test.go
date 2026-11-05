//go:build with_gvisor && !no_tailscale

package outbound

import (
	"os"
	"path/filepath"
	"testing"
)

// BETTBOX-CUSTOM: 重载后新实例启动时必须关掉共用 state-dir 的旧实例，不同 state-dir 互不影响。
func TestTailscaleClaimStateDirClosesPrevious(t *testing.T) {
	newNode := func(name, dir string) *Tailscale {
		node, err := NewTailscale(TailscaleOption{Name: name, StateDir: dir})
		if err != nil {
			t.Fatalf("NewTailscale(%s): %v", name, err)
		}
		t.Cleanup(func() { _ = node.Close() })
		return node
	}
	oldNode := newNode("ts", "tailscale-claim-test/a")
	other := newNode("ts-other", "tailscale-claim-test/b")
	newer := newNode("ts", "tailscale-claim-test/a")

	oldNode.claimStateDir()
	other.claimStateDir()
	newer.claimStateDir()

	if oldNode.ctx.Err() == nil {
		t.Fatal("previous instance sharing the state dir should be closed")
	}
	if newer.ctx.Err() != nil || other.ctx.Err() != nil {
		t.Fatal("current instance and instance with another state dir must stay open")
	}
	if err := oldNode.Close(); err != nil {
		t.Fatalf("second Close should be a no-op: %v", err)
	}

	tailscaleStateDirMu.Lock()
	owner := tailscaleStateDirOwner[newer.option.StateDir]
	tailscaleStateDirMu.Unlock()
	if owner != newer {
		t.Fatal("closing the old instance must not release the new owner")
	}
}

// BETTBOX-CUSTOM: 参数不变的重载复用运行中的实例，旧配置释放引用不关闭；参数变化才换新实例。
func TestTailscaleReuseAcrossReload(t *testing.T) {
	accept := true
	option := TailscaleOption{Name: "ts", StateDir: "tailscale-reuse-test/a", Hostname: "mac-bettbox", AcceptRoutes: &accept}
	newNode := func(opt TailscaleOption) *Tailscale {
		node, err := NewTailscale(opt)
		if err != nil {
			t.Fatalf("NewTailscale: %v", err)
		}
		return node
	}

	running := newNode(option)
	t.Cleanup(func() { _ = running.shutdown() })
	running.claimStateDir() // 模拟已启动

	sameAccept := true
	same := option
	same.AcceptRoutes = &sameAccept // 指针不同、值相同也应复用
	reloaded := newNode(same)
	if reloaded != running {
		t.Fatal("reload with identical options should reuse the running instance")
	}

	// BETTBOX-CUSTOM: Auth Key 重新注册后标记不再复用，参数相同也要新建实例。
	running.noReuse.Store(true)
	fresh := newNode(same)
	if fresh == running {
		t.Fatal("instance marked noReuse must not be reused")
	}
	_ = fresh.shutdown()
	running.noReuse.Store(false)

	if err := running.Close(); err != nil { // 旧配置被回收
		t.Fatalf("Close: %v", err)
	}
	if running.ctx.Err() != nil {
		t.Fatal("releasing the old config reference must keep the shared instance running")
	}

	changed := option
	changed.Hostname = "renamed"
	replaced := newNode(changed)
	t.Cleanup(func() { _ = replaced.shutdown() })
	if replaced == running {
		t.Fatal("changed options must create a new instance")
	}
	replaced.claimStateDir()
	if running.ctx.Err() == nil {
		t.Fatal("new instance with changed options must close the previous one even if still referenced")
	}

	if again := newNode(option); again == running {
		t.Fatal("closed instance must not be reused")
	} else {
		_ = again.shutdown()
	}
}

// 未被复用的实例最后一次 Close 真正关闭。
func TestTailscaleCloseReleasesLastRef(t *testing.T) {
	node, err := NewTailscale(TailscaleOption{Name: "ts", StateDir: "tailscale-reuse-test/b"})
	if err != nil {
		t.Fatal(err)
	}
	node.claimStateDir()
	reused, _ := NewTailscale(TailscaleOption{Name: "ts", StateDir: "tailscale-reuse-test/b"})
	if reused != node {
		t.Fatal("expected reuse")
	}
	_ = node.Close()
	_ = reused.Close()
	if node.ctx.Err() == nil {
		t.Fatal("instance should close after the last reference is released")
	}
	tailscaleStateDirMu.Lock()
	_, owned := tailscaleStateDirOwner[node.option.StateDir]
	tailscaleStateDirMu.Unlock()
	if owned {
		t.Fatal("closed instance must release the state dir")
	}
}

// BETTBOX-CUSTOM: 登录方式与 Auth Key 方式用不同 state-dir，切换时同名旧节点必须立即关闭。
func TestTailscaleClaimClosesSameNameOtherDir(t *testing.T) {
	login, _ := NewTailscale(TailscaleOption{Name: "ts-mode", StateDir: "tailscale-mode-test/login"})
	t.Cleanup(func() { _ = login.shutdown() })
	login.claimStateDir()
	key, _ := NewTailscale(TailscaleOption{Name: "ts-mode", StateDir: "tailscale-mode-test/key", AuthKey: "tskey-a"})
	t.Cleanup(func() { _ = key.shutdown() })
	key.claimStateDir()
	if login.ctx.Err() == nil {
		t.Fatal("switching auth mode must close the node using the other state dir")
	}
	if key.ctx.Err() != nil {
		t.Fatal("new node must stay open")
	}
}

// BETTBOX-CUSTOM: Auth Key 变化时清掉旧身份，相同 key 保留。
func TestTailscaleAuthKeyStateReset(t *testing.T) {
	node, _ := NewTailscale(TailscaleOption{Name: "ts-key", StateDir: "tailscale-key-test", AuthKey: "tskey-a"})
	t.Cleanup(func() { _ = node.shutdown() })
	dir := t.TempDir()
	node.option.StateDir = dir
	state := filepath.Join(dir, "tailscaled.state")
	write := func() {
		if err := os.WriteFile(state, []byte("{}"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	exists := func() bool { _, err := os.Stat(state); return err == nil }

	write() // 没有标记的旧状态视为来源不明，清掉
	node.prepareAuthKeyState()
	if exists() {
		t.Fatal("state without marker must be cleared")
	}
	write()
	node.prepareAuthKeyState()
	if !exists() {
		t.Fatal("same auth-key must keep the registered identity")
	}
	node.option.AuthKey = "tskey-b"
	node.prepareAuthKeyState()
	if exists() {
		t.Fatal("changed auth-key must clear the previous identity")
	}
	if b, _ := os.ReadFile(filepath.Join(dir, tailscaleAuthKeyMarker)); len(b) != 64 {
		t.Fatal("marker should store a sha256 hex digest, not the key")
	}
}
