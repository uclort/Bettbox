import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';

class _Listener with TrayListener {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tray_manager');
  const codec = StandardMethodCodec();

  Future<void> nativeEvent(String name, [Object? arguments]) async {
    final completed = Completer<void>();
    // ignore: deprecated_member_use
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(MethodCall(name, arguments)),
          (_) => completed.complete(),
        );
    await completed.future;
  }

  test('真实平台编码对常见网速使用 int32、大值使用 int64', () {
    const valueCodec = StandardMessageCodec();
    expect(valueCodec.encodeMessage(0)!.getUint8(0), 3);
    expect(valueCodec.encodeMessage(1234)!.getUint8(0), 3);
    expect(valueCodec.encodeMessage(2147483648)!.getUint8(0), 4);
  });

  test('Windows 打开期间不重建菜单、不丢失选中 ID，关闭后应用最新状态', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final listener = _Listener();
    trayManager.addListener(listener);
    addTearDown(() => trayManager.removeListener(listener));
    var selected = '';
    final oldItem = MenuItem(label: '旧菜单', onClick: (_) => selected = '旧菜单');
    await trayManager.setContextMenu(Menu(items: [oldItem]));
    await nativeEvent('onMenuOpen');
    final latest = MenuItem(label: '最新菜单', onClick: (_) => selected = '最新菜单');
    await trayManager.setContextMenu(Menu(items: [MenuItem(label: '中间状态')]));
    await trayManager.setContextMenu(Menu(items: [latest]), keepMenuOpen: true);
    expect(calls.where((call) => call.method == 'setContextMenu').length, 1);
    await nativeEvent('onTrayMenuItemClick', {'id': oldItem.id});
    expect(selected, '旧菜单');
    await nativeEvent('onMenuClose');
    expect(trayManager.isMenuOpen, isFalse);
    expect(calls.where((call) => call.method == 'setContextMenu').length, 2);
    expect(calls.last.arguments['menu']['items'][0]['label'], '最新菜单');
    await nativeEvent('onTrayMenuItemClick', {'id': latest.id});
    expect(selected, '最新菜单');
    // 重复关闭不能重复重建。
    await nativeEvent('onMenuClose');
    expect(calls.where((call) => call.method == 'setContextMenu').length, 2);
  });
}
