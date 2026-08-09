import 'dart:async';
import 'dart:collection';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';

import 'package:flutter/foundation.dart';

class DelayTestCoordinator extends ChangeNotifier {
  String? _testingGroupName;

  String? get testingGroupName => _testingGroupName;

  bool get isTesting => _testingGroupName != null;

  bool isTestingGroup(String groupName) => _testingGroupName == groupName;

  Future<bool> run(String groupName, Future<void> Function() action) async {
    if (isTesting) {
      return false;
    }

    _testingGroupName = groupName;
    notifyListeners();
    try {
      await action();
      return true;
    } finally {
      _testingGroupName = null;
      notifyListeners();
    }
  }
}

final delayTestCoordinator = DelayTestCoordinator();

@immutable
class DelayTestTarget {
  final String name;
  final String url;

  const DelayTestTarget({required this.name, required this.url});

  @override
  bool operator ==(Object other) {
    return other is DelayTestTarget && other.name == name && other.url == url;
  }

  @override
  int get hashCode => Object.hash(name, url);
}

class DelayTestRequestPool {
  final Map<DelayTestTarget, Future<Delay>> _pendingRequests = {};
  final Queue<_DelayTestRequest> _queue = Queue();
  int _activeCount = 0;

  int get pendingCount => _pendingRequests.length;
  int get activeCount => _activeCount;

  Future<Delay> run(
    DelayTestTarget target,
    Future<Delay> Function() action, {
    int maxConcurrent = defaultDelayTestConcurrencyLimit,
  }) {
    final pendingRequest = _pendingRequests[target];
    if (pendingRequest != null) {
      return pendingRequest;
    }

    final completer = Completer<Delay>();
    late final Future<Delay> request;
    request = completer.future.whenComplete(() {
      if (identical(_pendingRequests[target], request)) {
        _pendingRequests.remove(target);
      }
    });
    _pendingRequests[target] = request;
    _queue.add(
      _DelayTestRequest(
        action: action,
        completer: completer,
        maxConcurrent: normalizeDelayTestConcurrency(maxConcurrent),
      ),
    );
    _drain();
    return request;
  }

  void _drain() {
    while (_queue.isNotEmpty && _activeCount < _queue.first.maxConcurrent) {
      final request = _queue.removeFirst();
      _activeCount++;
      Future.sync(request.action)
          .then(
            request.completer.complete,
            onError: request.completer.completeError,
          )
          .whenComplete(() {
            _activeCount--;
            _drain();
          });
    }
  }
}

class _DelayTestRequest {
  final Future<Delay> Function() action;
  final Completer<Delay> completer;
  final int maxConcurrent;

  const _DelayTestRequest({
    required this.action,
    required this.completer,
    required this.maxConcurrent,
  });
}

final _delayTestRequestPool = DelayTestRequestPool();

double get listHeaderHeight {
  final measure = globalState.measure;
  return 20 + measure.titleMediumHeight + 4 + measure.bodyMediumHeight;
}

double getItemHeight(ProxyCardType proxyCardType) {
  final measure = globalState.measure;
  final baseHeight =
      16 + measure.bodyMediumHeight * 2 + measure.bodySmallHeight + 8 + 4;
  return switch (proxyCardType) {
    ProxyCardType.expand => baseHeight - measure.bodySmallHeight + measure.labelSmallHeight * 2 + 4,
    ProxyCardType.shrink => baseHeight,
    ProxyCardType.min => baseHeight - measure.bodyMediumHeight,
  };
}

Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
  if (_isNonTestableProxy(proxy)) return;
  final appController = globalState.appController;
  final state = appController.getProxyCardState(proxy.name);
  final url = appController.getRealTestUrl(
    state.testUrl.getSafeValue(testUrl ?? ''),
  );
  if (state.proxyName.isEmpty) {
    return;
  }
  await _testProxyDelay(DelayTestTarget(name: state.proxyName, url: url));
  appController.addSortNum();
}

