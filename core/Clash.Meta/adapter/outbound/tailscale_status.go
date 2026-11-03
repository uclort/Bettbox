//go:build with_gvisor && !no_tailscale

package outbound

import (
	"context"
	"strings"
	"time"

	"github.com/metacubex/tailscale/ipn"
)

const tailscaleAuthURLWait = 8 * time.Second

// Status 会按需启动节点；处于 NeedsLogin 时主动发起交互式登录并等待控制面下发登录链接。
func (t *Tailscale) Status(ctx context.Context) TailscaleStatus {
	if err := t.ensureStarted(ctx); err != nil {
		return TailscaleStatus{State: ipn.NoState.String(), Error: err.Error()}
	}
	lc, err := t.server.LocalClient()
	if err != nil {
		return TailscaleStatus{State: ipn.NoState.String(), Error: err.Error()}
	}
	deadline := time.Now().Add(tailscaleAuthURLWait)
	requested := false
	for {
		st, err := lc.StatusWithoutPeers(ctx)
		if err != nil {
			return TailscaleStatus{State: ipn.NoState.String(), Error: err.Error()}
		}
		status := TailscaleStatus{State: st.BackendState, AuthURL: st.AuthURL}
		for _, ip := range st.TailscaleIPs {
			status.IPs = append(status.IPs, ip.String())
		}
		if st.Self != nil {
			status.DNSName = strings.TrimSuffix(st.Self.DNSName, ".")
			if profile, ok := st.User[st.Self.UserID]; ok {
				status.LoginName = profile.LoginName
			}
		}
		if st.BackendState != ipn.NeedsLogin.String() || status.AuthURL != "" || time.Now().After(deadline) {
			return status
		}
		// 退出登录后 tsnet 不会自动重新发起交互式登录，这里补一次。
		if !requested {
			requested = true
			if err := lc.StartLoginInteractive(ctx); err != nil {
				status.Error = err.Error()
				return status
			}
		}
		select {
		case <-ctx.Done():
			return status
		case <-time.After(300 * time.Millisecond):
		}
	}
}

// Logout 退出当前账号；下次查询状态时会生成新的登录链接，用于切换账号。
func (t *Tailscale) Logout(ctx context.Context) error {
	if err := t.ensureStarted(ctx); err != nil {
		return err
	}
	lc, err := t.server.LocalClient()
	if err != nil {
		return err
	}
	return lc.Logout(ctx)
}
