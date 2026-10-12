### 2026-10-12 同步 Bettbox 1.19.5 与 Mihomo v1.19.32

- 同步 Bettbox 上游 `26865630fef4 → afcc5cf0b3e1` 的 30 个提交，包含无边框主题、可折叠侧边栏、列表和编辑器优化、策略组脚本选项、GeoData 在线下载、回环流量保护以及 Windows Helper 进程管理改进。
- 更新内置 Mihomo 至 `v1.19.32`，重新生成并固定私有 Snell v6 内核；保留接口 DNS 跟随与回退、macOS Scoped Resolver、TUN 关闭处理和连接变更通知。
- 融合新版界面后继续保留独立网络面板、WebDAV 共享配置边界、统一代理/TUN 启停、Android 悬浮总开关、macOS 菜单与 Dock 生命周期，以及 Windows 原生托盘测速和应用内更新。
- 核心启动接入上游控制通道重建重试与 Linux AppImage 内核同步，保留启动失败及 IPC 断开的网络开关回滚；Windows Helper 仍按需启动、退出时停止，安装器升级不主动创建或启动服务。
- Windows 代理接入上游 IPv6 回环绕过兼容处理，保留注册表与 WinINet 双通道启停，并同步重新生成模型与七种语言资源。
