import 'dart:async';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/providers/state.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayManager extends ConsumerStatefulWidget {
  final Widget child;

  const TrayManager({super.key, required this.child});

  @override
  ConsumerState<TrayManager> createState() => _TrayContainerState();
}

class _TrayContainerState extends ConsumerState<TrayManager> with TrayListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    ref.listenManual(trayStateProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.updateTray();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  bool get _shouldTemporarilyShowHiddenItems {
    if (!system.isMacOS || !trayManager.isOptionKeyPressed) {
      return false;
    }
    return !ref.read(
      proxiesStyleSettingProvider.select((state) => state.showHiddenItems),
    );
  }

  Future<void> _handleTrayIconClick({required bool isRightClick}) async {
    if (_shouldTemporarilyShowHiddenItems) {
      await globalState.appController.showTrayMenu(includeHiddenItems: true);
      return;
    }
    final vpnProps = ref.read(vpnSettingProvider);
    final behavior = isRightClick
        ? vpnProps.trayRightClickBehavior
        : vpnProps.trayLeftClickBehavior;
    if (behavior == TrayClickBehavior.showMenu) {
      if (system.isWindows) {
        // Windows 必须在托盘点击回调的同一轮消息中弹出已经缓存的菜单。
        // 先异步重建菜单会错过 Shell 的弹出时机，表现为菜单闪一下后消失。
        // ignore: deprecated_member_use
        await trayManager.popUpContextMenu(bringAppToFront: true);
      } else {
        await globalState.appController.showTrayMenu();
      }
      return;
    }
    window?.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(_handleTrayIconClick(isRightClick: true));
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_handleTrayIconClick(isRightClick: false));
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.submenu != null) return;
    if (globalState.backgroundMode.value) {
      globalState.appController.updateTray(false, false, true);
    }
  }

  @override
  dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }
}
