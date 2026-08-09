# Bettbox 仓库协作约束

- 始终使用中文沟通。
- 除非用户明确要求，否则不得创建 Pull Request。
- 同步或融合 Bettbox、Mihomo、Snell 上游代码前，必须完整阅读 `.custom-build/release-notes/CUSTOM_CHANGES.md`。
- 融合前后必须搜索 `BETTBOX-CUSTOM`，确认自定义逻辑仍然存在，并运行变更清单中对应的回归测试。
- 不得因为上游文件覆盖而静默删除自定义行为；无法兼容时先说明冲突和替代方案。
