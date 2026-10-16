### 2026-10-16 Impeller 配置与上游保持一致

- 源码版本更新为 `1.19.6+2026101602`，Impeller 按平台和架构选择，完整恢复上游构建逻辑，没有新增应用内开关。
- Intel Mac 打包时关闭 Impeller，继续使用 Skia/Metal，保留旧 Intel Mac 的闪屏兼容处理；Apple Silicon 移除强制关闭配置，恢复 Flutter 默认渲染路径。
- 最终 Mac 安装包按架构校验配置：Intel 必须明确关闭，Apple Silicon 必须沿用默认值；Windows/Linux 继续遵循上游关闭策略。
