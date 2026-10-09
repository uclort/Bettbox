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

### 私有覆写脚本

- `scripts/uclort-desktop.js` 与 `scripts/uclort-sukka.js` 保存在私有 `uclort/custom-mihomo` 仓库，包含私有订阅与内网信息，不提交到公开 Bettbox；当前同步提交为 `5a0477bb0ffb88eb8e3a30239eda1960112cadb5`。
- `uclort-desktop.js` 保留源节点与 Provider，过滤套餐/流量提示节点，按地区与倍率排序，重建 Global、Apple、Emby、抓包、CC 内网和 Fallback 分组；`latencyTestUrl` 统一 Provider 健康检查和策略组测速地址。
- `uclort-sukka.js` 以 `Uclort.conf` 为基准接入 Sukka 官方 Mihomo `domainset / non_ip / ip` 规则集；Bettbox 运行端口、TUN 启停和栈模式沿用客户端当前状态，源 hosts 仅按保护条件替换节点服务器域名。
- 固定自定义规则统一放在 `BETTBOX_CUSTOM_RULES`，支持可选说明注释；网络面板通过 Sub-Store wholeFile/file API 读取、追加、修改、删除和拖动排序，保存前重新读取远端脚本，避免覆盖其他改动。
- `CC-intranet-en5` 使用 `dns-follow-interface: true` 与 `allow-other-interface: true`；CC 内网由 `ruleOptionsEnable.CC内网` 单一开关控制，关闭时恢复 `10.0.0.0/8` DIRECT。
- 修改后至少运行 `node --check scripts/uclort-desktop.js`、`node --check scripts/uclort-sukka.js`、`node scripts/uclort-sukka.test.js`，并通过 Bettbox 实际导入 URL 与远端文件逐字节校验。

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
- 同步后至少运行 `go test ./transport/snell ./adapter/outbound ./component/dialer ./component/dhcp ./dns ./listener/sing_tun ./constant ./tunnel ./tunnel/statistic`。

### 应用内更新

- “关于本机 → 查找更新”检查 `uclort/Bettbox` 已发布的最新自定义 Release；“Github Releases”直接打开该仓库的 Releases 页面。
- macOS 使用 Sparkle、Windows 使用 WinSparkle；安装前继续执行内核、代理和系统 DNS 退出清理。
- Windows 自定义安装包使用单文件启动器内嵌原 Inno Setup 安装器；启动器优先在 `%LOCALAPPDATA%\Bettbox\InstallerTemp` 创建独立临时目录并覆盖子进程的 `TEMP/TMP`，避免系统 `%TEMP%` 权限损坏或安全策略导致“错误 5：拒绝访问”。载荷释放缓冲使用堆内存，避免 1 MB 栈缓冲触发 `STATUS_STACK_OVERFLOW`。静默卸载跳过用户数据确认框并默认保留用户数据，交互卸载保留确认；Helper 服务按需启动，主程序退出时主动停止，首次 TUN 管理员授权后最多等待 30 秒直至 Helper 可用，已有服务启动失败时立即进入提权重配，只有实际启动成功才执行短健康等待，避免重复等待 30 秒；安装器升级时仅更新已有服务路径并保留鉴权环境，不创建或启动 Helper，残留 Helper/Core 由安装器静默清理。Windows 主窗口使用稳定原生标记识别已有实例，重复启动会恢复并聚焦现有窗口；首次启动窗口展示位于核心、TUN 授权和 Helper 初始化之前，不被网络启动链路阻塞。WinSparkle 初始化时从 `ProductVersion` 提取构建号，完整版本通过 `win_sparkle_set_app_details` 展示，纯构建号通过 `win_sparkle_set_app_build_version` 与 appcast 的 `sparkle:version` 比较；appcast 的 `title` 和 `sparkle:shortVersionString` 也发布最终安装版本 `1.19.3+构建号`，更新弹窗两侧均可直接对比版本差异；代码位于 `lib/common/app_updater.dart`、`lib/common/system.dart`、`lib/controller.dart`、`windows/runner`、`windows/packaging/exe/launcher`、`windows/packaging/exe/package_windows.dart`、`windows/packaging/exe/inno_setup.iss` 与 `.github/workflows/custom-build.yml`，自定义构建通过无效 `TEMP/TMP` 下的静默安装回归验证；回归安装和卸载均有 5 分钟超时、进程诊断和强制清理，并校验 Windows `ProductVersion` 包含本次构建号、appcast `echo` 生成字段包含完整版本、窗口展示顺序、Helper 启动失败快速回退以及安装后 Helper 进程与服务未运行。
- Windows 安装启动器 Release 构建使用静态 MSVC 运行库（`/MT`），不依赖系统 `VCRUNTIME140.dll` / `MSVCP140.dll`；构建校验位于 `.github/workflows/custom-build.yml`。
- 默认 Release 同时发布 Windows x64 与 Windows ARM64；ARM64 使用原生 Runner 和 Flutter ARM 工具链，私有内核检出时以 UTF-8 无 BOM、LF 结尾写入 SSH 私钥并收紧 ACL，同时让 PowerShell 原生命令错误立即终止构建；ARM64 仅执行 `flutter pub get`，复用源码中已提交的 build_runner 生成文件，避免 Dart 生成器在原生镜像上长时间无输出。Helper 显式选择对应 Rust MSVC target，WinSparkle 按目标架构切换预编译库，并对安装包及最终目录内原生 EXE/DLL 执行 PE 架构校验。Windows ARM64 使用独立 `appcast-windows-arm64.xml` 更新源；补丁脚本位于 `windows/packaging/patch_auto_updater_windows.dart`。
- Android 使用 arm64-v8a 固定签名 APK，校验 SHA-256 后通过独立 `FileProvider` URI 调用系统安装器；安装器无法打开时显示失败提示，发布前校验 Provider 与 `app_updates` 路径配置。更新检查读取 `custom-update-feed` 分支静态 JSON，避免 GitHub Releases API 匿名限流。
- 自动检查与手动检查使用同一发布源，草稿 Release 不会被识别为可用更新。

