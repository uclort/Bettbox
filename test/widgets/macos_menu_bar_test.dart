import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/widgets/macos_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('macOS 菜单随主工程语言切换并移除无效模板功能', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter/menu'),
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/menu'),
        null,
      ),
    );

    Future<List<PlatformMenuItem>> load(Locale locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (_, child) => MacOSMenuBar(child: child!),
          home: const Scaffold(body: TextField()),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus;
    }

    Iterable<PlatformMenuItem> flatten(Iterable<PlatformMenuItem> items) sync* {
      for (final item in items) {
        yield item;
        yield* flatten(item is PlatformMenu ? item.menus : item.members);
      }
    }

    final zh = await load(const Locale('zh', 'CN'));
    expect(zh.map((item) => item.label), ['Bettbox', '编辑', '显示', '窗口']);
    final labels = flatten(zh).map((item) => item.label).toList();
    expect(
      labels,
      containsAll(['关于 Bettbox', '设置…', '检查更新', '复制', '粘贴', '退出 Bettbox']),
    );
    expect(
      labels.any(
        (label) =>
            label.contains('Services') ||
            label.contains('Spelling') ||
            label.contains('Find'),
      ),
      isFalse,
    );
    final en = await load(const Locale('en'));
    expect(en.map((item) => item.label), ['Bettbox', 'Edit', 'View', 'Window']);
    expect(flatten(en).map((item) => item.label), contains('Settings…'));
    final tc = await load(const Locale('zh', 'TC'));
    expect(tc.map((item) => item.label), ['Bettbox', '編輯', '顯示', '視窗']);
    expect(
      calls.where((call) => call.method == 'Menu.setMenus').length,
      greaterThanOrEqualTo(3),
    );
  });
}
