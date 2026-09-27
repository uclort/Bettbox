### 2026-09-27 修复 Android 下载后无法安装 APK

- 修复同步上游后 Android 更新专用 `FileProvider` 与路径配置被删除，导致 APK 下载完成后无法生成安装 URI、点击“立即安装”没有反应的问题。
- 安装 URI 仅开放应用私有目录下的 `app_updates`，并在系统安装器无法启动时显示“安装未知应用”权限提示。
- 修正 Android 关于页“Github Releases”入口，直接打开 `uclort/Bettbox` 的 Releases 页面，不再停留在仓库首页。
- 自定义发布流程新增 Android 更新 Provider 配置校验，避免后续上游同步再次静默删除安装能力。
