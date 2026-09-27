### 2026-09-27 同步上游 Bettbox 1.19.3

- 同步官方 `appshubcc/Bettbox` 的 `main@26865630fef4`，纳入最新核心、WebDAV 多版本备份与轻量加密、Windows 便携模式、局域网用户验证、代理列表自动吸顶及媒体解锁检测修复。
- 删除自定义“关闭窗口后强制隐藏 Dock 图标”实现及其回归测试，改用上游“常驻 Dock”配置、启动状态恢复和 `window_ext` 动态切换逻辑。
- 保留 WebDAV 共享配置边界、macOS TUN/DNS 恢复、隐藏策略组、Inline Provider、应用内更新、菜单栏增强、系统代理所有权保护、Snell v6 与接口 DNS 等自定义能力。
