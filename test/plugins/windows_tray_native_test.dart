import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'plugins/tray_manager/windows/tray_manager_plugin.cpp',
  ).readAsStringSync();
  final trayManagerSource = File(
    'lib/manager/tray_manager.dart',
  ).readAsStringSync();
  final menuHostSource = File(
    'plugins/tray_manager/windows/tray_menu_host.h',
  ).readAsStringSync();
  final controllerSource = File('lib/controller.dart').readAsStringSync();
  final clashServiceSource = File('lib/clash/service.dart').readAsStringSync();
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
    final handleBlock = RegExp(
      r'std::optional<LRESULT> TrayManagerPlugin::HandleWindowProc\(HWND hWnd,[\s\S]*?'
      r'void TrayManagerPlugin::SetNativeMenuClickBehavior',
      multiLine: true,
    ).firstMatch(source)?.group(0);

    final popupBlock = RegExp(
      r'^void TrayManagerPlugin::SetNativeMenuClickBehavior[\s\S]*?'
      r'void TrayManagerPlugin::PopUpContextMenu[\s\S]*?'
      r'void TrayManagerPlugin::GetBounds',
      multiLine: true,
    ).firstMatch(source)?.group(0);

    expect(handleBlock, isNotNull);
    expect(handleBlock, contains('case WM_RBUTTONUP:'));
    expect(handleBlock, contains('if (right_click_shows_menu_)'));
    expect(handleBlock, contains('ShowContextMenu();'));
    expect(popupBlock, isNotNull);
    expect(source, contains('"setNativeMenuClickBehavior"'));
    expect(menuHostSource, contains('SetForegroundWindow(window_);'));
    expect(menuHostSource, contains('TPM_RIGHTBUTTON'));
    expect(menuHostSource, contains('TPM_RETURNCMD | TPM_NONOTIFY'));
    expect(menuHostSource, contains('PostMessageW(window_, WM_NULL, 0, 0);'));
    expect(source, contains('nid.hWnd = menu_host_->window();'));
    expect(popupBlock, contains('static_cast<int>(command)'));
    expect(popupBlock, isNot(contains('ShowWindow(')));
  });

  test('Windows 网速同时接受 32 位和 64 位编码且失败不阻断菜单', () {
    expect(source, contains('ReadInteger(ValueOrNull(args, "upload"))'));
    expect(source, contains('ReadInteger(ValueOrNull(args, "download"))'));
    final integerSource = File(
      'plugins/tray_manager/windows/tray_integer.h',
    ).readAsStringSync();
    expect(integerSource, contains('std::get_if<int32_t>'));
    expect(integerSource, contains('std::get_if<int64_t>'));
    expect(source, contains('if (is_menu_open_ && !should_keep_open)'));
    expect(source, contains('pending_menu_ = args;'));
  });

  test('Windows 托盘原生点击行为跟随统一配置', () {
    final updateBlock = RegExp(
      r'Future<void> _doUpdate\(\{[\s\S]*?'
      r'if \(!silent && !Platform\.isLinux\)',
      multiLine: true,
    ).firstMatch(File('lib/common/tray.dart').readAsStringSync())?.group(0);

    expect(updateBlock, isNotNull);
    expect(updateBlock, contains('setNativeMenuClickBehavior'));
    expect(updateBlock, contains('TrayClickBehavior.showMenu'));
    expect(
      File('plugins/tray_manager/lib/src/tray_manager.dart').readAsStringSync(),
      contains('Future<void> setNativeMenuClickBehavior'),
    );
  });

  test('Windows TUN 启动完成前验证 Core 健康状态', () {
    expect(controllerSource, contains('verifyCoreReady'));
    expect(
      controllerSource,
      contains('verifyCoreReady: () => clashService!.checkCoreHealth()'),
    );
    expect(controllerSource, contains('系统代理和虚拟网卡已自动关闭'));
  });

  test('网络开关使用真实 Core 健康状态而非陈旧运行标记', () {
    final updateTunBlock = RegExp(
      r'Future<void> updateTun\(\[bool\? enabled\]\) async \{[\s\S]*?'
      r'Future<void> updateSystemProxy',
      multiLine: true,
    ).firstMatch(controllerSource)?.group(0);

    expect(updateTunBlock, isNotNull);
    expect(updateTunBlock, contains('await isDesktopCoreHealthy()'));
    expect(
      controllerSource,
      contains('return await clashService!.checkCoreHealth();'),
    );
  });

  test('Helper Core 的 IPC 断开也会触发异常退出回滚', () {
    expect(clashServiceSource, contains('onUnexpectedExit'));
    expect(
      clashServiceSource,
      contains("_notifyUnexpectedExit(details ?? 'BettboxCore 控制连接意外断开')"),
    );
    expect(clashServiceSource, contains('BettboxCore 启动超时，未建立控制连接'));
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
