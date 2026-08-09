import 'package:bett_box/controller.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('macOS TUN startup', () {
    test('starts the listener before applying TUN', () async {
      final events = <String>[];

      final started = await runMacOSTunStartup(
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

        final started = await runMacOSTunStartup(
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

      final started = await runMacOSTunStartup(
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
        runMacOSTunStartup(
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
        runMacOSTunStartup(
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
        runMacOSTunStartup(
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
}
