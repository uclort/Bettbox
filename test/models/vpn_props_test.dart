import 'dart:convert';

import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VpnProps 托盘点击行为', () {
    test('默认左键显示面板、右键显示菜单', () {
      const props = VpnProps();

      expect(props.trayLeftClickBehavior, TrayClickBehavior.showPanel);
      expect(props.trayRightClickBehavior, TrayClickBehavior.showMenu);
    });

    test('序列化后能够独立恢复左右键设置', () {
      const props = VpnProps(
        trayLeftClickBehavior: TrayClickBehavior.showMenu,
        trayRightClickBehavior: TrayClickBehavior.showPanel,
      );

      final restored = VpnProps.fromJson(
        jsonDecode(jsonEncode(props.toJson())) as Map<String, dynamic>,
      );

      expect(restored.trayLeftClickBehavior, TrayClickBehavior.showMenu);
      expect(restored.trayRightClickBehavior, TrayClickBehavior.showPanel);
    });
  });

  group('首次安装网络开关', () {
    test('系统代理和虚拟网卡默认关闭', () {
      expect(const VpnProps().systemProxy, isFalse);
      expect(const NetworkProps().systemProxy, isFalse);
      expect(defaultClashConfig.tun.enable, isFalse);
    });

    test('旧配置缺少系统代理字段时保持关闭', () {
      expect(VpnProps.fromJson(const {}).systemProxy, isFalse);
      expect(NetworkProps.fromJson(const {}).systemProxy, isFalse);
    });
  });
}