### macOS TUN、DNS 与唤醒恢复

- macOS 实际 TUN 配置将 `system` 栈映射为 `mixed`；显式 `mixed` 或 `gvisor` 保持原值。
- 桌面切换 TUN 栈使用串行核心重启；失效 IPC socket 立即丢弃，异常退出记录退出码和 stderr。
- macOS 开启 TUN 时自动托管当前网络服务 DNS，关闭 TUN、停止或退出时恢复原 DNS；下次启动会清理残留托管状态。
- 系统唤醒、Wi-Fi 切换或默认出口租约变化后，通过网卡、网关、地址、网络服务和 DHCP 信息生成的指纹识别真实网络变化。
- 等待网络稳定后迁移托管 DNS、关闭旧连接、重建 Mihomo resolver 的 DoH/DoT 连接池、刷新 DNS/Fake-IP，并按需停止监听后重建 TUN；桌面 IPC 的 `resetConnections` 方法名与 Dart 调用保持一致，恢复任务支持代际取消和一次重试。
- 启动 TUN 前检查其他 VPN 遗留的 `1.0.0.0/8` utun 路由；发现冲突时保持关闭并提示接口。
- macOS TUN 关闭竞态的 `ENOTSOCK` 按标准关闭处理，避免旧批量读协程日志风暴和 CPU 满载；Mixed/GVisor 所需方法集继续保留，并兼容 sing-tun 新增的 Darwin `BatchSize` 接口。
- 主要测试为 `test/application/macos_network_recovery_test.dart`、`test/controller/macos_tun_startup_test.dart`、`test/models/clash_config_test.dart` 及 `core/Clash.Meta/listener/sing_tun` 定向测试。

### macOS 与 Windows 托盘

