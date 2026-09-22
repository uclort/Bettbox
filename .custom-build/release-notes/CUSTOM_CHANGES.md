## 本包改动（相较上游版本）

### 上游融合必检

- 同步 Bettbox、Mihomo 或 Snell 前后搜索 `BETTBOX-CUSTOM`，逐项确认标记代码仍然存在。
- 融合后运行相关目录的 Go/Flutter 回归测试；不得仅以编译成功代替行为验证。
- 本文件只登记当前仍保留的自定义功能；修改、迁移、删除或被上游等价能力替代时必须同步更新。
- `LATEST_CHANGES.md` 只记录相较上一自定义 Release 的增量，不能替代本文件。
- 未经用户明确要求，不创建 Pull Request。

### WebDAV 配置同步边界

- WebDAV 使用现有 ZIP 备份格式的 `shared-config` 范围，只同步订阅配置、配置 YAML 与 `ScriptProps.scripts`。
- 当前配置、当前脚本、节点选择、策略组展开状态和 Provider 派生缓存保持本机状态；App、DAV 凭据、主题、窗口、托盘、热键、代理、TUN、访问控制、界面样式、测速过滤和超时等设置不跨设备覆盖。
- 本地导入导出继续使用完整备份语义；历史完整 WebDAV 包恢复时同样只应用共享配置字段。
- 代码位于 `lib/controller.dart`、`lib/models/config.dart` 与 `lib/views/backup_and_recovery.dart`；回归测试为 `test/models/webdav_shared_config_test.dart`。

### Mihomo：direct proxy 跟随接口 DNS

- direct proxy 支持 `dns-follow-interface`；仅在配置 `interface-name` 时生效，省略默认为 `true`。
- direct proxy 支持 `allow-other-interface`，省略默认为 `true`；指定接口不存在、未运行或缺少目标协议族地址时，连接和接口 DNS 一并回退到当前默认接口。
- 显式设为 `false` 时保持严格接口绑定；接口可用但普通连接失败时不会越权回退。
- macOS 的 `dhcp://<interface>` 优先读取系统 Scoped Resolver，读取不到时再使用 Mihomo DHCP 广播；DNS 失败或连接重置时按需刷新并重试，其他平台保留原一小时缓存。
- 标记位于 `core/Clash.Meta/adapter/outbound/direct.go`、`component/dialer/options.go`、`component/dhcp/dhcp.go` 和 `dns/dhcp.go`；对应目录测试必须保留。

### Snell v6 与自定义内核

- 私有 `uclort/custom-mihomo` 以 Bettbox 当前内置 Mihomo 源码树为输入，应用 `patches/opensnell-v6.patch` 后供构建替换使用。
- Snell v6 支持 `version: 6` 及 `default / unshaped / unsafe-raw` 模式；补丁来源与许可证记录在私有仓库的 `OPEN-SNELL-V6` 和 `THIRD_PARTY_NOTICES.md`。
- `.custom-build/metadata/custom-mihomo-commit` 固定每次构建使用的私有内核提交；构建前校验 Bettbox 核心树、Mihomo 版本和 Snell 补丁摘要。
- 同步后至少运行 `go test ./transport/snell ./adapter/outbound ./component/dialer ./component/dhcp ./dns ./listener/sing_tun`。

### 应用内更新

- “关于本机 → 查找更新”检查 `uclort/Bettbox` 已发布的最新自定义 Release。
- macOS 使用 Sparkle、Windows 使用 WinSparkle；安装前继续执行内核、代理和系统 DNS 退出清理。
- Android 使用 arm64-v8a 固定签名 APK，校验 SHA-256 后调用系统安装器；更新检查读取 `custom-update-feed` 分支静态 JSON，避免 GitHub Releases API 匿名限流。
- 自动检查与手动检查使用同一发布源，草稿 Release 不会被识别为可用更新。

### macOS TUN、DNS 与唤醒恢复

