//go:build with_gvisor && !no_tailscale

package outbound

import (
	"context"
	"sort"
	"strings"
	"time"

	"github.com/metacubex/tailscale/ipn"
	"github.com/metacubex/tailscale/ipn/ipnstate"
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
		st, err := lc.Status(ctx)
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
		if st.BackendState == ipn.Running.String() {
			status.Peers = tailscalePeers(st)
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

// tailscalePeers 在线设备优先，同状态按名称排序。
func tailscalePeers(st *ipnstate.Status) []TailscalePeer {
	peers := make([]TailscalePeer, 0, len(st.Peer))
	for _, p := range st.Peer {
		peer := TailscalePeer{
			HostName: p.HostName,
			DNSName:  strings.TrimSuffix(p.DNSName, "."),
			OS:       p.OS,
			Online:   p.Online,
			Active:   p.Active,
			ExitNode: p.ExitNode,
			CurAddr:  p.CurAddr,
			Relay:    p.Relay,
		}
		for _, ip := range p.TailscaleIPs {
			peer.IPs = append(peer.IPs, ip.String())
		}
		peers = append(peers, peer)
	}
	sort.SliceStable(peers, func(i, j int) bool {
		if peers[i].Online != peers[j].Online {
			return peers[i].Online
		}
		return peers[i].DNSName < peers[j].DNSName
	})
	return peers
}
