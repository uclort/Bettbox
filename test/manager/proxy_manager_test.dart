import 'package:bett_box/manager/proxy_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('系统代理启动同步', () {
    test('应用初始化期间等待核心启动，不先关闭将要启用的系统代理', () {
      expect(
        shouldDeferInitialSystemProxySync(
          isInitialized: false,
          isStart: false,
          systemProxy: true,
        ),
        isTrue,
      );
    });

    test('核心启动后立即同步系统代理', () {
      expect(
        shouldDeferInitialSystemProxySync(
          isInitialized: false,
          isStart: true,
          systemProxy: true,
        ),
        isFalse,
      );
    });

    test('系统代理关闭时立即清理残留设置', () {
      expect(
        shouldDeferInitialSystemProxySync(
          isInitialized: false,
          isStart: false,
          systemProxy: false,
        ),
        isFalse,
      );
    });
  });
}
