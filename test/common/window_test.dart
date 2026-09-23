import 'package:bett_box/common/window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('窗口隐藏时移除 Dock 图标，窗口显示时恢复 Dock 图标', () async {
    const channel = MethodChannel('window_manager');
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

    await syncDockIconVisibility(isVisible: false);
    expect(calls.single.method, 'setSkipTaskbar');
    expect(calls.single.arguments, {'isSkipTaskbar': true});

    calls.clear();
    await syncDockIconVisibility(isVisible: true);
    expect(calls.single.method, 'setSkipTaskbar');
    expect(calls.single.arguments, {'isSkipTaskbar': false});
  });
}
