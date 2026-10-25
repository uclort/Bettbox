### 2026-10-25 修复 macOS Monterey 开机启动

- macOS 12 不再调用缺少 Helper 的 `SMLoginItemSetEnabled`，改为写入当前用户的 LaunchAgent，下次登录启动当前 App。
- macOS 13 及以上继续使用 `SMAppService`，启动时删除 Monterey 留下的 LaunchAgent，避免两套机制同时启动。

