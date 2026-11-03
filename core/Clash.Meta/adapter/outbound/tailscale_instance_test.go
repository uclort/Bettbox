//go:build with_gvisor && !no_tailscale

package outbound

import (
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
