import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'plugins/tray_manager/windows/tray_manager_plugin.cpp',
  ).readAsStringSync();
  final trayManagerSource = File(
    'lib/manager/tray_manager.dart',
  ).readAsStringSync();
  final controllerSource = File('lib/controller.dart').readAsStringSync();
  final clashServiceSource = File(
    'lib/clash/service.dart',
  ).readAsStringSync();
  final applicationSource = File('lib/application.dart').readAsStringSync();

  test('Windows 托盘网速写入 tooltip 并保留应用名称', () {
    expect(source, contains('std::wstring base_tooltip_;'));
    expect(source, contains('void TrayManagerPlugin::_UpdateToolTip()'));
    expect(source, contains('StringCchCopyW(nid.szTip'));

    final setSpeedBlock = RegExp(
      r'^void TrayManagerPlugin::SetSpeedTitle[\s\S]*?'
      r'void TrayManagerPlugin::ClearSpeedTitle',
      multiLine: true,
    ).firstMatch(source)?.group(0);
    expect(setSpeedBlock, isNotNull);
    expect(setSpeedBlock, contains('_UpdateToolTip();'));
  });

  test('Windows 启用图标按系统明暗使用高对比前景色', () {
    expect(source, contains('bool tray_icon_dark_ = false;'));
    expect(source, contains('*brightness == "dark"'));
    expect(source, contains('isDark ? 255 : 0'));
    expect(
      source,
      contains('Color tint(255, tintValue, tintValue, tintValue)'),
    );
    expect(
      source,
      contains('ApplyTemplateIcon(tray_icon_active_, tray_icon_dark_)'),
    );
  });

  test('Windows 右键菜单按系统要求激活并完成消息循环', () {
    final popupBlock = RegExp(
      r'^void TrayManagerPlugin::PopUpContextMenu[\s\S]*?'
      r'void TrayManagerPlugin::GetBounds',
      multiLine: true,
    ).firstMatch(source)?.group(0);

    expect(popupBlock, isNotNull);
    expect(popupBlock, contains('SetForegroundWindow(hWnd);'));
    expect(popupBlock, contains('TPM_RIGHTBUTTON'));
    expect(popupBlock, contains('PostMessage(hWnd, WM_NULL, 0, 0);'));
    expect(
      source,
      contains('static_cast<int>(LOWORD(wParam))'),
    );
  });

  test('Windows 托盘点击直接弹出缓存菜单，不在点击回调中异步重建', () {
    final clickBlock = RegExp(
      r'Future<void> _handleTrayIconClick[\s\S]*?'
      r'@override\s+void onTrayIconRightMouseDown',
    ).firstMatch(trayManagerSource)?.group(0);

    expect(clickBlock, isNotNull);
    expect(clickBlock, contains('if (system.isWindows)'));
    expect(
      clickBlock,
      contains('popUpContextMenu(bringAppToFront: true)'),
    );
    expect(
      clickBlock,
      contains('globalState.appController.showTrayMenu()'),
    );
  });

  test('Windows TUN 启动完成前验证 Core 健康状态', () {
    expect(controllerSource, contains('verifyCoreReady'));
    expect(
      controllerSource,
      contains('verifyCoreReady: () => clashService!.checkCoreHealth()'),
    );
    expect(
      controllerSource,
      contains('系统代理和虚拟网卡已自动关闭'),
    );
  });

  test('Helper Core 的 IPC 断开也会触发异常退出回滚', () {
    expect(clashServiceSource, contains('onUnexpectedExit'));
    expect(
      clashServiceSource,
      contains("_notifyUnexpectedExit(details ?? 'BettboxCore 控制连接意外断开')"),
    );
    expect(
      clashServiceSource,
      contains('BettboxCore 启动超时，未建立控制连接'),
    );
  });

  test('网络面板控制端在应用初始化前启动', () {
    final initBlock = RegExp(
      r'Future<void> _initApp\(\) async \{[\s\S]*?'
      r'globalState\.appController\.initLink\(\);',
    ).firstMatch(applicationSource)?.group(0);

    expect(initBlock, isNotNull);
    expect(
      initBlock!.indexOf('ExternalControl.start()'),
      lessThan(initBlock.indexOf('globalState.appController.init()')),
    );
  });
}
