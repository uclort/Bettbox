## 本包改动（相较上游版本）

### 上游融合必检

- 同步 Bettbox、Mihomo 或 Snell 前后搜索 `BETTBOX-CUSTOM`，逐项确认标记代码仍然存在。
- 融合后运行相关目录的 Go/Flutter 回归测试；不得仅以编译成功代替行为验证。
- 本文件是 Bettbox、custom-mihomo 和私有覆写脚本的自定义功能总账；修改、迁移、删除或被上游等价能力替代时，必须同步更新本文件和对应测试。
- `LATEST_CHANGES.md` 只记录相较上一自定义 Release 的增量，不能替代本文件。
- 未经用户明确要求，不创建 Pull Request。

### 私有覆写脚本

- 本地文件为 `scripts/uclort-desktop.js`。脚本包含私有订阅地址，因此不提交到公开 Bettbox 仓库；完整版本保存在私有 custom-mihomo 仓库同路径下，修改时必须同步两份并对照本节。远端 Sub-Store 使用文件 API 更新 `fx.js`，更新后必须重新读取并与本地文件逐字节校验。
- `latencyTestUrl` 是唯一测速地址，默认 `http://www.gstatic.com/generate_204`；OwO、源 HTTP/File Provider、脚本生成的 Inline Provider 和所有策略组均从该变量读取。Bettbox 开启“覆写测速链接”时由客户端配置入口统一覆盖策略组与 Provider。
- 保留源节点和源 Provider，过滤套餐/流量提示节点，为源节点增加 `FC - ` 前缀并按美国、日本、香港及倍率排序；首选地区与其他节点分别转为 Inline Provider。
- 重建 Global、地区、Apple、Emby、抓包、CC 内网和 Fallback 分组及规则；新加坡、台湾不生成地区组。
- `CC-intranet-en5` 使用 `dns-follow-interface: true` 和 `allow-other-interface: true`；内网域名仅维护一份路由清单，固定 hosts 保留为注释回退。
- DNS 使用 Fake-IP、国内外分流和源节点域名策略；源 hosts 只在唯一 `proxy-server-nameserver` 指向 `dns.listen` 时改写节点服务器地址，不写回最终配置；域名与公共 DNS 匹配忽略大小写，DNS 的 `#DIRECT` 后缀会保留。
- 修改后至少运行 `node --check scripts/uclort-desktop.js`，并执行脚本断言确认所有带 URL 的策略组和所有 Provider 健康检查均使用 `latencyTestUrl`。

### Mihomo：direct proxy 跟随接口 DNS

- 自定义 direct proxy 支持 `dns-follow-interface`；仅在配置了 `interface-name` 时生效，省略默认为 `true`。
- 开启后，规则命中该 direct proxy 的域名由对应接口 DNS 解析，不再要求为同一批域名重复维护 `nameserver-policy`；显式设为 `false` 时保持原有全局 hosts/DNS 流程。
- 自定义 direct proxy 支持 `allow-other-interface`，省略默认为 `true`；指定接口不存在、未运行或没有目标协议族地址时，连接和 `dns-follow-interface` 同步改用当前默认接口。TUN 开启时复用其默认接口监控器，未开启 TUN 时通过系统路由探测接口名；显式设为 `false` 时保持严格绑定，接口可用但普通连接失败时也不会越权回退。
- macOS 的 `dhcp://<interface>` 优先读取系统当前 Scoped Resolver，读取不到时才回退 Mihomo 原有 DHCP 广播，避免企业 DHCP 不响应重复 `DHCPDISCOVER`；正常状态不轮询，DNS 请求失败或连接重置时立即刷新并重试，其他平台继续使用原来的一小时缓存。
- 核心标记位于 `core/Clash.Meta/adapter/outbound/direct.go`、`core/Clash.Meta/component/dialer/options.go`、`core/Clash.Meta/component/dhcp/dhcp.go` 和 `core/Clash.Meta/dns/dhcp.go`；回归测试位于对应包的 `direct_test.go`、`options_test.go`、`system_darwin_test.go`、`dhcp_test.go`。
- 覆写脚本 `scripts/uclort-desktop.js` 的 `CC-intranet-en5` 显式开启两个参数；内网域名只维护路由清单，固定 hosts 继续作为注释回退。

### 应用内更新

- “关于本机 → 查找更新”改为检查 `uclort/Bettbox` 已发布的最新自定义 Release。
- macOS 使用 Sparkle、Windows 使用 WinSparkle 在应用内下载并替换安装包；更新安装前继续执行 Bettbox 原有的内核、代理和系统 DNS 退出清理。
- Android 自动选择 arm64-v8a 固定签名 APK，校验 Release 资产的 SHA-256 后调用系统安装器，因此后续自定义版本可以直接覆盖安装。
- 自动检查更新与手动检查使用同一自定义发布源；草稿 Release 不会被识别为可用更新。

