## 本包改动（相较上游版本）

### 上游融合必检

- 同步 Bettbox、Mihomo 或 Snell 前后搜索 `BETTBOX-CUSTOM`，逐项确认标记代码仍然存在。
- 融合后运行相关目录的 Go/Flutter 回归测试；不得仅以编译成功代替行为验证。
- 本文件是 Bettbox、custom-mihomo 和私有覆写脚本的自定义功能总账；修改、迁移、删除或被上游等价能力替代时，必须同步更新本文件和对应测试。
- `LATEST_CHANGES.md` 只记录相较上一自定义 Release 的增量，不能替代本文件。
- 未经用户明确要求，不创建 Pull Request。

### WebDAV 配置同步边界

- WebDAV 使用现有 ZIP 备份格式的 `shared-config` 范围，只写入订阅配置与 `ScriptProps.scripts`；配置内的覆写规则、脚本使用开关和分组开关随订阅配置同步。配置 YAML 文件继续同步，但不再打包当前配置的 Provider 派生缓存。
- `currentProfileId`、`ScriptProps.currentId`、配置内的 `currentGroupName / selectedMap / unfoldSet` 均为本机选择状态，不写入共享包；恢复时按配置 ID 合并回本机状态。App、DAV 凭据、主题、窗口、托盘、热键、代理/TUN、访问控制、界面样式、测速过滤和超时等设置全部保持平台独立。
- 本地导出与导入仍使用原有完整备份语义。WebDAV 读取历史完整包时也只应用共享配置字段，代码位于 `lib/controller.dart`、`lib/models/config.dart` 与 `lib/views/backup_and_recovery.dart`，回归测试位于 `test/models/webdav_shared_config_test.dart`。

### 私有覆写脚本

- 本地文件为 `scripts/uclort-desktop.js`。脚本包含私有订阅地址，因此不提交到公开 Bettbox 仓库；完整版本保存在私有 custom-mihomo 仓库同路径下，当前同步提交为 `4d61997`。远端 Sub-Store 使用文件 API 更新 `fx.js`，更新后必须重新读取并与本地文件逐字节校验。
- 私有 custom-mihomo 另维护 `scripts/uclort-sukka.js`：以 `Uclort.conf` 为基准，按照原顺序接入 SukkaW 官方 Mihomo `domainset / non_ip / ip` 规则集，并生成 Mihomo 可等价实现的通用、DNS、代理、策略组、跳过代理和规则配置；Bettbox 运行端口、TUN 启停及栈模式仍沿用当前状态。源 hosts 仅按原覆写脚本的保护条件替换节点服务器域名，消费后不写回运行配置，也不填充脚本默认 hosts。CC 内网仍由 `ruleOptionsEnable.CC内网` 单一开关控制，不是必填项；关闭时不生成 `CC-intranet-en5`、`CC-intranet` 策略组或内网规则，`10.0.0.0/8` 恢复 Surge 的 DIRECT。远端 Sub-Store 文件为 `uclort-sukka.js`，必须保存为 `source: local` 的本地文件；若误建为无 URL 的远程文件，`/api/file/uclort-sukka.js` 会返回 500。同步后须通过 Bettbox 实际导入 URL下载并逐字节校验；回归测试为 `node scripts/uclort-sukka.test.js`。
- 固定自定义规则统一放在脚本顶部的 JSON 字符串数组 `BETTBOX_CUSTOM_RULES`，带开关的 CC 内网、抓包和 Emby 规则集中由 `buildCustomRules()` 生成；网络面板通过 Sub-Store `/api/wholeFile/:name` 读取该数组，支持新增、修改、删除和拖动排序。每条规则可携带可选说明，保存时写为规则上方的 `// 说明：…` JS 注释，读取、拖动和删除时始终与对应规则绑定。保存前重新读取最新脚本，再通过 `/api/file/:name` 仅替换该变量，不覆盖其他脚本改动；变量缺失、格式错误或新增规则重复时不写入远端文件。
- `latencyTestUrl` 是唯一测速地址，默认 `https://g.cn/generate_204`；OwO、源 HTTP/File Provider、脚本生成的 Inline Provider 和所有策略组均从该变量读取。Bettbox 开启“覆写测速链接”时由客户端配置入口统一覆盖策略组与 Provider。
- 保留源节点和源 Provider，过滤套餐/流量提示节点，为源节点增加 `FC-` 前缀并按美国、日本、香港及倍率排序；首选地区与其他节点分别转为 Inline Provider。
- 重建 Global、地区、Apple、Emby、抓包、CC 内网和 Fallback 分组及规则；新加坡、台湾不生成地区组。
- `CC-intranet-en5` 使用 `dns-follow-interface: true` 和 `allow-other-interface: true`；内网域名仅维护一份路由清单，固定 hosts 保留为注释回退。
- DNS 使用 Fake-IP、国内外分流和源节点域名策略；源 hosts 只在唯一 `proxy-server-nameserver` 指向 `dns.listen` 时改写节点服务器地址，不写回最终配置；域名与公共 DNS 匹配忽略大小写，DNS 的 `#DIRECT` 后缀会保留。
- 脚本生成的 TUN 配置固定使用 `mixed` 栈，与 macOS 客户端的实际运行映射一致。
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
- Android 检查更新改读 `custom-update-feed` 分支的静态 JSON 更新源，不再调用容易触发匿名限流的 GitHub Releases API；更新源包含 Release tag、版本说明、APK 地址、大小和 SHA-256，代码位于 `lib/common/request.dart`，发布生成位于 `.github/workflows/custom-build.yml`。
- 自动检查更新与手动检查使用同一自定义发布源；草稿 Release 不会被识别为可用更新。