Future<Delay> _testProxyDelay(DelayTestTarget target) async {
  final appController = globalState.appController;
  appController.setDelay(Delay(url: target.url, name: target.name, value: 0));
  return _delayTestRequestPool.run(target, () async {
    try {
      final result = await clashCore.getDelay(target.url, target.name);
      final delay = Delay(
        url: target.url,
        name: target.name,
        value: (result.value ?? -1) > 0 ? result.value : -1,
      );
      appController.setDelay(delay);
      return delay;
    } catch (e) {
      commonPrint.log('Delay test failed for ${target.name}: $e');
      final delay = Delay(url: target.url, name: target.name, value: -1);
      appController.setDelay(delay);
      return delay;
    }
  }, maxConcurrent: globalState.config.proxiesStyle.concurrencyLimit);
}

bool _isNonTestableProxyName(String proxyName) {
  final name = proxyName.toUpperCase();
  return name == 'REJECT' || name == 'REJECT-DROP' || name == 'PASS';
}

bool _isNonTestableProxyType(String proxyType) {
  return proxyType.toUpperCase() == 'REMATCH';
}

bool _isNonTestableProxy(Proxy proxy) {
  return _isNonTestableProxyName(proxy.name) ||
      _isNonTestableProxyType(proxy.type);
}

String? _getProxyType(String proxyName) {
  final groups = globalState.appController.getCurrentGroups();
  for (final group in groups) {
    if (group.name == proxyName) return group.type.name;
    for (final proxy in group.all) {
      if (proxy.name == proxyName) return proxy.type;
    }
  }
  return null;
}

Future<void> delayTest(
  List<Proxy> proxies, {
  String? testUrl,
  String? groupName,
  Future<void> Function()? onDelayUpdated,
}) async {
  Future<void> runTest() async {
    final appController = globalState.appController;
    final stopwatch = Stopwatch()..start();
    final targets = <DelayTestTarget>{};
    for (final proxy in proxies) {
      if (_isNonTestableProxy(proxy)) {
        continue;
      }
      final state = appController.getProxyCardState(proxy.name);
      final url = appController.getRealTestUrl(
        state.testUrl.getSafeValue(testUrl ?? ''),
      );
      final name = state.proxyName;
      if (name.isEmpty ||
          _isNonTestableProxyName(name) ||
          _isNonTestableProxyType(_getProxyType(name) ?? '')) {
        continue;
      }
      targets.add(DelayTestTarget(name: name, url: url));
    }

    commonPrint.log(
      '[DELAY-TEST][BATCH] phase=start group="${groupName ?? ''}" '
      'targets=${targets.length} concurrency='
      '${normalizeDelayTestConcurrency(globalState.config.proxiesStyle.concurrencyLimit)}',
    );
    final results = await Future.wait(
      targets.map((target) async {
        final result = await _testProxyDelay(target);
        await onDelayUpdated?.call();
        return result;
      }),
    );
    final successCount = results
        .where((delay) => (delay.value ?? -1) > 0)
        .length;
    commonPrint.log(
      '[DELAY-TEST][BATCH] phase=finish group="${groupName ?? ''}" '
      'targets=${targets.length} success=$successCount '
      'failed=${results.length - successCount} '
      'elapsed=${stopwatch.elapsedMilliseconds}ms',
    );
    appController.addSortNum();
  }

  if (groupName == null || groupName.isEmpty) {
    await runTest();
    return;
  }
  await delayTestCoordinator.run(groupName, runTest);
}

double getScrollToSelectedOffset({
  required String groupName,
  required List<Proxy> proxies,
}) {
  final appController = globalState.appController;
  final columns = appController.getProxiesColumns();
  final proxyCardType = globalState.config.proxiesStyle.cardType;
  final selectedProxyName = appController.getSelectedProxyName(groupName);
  final findSelectedIndex = proxies.indexWhere(
    (proxy) => proxy.name == selectedProxyName,
  );
  final selectedIndex = findSelectedIndex != -1 ? findSelectedIndex : 0;
  final rows = (selectedIndex / columns).floor();
  return rows * getItemHeight(proxyCardType) + (rows - 1) * 8;
}