### TUN 自动托管系统 DNS

- macOS 开启虚拟网卡时自动托管系统 DNS，不再提供独立开关；关闭虚拟网卡或停止 Bettbox 时自动恢复。
- 修复 Wi-Fi 之间切换时连接类型不变、网络变化事件被过滤，导致 DNS 与 TUN 继续沿用旧网络状态的问题。
- 通过默认出口的网卡、网关、地址、网络服务及 DHCP 信息生成网络指纹，Wi-Fi 之间切换或默认出口租约变化时也能识别真实网络变化。
- 等待新网络稳定后，自动迁移托管 DNS、关闭旧连接、刷新 DNS/Fake-IP 缓存，并停止后重建 TUN listener、重新探测默认出口。
- 网络恢复任务支持代际取消，手动停止和退出优先于后台恢复，避免恢复流程重新拉起已停止的监听与 TUN。
- 核心监听、连接清理和 DNS/Fake-IP 缓存刷新设置明确的成功判定及时间边界，避免超时后仍继续恢复 TUN。
- 生效期间当前网络服务只使用 `223.5.5.5`，避免 DHCP DNS 优先绕过 Mihomo。
- 停止、退出或下次启动检测到残留状态时，恢复启用前的 DNS；启用前没有自定义 DNS 时恢复为系统自动获取。
- 启动 TUN 前检测其他 VPN 遗留的 `1.0.0.0/8` utun 路由；发现冲突时保持 TUN 关闭并提示接口，避免核心以 `file exists` 失败。
- macOS TUN 关闭竞态产生 `ENOTSOCK` 时按标准关闭处理并退出旧批量读协程，避免 `batch read packet` 日志风暴、核心与界面 CPU 满载以及后续连接受影响。代码位于 `core/Clash.Meta/listener/sing_tun/server_notwindows.go`，回归测试为同目录 `server_notwindows_test.go`。

### macOS 菜单栏与托盘