- 桌面托盘提供系统代理、虚拟网卡、重启内核、重启软件、自动启动、亮屏锁、策略组和节点选择；macOS 与 Windows 使用同一套左右键行为配置，可分别设置为显示窗口或显示菜单。
- Dock 图标完全跟随主窗口状态：窗口显示或最小化时显示，窗口关闭到托盘或静默启动时隐藏；不再提供“常驻 DOCK”开关，也不读取历史偏好。代码位于 `plugins/window_ext/macos/Classes/WindowExtPlugin.swift`、`macos/Runner/AppDelegate.swift` 与 `macos/Runner/MainFlutterWindow.swift`，策略映射测试位于 `macos/RunnerTests/RunnerTests.swift`。
- macOS 与 Windows 均支持独立开启实时上传/下载速率；系统代理与虚拟网卡均关闭时立即归零并显示为未启用状态。
- macOS 与 Windows 共用模板图标：启用系统代理或虚拟网卡时高亮，未启用时使用 60% 中性灰渲染，配色和启停语义保持一致。Windows 移除“托盘反转”设置，历史配置继续保留但不再影响托盘。
- 托盘一级菜单提供显示窗口、网络面板、模式、策略组、系统代理、虚拟网卡和重启内核；“显示窗口 / 网络面板 / 系统代理 / 虚拟网卡 / 重启内核 / 退出”使用 `⌘M / ⌘D / ⌘S / ⌘E / ⌘R / ⌘Q`。
- 二级菜单父项只展开子菜单；节点测速结果使用独立右对齐列。
- 首次安装特权工具后原位刷新托盘；从后台显示窗口或从托盘重启内核后主动同步最终运行状态。
- 系统代理管理器只关闭当前 Bettbox 进程成功启用过的代理，避免误关 Surge 等其他软件的系统代理。
- 代码位于 `lib/common/tray.dart`、`lib/common/utils.dart`、`lib/manager/tray_manager.dart`、`lib/providers/state.dart`、`plugins/tray_manager/macos/Classes/TrayIcon.swift`、`plugins/tray_manager/windows/tray_manager_plugin.cpp` 和 `plugins/proxy/lib/proxy.dart`；回归测试为 `test/common/tray_active_state_test.dart`、`test/plugins/tray_menu_open_state_test.dart` 与 `macos/RunnerTests/RunnerTests.swift`。

### 隐藏策略组

- 代理页“显示隐藏项”按配置原始顺序显示隐藏策略组，托盘同步遵循该设置。
- 设置关闭时，macOS 可按住 Option 点击托盘图标临时显示隐藏策略组；Option 状态同时读取点击事件和当前键盘修饰键，避免菜单栏事件丢失修饰键。

### Inline Provider 内容查看

- Inline 类型代理提供者可直接从运行配置序列化查看节点内容；HTTP 与 File 类型继续使用原文件读取方式。
- 回归测试为 `core/hub_test.go`。

### HarmonyOS Sans 字体

- 内置 HarmonyOS Sans 补齐标准 U+0020 空格字形，避免列表、详情和输入框出现异常大的词间距。

### 网络面板

- macOS、Windows 和 Linux 导航保留一个“面板”tab，点击以同一可执行文件的 `--network-panel` 参数启动独立进程；Windows Runner 为面板使用独立原生窗口标题并跳过主窗口单实例激活，确保第二进程能进入 Dart 面板入口；面板使用专属 Dock/任务栏图标，关闭面板不影响主窗口，主进程退出或管道断开时自动关闭面板。
- Android 不再把网络功能顺序平铺到“更多”；“更多 → 查看”分组只提供一个“网络面板”二级页，并显示“查看网络请求、连接和流量信息”副标题，进入后在面板内部切换最近请求、活动连接、DNS、日志和 Sub-Store 五个 tab；桌面端主导航的大 tab 保持简洁的“面板”，同一网络监控功能的其他入口统一使用“网络面板”，首页“在线面板”属于另一项功能并保持不变。
- 独立面板进程不初始化 Mihomo、单例锁或托盘，通过 `ExternalControl` 本地 UDS/TCP 通道读取请求、连接和日志并执行清理/断连；请求与日志变更使用持久订阅主动通知，事件刷新限制为 250 ms。
- 请求与连接按 Mihomo `TrackerInfo` 的进程、来源、目标、协议、规则、出站链和状态动态分类，支持全文搜索、移动端筛选、右键生成规则、当前配置追加/覆盖规则和独立详情；状态按活动快照、真实出站 socket、`REJECT` 和链路终态区分。
- DNS 页由当前生效配置读取 `default-nameserver / nameserver / fallback / proxy-server-nameserver / direct-nameserver / nameserver-policy / hosts`，并合并系统 Hosts、运行缓存、Fake-IP 与出站节点 DNS；支持同时清理 DNS 缓存和 Fake-IP。
- 不再提供信息价值有限的设备与流量统计子页面；请求和连接列表仍保留单条记录的实时速率、累计上传下载和连接详情。
- 日志页按实际级别分类；Sub-Store 页支持凭据历史、固定规则读取/新增/修改/删除/拖动排序，保存前重新读取远端脚本并仅替换 `BETTBOX_CUSTOM_RULES`。
- 选中请求或连接后展开可拖动详情，区分客户端、目标、Fake-IP、实际出站本地/远端地址、GeoIP/ASN 和完整策略链；macOS 通过 `NSWorkspace` 读取进程图标，并发请求合并且复用历史 `.app` 路径。
- custom-mihomo 为每条连接保存 DNS 逐服务器尝试、规则匹配、策略链和真实 socket 建立事件，`TrackerInfo` 返回 `trace / outboundLocalAddress / outboundRemoteAddress`；连接加入与离开均发送同 ID 通知，请求记录按 ID 原位更新。
- 代码位于 `lib/views/network_monitor*.dart`、`lib/common/window.dart`、`lib/common/external_control.dart`、`lib/common/navigation.dart`、`lib/views/network_monitor_navigation.dart`、`lib/enum/enum.dart`、`lib/widgets/google_bottom_nav_bar.dart` 和 `lib/common/tray.dart`；回归测试为 `test/views/network_monitor_test.dart`、`core/Clash.Meta/tunnel/statistic/manager_notify_test.go` 及私有内核 `constant / dns / tunnel / tunnel/statistic` 测试。

