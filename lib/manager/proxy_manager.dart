import 'dart:async';

import 'package:bett_box/common/print.dart';
import 'package:bett_box/common/proxy.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/app.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/providers/state.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@visibleForTesting
bool shouldDeferInitialSystemProxySync({
  required bool isInitialized,
  required bool isStart,
  required bool systemProxy,
}) {
  return !isInitialized && !isStart && systemProxy;
}

class ProxyManager extends ConsumerStatefulWidget {
  final Widget child;

  const ProxyManager({super.key, required this.child});

  @override
  ConsumerState createState() => _ProxyManagerState();
}

class _ProxyManagerState extends ConsumerState<ProxyManager> {
  Future<void> _pendingUpdate = Future.value();
  bool _deferredProxySync = false;

  Future<void> _updateProxy(ProxyState proxyState) async {
    if (proxy == null) return;

    final isStart = proxyState.isStart;
    final systemProxy = proxyState.systemProxy;
    final port = proxyState.port;
    final bool? updated;
    if (isStart && systemProxy) {
      updated = await proxy?.startProxy(port, proxyState.bypassDomain);
    } else {
      updated = await proxy?.stopProxy();
    }
    if (updated != true) {
      throw StateError(
        isStart && systemProxy ? '系统代理启用失败' : '系统代理关闭失败',
      );
    }
  }

  void _scheduleProxyUpdate(ProxyState proxyState) {
    _pendingUpdate = _pendingUpdate
        .catchError((_) {})
        .then((_) => _updateProxy(proxyState))
        .catchError((Object error, StackTrace stackTrace) {
          commonPrint.log('同步系统代理失败：$error\n$stackTrace');
          if (mounted && proxyState.isStart && proxyState.systemProxy) {
            ref
                .read(networkSettingProvider.notifier)
                .updateState((state) => state.copyWith(systemProxy: false));
            globalState.showNotifier('系统代理启用失败，已自动关闭');
          }
        });
    unawaited(_pendingUpdate);
  }

  void _handleProxyState(ProxyState proxyState) {
    final shouldDefer = shouldDeferInitialSystemProxySync(
      isInitialized: ref.read(initProvider),
      isStart: proxyState.isStart,
      systemProxy: proxyState.systemProxy,
    );
    if (shouldDefer) {
      _deferredProxySync = true;
      return;
    }

    _deferredProxySync = false;
    _scheduleProxyUpdate(proxyState);
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(proxyStateProvider, (prev, next) {
      if (prev != next) {
        _handleProxyState(next);
      }
    }, fireImmediately: true);
    ref.listenManual(initProvider, (prev, next) {
      if (next && _deferredProxySync) {
        _deferredProxySync = false;
        _scheduleProxyUpdate(ref.read(proxyStateProvider));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
