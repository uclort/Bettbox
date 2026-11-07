package tls

// BETTBOX-CUSTOM: 本目录是 github.com/metacubex/tls v0.1.9 的副本（去掉测试），
// 仅新增 ClientCurvePreferencesHook，由 core/go.mod 的 replace 引用。
// 这个分支把 ML-KEM 写死在默认曲线里，GODEBUG=tlsmlkem=0 对它无效；
// 部分网络会丢弃发往 *.tailscale.com、带 X25519MLKEM768 的 ClientHello，
// 内置 Tailscale 节点又无法逐连接传入 CurvePreferences，所以在这里留一个按 SNI 收窄的钩子。

// ClientCurvePreferencesHook 在 Config.CurvePreferences 为空时按 ServerName 返回允许的曲线，
// 返回空表示保持默认。只在进程初始化阶段设置。
var ClientCurvePreferencesHook func(serverName string) []CurveID

func hookedClientCurvePreferences(c *Config) []CurveID {
	if c == nil || c.ServerName == "" || ClientCurvePreferencesHook == nil {
		return nil
	}
	return ClientCurvePreferencesHook(c.ServerName)
}
