import 'dart:async';
import 'dart:io';

import 'package:bett_box/controller.dart';
import 'package:bett_box/common/system.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Windows Helper 启动', () {
    test('服务启动失败时不进入健康等待', () async {
      var waited = false;

      final healthy = await startWindowsHelperAndWait(
        start: () async => ProcessResult(1, 5, '', 'Access is denied.'),
        waitForHealthy: () async {
          waited = true;
          return true;
        },
      );

      expect(healthy, isFalse);
      expect(waited, isFalse);
    });

    test('服务启动成功后才等待 Helper 可用', () async {
      var waited = false;

      final healthy = await startWindowsHelperAndWait(
        start: () async => ProcessResult(1, 0, '', ''),
        waitForHealthy: () async {
          waited = true;
          return true;
        },
      );

      expect(healthy, isTrue);
      expect(waited, isTrue);
    });

    test('管理员授权后持续等待 Helper 变为可用', () async {
      var attempts = 0;

      final healthy = await waitForWindowsHelperHealthy(
        check: () async => ++attempts == 4,
        maxAttempts: 6,
        interval: Duration.zero,
      );

      expect(healthy, isTrue);
      expect(attempts, 4);
    });

    test('达到最大尝试次数后才报告 Helper 不可用', () async {
      var attempts = 0;

      final healthy = await waitForWindowsHelperHealthy(
        check: () async {
          attempts++;
          return false;
        },
        maxAttempts: 3,
        interval: Duration.zero,
      );

      expect(healthy, isFalse);
      expect(attempts, 3);
    });
  });

  group('桌面 TUN 启动', () {
    test('等待管理员授权完成后才启动监听', () async {
      final authorization = Completer<Result<bool>>();
      final events = <String>[];

      final startup = runDesktopTunStartup(
        requestAdmin: () => authorization.future,
        restartCore: () async => events.add('restart'),
        setupCoreWithoutTun: () async => events.add('setupWithoutTun'),
        applyTunConfig: () async => events.add('apply'),
        startListener: () async => events.add('start'),
        stopListener: () async => events.add('stop'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);

      authorization.complete(Result.success(true));
      expect(await startup, isTrue);
      expect(events, ['start', 'apply']);
    });

    test('starts the listener before applying TUN', () async {
      final events = <String>[];

      final started = await runDesktopTunStartup(
        requestAdmin: () async {
          events.add('authorize');
          return Result.success(true);
        },
        restartCore: () async => events.add('restart'),
        setupCoreWithoutTun: () async => events.add('setupWithoutTun'),
        applyTunConfig: () async => events.add('apply'),
        startListener: () async => events.add('start'),
        stopListener: () async => events.add('stop'),
      );

      expect(started, isTrue);
      expect(events, ['authorize', 'start', 'apply']);
    });

    test(
      'restarts, starts, then reapplies TUN after new authorization',
      () async {
        final events = <String>[];

        final started = await runDesktopTunStartup(
          requestAdmin: () async {
            events.add('authorize');
            return Result.success(true, needRestart: true);
          },
          restartCore: () async => events.add('restart'),
          setupCoreWithoutTun: () async => events.add('setupWithoutTun'),
          applyTunConfig: () async => events.add('apply'),
          startListener: () async => events.add('start'),
          stopListener: () async => events.add('stop'),
        );

        expect(started, isTrue);
        expect(events, [
          'authorize',
          'restart',
          'setupWithoutTun',
          'start',
          'apply',
        ]);
      },
    );

    test('does not start when authorization fails', () async {
      final events = <String>[];

      final started = await runDesktopTunStartup(
        requestAdmin: () async {
          events.add('authorize');
          return Result<bool>.error('authorization failed');
        },
        restartCore: () async => events.add('restart'),
        setupCoreWithoutTun: () async => events.add('setupWithoutTun'),
        applyTunConfig: () async => events.add('apply'),
        startListener: () async => events.add('start'),
        stopListener: () async => events.add('stop'),
      );

      expect(started, isFalse);
      expect(events, ['authorize']);
    });

    test('stops the listener when applying TUN fails', () async {
      final events = <String>[];

      await expectLater(
        runDesktopTunStartup(
          requestAdmin: () async {
            events.add('authorize');
            return Result.success(true);
          },
          restartCore: () async => events.add('restart'),
          setupCoreWithoutTun: () async => events.add('setupWithoutTun'),
          applyTunConfig: () async {
            events.add('apply');
            throw StateError('apply failed');
          },
          startListener: () async => events.add('start'),
          stopListener: () async => events.add('stop'),
        ),
        throwsStateError,
      );

      expect(events, ['authorize', 'start', 'apply', 'stop']);
    });

    test('does not start when restarting the core fails', () async {
      final events = <String>[];

      await expectLater(
        runDesktopTunStartup(
          requestAdmin: () async {
            events.add('authorize');
            return Result.success(true, needRestart: true);
          },
          restartCore: () async {
            events.add('restart');
            throw StateError('restart failed');
          },
          setupCoreWithoutTun: () async => events.add('setupWithoutTun'),
          applyTunConfig: () async => events.add('apply'),
          startListener: () async => events.add('start'),
          stopListener: () async => events.add('stop'),
        ),
        throwsStateError,
      );

      expect(events, ['authorize', 'restart']);
    });

    test('does not start when the post-restart non-TUN setup fails', () async {
      final events = <String>[];

      await expectLater(
        runDesktopTunStartup(
          requestAdmin: () async {
            events.add('authorize');
            return Result.success(true, needRestart: true);
          },
          restartCore: () async => events.add('restart'),
          setupCoreWithoutTun: () async {
            events.add('setupWithoutTun');
            throw StateError('setup failed');
          },
          applyTunConfig: () async => events.add('apply'),
          startListener: () async => events.add('start'),
          stopListener: () async => events.add('stop'),
        ),
        throwsStateError,
      );

      expect(events, ['authorize', 'restart', 'setupWithoutTun']);
    });
  });

  group('macOS TUN 重建', () {
    test('按关闭 TUN、停止监听、修复网络、启动监听、恢复 TUN 的顺序执行', () async {
      final events = <String>[];

      await rebuildMacOSTun(
        disableTun: () async => events.add('disableTun'),
        stopListener: () async => events.add('stopListener'),
        repairNetwork: () async => events.add('repairNetwork'),
        startListener: () async => events.add('startListener'),
        restoreTun: () async => events.add('restoreTun'),
      );

      expect(events, [
        'disableTun',
        'stopListener',
        'repairNetwork',
        'startListener',
        'restoreTun',
      ]);
    });

    test('网络修复失败时仍恢复监听与 TUN', () async {
      final events = <String>[];

      await expectLater(
        rebuildMacOSTun(
          disableTun: () async => events.add('disableTun'),
          stopListener: () async => events.add('stopListener'),
          repairNetwork: () async {
            events.add('repairNetwork');
            throw StateError('repair failed');
          },
          startListener: () async => events.add('startListener'),
          restoreTun: () async => events.add('restoreTun'),
        ),
        throwsStateError,
      );

      expect(events, [
        'disableTun',
        'stopListener',
        'repairNetwork',
        'startListener',
        'restoreTun',
      ]);
    });

    test('关闭 TUN 失败时仍尝试恢复原状态', () async {
      final events = <String>[];

      await expectLater(
        rebuildMacOSTun(
          disableTun: () async {
            events.add('disableTun');
            throw StateError('disable failed');
          },
          stopListener: () async => events.add('stopListener'),
          repairNetwork: () async => events.add('repairNetwork'),
          startListener: () async => events.add('startListener'),
          restoreTun: () async => events.add('restoreTun'),
        ),
        throwsStateError,
      );

      expect(events, ['disableTun', 'restoreTun']);
    });

    test('停止监听失败时先确认监听恢复，再恢复 TUN', () async {
      final events = <String>[];

      await expectLater(
        rebuildMacOSTun(
          disableTun: () async => events.add('disableTun'),
          stopListener: () async {
            events.add('stopListener');
            throw StateError('stop failed');
          },
          repairNetwork: () async => events.add('repairNetwork'),
          startListener: () async => events.add('startListener'),
          restoreTun: () async => events.add('restoreTun'),
        ),
        throwsStateError,
      );

      expect(events, [
        'disableTun',
        'stopListener',
        'startListener',
        'restoreTun',
      ]);
    });

    test('启动监听失败时不恢复 TUN', () async {
      final events = <String>[];

      await expectLater(
        rebuildMacOSTun(
          disableTun: () async => events.add('disableTun'),
          stopListener: () async => events.add('stopListener'),
          repairNetwork: () async => events.add('repairNetwork'),
          startListener: () async {
            events.add('startListener');
            throw StateError('start failed');
          },
          restoreTun: () async => events.add('restoreTun'),
        ),
        throwsStateError,
      );

      expect(events, [
        'disableTun',
        'stopListener',
        'repairNetwork',
        'startListener',
      ]);
    });

    test('用户主动停止或退出后不再恢复监听和 TUN', () async {
      final events = <String>[];
      var shouldRestore = true;

      await rebuildMacOSTun(
        disableTun: () async => events.add('disableTun'),
        stopListener: () async => events.add('stopListener'),
        repairNetwork: () async {
          events.add('repairNetwork');
          shouldRestore = false;
        },
        startListener: () async => events.add('startListener'),
        restoreTun: () async => events.add('restoreTun'),
        shouldRestore: () => shouldRestore,
      );

      expect(events, ['disableTun', 'stopListener', 'repairNetwork']);
    });

    test('启动监听期间用户主动停止时不再恢复 TUN', () async {
      final events = <String>[];
      var shouldRestore = true;

      await rebuildMacOSTun(
        disableTun: () async => events.add('disableTun'),
        stopListener: () async => events.add('stopListener'),
        repairNetwork: () async => events.add('repairNetwork'),
        startListener: () async {
          events.add('startListener');
          shouldRestore = false;
        },
        restoreTun: () async => events.add('restoreTun'),
        shouldRestore: () => shouldRestore,
      );

      expect(events, [
        'disableTun',
        'stopListener',
        'repairNetwork',
        'startListener',
      ]);
    });
  });

  group('managed macOS DNS state', () {
    test('follows the running TUN state', () {
      for (final isRunning in [false, true]) {
        for (final tunEnabled in [false, true]) {
          expect(
            shouldUseManagedMacOSDns(
              isRunning: isRunning,
              tunEnabled: tunEnabled,
            ),
            isRunning && tunEnabled,
            reason: 'isRunning=$isRunning, tunEnabled=$tunEnabled',
          );
        }
      }
    });
  });

  test('系统代理或 TUN 任一开启时桌面内核就应运行', () {
    for (final systemProxy in [false, true]) {
      for (final tunEnabled in [false, true]) {
        expect(
          shouldRunDesktopCore(
            systemProxy: systemProxy,
            tunEnabled: tunEnabled,
          ),
          systemProxy || tunEnabled,
        );
      }
    }
  });

  test('只识别会与 macOS TUN 启动冲突的分流路由', () {
    const conflictingRoute = '''
destination: 1.0.0.0
       mask: 255.0.0.0
  interface: utun9
''';
    const normalRoute = '''
destination: default
    gateway: 192.168.0.1
  interface: en0
''';

    expect(parseMacOSTunRouteConflict(conflictingRoute), 'utun9');
    expect(parseMacOSTunRouteConflict(normalRoute), isNull);
  });
}
