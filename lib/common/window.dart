import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class Window {
  Future<void> init() async {
    final props = globalState.config.windowProps;
    if (system.isWindows) {
      protocol.register('clash');
      protocol.register('clashmeta');
      protocol.register('bettbox');
    }
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      size: Size(props.width, props.height),
      minimumSize: const Size(380, 400),
    );
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setAlwaysOnTop(props.isPinned);
    if (!system.isMacOS) {
      final left = props.left;
      final top = props.top;
      if (left == null || top == null || (left == 0 && top == 0)) {
        await windowManager.setAlignment(Alignment.center);
      } else {
        bool isPositionValid = false;
        try {
          final displays = await screenRetriever.getAllDisplays();
          isPositionValid = displays.any((display) {
            final pos = display.visiblePosition;
            final size = display.visibleSize ?? display.size;
            if (pos == null) return false;
            return Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height)
                .contains(Offset(left, top));
          });
        } catch (_) {}
        if (isPositionValid) {
          await windowManager.setPosition(Offset(left, top));
        } else {
          await windowManager.setAlignment(Alignment.center);
        }
      }
    }
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
    });
  }

  void updateMacOSBrightness(Brightness brightness) {}

  Future<void> show() async {
    globalState.handleForeground();
    render?.resume();
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
    await globalState.resumeForegroundUpdates();
    await globalState.appController.syncWakelockIfNeeded();
  }

  Future<bool> get isVisible async {
    return await windowManager.isVisible();
  }

  Future<bool> get isMinimized async {
    return await windowManager.isMinimized();
  }

  Future<void> close() async {
    try {
      await trayManager.destroy();
      commonPrint.log('The tray icon has been destroyed.');
    } catch (e) {
      commonPrint.log('Failed to destroy the tray icon: $e');
    }

    exit(0);
  }

  Future<void> hide() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
    await globalState.handleBackground();
  }
}

final window = system.isDesktop ? Window() : null;

class NetworkMonitorProcess {
  Process? _process;
  Future<void>? _opening;

  Future<void> open() {
    final opening = _opening;
    if (opening != null) return opening;
    final future = _open();
    _opening = future;
    return future.whenComplete(() {
      if (identical(_opening, future)) _opening = null;
    });
  }

  Future<void> _open() async {
    final current = _process;
    if (current != null) {
      try {
        current.stdin.writeln('show');
        await current.stdin.flush();
        return;
      } catch (_) {
        if (identical(_process, current)) _process = null;
        current.kill();
      }
    }

    final process = await Process.start(
      Platform.resolvedExecutable,
      const ['--network-panel'],
      workingDirectory: File(Platform.resolvedExecutable).parent.path,
    );
    _process = process;
    unawaited(process.stdout.drain<void>());
    unawaited(
      process.stderr
          .transform(utf8.decoder)
          .forEach((line) => commonPrint.log('Network panel: $line')),
    );
    unawaited(
      process.exitCode.then((_) {
        if (identical(_process, process)) _process = null;
      }),
    );
  }

  Future<void> close() async {
    final process = _process;
    _process = null;
    if (process == null) return;
    try {
      process.stdin.writeln('exit');
      await process.stdin.flush();
      await process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      process.kill();
    }
  }
}

final networkMonitorProcess = NetworkMonitorProcess();