### TUN 自动托管系统 DNS

- macOS 的实际 TUN 配置将 `system` 栈映射为 `mixed`，规避 Mihomo 已知的微信聊天图片/表情无法接收问题；显式选择 `mixed` 或 `gvisor` 时保持原值。统一落点为 `lib/models/clash_config.dart` 的 `TunExt.getRealTun`，回归测试位于 `test/models/clash_config_test.dart`。
- 桌面端切换 TUN 栈时使用现有串行内核重启流程，不再对运行中的 TUN 热切换栈；核心 IPC 在连接关闭或写入失败后立即丢弃旧 socket，异常退出会记录退出码与最后一段 stderr，避免继续写旧连接产生 `Broken pipe`。代码位于 `lib/views/config/network.dart` 与 `lib/clash/service.dart`。
- macOS 开启虚拟网卡时自动托管系统 DNS，不再提供独立开关；关闭虚拟网卡或停止 Bettbox 时自动恢复。
- 修复 Wi-Fi 之间切换时连接类型不变、网络变化事件被过滤，导致 DNS 与 TUN 继续沿用旧网络状态的问题。
- 通过默认出口的网卡、网关、地址、网络服务及 DHCP 信息生成网络指纹，Wi-Fi 之间切换或默认出口租约变化时也能识别真实网络变化。
- 等待新网络稳定后，自动迁移托管 DNS、关闭旧连接、刷新 DNS/Fake-IP 缓存，并停止后重建 TUN listener、重新探测默认出口。
- 网络恢复任务支持代际取消，手动停止和退出优先于后台恢复，避免恢复流程重新拉起已停止的监听与 TUN。
- 核心监听、连接清理和 DNS/Fake-IP 缓存刷新设置明确的成功判定及时间边界，避免超时后仍继续恢复 TUN。
- 生效期间当前网络服务只使用 `223.5.5.5`，避免 DHCP DNS 优先绕过 Mihomo。
- 停止、退出或下次启动检测到残留状态时，恢复启用前的 DNS；启用前没有自定义 DNS 时恢复为系统自动获取。
- 启动 TUN 前检测其他 VPN 遗留的 `1.0.0.0/8` utun 路由；发现冲突时保持 TUN 关闭并提示接口，避免核心以 `file exists` 失败。
- macOS TUN 关闭竞态产生 `ENOTSOCK` 时按标准关闭处理并退出旧批量读协程，避免 `batch read packet` 日志风暴、核心与界面 CPU 满载以及后续连接受影响；关闭感知包装器同时保留 Mixed/GVisor 所需的 `GVisorTun` 方法集，避免 Mixed 建栈时核心崩溃。代码位于 `core/Clash.Meta/listener/sing_tun/server_notwindows.go` 与 `server_notwindows_gvisor.go`，回归测试为同目录 `server_notwindows_test.go` 和 `server_notwindows_gvisor_test.go`。

