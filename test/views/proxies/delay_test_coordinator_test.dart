import 'dart:async';

import 'package:bett_box/models/models.dart';
import 'package:bett_box/views/proxies/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shares testing state and rejects overlapping group tests', () async {
    final coordinator = DelayTestCoordinator();

    expect(coordinator.isTesting, isFalse);
    expect(coordinator.testingGroupName, null);

    var actionExecuted = false;
    final testFuture = coordinator.run('ProxyGroup', () async {
      actionExecuted = true;
      expect(coordinator.isTesting, isTrue);
      expect(coordinator.testingGroupName, 'ProxyGroup');
      expect(coordinator.isTestingGroup('ProxyGroup'), isTrue);
      expect(coordinator.isTestingGroup('OtherGroup'), isFalse);
    });

    final secondTestStarted = await coordinator.run('OtherGroup', () async {});
    expect(secondTestStarted, isFalse);

    await testFuture;

    expect(actionExecuted, isTrue);
    expect(coordinator.isTesting, isFalse);
    expect(coordinator.testingGroupName, null);
  });

  test('clears testing state when a delay test fails', () async {
    final coordinator = DelayTestCoordinator();

    try {
      await coordinator.run('ProxyGroup', () async {
        throw Exception('network error');
      });
    } catch (_) {}

    expect(coordinator.isTesting, isFalse);
    expect(coordinator.testingGroupName, null);
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

  test(
    'deduplicates concurrent requests for the same resolved target',
    () async {
      final pool = DelayTestRequestPool();
      const target = DelayTestTarget(
        name: 'resolved-proxy',
        url: 'https://example.com/generate_204',
      );
      final completer = Completer<Delay>();
      var requestCount = 0;

      Future<Delay> request() {
        requestCount += 1;
        return completer.future;
      }

      final first = pool.run(target, request);
      final second = pool.run(target, request);

      expect(requestCount, 1);
      expect(pool.pendingCount, 1);

      const result = Delay(
        name: 'resolved-proxy',
        url: 'https://example.com/generate_204',
        value: 120,
      );
      completer.complete(result);

      expect(await first, result);
      expect(await second, result);
      expect(pool.pendingCount, 0);
    },
  );

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

  test('limits concurrent requests and releases failed slots', () async {
    final pool = DelayTestRequestPool();
    final completers = List.generate(3, (_) => Completer<Delay>());
    var started = 0;
    var maxActive = 0;

    Future<Delay> request(int index) async {
      started++;
      maxActive = pool.activeCount > maxActive ? pool.activeCount : maxActive;
      return completers[index].future;
    }

    final requests = List.generate(
      3,
      (index) => pool.run(
        DelayTestTarget(name: 'proxy-$index', url: 'https://example.com'),
        () => request(index),
        maxConcurrent: 2,
      ),
    );

    expect(started, 2);
    final firstFailure = requests.first.then<void>((_) {}, onError: (_) {});
    completers[0].completeError(Exception('network error'));
    await Future<void>.delayed(Duration.zero);
    expect(started, 3);

    for (var index = 1; index < completers.length; index++) {
      completers[index].complete(
        Delay(name: 'proxy-$index', url: 'https://example.com', value: 10),
      );
    }
    await firstFailure;
    await Future.wait(requests.skip(1));

    expect(maxActive, 2);
    expect(pool.activeCount, 0);
  });
}
