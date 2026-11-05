//go:build with_gvisor && !no_tailscale

package outbound

import (
	"context"
	"sort"
	"strings"
	"time"

	"github.com/metacubex/mihomo/log"
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
		needsLogin := st.BackendState == ipn.NeedsLogin.String()
		// BETTBOX-CUSTOM: Auth Key 方式只认 key，不给浏览器登录链接；注册失败时返回控制面的原因。
		if t.option.AuthKey != "" {
			status.AuthURL = ""
			tried := false
			if needsLogin {
				var err error
				if tried, err = t.tryAuthKeyLogin(ctx); err != nil {
					status.Error = err.Error()
					return status
				}
			}
			if !tried && (!needsLogin || time.Now().After(deadline)) {
				if needsLogin {
					// 优先给控制面的注册错误；没有时才用健康提示（未登录时 DERP 连不上属于连带现象）。
					if msg, _ := t.authKeyLoginErr.Load().(string); msg != "" {
						status.Error = msg
					} else {
						status.Error = strings.Join(st.Health, "; ")
					}
				}
				return status
			}
		} else {
			if !needsLogin || status.AuthURL != "" || time.Now().After(deadline) {
				return status
			}
			// 退出登录后 tsnet 不会自动重新发起交互式登录，这里补一次。
			if !requested {
				requested = true
				t.restoreLoginPrefs(ctx)
				if err := lc.StartLoginInteractive(ctx); err != nil {
					status.Error = err.Error()
					return status
				}
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
	if err := lc.Logout(ctx); err != nil {
		return err
	}
	// BETTBOX-CUSTOM: Auth Key 方式下退出即「重新注册」，下次查询状态时用 key 重新注册。
	t.authKeyLoginAt.Store(0)
	t.authKeyLoginErr.Store("")
	return nil
}

// BETTBOX-CUSTOM: Auth Key 自动重新注册的节流间隔。
const tailscaleAuthKeyRetry = 20 * time.Second

// tryAuthKeyLogin 在节流间隔外用 key 重新注册一次，返回是否真的尝试了。
func (t *Tailscale) tryAuthKeyLogin(ctx context.Context) (bool, error) {
	if t.option.AuthKey == "" {
		return false, nil
	}
	now := time.Now().UnixNano()
	last := t.authKeyLoginAt.Load()
	if last != 0 && time.Duration(now-last) < tailscaleAuthKeyRetry {
		return false, nil
	}
	if !t.authKeyLoginAt.CompareAndSwap(last, now) {
		return false, nil
	}
	log.Infoln("[Tailscale](%s) needs login, registering with auth-key", t.Name())
	err := t.loginWithAuthKey(ctx)
	if err != nil {
		t.authKeyLoginErr.Store(err.Error())
		log.Warnln("[Tailscale](%s) auth-key login failed: %v", t.Name(), err)
	}
	return true, err
}

// retryAuthKeyLogin 在后台等到节流间隔结束后重试，仍需登录才注册；节点关闭或已登录即停。
func (t *Tailscale) retryAuthKeyLogin() {
	for attempt := 0; attempt < 3; attempt++ {
		if wait := tailscaleAuthKeyRetry - time.Duration(time.Now().UnixNano()-t.authKeyLoginAt.Load()); wait > 0 {
			select {
			case <-t.ctx.Done():
				return
			case <-time.After(wait):
			}
		}
		lc, err := t.server.LocalClient()
		if err != nil {
			return
		}
		ctx, cancel := context.WithTimeout(t.ctx, 30*time.Second)
		st, err := lc.StatusWithoutPeers(ctx)
		if err != nil || st.BackendState != ipn.NeedsLogin.String() {
			cancel()
			return
		}
		tried, _ := t.tryAuthKeyLogin(ctx)
		cancel()
		if tried {
			return
		}
	}
}

// BETTBOX-CUSTOM: 退出登录会删掉当前 profile，新 profile 的偏好是默认值；重新登录前补回设备名、
// 控制面地址与子网路由等设置，否则设备名会变成系统主机名。
func (t *Tailscale) restoreLoginPrefs(ctx context.Context) {
	lc, err := t.server.LocalClient()
	if err != nil {
		return
	}
	mp := &ipn.MaskedPrefs{}
	if t.option.Hostname != "" {
		mp.Hostname, mp.HostnameSet = t.option.Hostname, true
	}
	if t.option.ControlURL != "" {
		mp.ControlURL, mp.ControlURLSet = t.option.ControlURL, true
	}
	if mp.HostnameSet || mp.ControlURLSet {
		_, _ = lc.EditPrefs(ctx, mp)
	}
	_ = t.applyPrefs(ctx)
}

// BETTBOX-CUSTOM: 进程内用 auth-key 重新注册（与 tsnet 启动时的流程一致），不需要重启节点。
func (t *Tailscale) loginWithAuthKey(ctx context.Context) error {
	lc, err := t.server.LocalClient()
	if err != nil {
		return err
	}
	prefs, err := lc.GetPrefs(ctx)
	if err != nil {
		return err
	}
	prefs.WantRunning = true
	prefs.LoggedOut = false
	if t.option.Hostname != "" {
		prefs.Hostname = t.option.Hostname
	}
	if t.option.ControlURL != "" {
		prefs.ControlURL = t.option.ControlURL
	}
	if err := lc.Start(ctx, ipn.Options{UpdatePrefs: prefs, AuthKey: t.option.AuthKey}); err != nil {
		return err
	}
	return t.applyPrefs(ctx)
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
