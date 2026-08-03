import 'package:bett_box/application.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('macOS network recovery', () {
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

    test('drops a queued recovery after a newer network event arrives', () {
      expect(
        isMacOSNetworkRecoveryCurrent(
          mounted: true,
          scheduledGeneration: 3,
          currentGeneration: 4,
        ),
        isFalse,
      );
      expect(
        isMacOSNetworkRecoveryCurrent(
          mounted: true,
          scheduledGeneration: 4,
          currentGeneration: 4,
        ),
        isTrue,
      );
    });

    test('detects a secondary physical interface disconnect and reconnect', () {
      final wifiAndEthernet = macOSPhysicalConnectivityResults([
        ConnectivityResult.wifi,
        ConnectivityResult.ethernet,
        ConnectivityResult.vpn,
      ]);
      final wifiOnly = macOSPhysicalConnectivityResults([
        ConnectivityResult.wifi,
        ConnectivityResult.vpn,
      ]);

      expect(
        didMacOSPhysicalConnectivityChange(
          previous: wifiAndEthernet,
          current: wifiOnly,
        ),
        isTrue,
      );
      expect(
        didMacOSPhysicalConnectivityChange(
          previous: wifiOnly,
          current: wifiAndEthernet,
        ),
        isTrue,
      );
    });

    test('ignores connectivity events caused only by the TUN interface', () {
      final withoutTun = macOSPhysicalConnectivityResults([
        ConnectivityResult.wifi,
        ConnectivityResult.ethernet,
      ]);
      final withTun = macOSPhysicalConnectivityResults([
        ConnectivityResult.wifi,
        ConnectivityResult.ethernet,
        ConnectivityResult.vpn,
      ]);

      expect(withTun, withoutTun);
      expect(
        didMacOSPhysicalConnectivityChange(
          previous: withoutTun,
          current: withTun,
        ),
        isFalse,
      );
    });
  });
}
