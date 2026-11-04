import 'dart:async';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/app.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/providers/state.dart';
import 'package:bett_box/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayManager extends ConsumerStatefulWidget {
  final Widget child;

  const TrayManager({super.key, required this.child});

  @override
  ConsumerState<TrayManager> createState() => _TrayContainerState();
}

class _TrayContainerState extends ConsumerState<TrayManager> with TrayListener {
  int? _lastStatusDelay;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    ref.listenManual(trayStateProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.updateTray();
      }
    });
    // BETTBOX-CUSTOM: 完整节点链路与「托盘显示策略组」设置不在 TrayState 中，
    // 变化后单独刷新托盘；显示策略组开启时，隐藏组的 now 变化也要刷新标签。
    ref.listenManual(
      appSettingProvider.select(
        (state) => (
          state.trayShowProxyChain,
          state.trayStatusGroupEnable,
          state.trayStatusGroupName,
          state.trayStatusShowName,
          state.trayStatusShowNode,
          state.trayStatusShowChain,
          state.trayStatusShowDelay,
          state.trayStatusBeforeSpeed,
        ),
      ),
      (prev, next) {
        if (prev != next) {
          globalState.appController.updateTray();
        }
      },
    );
    // BETTBOX-CUSTOM: 「显示节点延迟」开启时，只在指定策略组的延迟变化时刷新，
    // 批量测速期间其他节点的延迟更新不会触发托盘重建。
    ref.listenManual(delayDataSourceProvider, (prev, next) {
      final setting = ref.read(appSettingProvider);
      if (!setting.trayStatusGroupEnable || !setting.trayStatusShowDelay) {
        return;
      }
      final group = ref.read(groupsProvider).getGroup(
        setting.trayStatusGroupName,
      );
      if (group == null) return;
      final delay = ref.read(
        getDelayProvider(proxyName: group.name, testUrl: group.testUrl),
      );
      if (delay != _lastStatusDelay) {
        _lastStatusDelay = delay;
        globalState.appController.updateTray();
      }
    });
    ref.listenManual(groupsProvider, (prev, next) {
      if (prev != next &&
          ref.read(
            appSettingProvider.select((state) => state.trayStatusGroupEnable),
          )) {
        globalState.appController.updateTray();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  bool get _shouldTemporarilyShowHiddenItems {
    // BETTBOX-CUSTOM: macOS 按住 Option、Windows 按住 Alt 点击托盘临时显示隐藏组。
    if (!(system.isMacOS || system.isWindows) ||
        !trayManager.isOptionKeyPressed) {
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
        // The menu is opened natively during the Shell notification callback.
        // Reaching this branch means the native click behavior was not synced.
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
  void onTrayMenuClose() {
    unawaited(globalState.appController.handleTrayMenuClosed());
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
