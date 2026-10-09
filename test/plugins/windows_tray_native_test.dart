import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'plugins/tray_manager/windows/tray_manager_plugin.cpp',
  ).readAsStringSync();

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
}