### 统一启停交互

- 桌面端系统代理或 TUN 任一开启即启动核心，两者均关闭即停止核心；设置页、快捷卡片和托盘开关都调用 `updateSystemProxy` / `updateTun` 联动方法。Windows、macOS 和 Linux 的 TUN 首次启动统一同步执行无 TUN 基线配置、管理员授权、必要的特权核心重启、监听启动和 TUN 配置应用，任一步失败都会停止监听并回滚 TUN 开关；系统代理仍开启时恢复无 TUN 核心，避免 UI 已开启但实际网络黑洞。桌面窗口展示不等待该同步安全链路完成，因此 Windows 开启 TUN 后重启应用仍会先显示窗口，再在后台事件循环中完成授权和网络就绪。
- 桌面核心实际运行状态统一以 `globalState.isStart` 为准并同步到展示状态；Windows 系统代理调用串行执行，同时写入 WinINet 默认/RAS 连接和当前用户 `Internet Settings` 注册表，任一主通道成功即可完成启停，设置刷新尽力执行，避免特定 Windows 环境拒绝默认连接 API 时无法开启代理。启动配置要求开启系统代理时，初始化阶段延后首次同步，等待核心监听就绪后直接启用，不再先关闭再串行开启；配置要求关闭时仍立即清理残留代理。
- 移除桌面独立启动/停止入口、启动热键和“联动开关”设置；托盘保留网络面板、系统代理、TUN、重启内核等入口。
- Android 首页保留一个悬浮总开关，并避让底部导航与页面滚动内容；启动时间卡片仅作为非独立启停的运行时长展示，不再提供桌面独立启停操作。
- 回归测试为 `test/controller/macos_tun_startup_test.dart`。

### 自定义构建与发布

- `uclort/Bettbox` 明确标记为非官方个人自定义版；GitHub 操作必须显式指定该仓库。
- `custom-sync.yml` 与 `custom-build.yml` 仅支持手动触发；同步顺序为上游 Bettbox → 保留功能分支 → 私有 custom-mihomo → 自定义构建。
- 默认全平台构建发布 Android ARM64、Windows x64、Windows ARM64、macOS Apple Silicon 和 macOS Intel 共 5 个安装包；也可选择仅 macOS Apple Silicon 或仅 Android arm64-v8a，Android 构建同步静态更新源。
- 内核同步兼容新版 Mihomo 将版本号改为构建时注入的模式；源码版本为空时按 Bettbox 上游核心树继续同步，仍执行 Snell v6 补丁与 Go 回归。
- 自定义应用代码变化但未同步完整总账和发布增量时拒绝发布。

### 已删除的历史自定义功能

- 旧自定义节点测速并发、缓存、诊断和 Provider 生命周期改造此前已删除，继续使用 Bettbox 上游实现。