### macOS 菜单栏与托盘

- 增加实时上传、下载速率显示，可在“更多 → 增强工具”中独立开关。
- Bettbox 未启动，或系统代理与虚拟网卡均未开启时，图标和速率文字显示为灰色。
- 系统代理与虚拟网卡均关闭时上传、下载立即归零；重新开启任一接管方式时清除速率文字遗留的灰色前景色并恢复系统高亮色。托盘监听内核实际 TUN 状态，两个开关完成切换后均强制同步最终状态，避免图标停留在启动过程中的灰色快照。共享状态逻辑位于 `lib/providers/state.dart`、`lib/controller.dart` 和 `lib/common/tray.dart`，macOS 文字渲染位于 `plugins/tray_manager/macos/Classes/TrayIcon.swift`，回归测试位于 `test/common/tray_active_state_test.dart`。
- 启用状态使用 macOS 原生自适应颜色，自动匹配菜单栏背景。
- 恢复 macOS 菜单栏使用模板图标和原生 active/inactive 着色，避免上游托盘资源切换后活动状态显示为纯黑；代码位于 `lib/common/utils.dart`、`lib/common/tray.dart` 和 `plugins/tray_manager/macos/Classes/TrayIcon.swift`。
- 托盘点击行为支持“显示面板”和“显示菜单”，左键与右键可以分别配置。
- 移除旧“托盘增强”总开关，代理组菜单直接可用；速率和点击行为均作为增强工具中的独立一级设置。
- 修复应用位于后台时从托盘启动后，图标和菜单状态未立即更新的问题。
- 修复从托盘重启内核后，运行状态未主动同步，导致图标持续置灰且菜单仍显示“启动”的问题。
- 节点测速逻辑已在本次上游融合中恢复为 Bettbox `upstream/main` 原实现；此前自定义的并发、去重、缓存、独立超时、Provider 生命周期取消、测速诊断和 Provider URL 覆写逻辑已删除，相关行为以远端实现为准。
- 托盘一级菜单依次显示系统代理、虚拟网卡，并将重启内核放在一级、重启软件放入工具子菜单；“显示窗口 / 网络面板 / 系统代理 / 虚拟网卡 / 重启内核 / 退出”使用 macOS 原生菜单快捷键 `⌘M / ⌘D / ⌘S / ⌘E / ⌘R / ⌘Q`，菜单同步显示快捷键标识。
- 二级菜单父项只负责展开子菜单，不再响应无效的空点击。
- 节点测速结果使用独立右对齐列，菜单宽度同时为节点名称和结果预留空间。
- 移除独立的启动、停止入口，运行状态完全由系统代理和虚拟网卡开关驱动。
- 系统代理管理器只关闭当前 Bettbox 进程成功启用过的代理；启动、退出或状态同步时若系统代理开关本来就是关闭状态，不调用系统关闭代理命令，确保系统代理与虚拟网卡均关闭时不影响 Surge 等其他软件的系统代理。代码位于 `plugins/proxy/lib/proxy.dart`。
- 首次安装特权工具成功后原位刷新托盘，避免图标短暂消失再出现。

### 桌面网络面板