- macOS 实际 TUN 配置将 `system` 栈映射为 `mixed`；显式 `mixed` 或 `gvisor` 保持原值。
- 桌面切换 TUN 栈使用串行核心重启；失效 IPC socket 立即丢弃，异常退出记录退出码和 stderr。
- macOS 开启 TUN 时自动托管当前网络服务 DNS，关闭 TUN、停止或退出时恢复原 DNS；下次启动会清理残留托管状态。
- 系统唤醒、Wi-Fi 切换或默认出口租约变化后，通过网卡、网关、地址、网络服务和 DHCP 信息生成的指纹识别真实网络变化。
- 等待网络稳定后迁移托管 DNS、关闭旧连接、刷新 DNS/Fake-IP，并按需停止监听后重建 TUN；恢复任务支持代际取消和一次重试。
- 启动 TUN 前检查其他 VPN 遗留的 `1.0.0.0/8` utun 路由；发现冲突时保持关闭并提示接口。
- macOS TUN 关闭竞态的 `ENOTSOCK` 按标准关闭处理，避免旧批量读协程日志风暴和 CPU 满载；Mixed/GVisor 所需方法集继续保留，并兼容 sing-tun 新增的 Darwin `BatchSize` 接口。
- 主要测试为 `test/application/macos_network_recovery_test.dart`、`test/controller/macos_tun_startup_test.dart`、`test/models/clash_config_test.dart` 及 `core/Clash.Meta/listener/sing_tun` 定向测试。

### macOS 菜单栏与托盘

- 菜单栏提供系统代理、虚拟网卡、重启内核、重启软件、自动启动、亮屏锁、策略组和节点选择；左右键行为可分别配置为显示窗口或显示菜单。
- 支持独立开启实时上传/下载速率；系统代理与虚拟网卡均关闭时立即归零并显示为未启用状态。
- macOS 始终使用同一模板图标。启用时采用系统原生高亮；未启用时使用 `NSStatusBarButton.appearsDisabled` 的原生 off 外观，避免模板图标被绘制为纯黑。
- 托盘一级菜单依次显示系统代理、虚拟网卡和重启内核；“显示窗口 / 系统代理 / 虚拟网卡 / 重启内核 / 退出”使用 `⌘M / ⌘S / ⌘E / ⌘R / ⌘Q`。
- 二级菜单父项只展开子菜单；节点测速结果使用独立右对齐列。
- 首次安装特权工具后原位刷新托盘；从后台显示窗口或从托盘重启内核后主动同步最终运行状态。
- 系统代理管理器只关闭当前 Bettbox 进程成功启用过的代理，避免误关 Surge 等其他软件的系统代理。
- 代码位于 `lib/common/tray.dart`、`lib/providers/state.dart`、`plugins/tray_manager/macos/Classes/TrayIcon.swift` 和 `plugins/proxy/lib/proxy.dart`；回归测试为 `test/common/tray_active_state_test.dart` 与 `test/plugins/tray_menu_open_state_test.dart`。

### 统一启停交互

- 移除联动开关和独立启动/停止入口；系统代理或虚拟网卡任一开启即代表 Bettbox 运行。
- Android 首页保留一个悬浮总开关并避让底部导航及滚动内容。
- macOS 与 Android 的启动时间卡片只显示运行时长。

### 隐藏策略组

- 代理页“显示隐藏项”按配置原始顺序显示隐藏策略组，托盘同步遵循该设置。
- 设置关闭时，macOS 可按住 Option 点击托盘图标临时显示隐藏策略组。

### Inline Provider 内容查看

- Inline 类型代理提供者可直接从运行配置序列化查看节点内容；HTTP 与 File 类型继续使用原文件读取方式。
- 回归测试为 `core/hub_test.go`。

### HarmonyOS Sans 字体

- 内置 HarmonyOS Sans 补齐标准 U+0020 空格字形，避免列表、详情和输入框出现异常大的词间距。

### 自定义构建与发布

- `uclort/Bettbox` 明确标记为非官方个人自定义版；GitHub 操作必须显式指定该仓库。
- `custom-sync.yml` 与 `custom-build.yml` 仅支持手动触发；同步顺序为上游 Bettbox → 保留功能分支 → 私有 custom-mihomo → 自定义构建。
- 构建可选择全平台、仅 macOS Apple Silicon 或仅 Android arm64-v8a；Android 构建同步静态更新源。
- 内核同步兼容新版 Mihomo 将版本号改为构建时注入的模式；源码版本为空时按 Bettbox 上游核心树继续同步，仍执行 Snell v6 补丁与 Go 回归。
- 自定义应用代码变化但未同步完整总账和发布增量时拒绝发布。

### 已删除的历史自定义功能

- 独立网络面板、Sub-Store 固定规则管理、网络面板专属图标与独立进程/IPC 已删除。
- custom-mihomo 私有覆写脚本 `uclort-desktop.js`、`uclort-sukka.js` 及其测试已删除。
- 连接级 DNS/规则/出站链路追踪与连接加入通知已删除，请求和连接页面恢复 Bettbox 上游实现。
- 旧自定义节点测速并发、缓存、诊断和 Provider 生命周期改造此前已删除，继续使用 Bettbox 上游实现。