- 增加实时上传、下载速率显示，可在“更多 → 增强工具”中独立开关。
- Bettbox 未启动，或系统代理与虚拟网卡均未开启时，图标和速率文字显示为灰色。
- 启用状态使用 macOS 原生自适应颜色，自动匹配菜单栏背景。
- 托盘点击行为支持“显示面板”和“显示菜单”，左键与右键可以分别配置。
- 移除旧“托盘增强”总开关，代理组菜单直接可用；速率和点击行为均作为增强工具中的独立一级设置。
- 修复应用位于后台时从托盘启动后，图标和菜单状态未立即更新的问题。
- 修复从托盘重启内核后，运行状态未主动同步，导致图标持续置灰且菜单仍显示“启动”的问题。
- 策略组测速按钮改为接近系统菜单的全宽圆角高亮样式，修复点击无响应。
- 托盘菜单与代理面板共享测速状态；相同实际节点和测试地址复用测速请求，避免重复并发测速及较晚的超时结果覆盖已成功延迟，并持续显示测速进度和结果。
- 修复应用窗口未显示或未激活时，托盘延迟测速首次点击无响应的问题。
- macOS 托盘菜单改为点击托盘时才使用最新状态创建；菜单打开期间只原位更新，修复测速中或测速完成后节点切换、“显示”等菜单项点击丢失的问题。
- 托盘一级菜单依次显示系统代理、虚拟网卡，并将重启内核放在一级、重启软件放入工具子菜单；“显示窗口 / 网络面板 / 系统代理 / 虚拟网卡 / 重启内核 / 退出”使用 macOS 原生菜单快捷键 `⌘M / ⌘D / ⌘S / ⌘E / ⌘R / ⌘Q`，菜单同步显示快捷键标识。
- 二级菜单父项只负责展开子菜单，不再响应无效的空点击。
- 节点测速结果使用独立右对齐列，菜单宽度同时为节点名称和结果预留空间。
- 当前策略组测速时显示“⚡ 测速中...”，并保持不可重复点击。
- 标签页模式下其他策略组正在测速时，当前策略组的测速按钮保持原有外观；点击后提示正在测速的策略组名称，避免无反馈。
- 所有平台和测速入口在 Mihomo 内共用全局测速管理器，实际网络请求总数最多 16。手动测速与 Provider/Fallback 后台检查使用公平双队列：后台请求到来后优先获得下一个空闲槽，随后前后台轮转，不会排在整批手动测速之后；用户设置的 8/16 并发只限制手动队列，不会占死后台检查。
- Dart 和桥接层不再预先排队、缓存或防抖节点请求，所有手动意图立即进入 Mihomo 登记并复用在途任务；删除桥接层旧 `mBatch` 50 并发队列及其无人读取的结果缓存，避免错过 Provider 在途窗口和持续积累结果。不同策略组可以同时提交测速，仅同一组按钮在自身运行期间禁用。
- Mihomo 在配置代际切换时显式关闭旧 Proxy Provider，立即取消旧健康检查和拉取任务，避免覆盖安装或首次启动时新旧 Provider 同时测速。
- Mihomo 由一个全局测速管理器按“实际节点实例、测试地址、期望状态”管理在途 URLTest；Provider、Fallback、策略组和 Bettbox 主动测速命中同一在途节点时只增加等待者，并在完成后向所有等待者返回同一个结果。节点名称不作为唯一键，避免不同 Provider 的同名节点错误共享。
- 每个等待者保留自己的网络超时，计时从节点真正获得执行槽开始，排队时间不再伪装成网络超时；单个等待者超时不终止其他调用，最后一个等待者退出时才取消底层任务。Dart 桥接只保留 5 分钟异常兜底，不参与正常节点超时。
- 测速无论成功或失败，完成后都立即从管理器移除；下一次调用真实重新测速，不设置防抖、结果缓存或失败重试。Provider 只合并正在运行的同一轮健康检查，完成后不再保留 1 秒结果；配置重载或 Provider 替换节点实例时立即取消旧任务，避免旧结果回写和新节点误等旧批次。
- 回归测试位于 `adapter/urltest_test.go`，覆盖在途共享、完成后立即重测、失败后重测、等待者独立超时、排队不消耗网络超时以及前后台公平调度；Dart 回归测试位于 `test/views/proxies/delay_test_coordinator_test.dart`，覆盖多策略组并行提交和同组重复点击保护。
- 默认测速地址使用 `http://www.gstatic.com/generate_204`；HTTP 测速使用一次标准 GET，避免线路中间设备随机断开 HEAD，且不增加失败重试；HTTPS 覆写地址保持原测速逻辑。
- Provider 后台健康检查失败不会再向页面广播失败状态；主动测速仍会明确写入成功或失败终态，避免更新后首次运行时未测速节点先显示“检测失败”。
- 开启“覆写测速链接”时，核心同时覆盖策略组和 Provider 健康检查 URL，避免同一节点被两个测速地址产生的结果互相覆盖。
- 节点测速增加端到端诊断日志：Dart 批次、桥接排队和 Mihomo 网络阶段共享 request ID，Provider 健康检查另带 batch ID；失败时记录解析、拨号、请求构造、TLS、HTTP、状态校验阶段、context、错误类型、耗时和节点来源。测试 URL 的账号、查询参数与 fragment 会脱敏，日志不包含节点密码。代码位于 `lib/clash/core.dart`、`lib/clash/interface.dart`、`lib/views/proxies/common.dart`、`core/hub.go`、`core/Clash.Meta/adapter/adapter.go`、`core/Clash.Meta/tunnel/tunnel.go` 和私有 custom-mihomo 对应路径；回归测试为 `core/Clash.Meta/adapter/patch_test.go`、`adapter/urltest_test.go` 与 `tunnel/provider_lifecycle_test.go`。
- 应用内日志与请求记录容量提高到 1024 条，确保一次约 90 节点的详细测速日志不会在导出前被 256 条环形容量截断。
- 移除独立的启动、停止入口，运行状态完全由系统代理和虚拟网卡开关驱动。
- 系统代理管理器只关闭当前 Bettbox 进程成功启用过的代理；启动、退出或状态同步时若系统代理开关本来就是关闭状态，不调用系统关闭代理命令，确保系统代理与虚拟网卡均关闭时不影响 Surge 等其他软件的系统代理。代码位于 `plugins/proxy/lib/proxy.dart`。
- 首次安装特权工具成功后原位刷新托盘，避免图标短暂消失再出现。

### 桌面网络面板

