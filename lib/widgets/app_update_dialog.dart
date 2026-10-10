import 'package:bett_box/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class AppUpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;
  final String notes;
  final String confirmText;
  final void Function(String) openUrl;
  final String releaseUrl;

  const AppUpdateDialog({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.notes,
    required this.confirmText,
    required this.openUrl,
    required this.releaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    void openSafeUrl(String value) {
      final uri = Uri.tryParse(value);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        openUrl(value);
      }
    }

    return CommonDialog(
      title: '发现新版本',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最新版本：$latestVersion', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('当前版本：$currentVersion', style: theme.textTheme.bodyMedium),
          const Divider(height: 28),
          Text('更新内容', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          MarkdownBlock(
            data: notes.trim().isEmpty ? '暂未提供更新说明，请查看完整发布页。' : notes,
            config:
                (theme.brightness == Brightness.dark
                        ? MarkdownConfig.darkConfig
                        : MarkdownConfig.defaultConfig)
                    .copy(configs: [LinkConfig(onTap: openSafeUrl)]),
          ),
          if (releaseUrl.isNotEmpty)
            TextButton.icon(
              onPressed: () => openSafeUrl(releaseUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('查看完整发布页'),
            ),
        ],
      ),
    );
  }
}
