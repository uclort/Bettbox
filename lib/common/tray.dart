import 'dart:async';
import 'dart:io';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/network_monitor.dart';
import 'package:bett_box/views/proxies/common.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'common.dart';

class Tray {
  Timer? _debounceTimer;
  TrayState? _pendingState;
  bool _isUpdating = false;
  bool _pendingFocus = false;
  bool _pendingSilent = false;
  List<Group>? _pendingGroupsOverride;

  static const _debounceDelay = Duration(milliseconds: 300);

  Timer? _loadingTimer;
  int _loadingFrame = 0;
  final List<String> _loadingFrames = ['.', '..', '...'];

  Tray() {
    delayTestCoordinator.addListener(_handleDelayTestStateChanged);
  }

  void _handleDelayTestStateChanged() {
    if (system.isAndroid) return;
    unawaited(globalState.appController.updateTray(false, true));
  }

  bool _traySpeedEnabled = false;
  bool _trayTrafficActive = false;
  bool _isSpeedTitleVisible = false;
  Traffic _lastTraffic = Traffic();
  int? _lastDisplayedUpload;
  int? _lastDisplayedDownload;
  bool? _lastDisplayedActive;
  // BETTBOX-CUSTOM: 托盘图标旁的策略组标签（空串表示不显示），与网速共用标题。
  String _statusLabel = '';
  bool _statusLabelBeforeSpeed = false;
  String _lastStatusDelayText = '';
  String? _lastDisplayedLabel;
  bool? _lastDisplayedLabelBefore;
  bool? _lastDisplayedShowSpeed;

  // macOS 与 Windows 共用模板图标和状态渲染；Linux 仍使用普通彩色图标。
  bool get _supportsTrayTemplate => system.isMacOS || system.isWindows;

  void dispose() {
    delayTestCoordinator.removeListener(_handleDelayTestStateChanged);
    _debounceTimer?.cancel();
    _loadingTimer?.cancel();
  }

  Future _updateSystemTray({
    required Brightness? brightness,
    required bool isStart,
    bool force = false,
  }) async {
    if (system.isAndroid) {
      return;
    }
    final effectiveBrightness =
        brightness ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (force && !system.isMacOS) {
      await trayManager.destroy();
      _isSpeedTitleVisible = false;
      _lastDisplayedUpload = null;
      _lastDisplayedDownload = null;
      _lastDisplayedActive = null;
    }
    await trayManager.setIcon(
      utils.getTrayIconPath(brightness: effectiveBrightness, isStart: isStart),
      isTemplate: _supportsTrayTemplate,
      id: AppIdentity.compactName,
    );
    if (_supportsTrayTemplate) {
      await trayManager.setActive(isStart, brightness: effectiveBrightness);
    }
    if (!Platform.isLinux) {
      await trayManager.setToolTip(appName);
    }
  }

  Future<void> update({
    required TrayState trayState,
    bool focus = false,
    bool silent = false,
    bool force = false,
    List<Group>? groupsOverride,
  }) async {
    if (system.isAndroid) {
      return;
    }

    _debounceTimer?.cancel();

    if (_isUpdating) {
      _pendingState = trayState;
      _pendingFocus = focus;
      _pendingSilent = silent;
      _pendingGroupsOverride = groupsOverride;
      return;
    }

    if (force || focus) {
      await _doUpdate(
        trayState: trayState,
        focus: focus,
        silent: silent,
        groupsOverride: groupsOverride,
      );
    } else if (silent) {
      _debounceTimer = Timer(const Duration(milliseconds: 50), () async {
        await _doUpdate(
          trayState: trayState,
          focus: focus,
          silent: silent,
          groupsOverride: groupsOverride,
        );
      });
    } else {
      _debounceTimer = Timer(_debounceDelay, () async {
        await _doUpdate(
          trayState: trayState,
          focus: focus,
          groupsOverride: groupsOverride,
        );
      });
    }
  }