- 桌面导航以一个“面板”入口替换原“请求 / 连接 / 日志”三个页签；托盘菜单仍使用“网络面板”文案。Android 将最近请求、活动连接、DNS、设备、流量统计、日志和 Sub-Store 直接放在“网络”一级分组，不保留“工具 → 面板”二级目录。桌面点击入口后以同一可执行文件的 `--network-panel` 参数启动独立进程，在 Dock/任务栏使用基于 Bettbox 原图标逐像素保留、仅于右下角叠加蓝色网络波形徽标的专属图标；关闭面板不影响 Bettbox，Bettbox 正常退出或主进程管道断开时会关闭面板。
- 独立进程不初始化 Mihomo、单例锁或托盘，通过 `ExternalControl` 现有本地 UDS/TCP 通道读取主进程请求、连接和日志并执行清理/断连操作；请求与日志变更使用持久订阅连接主动通知，一次性请求在响应刷新后由服务端立即关闭 socket，避免面板刷新持续泄漏文件描述符。移除 `desktop_multi_window` 和子引擎全插件重复注册，避免 `tray_manager` 全局事件通道被子窗口覆盖。
- Android 在“更多”中以“工具”替换原“面板”入口，并以移动端目录分别进入最近请求、活动连接、DNS、设备、流量统计、日志和 Sub-Store；请求与连接点击后压入独立详情路由，系统返回手势只返回来源列表。macOS、Windows 和 Linux 的独立面板保留顶部页签、搜索与左侧 Mihomo 分类，内容区复用 Android 卡片页面，选中连接仍在底部展开可拖动详情并持久化高度，右键继续提供生成规则。两端共享数据映射、状态、规则生成与详情内容，继续复用主应用 Provider 或独立面板 IPC，不创建第二套数据服务。
- 面板集成最近请求、活动连接、DNS、设备、流量统计、日志和独立 Sub-Store 管理标签；最近请求与活动连接直接按 Mihomo `TrackerInfo` 的 `process / sourceIP / host|destinationIP / network / rule / chains` 动态分类并支持全文搜索。Android 与 macOS/Windows/Linux 统一维护同一套卡片列表，旧桌面表格、表头排序和列宽持久化实现已删除；macOS 通过原生 `NSWorkspace` 按进程路径读取 App 图标，并在进程侧栏、连接列表和详情中复用显示。同一路径的并发图标请求会合并，原生端只编码 64×64 PNG，避免面板打开时因重复全尺寸图标转换而卡死。
- 顶栏搜索框与页签统一垂直居中；桌面保留左侧分类，Android 以横向分类条和候选底部列表筛选。请求/连接可按进程、来源、目标、协议、规则、出站链及连接状态分类；设备只按内核可确认的进程、来源地址和活动/历史状态分类，流量维度直接切换聚合字段，日志分类使用实际事件级别 `error / warning / info / debug`。选中项使用透明背景、主题主色描边和明确前景色，避免主题色导致文字不可读。
- 请求和连接列表不展示内部 ID，状态按 Mihomo 活动快照、真实出站 socket、`REJECT` 和链路终态区分为红色失败/拦截、黄色建立中、蓝色已连接、绿色已结束及灰色未知。“日期”列改为“时间”并按本机时区显示，规则类型使用独立灰色标签与规则参数区分，策略列只显示最终策略，完整策略链仅在详情展示；策略文本连续空白统一压缩。内置 HarmonyOS Sans 字体补齐标准 U+0020 空格字形，从字体根源统一修复列表、详情、输入框及其他全局文本的异常大词间距，不再在各组件中拆分文本或硬编码间隔。无进程且无来源地址的 Mihomo 内部连接被过滤，真实客户端的 `REJECT` 规则命中继续保留。
- 请求、连接、DNS 和设备统一使用卡片式 `ListView` 惰性创建可见项，不再保留桌面表格或横向滚动实现；展开底部详情时列表与详情区域保持独立。
- DNS 由 `GlobalState.patchRawConfig` 读取当前生效配置，按 `default-nameserver / nameserver / fallback / proxy-server-nameserver / direct-nameserver / nameserver-policy / hosts` 原始配置键分类；系统 Hosts 读取 `/etc/hosts`，运行缓存按 `dnsMode` 的 `fake-ip / redir-host / hosts / normal` 分类并仅保留带有效目标 IP 的最新可见记录。移动端提供“配置 DNS / Hosts / 运行缓存 / Fake-IP”分组及可见缓存数量；清除内核 DNS 与 Fake-IP 后同步隐藏清理前的运行记录，之后由新连接重新填充。
- DNS 页通过 `flushDnsCache` 同时调用内核 DNS 缓存与 Fake-IP 映射清理；连接链路遇到 `dns_cache` 事件时显示“DNS 缓存命中（本次未发起 DNS 查询）”，标题列根据实际最长步骤文案动态限宽。
- 最近请求与活动连接的右键/更多菜单在 `lib/views/network_monitor_rule.dart` 提供“生成规则”对话框，支持域名、IP CIDR、进程名/路径、端口与网络类型；规则类型仅能下拉选择，匹配内容和策略可编辑，策略可从当前策略组/节点列表替换并复制最终 Clash/Mihomo 文本。Android 策略箭头打开可完整滚动的底部列表，避免长策略清单被弹层截断；规则生成、Sub-Store 凭据和规则管理统一使用 90% 紧凑字号。生成结果可直接加入当前配置的“附加到原始规则 / 覆盖原始规则”，无需自动开启覆写；重复规则二次确认后才继续添加。Sub-Store 入口既可将新规则补充至 `BETTBOX_CUSTOM_RULES` 顶部，也可读取后修改、删除和拖动排序；凭据态按内容使用较小高度，进入规则管理后动画展开，loading 由 Dialog 统一裁剪圆角。管理页每条规则使用独立边框卡片并支持可选说明，说明作为 JS 注释与规则同步读写；管理取消回到 Sub-Store 凭据页。文件地址与 API Key 仅在成功后写入本机最近 10 条历史，输入框本身只编辑、右侧箭头才展开历史。
- `monitorCompactWhitespace` 是面板策略名的唯一规范化入口，`monitorRulePolicies`、`monitorGeneratedRule`、列表、详情与规则预览共用该结果，避免配置中的 Unicode/连续空白在不同页面反复出现。策略编辑改为 `TextField + MenuAnchor`，输入区不自动弹菜单，只有右侧箭头控制展开。
- 结构化 Mihomo 链路的步骤标题、毫秒时间戳和事件内容使用独立列，内容多行换行保持自身左边界对齐。
- 流量页调用 Mihomo `getTraffic / getTotalTraffic` 展示实时和累计上传下载；最近完成请求与活动连接去重后只承担出站链、规则类型、进程、来源地址、网络协议和目标主机的样本聚合，不再将有限环形历史记录求和作为总流量。
- 请求与日志由主窗口收到新数据后主动推送，面板将事件刷新限制为最多每 250 ms 一次；活动连接受 Mihomo 快照接口限制，仅在连接页可见时每 250 ms 更新，流量页按内核统计周期每秒更新，其他页面每 5 秒兜底同步。
- Mihomo 在连接加入和离开时均回传同一连接 ID，Bettbox 请求记录按 ID 原位更新，最近请求页收到事件后立即刷新活动/完成状态，不再依赖 250 ms 主动快照；独立进程订阅通知显式刷新 socket，避免状态事件延迟到 5 秒兜底刷新。该页展示的是 Mihomo 连接而非 HTTPS 内部请求，浏览器复用 HTTP/2 或 QUIC 连接时不会新增记录。
- macOS 进程图标在 Mihomo 未返回进程路径时改由 `NSWorkspace.runningApplications` 按进程名读取运行中 App 图标；同一进程的历史记录会复用当前快照中优先选出的 `.app` 路径。图标加载完成回调不会返回并自等待当前 Future，首屏可见组件能立即原位替换占位图，修复必须滚出再滚回才显示的问题。
- 选中请求或连接后展开底部详情，顶部拖拽手柄可调整面板高度。通用页使用占满详情视口的响应式布局，地址和进程信息独占整行，所有长文本自动换行且可框选复制；显式滚动条固定在面板最右侧，并提供复制详情按钮。信息区分客户端地址、目标地址、内核 Fake-IP、实际出站本地地址和直连目标/代理入口地址，GeoIP/ASN 仅在 TrackerInfo 或现有核心 GeoIP 查询返回值时显示。原“计时 & 日志”改为“Mihomo 链路”，链路固定先展示当前请求目标和目标解析方式，本地未解析的代理目标明确标记为“真实解析交由代理远端完成”，不再将节点 DNS 冒充为当前目标解析；目标域名与代理节点服务器的 DNS 事件分别标记为“目标 DNS / 节点 DNS”，完整策略链按“命中规则 → 策略组 → 中间组 → 最终节点”顺序展示；链路中的节点 DNS 成功和缓存命中同步进入 DNS 页“运行缓存 / 出站节点”分类。链路文字支持选择复制，并优先展示 custom-mihomo 随当前连接返回的 DNS 逐服务器尝试/成功/失败、规则匹配、策略链和真实 socket 建立事件，旧内核才退回源端口与目标精确关联日志；Mihomo 不提供的 HTTP 请求/响应报头和正文页签已移除。
- custom-mihomo 的连接级链路上下文位于 `source/constant/connection_trace.go`，DNS、规则和出站事件接入 `source/dns` 与 `source/tunnel`，`source/tunnel/statistic/tracker.go` 将 `trace / outboundLocalAddress / outboundRemoteAddress` 随 TrackerInfo 返回；回归测试位于 `source/constant/connection_trace_test.go` 及相关 Go 包测试。
- 面板进程不跟踪来源应用，关闭时不调用任何应用激活 API；除 Bettbox 主进程负责启动和退出面板进程外，Dock、Cmd+Tab、窗口层级和关闭后的前台选择均由 macOS 按两个普通独立 App 处理。
- 面板代码位于 `lib/views/network_monitor.dart`、`lib/views/network_monitor_detail.dart`、`lib/views/network_monitor_mobile.dart`、`lib/views/network_monitor_data.dart` 和 `lib/views/network_monitor_rule.dart`，进程与 IPC 生命周期位于 `lib/common/window.dart`、`lib/common/external_control.dart`，桌面/Android 导航与托盘入口位于 `lib/common/navigation.dart`、`lib/views/network_monitor_navigation.dart` 和 `lib/common/tray.dart`；状态、时区、DNS 与入口回归测试位于 `test/views/network_monitor_test.dart`，独立进程入口覆盖 macOS、Windows 和 Linux。

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

