### 修复

- 修复 macOS 从 F50-Hm 切换至 GWM 等限制公网 53 端口的网络后，DIRECT 网站出现 DNS 解析超时的问题。

### 修改

- 网络切换及应用启动时读取当前默认网卡通过 DHCP 获得的 DNS。
- DHCP DNS 仅注入 Mihomo 运行时，用于 DoH 引导解析和 DIRECT 域名解析。
- 不修改订阅、本地配置或 WebDAV 数据；再次切换网络时自动移除旧网络的 DNS。