  Future<void> _doUpdate({
    required TrayState trayState,
    bool focus = false,
    bool silent = false,
    List<Group>? groupsOverride,
    bool prepareContextMenu = false,
  }) async {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      _traySpeedEnabled = trayState.enableTraySpeed;
      _statusLabel = _resolveStatusLabel(trayState);
      _statusLabelBeforeSpeed =
          globalState.config.appSetting.trayStatusBeforeSpeed;
      _trayTrafficActive =
          trayState.isStart && (trayState.systemProxy || trayState.tunEnable);
      if (system.isWindows) {
        final vpnProps = globalState.config.vpnProps;
        await trayManager.setNativeMenuClickBehavior(
          left: vpnProps.trayLeftClickBehavior == TrayClickBehavior.showMenu,
          right: vpnProps.trayRightClickBehavior == TrayClickBehavior.showMenu,
        );
      }
      if (!silent && !Platform.isLinux) {
        try {
          await _updateSystemTray(
            brightness: trayState.brightness,
            isStart: _trayTrafficActive,
            force: focus && !(system.isWindows && trayManager.isMenuOpen),
          );
        } on PlatformException catch (error) {
          commonPrint.log('更新托盘图标失败：$error');
        }
      }
      await _syncSpeedTitle();
      if (system.isMacOS && !prepareContextMenu && !trayManager.isMenuOpen) {
        return;
      }
      List<MenuItem> menuItems = [];
      final showMenuItem = MenuItem(
        key: 'shortcut:command-m',
        label: '显示窗口',
        onClick: (_) {
          window?.show();
        },
      );
      menuItems.add(showMenuItem);
      menuItems.add(MenuItem.separator());
      for (final mode in Mode.values) {
        menuItems.add(
          MenuItem.checkbox(
            label: Intl.message(mode.name),
            onClick: (_) {
              globalState.appController.changeMode(mode);
            },
            checked: mode == trayState.mode,
          ),
        );
      }
      menuItems.add(MenuItem.separator());
      final menuGroups = groupsOverride ?? trayState.groups;
      // BETTBOX-CUSTOM: 完整策略组列表（含隐藏组）用于解析选中目标与最终节点。
      final allGroups = menuGroups.isEmpty
          ? const <Group>[]
          : globalState.appController.getAllGroups();
      final selectionGroups = allGroups.isEmpty ? menuGroups : allGroups;
      final showProxyChain = globalState.config.appSetting.trayShowProxyChain;
      for (final group in menuGroups) {
        List<MenuItem> subMenuItems = [];

        final isTestingThisGroup = delayTestCoordinator.isTestingGroup(
          group.name,
        );
        final pinnedProxy = trayPinnedProxyName(group, trayState.selectedMap);

        // BETTBOX-CUSTOM: URLTest / Fallback 子菜单顶部用不可点击的说明解释交互，
        // 随固定状态切换文案；固定的节点前显示锁，与窗口策略组卡片一致。
        if (group.type.isComputedSelected) {
          subMenuItems.add(
            MenuItem(
              label: pinnedProxy.isEmpty
                  ? appLocalizations.trayPinHintAuto
                  : appLocalizations.trayPinHintPinned,
              disabled: true,
            ),
          );
          subMenuItems.add(MenuItem.separator());
        }

        subMenuItems.add(
          MenuItem(
            key: 'persistent-delay-test',
            label: isTestingThisGroup
                ? '⚡ ${appLocalizations.testingDelay}...'
                : '⚡ ${appLocalizations.startTest}',
            disabled: delayTestCoordinator.isTesting,
            onClick: (_) => _testGroupDelay(group),
          ),
        );

        subMenuItems.add(MenuItem.separator());

        final selectable = isTrayGroupManuallySelectable(group);
        final proxies = globalState.appController.getSortProxies(
          proxies: group.all,
          sortType: globalState.config.proxiesStyle.sortType,
          testUrl: group.testUrl,
        );
        for (final proxy in proxies) {
          final delay = globalState.appController.getTrayProxyDelay(
            proxyName: proxy.name,
            testUrl: group.testUrl,
          );

          final delayText = _formatProxySublabel(delay);
          final groupSelection = trayGroupSelectionLabel(
            groupName: proxy.name,
            groups: selectionGroups,
            selectedMap: trayState.selectedMap,
            showChain: showProxyChain,
          );
          final locked = pinnedProxy.isNotEmpty && pinnedProxy == proxy.name;
          subMenuItems.add(
            MenuItem.checkbox(
              key: 'proxy-item:${proxy.name}',
              // BETTBOX-CUSTOM: 作为节点出现的策略组被固定时，名称前带锁。
              label: trayLockedGroupName(
                proxy.name,
                selectionGroups,
                trayState.selectedMap,
              ),
              sublabel: joinTrayDetail(groupSelection, delayText),
              // BETTBOX-CUSTOM: 固定的节点勾选列画锁代替对号。
              icon: locked ? trayMenuLockedIcon : null,
              checked:
                  !locked &&
                  group.getCurrentSelectedName(
                        trayState.selectedMap[group.name] ?? '',
                      ) ==
                      proxy.name,
              // BETTBOX-CUSTOM: 不可手动选择的组（LoadBalance 等）节点置灰，原生侧
              // 不响应点击也不关闭菜单。
              disabled: !selectable,
              onClick: (_) {
                if (!selectable) return;
                final appController = globalState.appController;
                final next = trayNextSelection(
                  group,
                  trayState.selectedMap,
                  proxy.name,
                );
                appController.updateCurrentSelectedMap(group.name, next);
                if (group.type.isComputedSelected) {
                  // 与窗口卡片相同：固定或解除后刷新策略组，拿到内核新的 now。
                  appController.changeProxyDebounce(group.name, next);
                } else {
                  appController.changeProxy(
                    groupName: group.name,
                    proxyName: next,
                  );
                }
              },
            ),
          );
        }
        menuItems.add(
          MenuItem.submenu(
            key: 'group-item:${group.name}',
            label: group.name,
            // BETTBOX-CUSTOM: 被固定的自动组在名称前显示锁，避免误以为按顺序选择。
            icon: isTrayGroupPinned(group, trayState.selectedMap)
                ? trayMenuLockedIcon
                : null,
            sublabel: joinTrayDetail(
              trayGroupSelectionLabel(
                groupName: group.name,
                groups: selectionGroups,
                selectedMap: trayState.selectedMap,
                showChain: showProxyChain,
              ),
              _formatProxySublabel(
                globalState.appController.getTrayProxyDelay(
                  proxyName: group.name,
                  testUrl: group.testUrl,
                ),
              ),
            ),
            submenu: Menu(items: subMenuItems),
          ),
        );
      }
      if (menuGroups.isNotEmpty) {
        menuItems.add(MenuItem.separator());
      }
      menuItems.add(
        MenuItem(
          key: 'shortcut:command-d',
          label: '网络面板',
          onClick: (_) async {
            try {
              await openNetworkMonitorWindow();
            } catch (error) {
              globalState.showNotifier('打开网络面板失败：$error');
            }
          },
        ),
      );
      menuItems.add(MenuItem.separator());
      menuItems.add(
        MenuItem.checkbox(
          key: 'shortcut:command-s',
          label: appLocalizations.systemProxy,
          onClick: (_) async {
            await globalState.appController.updateSystemProxy();
          },
          checked: trayState.systemProxy,
        ),
      );
      menuItems.add(
        MenuItem.checkbox(
          key: 'shortcut:command-e',
          label: appLocalizations.tun,
          onClick: (_) async {
            await globalState.appController.updateTun();
          },
          checked: trayState.tunEnable,
        ),
      );
      menuItems.add(MenuItem.separator());
      menuItems.add(
        MenuItem(
          key: 'shortcut:command-r',
          label: appLocalizations.restartCoreTitle,
          onClick: (_) async {
            final appController = globalState.appController;
            try {
              await appController.restartCore();
            } finally {
              await appController.syncDesktopRuntimeState(
                preferCurrentState: true,
              );
              await appController.updateTray();
            }
          },
        ),
      );

      final List<MenuItem> moreMenuItems = [
        MenuItem.checkbox(
          label: appLocalizations.autoLaunch,
          onClick: (_) async {
            globalState.appController.updateAutoLaunch();
          },
          checked: trayState.autoLaunch,
        ),
        _buildCopyEnvSubmenu(trayState.port),
        MenuItem(
          label: appLocalizations.restartApp,
          onClick: (_) async {
            await system.restartApp();
          },
        ),
      ];

      if (!system.isAndroid) {
        moreMenuItems.add(
          MenuItem.checkbox(
            label: appLocalizations.wakelock,
            onClick: (_) async {
              await _toggleWakelock(trayState.wakelockEnabled);
            },
            checked: trayState.wakelockEnabled,
          ),
        );
      }

      menuItems.add(
        MenuItem.submenu(
          label: appLocalizations.tools,
          submenu: Menu(items: moreMenuItems),
        ),
      );

      menuItems.add(MenuItem.separator());
      final exitMenuItem = MenuItem(
        key: 'shortcut:command-q',
        label: appLocalizations.exit,
        onClick: (_) async {
          await globalState.appController.handleExit();
        },
      );
      menuItems.add(exitMenuItem);
      final menu = Menu(items: menuItems);
      final keepMenuOpen =
          silent || (_supportsTrayTemplate && trayManager.isMenuOpen);
      await trayManager.setContextMenu(
        menu,
        keepMenuOpen: keepMenuOpen,
        brightness: trayState.brightness,
      );
      if (Platform.isLinux) {
        await _updateSystemTray(
          brightness: trayState.brightness,
          isStart: trayState.isStart,
          force: focus,
        );
      }
    } finally {
      _isUpdating = false;

      if (_pendingState != null) {
        final pending = _pendingState;
        final pendingFocus = _pendingFocus;
        final pendingSilent = _pendingSilent;
        // BETTBOX-CUSTOM: 排队的刷新优先使用自己携带的分组（含 Option 隐藏组）。
        final pendingGroups = _pendingGroupsOverride ?? groupsOverride;
        _pendingState = null;
        _pendingFocus = false;
        _pendingSilent = false;
        _pendingGroupsOverride = null;
        await _doUpdate(
          trayState: pending!,
          focus: pendingFocus,
          silent: pendingSilent,
          groupsOverride: pendingGroups,
          prepareContextMenu: prepareContextMenu,
        );
      }
    }
  }

  Future<void> updateSpeed(Traffic traffic) async {
    _lastTraffic = _trayTrafficActive ? traffic : Traffic();
    if (!_supportsTrayTemplate || !_traySpeedEnabled) {
      return;
    }
    await _setSpeedTitle(_lastTraffic);
  }

  /// BETTBOX-CUSTOM: 按「增强工具 → 托盘显示策略组」解析标签；未开启、策略组
  /// 不存在或三项都未勾选时为空。解析使用含隐藏组的完整列表。
  String _resolveStatusLabel(TrayState trayState) {
    if (!_supportsTrayTemplate) return '';
    final setting = globalState.config.appSetting;
    if (!setting.trayStatusGroupEnable ||
        setting.trayStatusGroupName.isEmpty) {
      return '';
    }
    final allGroups = globalState.appController.getAllGroups();
    final groups = allGroups.isEmpty ? trayState.groups : allGroups;
    final groupName = trayStatusEffectiveGroupName(
      trayState.mode,
      setting.trayStatusGroupName,
    );
    var delayText = '';
    if (setting.trayStatusShowDelay) {
      final group = groups.getGroup(groupName);
      final delay = group == null
          ? null
          : globalState.appController.getTrayProxyDelay(
              proxyName: group.name,
              testUrl: group.testUrl,
            );
      // 测速中（0）沿用上次结果，避免菜单栏宽度来回跳动。
      delayText = delay == 0
          ? _lastStatusDelayText
          : trayStatusDelayText(
              delay,
              timeoutText: appLocalizations.trayStatusDelayTimeout,
            );
    }
    _lastStatusDelayText = delayText;
    return trayStatusGroupLabel(
      groupName: groupName,
      groups: groups,
      selectedMap: trayState.selectedMap,
      showName: setting.trayStatusShowName,
      showNode: setting.trayStatusShowNode,
      showChain: setting.trayStatusShowChain,
      delayText: delayText,
    );
  }

  Future<void> _syncSpeedTitle() async {
    if (!_supportsTrayTemplate) {
      return;
    }
    if (!_traySpeedEnabled && _statusLabel.isEmpty) {
      if (!_isSpeedTitleVisible) {
        return;
      }
      try {
        await trayManager.clearSpeedTitle();
      } on PlatformException catch (error) {
        commonPrint.log('清除托盘网速失败：$error');
        return;
      }
      _isSpeedTitleVisible = false;
      _lastDisplayedUpload = null;
      _lastDisplayedDownload = null;
      _lastDisplayedActive = null;
      return;
    }

    if (!_trayTrafficActive) {
      _lastTraffic = Traffic();
    }
    await _setSpeedTitle(_lastTraffic);
  }

  Future<void> _setSpeedTitle(Traffic traffic) async {
    final upload = traffic.up.value;
    final download = traffic.down.value;
    final label = _statusLabel;
    final labelBefore = _statusLabelBeforeSpeed;
    final showSpeed = _traySpeedEnabled;
    if (_isSpeedTitleVisible &&
        _lastDisplayedUpload == upload &&
        _lastDisplayedDownload == download &&
        _lastDisplayedActive == _trayTrafficActive &&
        _lastDisplayedLabel == label &&
        _lastDisplayedLabelBefore == labelBefore &&
        _lastDisplayedShowSpeed == showSpeed) {
      return;
    }
    try {
      if (label.isEmpty) {
        await trayManager.setSpeedTitle(
          upload: upload,
          download: download,
          active: _trayTrafficActive,
        );
      } else {
        // BETTBOX-CUSTOM: 有策略组标签时改走组合标题；网速关闭时标签占用网速位置。
        await trayManager.setStatusTitle(
          label: label,
          labelBeforeSpeed: labelBefore,
          showSpeed: showSpeed,
          upload: upload,
          download: download,
          active: _trayTrafficActive,
        );
      }
    } on PlatformException catch (error) {
      // BETTBOX-CUSTOM: 网速属于装饰能力，失败不能阻断原生菜单初始化。
      commonPrint.log('更新托盘网速失败：$error');
      return;
    }
    _isSpeedTitleVisible = true;
    _lastDisplayedUpload = upload;
    _lastDisplayedDownload = download;
    _lastDisplayedActive = _trayTrafficActive;
    _lastDisplayedLabel = label;
    _lastDisplayedLabelBefore = labelBefore;
    _lastDisplayedShowSpeed = showSpeed;
  }

  Future<void> showContextMenu({
    required TrayState trayState,
    required List<Group> groups,
  }) async {
    _debounceTimer?.cancel();
    while (_isUpdating) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await _doUpdate(
      trayState: trayState,
      groupsOverride: groups,
      prepareContextMenu: true,
    );
    await trayManager.popUpContextMenu();
  }

  MenuItem _buildCopyEnvSubmenu(int port) {
    final items = <MenuItem>[];

    final shells = <({String label, Future<void> Function() action})>[
      (label: 'PowerShell', action: () => _copyEnvPowerShell(port)),
      (label: 'CMD', action: () => _copyEnvCmd(port)),
      (label: 'Bash', action: () => _copyEnvBash(port)),
      (label: 'Fish', action: () => _copyEnvFish(port)),
    ];

    for (final shell in shells) {
      items.add(
        MenuItem(
          label: shell.label,
          onClick: (_) async {
            await shell.action();
          },
        ),
      );
    }

    return MenuItem.submenu(
      label: appLocalizations.copyEnvVar,
      submenu: Menu(items: items),
    );
  }

  Future<void> _copyEnvPowerShell(int port) async {
    final url = 'http://127.0.0.1:$port';
    final cmd =
        '\$env:http_proxy="$url"\n'
        '\$env:https_proxy="$url"\n'
        '\$env:all_proxy="$url"';
    await Clipboard.setData(ClipboardData(text: cmd));
  }

  Future<void> _copyEnvCmd(int port) async {
    final url = 'http://127.0.0.1:$port';
    final cmd =
        'set http_proxy=$url\n'
        'set https_proxy=$url\n'
        'set all_proxy=$url';
    await Clipboard.setData(ClipboardData(text: cmd));
  }

  Future<void> _copyEnvBash(int port) async {
    final url = 'http://127.0.0.1:$port';
    final cmd =
        'export http_proxy=$url\n'
        'export https_proxy=$url\n'
        'export all_proxy=$url';
    await Clipboard.setData(ClipboardData(text: cmd));
  }

  Future<void> _copyEnvFish(int port) async {
    final url = 'http://127.0.0.1:$port';
    final cmd =
        'set -gx http_proxy $url\n'
        'set -gx https_proxy $url\n'
        'set -gx all_proxy $url';
    await Clipboard.setData(ClipboardData(text: cmd));
  }

  Future<void> _toggleWakelock(bool currentEnabled) async {
    try {
      if (currentEnabled) {
        try {
          await WakelockPlus.disable();
        } catch (e) {
          commonPrint.log('WakeLock disable OS error: $e');
        }
        globalState.appController.stopWakelockAutoRecovery();
      } else {
        try {
          await WakelockPlus.enable();
        } catch (e) {
          commonPrint.log('WakeLock enable OS error: $e');
        }
        globalState.appController.startWakelockAutoRecovery();
      }
      globalState.updateWakelockState(!currentEnabled);
      await globalState.appController.updateTray();
    } catch (e) {
      commonPrint.log('WakeLock toggle error: $e');
    }
  }

  String _formatProxySublabel(int? delay) {
    if (delay == null) {
      return '';
    } else if (delay == 0) {
      return _supportsTrayTemplate ? _loadingFrames[_loadingFrame] : '...';
    } else if (delay < 0) {
      return '×';
    } else {
      return '${delay}ms';
    }
  }

  void _startLoadingAnimation() {
    if (!_supportsTrayTemplate) {
      return;
    }
    _loadingTimer?.cancel();
    _loadingFrame = 0;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!delayTestCoordinator.isTesting) return;
      _scheduleLoadingUpdate();
    });
  }

  void _scheduleLoadingUpdate() {
    if (!delayTestCoordinator.isTesting || !_supportsTrayTemplate) return;
    _loadingTimer = Timer(const Duration(milliseconds: 300), () async {
      if (trayManager.isMenuOpen) {
        _loadingFrame = (_loadingFrame + 1) % _loadingFrames.length;
        await globalState.appController.updateTray(false, true);
      }
      _scheduleLoadingUpdate();
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
    _loadingFrame = 0;
  }

  Future<void> _testGroupDelay(Group group) async {
    if (delayTestCoordinator.isTesting) return;

    final appController = globalState.appController;
    final testableProxies = group.all.where((p) {
      final name = p.name.toUpperCase();
      return name != 'REJECT' &&
          name != 'REJECT-DROP' &&
          name != 'PASS' &&
          p.type.toUpperCase() != 'REMATCH';
    }).toList();

    try {
      if (_supportsTrayTemplate) {
        _startLoadingAnimation();
      }
      await delayTest(
        testableProxies,
        testUrl: group.testUrl,
        groupName: group.name,
        onDelayUpdated: _supportsTrayTemplate
            ? () async {
                if (!trayManager.isMenuOpen) return;
                await appController.updateTray(false, true);
              }
            : null,
      );
    } catch (e) {
      commonPrint.log('Delay test error: $e');
    } finally {
      if (_supportsTrayTemplate) {
        _stopLoadingAnimation();
      }
      await appController.updateTray(false, true);
    }
  }
}

final tray = Tray();