- `custom-sync.yml` 仅保留手动触发，移除每天四次的定时同步与构建，避免无人值守同步上游代码。
- Release 保留本包相较上游的完整功能说明，并单独列出相较上一自定义 Release 的上游同步与自定义增量。
- `custom-build.yml` 的手动触发支持仅构建并发布 macOS Apple Silicon，或仅构建并发布 Android arm64-v8a；单平台模式只创建对应 Action 任务与 Release 资产，不消耗其他平台构建资源，两个选项不能同时启用；包含 Android 时同步生成静态 Android 更新源，桌面更新源仍按构建平台生成。
- 自定义应用代码发生变化但没有补充增量说明时拒绝发布，避免 Release 内容与安装包不一致。
- 自定义应用代码发生变化但没有同步完整改动总账时同样拒绝发布。

### 自定义内核同步

- 私有 `custom-mihomo` 当前提交为 `0509ad43f718`，基线记录为 Bettbox `main@6291ab3d7e2d`；内核源码树仍为已验证的 `f97606094dc467e6e8c62d22c586514d50c7d0d8`，继续应用 `opensnell-v6.patch`，并通过 `go test ./transport/snell ./adapter/outbound`。

### 2026-08-21 上游融合校验

- 上游 Bettbox `main@6291ab3d7e2d` 已合入 `custom-build`；托盘、网络面板、TUN/DNS、WebDAV 和应用内更新等自定义逻辑保留。
- 合并冲突修正了配置更新并发集合、桌面仪表盘生命周期判断及重复托盘点击弹窗；对应回归测试位于 `test/common/tray_active_state_test.dart`、`test/controller/macos_tun_startup_test.dart`、`test/models/clash_config_test.dart`、`test/models/webdav_shared_config_test.dart` 和 `test/views/network_monitor_test.dart`。
- 修复上游托盘点击回调与现有自定义回调重复合并，保留单份左右键处理及父级菜单空点击保护；代码位于 `lib/manager/tray_manager.dart`。
