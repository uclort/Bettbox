import 'package:bett_box/common/tray.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('两个接管开关关闭时网速归零，任一开启时恢复活动状态', () async {
    const channel = MethodChannel('tray_manager');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final subject = Tray();
    addTearDown(subject.dispose);
    const active = TrayState(
      mode: Mode.rule,
      port: 7890,
      autoLaunch: false,
      systemProxy: false,
      tunEnable: true,
      isStart: true,
      locale: null,
      brightness: Brightness.light,
      groups: [],
      selectedMap: {},
      enableTraySpeed: true,
    );

    await subject.update(trayState: active, force: true);
    await subject.updateSpeed(Traffic(up: 1234, down: 5678));
    await subject.update(
      trayState: active.copyWith(tunEnable: false),
      force: true,
    );
    await subject.updateSpeed(Traffic(up: 9999, down: 9999));

    final inactiveSpeed = calls.lastWhere(
      (call) => call.method == 'setSpeedTitle',
    );
    expect(inactiveSpeed.arguments, {
      'upload': 0,
      'download': 0,
      'active': false,
    });

    await subject.update(trayState: active, force: true);
    expect(calls.lastWhere((call) => call.method == 'setActive').arguments, {
      'active': true,
    });

    await subject.update(
      trayState: active.copyWith(tunEnable: false, systemProxy: true),
      force: true,
    );

    expect(calls.lastWhere((call) => call.method == 'setActive').arguments, {
      'active': true,
    });
    expect(
      calls.lastWhere((call) => call.method == 'setSpeedTitle').arguments,
      {'upload': 0, 'download': 0, 'active': true},
    );
  });
}
