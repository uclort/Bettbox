# Bettbox 仓库协作约束

- 始终使用中文沟通。
- 除非用户明确要求，否则不得创建 Pull Request。
- 同步或融合 Bettbox、Mihomo、Snell 上游代码前，必须完整阅读 `.custom-build/release-notes/CUSTOM_CHANGES.md`。
- 修改 Bettbox 自定义代码、custom-mihomo 或本地覆写脚本后，必须同步更新 `.custom-build/release-notes/CUSTOM_CHANGES.md`；本次发布增量另写入 `LATEST_CHANGES.md`。
- 本地覆写脚本包含私有订阅地址，不提交到公开仓库；修改后必须同步到私有 custom-mihomo 仓库的 `scripts/uclort-desktop.js`，并在 `CUSTOM_CHANGES.md` 更新功能、关键常量、代码落点和验证方式。
- 融合前后必须搜索 `BETTBOX-CUSTOM`，确认自定义逻辑仍然存在，并运行变更清单中对应的回归测试。
- 不得因为上游文件覆盖而静默删除自定义行为；无法兼容时先说明冲突和替代方案。
