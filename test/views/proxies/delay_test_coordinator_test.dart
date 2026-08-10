import 'dart:async';

import 'package:bett_box/views/proxies/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracks groups independently and rejects only the same group', () async {
    final coordinator = DelayTestCoordinator();
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();

    expect(coordinator.isTesting, isFalse);

    final testFuture = coordinator.run('ProxyGroup', () async {
      firstStarted.complete();
      await releaseFirst.future;
    });
    await firstStarted.future;

    expect(coordinator.isTesting, isTrue);
    expect(coordinator.isTestingGroup('ProxyGroup'), isTrue);
    expect(coordinator.isTestingGroup('OtherGroup'), isFalse);

    final sameGroupStarted = await coordinator.run('ProxyGroup', () async {});
    expect(sameGroupStarted, isFalse);

    final otherGroupStarted = await coordinator.run('OtherGroup', () async {
      expect(coordinator.isTesting, isTrue);
      expect(coordinator.isTestingGroup('ProxyGroup'), isTrue);
      expect(coordinator.isTestingGroup('OtherGroup'), isTrue);
    });
    expect(otherGroupStarted, isTrue);

    releaseFirst.complete();
    await testFuture;

    expect(coordinator.isTesting, isFalse);
  });

  test('clears testing state when a delay test fails', () async {
    final coordinator = DelayTestCoordinator();

    try {
      await coordinator.run('ProxyGroup', () async {
        throw Exception('network error');
      });
    } catch (_) {}

    expect(coordinator.isTesting, isFalse);
  });

  test('notifies listeners when a group test starts and finishes', () async {
    final coordinator = DelayTestCoordinator();
    var notifications = 0;

    coordinator.addListener(() {
      notifications++;
    });

    await coordinator.run('ProxyGroup', () async {});

    expect(notifications, 2);
  });

  test('keeps targets with different test URLs independent', () {
    const first = DelayTestTarget(
      name: 'resolved-proxy',
      url: 'https://example.com/a',
    );
    const second = DelayTestTarget(
      name: 'resolved-proxy',
      url: 'https://example.com/b',
    );

    expect({first, second}, hasLength(2));
  });
}
