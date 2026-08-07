import 'package:bett_box/application.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('macOS network recovery', () {
    test('retries a failed recovery once and then succeeds', () async {
      var attempts = 0;

      await runMacOSNetworkRecoveryWithRetry(() async {
        attempts++;
        if (attempts == 1) throw StateError('transient failure');
      }, retryDelay: Duration.zero);

      expect(attempts, 2);
    });

    test('stops after the single recovery retry also fails', () async {
      var attempts = 0;

      await expectLater(
        runMacOSNetworkRecoveryWithRetry(() async {
          attempts++;
          throw StateError('persistent failure');
        }, retryDelay: Duration.zero),
        throwsStateError,
      );

      expect(attempts, 2);
    });

    test('skips an unchanged network during regular connectivity updates', () {
      expect(
        shouldReconcileMacOSNetworkState(
          previousFingerprint: 'same-network',
          currentFingerprint: 'same-network',
        ),
        isFalse,
      );
    });

    test('forces recovery after wake even when the network is unchanged', () {
      expect(
        shouldReconcileMacOSNetworkState(
          previousFingerprint: 'same-network',
          currentFingerprint: 'same-network',
          force: true,
        ),
        isTrue,
      );
    });

    test('recovers when the network fingerprint changes', () {
      expect(
        shouldReconcileMacOSNetworkState(
          previousFingerprint: 'old-network',
          currentFingerprint: 'new-network',
        ),
        isTrue,
      );
    });

    test('consumes a wake force once and coalesces self-generated events', () {
      final coordinator = MacOSNetworkRecoveryCoordinator();

      coordinator.schedule(force: true);
      final wakeRequest = coordinator.beginNext();
      expect(wakeRequest?.force, isTrue);
      expect(coordinator.isProcessing, isTrue);

      // TUN 重建会产生 connectivity 事件，只应排队普通复核。
      coordinator.schedule();
      expect(coordinator.beginNext(), isNull);

      coordinator.completeCurrent();
      final followUpRequest = coordinator.beginNext();
      expect(followUpRequest?.force, isFalse);
      coordinator.completeCurrent();
      expect(coordinator.hasPendingRequest, isFalse);
    });

    test('唤醒恢复产生的自身网络事件不会触发第二次恢复', () {
      final coordinator = MacOSNetworkRecoveryCoordinator();
      const fingerprint = 'same-network';

      coordinator.schedule(force: true);
      final wakeRequest = coordinator.beginNext()!;
      expect(
        shouldReconcileMacOSNetworkState(
          previousFingerprint: fingerprint,
          currentFingerprint: fingerprint,
          force: wakeRequest.force,
        ),
        isTrue,
      );

      coordinator.schedule();
      coordinator.completeCurrent();
      final selfGeneratedRequest = coordinator.beginNext()!;
      expect(
        shouldReconcileMacOSNetworkState(
          previousFingerprint: fingerprint,
          currentFingerprint: fingerprint,
          force: selfGeneratedRequest.force,
        ),
        isFalse,
      );
    });

    test('恢复期间发生真实换网时会执行后续恢复', () {
      final coordinator = MacOSNetworkRecoveryCoordinator();

      coordinator.schedule(force: true);
      expect(coordinator.beginNext()?.force, isTrue);

      coordinator.schedule();
      coordinator.completeCurrent();
      final networkChangeRequest = coordinator.beginNext()!;
      expect(
        shouldReconcileMacOSNetworkState(
          previousFingerprint: 'old-network',
          currentFingerprint: 'new-network',
          force: networkChangeRequest.force,
        ),
        isTrue,
      );
    });

    test('keeps a real wake request received during an active recovery', () {
      final coordinator = MacOSNetworkRecoveryCoordinator();

      coordinator.schedule();
      expect(coordinator.beginNext()?.force, isFalse);

      coordinator.schedule(force: true);
      coordinator.completeCurrent();

      expect(coordinator.beginNext()?.force, isTrue);
    });

    test('coalesces repeated connectivity events into one request', () {
      final coordinator = MacOSNetworkRecoveryCoordinator();

      coordinator.schedule();
      coordinator.schedule();
      coordinator.schedule();

      expect(coordinator.beginNext()?.force, isFalse);
      coordinator.completeCurrent();
      expect(coordinator.beginNext(), isNull);
    });

    test('clears queued recovery during application disposal', () {
      final coordinator = MacOSNetworkRecoveryCoordinator();

      coordinator.schedule(force: true);
      coordinator.clearPending();

      expect(coordinator.beginNext(), isNull);
    });
  });
}
