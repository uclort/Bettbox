### 2026-09-22 自定义功能精简与菜单栏图标修复

- 按保留清单精简自定义版：继续保留 WebDAV 共享边界、macOS TUN/DNS 与唤醒恢复、统一启停、隐藏策略组、Inline Provider 查看、应用内更新、自定义构建、系统代理所有权保护、HarmonyOS Sans 空格修复、Snell v6 及接口 DNS。
- 删除独立网络面板及其最近请求、连接、DNS、设备、流量、日志、规则生成和 Sub-Store 管理页面；同时删除独立进程、IPC、专属图标、导航/托盘入口和对应测试。
- 删除 TrackerInfo 连接链路扩展、连接加入通知以及私有 custom-mihomo 覆写脚本；请求、连接和进程图标展示恢复 Bettbox 上游实现。
- macOS 未启用菜单栏图标改用 `NSStatusBarButton.appearsDisabled` 原生 off 状态，继续保留模板图标；解决最新包中未启动状态仍显示纯黑的问题，实时速率文字继续使用系统次级标签灰色。
- 自定义功能总账已重写为当前仍保留的能力，移除不再维护的历史实现说明。
