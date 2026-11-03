## 新增

- 内置 Tailscale 节点：内核作为独立设备加入 Tailnet，支持浏览器登录、设备列表与出口节点；桌面端另有「Tailscale App 共存」开关
- 托盘策略组菜单显示选中节点与延迟，支持 Option / Alt 显示隐藏组，Windows 增加字母快捷键
- 侧边栏图标、面板标题等界面自定义，隐藏策略组，Inline Provider 内容查看
- Android 应用权限页，本地网络权限运行时申请
- 应用内更新：Android 下载并安装，桌面端使用自定义更新源

## 优化

- 测速时保持托盘子菜单打开，菜单不再跳动
- macOS 网络切换、睡眠唤醒后自动恢复 TUN、DNS 与系统代理
- 内核重启与配置切换串行执行，避免启动竞态

## 修复

- macOS 静默启动时窗口闪现
- Tailscale 共存时控制面域名返回真实 IP，Rex 等内嵌 tsnet 的应用登录不再无响应
- 内置 Tailscale 节点重载配置后出现重复设备（Duplicate node key）

## 移除

- 无

## 兼容性变更

- 与上游共用同一份配置格式，自定义项默认关闭，升级后行为保持不变

## 内核

- 自定义 Mihomo 内核：Snell v6、direct proxy 跟随接口 DNS、Tailscale 出站状态接口
