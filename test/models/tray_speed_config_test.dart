import 'dart:convert';

import 'package:bett_box/models/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VpnProps 托盘速率', () {
    test('默认关闭', () {
      expect(const VpnProps().enableTraySpeed, isFalse);
    });

    test('序列化后能够恢复开关状态', () {
      const props = VpnProps(enableTraySpeed: true);

      final restored = VpnProps.fromJson(
        jsonDecode(jsonEncode(props.toJson())) as Map<String, dynamic>,
      );

      expect(restored.enableTraySpeed, isTrue);
    });
  });

  // BETTBOX-CUSTOM: 托盘完整节点链路与托盘显示策略组。
  group('AppSettingProps 托盘策略组显示', () {
    test('默认值', () {
      const props = AppSettingProps();
      expect(props.trayShowProxyChain, isFalse);
      expect(props.trayStatusGroupEnable, isFalse);
      expect(props.trayStatusGroupName, isEmpty);
      expect(props.trayStatusShowName, isFalse);
      expect(props.trayStatusShowNode, isTrue);
      expect(props.trayStatusShowChain, isFalse);
      expect(props.trayStatusShowDelay, isFalse);
      expect(props.trayStatusBeforeSpeed, isFalse);
    });

    test('序列化后能够恢复全部设置', () {
      const props = AppSettingProps(
        trayShowProxyChain: true,
        trayStatusGroupEnable: true,
        trayStatusGroupName: 'Global',
        trayStatusShowName: true,
        trayStatusShowNode: false,
        trayStatusShowChain: true,
        trayStatusShowDelay: true,
        trayStatusBeforeSpeed: true,
      );
      final restored = AppSettingProps.fromJson(
        jsonDecode(jsonEncode(props.toJson())) as Map<String, dynamic>,
      );
      expect(restored.trayShowProxyChain, isTrue);
      expect(restored.trayStatusGroupEnable, isTrue);
      expect(restored.trayStatusGroupName, 'Global');
      expect(restored.trayStatusShowName, isTrue);
      expect(restored.trayStatusShowNode, isFalse);
      expect(restored.trayStatusShowChain, isTrue);
      expect(restored.trayStatusShowDelay, isTrue);
      expect(restored.trayStatusBeforeSpeed, isTrue);
    });
  });
}