- 桌面导航以一个“网络面板”入口替换原“请求 / 连接 / 日志”三个页签；托盘菜单在“虚拟网卡”上方提供相同入口并以上下分割线隔开。点击后以同一可执行文件的 `--network-panel` 参数启动独立进程，在 Dock/任务栏使用基于 Bettbox 原图标逐像素保留、仅于右下角叠加蓝色网络波形徽标的专属图标；关闭面板不影响 Bettbox，Bettbox 正常退出或主进程管道断开时会关闭面板。
- 独立进程不初始化 Mihomo、单例锁或托盘，通过 `ExternalControl` 现有本地 UDS/TCP 通道读取主进程请求、连接和日志并执行清理/断连操作；请求与日志变更使用持久订阅连接主动通知。移除 `desktop_multi_window` 和子引擎全插件重复注册，避免 `tray_manager` 全局事件通道被子窗口覆盖。
- Android 在“更多”中提供“网络面板”入口，并以内嵌页面复用同一套数据和交互，不加载桌面多窗口能力。
- 面板集成最近请求、活动连接、DNS、设备、流量统计和日志；最近请求与活动连接直接按 Mihomo `TrackerInfo` 的 `process / sourceIP / host|destinationIP / network / rule / chains` 动态分类，并支持全文搜索、全部表头升降序和拖拽列宽。macOS 通过原生 `NSWorkspace` 按进程路径读取 App 图标，并在进程侧栏、连接表和详情中复用显示。
- 顶栏搜索框与页签统一垂直居中；设备页只按内核可确认的进程、来源地址和活动/历史状态分类，不再套用 Surge 的静态 IP、网关或接管模式；日志侧栏直接使用 Mihomo 实际事件级别 `error / warning / info / debug`，不展示不会产生记录的 `silent` 配置状态。
- 请求和连接列表不展示内部 ID，状态列仅按错误、活动、结束和其他状态显示红、黄、绿、灰圆点；日期按本机时区显示，策略链中的 ASCII 与 Unicode 连续空白统一压缩。无进程且无来源地址的 Mihomo 内部连接被过滤，真实客户端的 `REJECT` 规则命中继续保留。
- 请求、连接、DNS 和设备表使用固定行高 `ListView.builder` 惰性创建可见行，不再由 `DataTable` 一次性构建全部历史记录；水平与垂直滚动相互独立并裁剪在内容区，展开底部详情时不发生表格穿透或错位。
- DNS 由 `GlobalState.patchRawConfig` 读取当前生效配置，按 `default-nameserver / nameserver / fallback / proxy-server-nameserver / direct-nameserver / nameserver-policy / hosts` 原始配置键分类；系统 Hosts 读取 `/etc/hosts`，运行时解析按 `dnsMode` 的 `fake-ip / redir-host / hosts / normal` 分类并仅保留带有效目标 IP 的最新记录。
- 流量页调用 Mihomo `getTraffic / getTotalTraffic` 展示实时和累计上传下载；最近完成请求与活动连接去重后只承担出站链、规则类型、进程、来源地址、网络协议和目标主机的样本聚合，不再将 1024 条环形历史记录求和作为总流量。
- 请求与日志由主窗口收到新数据后主动推送，面板将事件刷新限制为最多每 250 ms 一次；活动连接受 Mihomo 快照接口限制，仅在连接页可见时每 250 ms 更新，流量页按内核统计周期每秒更新，其他页面每 5 秒兜底同步。
- 选中请求或连接后展开底部详情，展示通用信息、计时与日志，以及请求/响应报头和正文页签；Mihomo 未提供 HTTP 原文时明确显示不可用，不伪造抓包数据。
- 面板进程不跟踪来源应用，关闭时不调用任何应用激活 API；除 Bettbox 主进程负责启动和退出面板进程外，Dock、Cmd+Tab、窗口层级和关闭后的前台选择均由 macOS 按两个普通独立 App 处理。
- 面板代码位于 `lib/views/network_monitor.dart`、`lib/views/network_monitor_detail.dart` 和 `lib/views/network_monitor_data.dart`，进程与 IPC 生命周期位于 `lib/common/window.dart`、`lib/common/external_control.dart`，桌面/Android 导航与托盘入口位于 `lib/common/navigation.dart`、`lib/views/network_monitor_navigation.dart` 和 `lib/common/tray.dart`；排序、列宽、状态、时区、DNS 与入口回归测试位于 `test/views/network_monitor_test.dart`，独立进程入口覆盖 macOS、Windows 和 Linux。

### 统一启停交互

- 移除“联动开关”，系统代理或虚拟网卡任一开启即代表 Bettbox 启动。
- Android 首页只保留一个悬浮总开关，并避让底部导航及页面滚动内容。
- macOS 与 Android 的启动时间卡片只显示运行时长，不再承担启停操作。

### 隐藏策略组

- 代理页面增加“显示隐藏项”开关，开启后按配置原始顺序显示隐藏策略组。
- 托盘菜单同步遵循“显示隐藏项”设置。
- 设置关闭时，可按住 Option 点击托盘图标临时显示隐藏策略组。

### 代理提供者内容查看

- 支持直接查看 Inline 类型代理提供者的节点内容，不再提示 `provider path is empty`。
- HTTP 与 File 类型提供者继续使用原有文件读取方式。

### 自定义构建与发布

- Release 保留本包相较上游的完整功能说明，并单独列出相较上一自定义 Release 的上游同步与自定义增量。
- `custom-build.yml` 的手动触发支持仅构建并发布 macOS Apple Silicon；该模式只生成 arm64 DMG、对应更新元数据和 Sparkle appcast，其他平台不会创建 Action 任务。
- 自定义应用代码发生变化但没有补充增量说明时拒绝发布，避免 Release 内容与安装包不一致。
- 自定义应用代码发生变化但没有同步完整改动总账时同样拒绝发布。
