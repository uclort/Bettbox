import 'package:bett_box/common/fixed.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/app_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.light,
      requests: FixedList(100),
      logs: FixedList(100),
      traffics: FixedList(30),
      totalTraffic: Traffic(),
      version: 1,
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });
  testWidgets('更新框显示完整版本、Markdown 正文和发布页入口', (tester) async {
    final links = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AppUpdateDialog(
            currentVersion: '1.19.3+2090000183',
            latestVersion: '1.19.3+2090000184',
            notes: '## 更新标题\n\n- **完整正文**\n\n[链接](https://example.com)',
            confirmText: '下载并安装',
            openUrl: links.add,
            releaseUrl: 'https://github.com/uclort/Bettbox/releases/tag/test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('当前版本：1.19.3+2090000183'), findsOneWidget);
    expect(find.text('最新版本：1.19.3+2090000184'), findsOneWidget);
    expect(find.textContaining('更新标题', findRichText: true), findsOneWidget);
    expect(find.textContaining('完整正文', findRichText: true), findsOneWidget);
    await tester.ensureVisible(find.text('查看完整发布页'));
    await tester.tap(find.text('查看完整发布页'));
    expect(links, ['https://github.com/uclort/Bettbox/releases/tag/test']);
  });

  testWidgets('空描述有兜底且拒绝打开非 HTTP 发布链接', (tester) async {
    final links = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AppUpdateDialog(
            currentVersion: '1.19.3+183',
            latestVersion: '1.19.3+184',
            notes: '',
            confirmText: '下载并安装',
            openUrl: links.add,
            releaseUrl: 'file:///tmp/not-a-release',
          ),
        ),
      ),
    );
    expect(find.textContaining('暂未提供更新说明', findRichText: true), findsOneWidget);
    await tester.tap(find.text('查看完整发布页'));
    expect(links, isEmpty);
  });
}
