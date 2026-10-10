import 'package:bett_box/common/tray.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  test('托盘图标与网速状态不再区分 macOS 和 Windows', () async {
    globalState.config = Config(themeProps: defaultThemeProps);
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
    final iconCall = calls.lastWhere((call) => call.method == 'setIcon');
    expect(iconCall.arguments['iconPath'], contains('icon_template.png'));
    expect(iconCall.arguments['isTemplate'], true);
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
      'brightness': 'light',
    });

    await subject.update(
      trayState: active.copyWith(tunEnable: false, systemProxy: true),
      force: true,
    );

    expect(calls.lastWhere((call) => call.method == 'setActive').arguments, {
      'active': true,
      'brightness': 'light',
    });
    expect(
      calls.lastWhere((call) => call.method == 'setSpeedTitle').arguments,
      {'upload': 0, 'download': 0, 'active': true},
    );
  });

  test('网速平台接口异常时仍初始化菜单并允许下一次重试', () async {
    globalState.config = Config(themeProps: defaultThemeProps);
    const channel = MethodChannel('tray_manager');
    final calls = <MethodCall>[];
    var failSpeed = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'setSpeedTitle' && failSpeed) {
            throw PlatformException(code: 'bad_args');
          }
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final subject = Tray();
    addTearDown(subject.dispose);
    const state = TrayState(
      mode: Mode.rule,
      port: 7890,
      autoLaunch: false,
      systemProxy: false,
      tunEnable: false,
      isStart: false,
      locale: null,
      brightness: Brightness.light,
      groups: [],
      selectedMap: {},
      enableTraySpeed: true,
    );
    // macOS 测试主机也用完整菜单路径，覆盖网速异常后的初始化。
    await subject.showContextMenu(trayState: state, groups: []);
    expect(calls.any((call) => call.method == 'setContextMenu'), isTrue);
    expect(calls.any((call) => call.method == 'popUpContextMenu'), isTrue);
    final failedCount = calls
        .where((call) => call.method == 'setSpeedTitle')
        .length;
    failSpeed = false;
    await subject.updateSpeed(Traffic());
    expect(
      calls.where((call) => call.method == 'setSpeedTitle').length,
      failedCount + 1,
    );
  });
}
