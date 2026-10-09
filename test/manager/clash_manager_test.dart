import 'package:bett_box/manager/clash_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('桌面配置切换', () {
    test('首次添加配置且网络开关均关闭时不硬重启核心', () {
      expect(
        shouldHardRestartDesktopCoreOnProfileChange(
          isDesktop: true,
          profileChanged: true,
          isRunning: false,
          systemProxy: false,
          tunEnabled: false,
        ),
        isFalse,
      );
    });

    test('核心运行中或网络开关开启时继续硬重启核心', () {
      for (final state in [
        (isRunning: true, systemProxy: false, tunEnabled: false),
        (isRunning: false, systemProxy: true, tunEnabled: false),
        (isRunning: false, systemProxy: false, tunEnabled: true),
      ]) {
        expect(
          shouldHardRestartDesktopCoreOnProfileChange(
            isDesktop: true,
            profileChanged: true,
            isRunning: state.isRunning,
            systemProxy: state.systemProxy,
            tunEnabled: state.tunEnabled,
          ),
          isTrue,
        );
      }
    });
  });
}
