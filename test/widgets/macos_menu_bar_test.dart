import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/widgets/macos_menu_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('布局切换不能在新菜单注册后清空原生菜单', (tester) async {
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
    final wrap = ValueNotifier(false);
    addTearDown(wrap.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (_, child) {
          // 对应 Application.builder：响应式结构只能在菜单组件内部切换。
          return MacOSMenuBar(
            child: ValueListenableBuilder(
              valueListenable: wrap,
              builder: (_, wrapped, _) =>
                  wrapped ? Row(children: [Expanded(child: child!)]) : child!,
            ),
          );
        },
        home: const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    final original = tester.element(find.byType(PlatformMenuBar));
    final registered = calls
        .where((call) => call.method == 'Menu.setMenus')
        .length;
    wrap.value = true;
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(PlatformMenuBar)), same(original));
    final last = calls.lastWhere((call) => call.method == 'Menu.setMenus');
    expect((last.arguments as Map)['0'], isNotEmpty);
    wrap.value = false;
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(PlatformMenuBar)), same(original));
    expect((calls.last.arguments as Map)['0'], isNotEmpty);
    final setMenus = calls
        .where((call) => call.method == 'Menu.setMenus')
        .toList();
    expect(setMenus.length, registered, reason: '尺寸切换不应反复销毁或重建原生菜单');
    expect(
      setMenus.skip(1).every((call) => (call.arguments as Map)['0'].isNotEmpty),
      isTrue,
      reason: '初始清理之后不能再向原生层发送空菜单',
    );
  });

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
            ...GlobalMaterialLocalizations.delegates,
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
    final windowCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        windowCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      ),
    );
    final close = flatten(zh).firstWhere((item) => item.label == '关闭');
    final closeShortcut = close.shortcut! as SingleActivator;
    expect(closeShortcut.trigger, LogicalKeyboardKey.keyW);
    expect(closeShortcut.meta, isTrue);
    close.onSelected!();
    await tester.pump();
    expect(windowCalls.map((call) => call.method), ['close']);
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
