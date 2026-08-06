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
          applyTunConfig: () async => events.add('apply'),
          startListener: () async => events.add('start'),
          stopListener: () async => events.add('stop'),
        );

        expect(started, isTrue);
        expect(events, ['authorize', 'restart', 'start', 'apply']);
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
          applyTunConfig: () async => events.add('apply'),
          startListener: () async => events.add('start'),
          stopListener: () async => events.add('stop'),
        ),
        throwsStateError,
      );

      expect(events, ['authorize', 'restart']);
    });
  });

  group('managed macOS DNS state', () {
    test('requires the master switch, TUN, and automatic DNS', () {
      for (final isRunning in [false, true]) {
        for (final tunEnabled in [false, true]) {
          for (final autoSetSystemDns in [false, true]) {
            expect(
              shouldUseManagedMacOSDns(
                isRunning: isRunning,
                tunEnabled: tunEnabled,
                autoSetSystemDns: autoSetSystemDns,
              ),
              isRunning && tunEnabled && autoSetSystemDns,
              reason:
                  'isRunning=$isRunning, tunEnabled=$tunEnabled, '
                  'autoSetSystemDns=$autoSetSystemDns',
            );
          }
        }
      }
    });
  });
}
