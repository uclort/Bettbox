import 'package:bett_box/controller.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('macOS TUN startup', () {
    test('applies TUN before starting the listener', () async {
      final events = <String>[];

      final started = await runMacOSTunStartup(
        requestAdmin: () async {
          events.add('authorize');
          return Result.success(true);
        },
        restartCore: () async => events.add('restart'),
        applyTunConfig: () async => events.add('apply'),
        startListener: () async => events.add('start'),
      );

      expect(started, isTrue);
      expect(events, ['authorize', 'apply', 'start']);
    });

    test('restarts the core before starting after new authorization', () async {
      final events = <String>[];

      final started = await runMacOSTunStartup(
        requestAdmin: () async {
          events.add('authorize');
          return Result.success(true, needRestart: true);
        },
        restartCore: () async => events.add('restart'),
        applyTunConfig: () async => events.add('apply'),
        startListener: () async => events.add('start'),
      );

      expect(started, isTrue);
      expect(events, ['authorize', 'restart', 'start']);
    });

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
      );

      expect(started, isFalse);
      expect(events, ['authorize']);
    });

    test('does not start when applying TUN fails', () async {
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
        ),
        throwsStateError,
      );

      expect(events, ['authorize', 'apply']);
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
        ),
        throwsStateError,
      );

      expect(events, ['authorize', 'restart']);
    });
  });
}
