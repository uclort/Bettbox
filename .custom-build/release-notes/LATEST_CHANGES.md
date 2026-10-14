### 2026-10-14 修复 macOS Monterey / Intel Mac 闪屏与渲染异常

- macOS 显式关闭新版 Flutter 默认启用的 Impeller，统一使用 Skia/Metal，针对 2016 Intel MacBook Pro、macOS `12.7.6` 上视频显示的条纹、文字拉伸和页面内容丢失进行兼容回退；主窗口和独立网络面板同时生效。
- Intel 与 Apple Silicon 安装包都增加最终 App 渲染配置校验，防止打包时丢失 `FLTEnableImpeller = false`。
- 用户已在受影响的 2016 Intel MacBook Pro、macOS `12.7.6` 上确认同版本 Skia 兼容测试包正常；8 项相关 Flutter 回归及测试包配置、内容与签名校验通过。
