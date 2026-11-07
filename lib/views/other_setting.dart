import 'package:bett_box/common/common.dart';
import 'package:bett_box/common/network_matcher.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/plugins/service.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmartAutoStopSection extends ConsumerWidget {
  const SmartAutoStopSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartAutoStop = ref.watch(
      vpnSettingProvider.select((state) => state.smartAutoStop),
    );
    final smartAutoStopNetworks = ref.watch(
      vpnSettingProvider.select((state) => state.smartAutoStopNetworks),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListItem.switchItem(
          title: Text(appLocalizations.smartAutoStop),
          subtitle: Text(appLocalizations.smartAutoStopDesc),
          delegate: SwitchDelegate(
            value: smartAutoStop,
            onChanged: (bool value) async {
              ref
                  .read(vpnSettingProvider.notifier)
                  .updateState((state) => state.copyWith(smartAutoStop: value));
            },
          ),
        ),
        if (smartAutoStop) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: context.colorScheme.outlineVariant.withValues(
              alpha: context.colorScheme.brightness == Brightness.light
                  ? 0.6
                  : 0.45,
            ),
            indent: 16,
            endIndent: 16,
          ),
          ListItem.input(
            title: Text(appLocalizations.networkMatch),
            subtitle: Text(
              smartAutoStopNetworks.isEmpty
                  ? appLocalizations.networkMatchHint
                  : smartAutoStopNetworks,
            ),
            delegate: InputDelegate(
              title: appLocalizations.networkMatch,
              value: smartAutoStopNetworks,
              onChanged: (String? value) {
                if (value != null) {
                  ref
                      .read(vpnSettingProvider.notifier)
                      .updateState(
                        (state) => state.copyWith(smartAutoStopNetworks: value),
                      );
                }
              },
              validator: (String? value) {
                if (value == null || value.isEmpty) return null;
                return NetworkMatcher.getValidationError(
                  value,
                  invalidFormatMsg: appLocalizations.invalidIpFormat,
                  tooManyRulesMsg: appLocalizations.tooManyRules,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class DozeSuspendItem extends ConsumerWidget {
  const DozeSuspendItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dozeSuspend = ref.watch(
      vpnSettingProvider.select((state) => state.dozeSuspend),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.dozeSuspend),
      subtitle: Text(appLocalizations.dozeSuspendDesc),
      delegate: SwitchDelegate(
        value: dozeSuspend,
        onChanged: (bool value) {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(dozeSuspend: value));
        },
      ),
    );
  }
}

class StoreFixItem extends ConsumerWidget {
  const StoreFixItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeFix = ref.watch(
      vpnSettingProvider.select((state) => state.storeFix),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.storeFix),
      subtitle: Text(appLocalizations.storeFixDesc),
      delegate: SwitchDelegate(
        value: storeFix,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(storeFix: value));

          final currentHosts = Map<String, String>.from(
            ref.read(patchClashConfigProvider).hosts,
          );

          if (value) {
            currentHosts['services.googleapis.cn'] = 'services.googleapis.com';
          } else {
            currentHosts.remove('services.googleapis.cn');
          }

          ref
              .read(patchClashConfigProvider.notifier)
              .updateState((state) => state.copyWith(hosts: currentHosts));
        },
      ),
    );
  }
}

class CloseConnectionsItem extends ConsumerWidget {
  const CloseConnectionsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final closeConnections = ref.watch(
      appSettingProvider.select((state) => state.closeConnections),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoCloseConnections),
      subtitle: Text(appLocalizations.autoCloseConnectionsDesc),
      delegate: SwitchDelegate(
        value: closeConnections,
        onChanged: (value) async {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(closeConnections: value));
        },
      ),
    );
  }
}

class QuickResponseItem extends ConsumerWidget {
  const QuickResponseItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickResponse = ref.watch(
      vpnSettingProvider.select((state) => state.quickResponse),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.quickResponse),
      subtitle: Text(appLocalizations.quickResponseDesc),
      delegate: SwitchDelegate(
        value: quickResponse,
        onChanged: (bool value) {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(quickResponse: value));
        },
      ),
    );
  }
}

class NetworkFixItem extends ConsumerWidget {
  const NetworkFixItem({super.key});

  Future<void> _applyNetworkFix(bool enable) async {
    try {
      const regPath =
          r'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet';

      if (enable) {
        final commands = [
          'reg add "$regPath" /v ActiveDnsProbeContent /t REG_SZ /d "131.107.255.255" /f',
          'reg add "$regPath" /v ActiveDnsProbeContentV6 /t REG_SZ /d "fd3e:4f5a:5b81::1" /f',
          'reg add "$regPath" /v ActiveDnsProbeHost /t REG_SZ /d "dns.msftncsi.com" /f',
          'reg add "$regPath" /v ActiveDnsProbeHostV6 /t REG_SZ /d "dns.msftncsi.com" /f',
          'reg add "$regPath" /v ActiveWebProbeContent /t REG_SZ /d "" /f',
          'reg add "$regPath" /v ActiveWebProbeContentV6 /t REG_SZ /d "" /f',
          'reg add "$regPath" /v ActiveWebProbeHost /t REG_SZ /d "dns.alidns.com" /f',
          'reg add "$regPath" /v ActiveWebProbeHostV6 /t REG_SZ /d "dns.alidns.com" /f',
          'reg add "$regPath" /v ActiveWebProbePath /t REG_SZ /d "dns-query" /f',
          'reg add "$regPath" /v ActiveWebProbePathV6 /t REG_SZ /d "dns-query" /f',
          'reg add "$regPath" /v CaptivePortalTimer /t REG_DWORD /d 0x00000000 /f',
          'reg add "$regPath" /v CaptivePortalTimerBackOffIncrementsInSeconds /t REG_DWORD /d 0x00000001 /f',
          'reg add "$regPath" /v CaptivePortalTimerMaxInSeconds /t REG_DWORD /d 0x0000001e /f',
          'reg add "$regPath" /v EnableActiveProbing /t REG_DWORD /d 0x00000001 /f',
          'reg add "$regPath" /v PassivePollPeriod /t REG_DWORD /d 0x0000000f /f',
          'reg add "$regPath" /v StaleThreshold /t REG_DWORD /d 0x0000001e /f',
          'reg add "$regPath" /v WebTimeout /t REG_DWORD /d 0x00000023 /f',
        ];

        for (final cmd in commands) {
          windows?.runas(cmd, '', showWindow: false);
        }
      } else {
        final commands = [
          'reg add "$regPath" /v ActiveDnsProbeContent /t REG_SZ /d "131.107.255.255" /f',
          'reg add "$regPath" /v ActiveDnsProbeContentV6 /t REG_SZ /d "fd3e:4f5a:5b81::1" /f',
          'reg add "$regPath" /v ActiveDnsProbeHost /t REG_SZ /d "dns.msftncsi.com" /f',
          'reg add "$regPath" /v ActiveDnsProbeHostV6 /t REG_SZ /d "dns.msftncsi.com" /f',
          'reg add "$regPath" /v ActiveWebProbeContent /t REG_SZ /d "Microsoft NCSI" /f',
          'reg add "$regPath" /v ActiveWebProbeContentV6 /t REG_SZ /d "Microsoft NCSI" /f',
          'reg add "$regPath" /v ActiveWebProbeHost /t REG_SZ /d "www.msftncsi.com" /f',
          'reg add "$regPath" /v ActiveWebProbeHostV6 /t REG_SZ /d "ipv6.msftncsi.com" /f',
          'reg add "$regPath" /v ActiveWebProbePath /t REG_SZ /d "ncsi.txt" /f',
          'reg add "$regPath" /v ActiveWebProbePathV6 /t REG_SZ /d "ncsi.txt" /f',
          'reg add "$regPath" /v CaptivePortalTimer /t REG_DWORD /d 0x00000000 /f',
          'reg add "$regPath" /v CaptivePortalTimerBackOffIncrementsInSeconds /t REG_DWORD /d 0x00000001 /f',
          'reg add "$regPath" /v CaptivePortalTimerMaxInSeconds /t REG_DWORD /d 0x0000001e /f',
          'reg add "$regPath" /v EnableActiveProbing /t REG_DWORD /d 0x00000001 /f',
          'reg add "$regPath" /v PassivePollPeriod /t REG_DWORD /d 0x0000000f /f',
          'reg add "$regPath" /v StaleThreshold /t REG_DWORD /d 0x0000001e /f',
          'reg add "$regPath" /v WebTimeout /t REG_DWORD /d 0x00000023 /f',
        ];

        for (final cmd in commands) {
          windows?.runas(cmd, '', showWindow: false);
        }
      }
    } catch (e) {
      commonPrint.warn('Network fix error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkFix = ref.watch(
      vpnSettingProvider.select((state) => state.networkFix),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.networkFix),
      subtitle: Text(appLocalizations.networkFixDesc),
      delegate: SwitchDelegate(
        value: networkFix,
        onChanged: (bool value) async {
          try {
            await _applyNetworkFix(value);

            ref
                .read(vpnSettingProvider.notifier)
                .updateState((state) => state.copyWith(networkFix: value));
          } catch (e) {
            if (context.mounted) {
              context.showSnackBar('Network fix failed: $e');
            }
          }
        },
      ),
    );
  }
}

class HighPriorityItem extends ConsumerWidget {
  const HighPriorityItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableHighPriority = ref.watch(
      appSettingProvider.select((state) => state.enableHighPriority),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.highPriority),
      subtitle: Text(appLocalizations.highPriorityDesc),
      delegate: SwitchDelegate(
        value: enableHighPriority,
        onChanged: (bool value) async {
          ref
              .read(appSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(enableHighPriority: value),
              );

          if (system.isWindows) {
            try {
              await globalState.appController.setProcessPriority(value);
            } catch (e) {
              commonPrint.warn('Set process priority error: $e');
              if (context.mounted) {
                context.showSnackBar('Failed to set process priority: $e');
              }
            }
          }
        },
      ),
    );
  }
}

class BatteryOptimizationItem extends StatelessWidget {
  final VoidCallback onRequest;

  const BatteryOptimizationItem({super.key, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return ListItem.switchItem(
      title: Text(appLocalizations.batteryOptimization),
      subtitle: Text(appLocalizations.batteryOptimizationDesc),
      delegate: SwitchDelegate(value: false, onChanged: (_) => onRequest()),
    );
  }
}

class LoopbackProtectionItem extends ConsumerWidget {
  const LoopbackProtectionItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loopbackProtection = ref.watch(
      vpnSettingProvider.select((state) => state.loopbackProtection),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.loopbackProtection),
      subtitle: Text(appLocalizations.loopbackProtectionDesc),
      delegate: SwitchDelegate(
        value: loopbackProtection,
        onChanged: (bool value) {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(loopbackProtection: value),
              );
        },
      ),
    );
  }
}

class DisableQuicSection extends ConsumerWidget {
  const DisableQuicSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disableQuic = ref.watch(
      vpnSettingProvider.select((state) => state.disableQuic),
    );
    final excludeChina = ref.watch(
      vpnSettingProvider.select((state) => state.excludeChina),
    );
    final locale = ref.watch(
      appSettingProvider.select((state) => state.locale),
    );
    final isRussian = locale?.toLowerCase().startsWith('ru') ?? false;
    final scriptActive = ref.watch(currentProfileScriptActiveProvider);
    final enabled = disableQuic && !scriptActive;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListItem.switchItem(
          title: Text(appLocalizations.disableQuic),
          subtitle: Text(
            scriptActive
                ? appLocalizations.disableQuicManagedDesc
                : appLocalizations.disableQuicDesc,
          ),
          delegate: SwitchDelegate(
            value: enabled,
            onChanged: scriptActive
                ? null
                : (bool value) async {
                    ref
                        .read(vpnSettingProvider.notifier)
                        .updateState(
                          (state) => state.copyWith(disableQuic: value),
                        );
                    globalState.appController.setupClashConfigDebounce();
                  },
          ),
        ),
        if (enabled && !isRussian) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: context.colorScheme.outlineVariant.withValues(
              alpha: context.colorScheme.brightness == Brightness.light
                  ? 0.6
                  : 0.45,
            ),
            indent: 16,
            endIndent: 16,
          ),
          ListItem.switchItem(
            title: Text(appLocalizations.excludeChina),
            subtitle: Text(appLocalizations.excludeChinaDesc),
            delegate: SwitchDelegate(
              value: excludeChina,
              onChanged: (bool value) async {
                ref
                    .read(vpnSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(excludeChina: value),
                    );
                globalState.appController.setupClashConfigDebounce();
              },
            ),
          ),
        ],
      ],
    );
  }
}

class HighPriorityNotificationItem extends ConsumerWidget {
  const HighPriorityNotificationItem({super.key});

  Future<bool> _showConfirmDialog(BuildContext context) async {
    final result = await globalState.showCommonDialog<bool>(
      child: CommonDialog(
        title: appLocalizations.notificationHighPriority,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop(false);
            },
            child: Text(appLocalizations.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop(true);
            },
            child: Text(appLocalizations.confirm),
          ),
        ],
        child: Text(appLocalizations.notificationHighPriorityTip),
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highPriority = ref.watch(
      vpnSettingProvider.select((state) => state.highPriorityNotification),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.notificationHighPriority),
      subtitle: Text(appLocalizations.notificationHighPriorityDesc),
      delegate: SwitchDelegate(
        value: highPriority,
        onChanged: (bool value) async {
          if (value) {
            final confirm = await _showConfirmDialog(context);
            if (!confirm) return;
          }
          ref
              .read(vpnSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(highPriorityNotification: value),
              );
          if (system.isAndroid) {
            await service?.setHighPriorityNotification(value);
          }
        },
      ),
    );
  }
}

class NetworkSpeedNotificationItem extends ConsumerWidget {
  const NetworkSpeedNotificationItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkSpeedNotification = ref.watch(
      vpnSettingProvider.select((state) => state.networkSpeedNotification),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.networkSpeedNotification),
      subtitle: Text(appLocalizations.networkSpeedNotificationDesc),
      delegate: SwitchDelegate(
        value: networkSpeedNotification,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(networkSpeedNotification: value),
              );
          if (!value && system.isAndroid) {
            await service?.restoreNotification();
          }
        },
      ),
    );
  }
}

class TrayClickBehaviorItem extends ConsumerWidget {
  const TrayClickBehaviorItem({super.key});

  String _getDisplayText(TrayClickBehavior behavior) {
    return switch (behavior) {
      TrayClickBehavior.showPanel => appLocalizations.showPanel,
      TrayClickBehavior.showMenu => appLocalizations.showMenu,
    };
  }

  Future<void> _showSettings(
    WidgetRef ref, {
    required TrayClickBehavior leftBehavior,
    required TrayClickBehavior rightBehavior,
  }) async {
    final result = await globalState
        .showCommonDialog<
          ({TrayClickBehavior leftBehavior, TrayClickBehavior rightBehavior})
        >(
          child: _TrayClickBehaviorDialog(
            leftBehavior: leftBehavior,
            rightBehavior: rightBehavior,
          ),
        );
    if (result == null) return;
    ref
        .read(vpnSettingProvider.notifier)
        .updateState(
          (state) => state.copyWith(
            trayLeftClickBehavior: result.leftBehavior,
            trayRightClickBehavior: result.rightBehavior,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (leftBehavior, rightBehavior) = ref.watch(
      vpnSettingProvider.select(
        (state) => (state.trayLeftClickBehavior, state.trayRightClickBehavior),
      ),
    );
    return ListItem(
      title: Text(appLocalizations.trayClickBehavior),
      subtitle: Text(
        '${appLocalizations.leftClickBehavior}：'
        '${_getDisplayText(leftBehavior)}  ·  '
        '${appLocalizations.rightClickBehavior}：'
        '${_getDisplayText(rightBehavior)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showSettings(
        ref,
        leftBehavior: leftBehavior,
        rightBehavior: rightBehavior,
      ),
    );
  }
}

class _TrayClickBehaviorDialog extends StatefulWidget {
  final TrayClickBehavior leftBehavior;
  final TrayClickBehavior rightBehavior;

  const _TrayClickBehaviorDialog({
    required this.leftBehavior,
    required this.rightBehavior,
  });

  @override
  State<_TrayClickBehaviorDialog> createState() =>
      _TrayClickBehaviorDialogState();
}

class _TrayClickBehaviorDialogState extends State<_TrayClickBehaviorDialog> {
  late TrayClickBehavior _leftBehavior;
  late TrayClickBehavior _rightBehavior;

  @override
  void initState() {
    super.initState();
    _leftBehavior = widget.leftBehavior;
    _rightBehavior = widget.rightBehavior;
  }

  List<ButtonSegment<TrayClickBehavior>> get _segments => [
    ButtonSegment(
      value: TrayClickBehavior.showPanel,
      icon: const Icon(Icons.dashboard_outlined),
      label: Text(appLocalizations.showPanel),
    ),
    ButtonSegment(
      value: TrayClickBehavior.showMenu,
      icon: const Icon(Icons.menu),
      label: Text(appLocalizations.showMenu),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.trayClickBehavior,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop((leftBehavior: _leftBehavior, rightBehavior: _rightBehavior));
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appLocalizations.leftClickBehavior,
            style: context.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<TrayClickBehavior>(
            segments: _segments,
            selected: {_leftBehavior},
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: (selection) {
              setState(() => _leftBehavior = selection.first);
            },
          ),
          const SizedBox(height: 20),
          Text(
            appLocalizations.rightClickBehavior,
            style: context.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<TrayClickBehavior>(
            segments: _segments,
            selected: {_rightBehavior},
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: (selection) {
              setState(() => _rightBehavior = selection.first);
            },
          ),
        ],
      ),
    );
  }
}

class EnableTraySpeedItem extends ConsumerWidget {
  const EnableTraySpeedItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableTraySpeed = ref.watch(
      vpnSettingProvider.select((state) => state.enableTraySpeed),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.enableTraySpeed),
      subtitle: Text(appLocalizations.enableTraySpeedDesc),
      delegate: SwitchDelegate(
        value: enableTraySpeed,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(enableTraySpeed: value));
          await globalState.appController.updateTray();
        },
      ),
    );
  }
}

// BETTBOX-CUSTOM: 托盘策略组右侧逐级显示完整节点链路（默认关闭，只补最终节点）。
class TrayShowProxyChainItem extends ConsumerWidget {
  const TrayShowProxyChainItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trayShowProxyChain = ref.watch(
      appSettingProvider.select((state) => state.trayShowProxyChain),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.trayShowProxyChain),
      subtitle: Text(appLocalizations.trayShowProxyChainDesc),
      delegate: SwitchDelegate(
        value: trayShowProxyChain,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(trayShowProxyChain: value),
              );
        },
      ),
    );
  }
}

// BETTBOX-CUSTOM: 托盘图标旁显示指定策略组（含隐藏组）。开启后可选组名 / 具体节点 /
// 完整链路三项，网速开启时可选放在网速前或后，网速关闭时占用网速位置。
// Windows 托盘没有标题位，写入悬浮提示。刷新由 TrayManager 监听这些字段触发。
class TrayStatusGroupItem extends ConsumerWidget {
  const TrayStatusGroupItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enable = ref.watch(
      appSettingProvider.select((state) => state.trayStatusGroupEnable),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.trayStatusGroup),
      subtitle: Text(appLocalizations.trayStatusGroupDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (bool value) {
          final groups = trayStatusSelectableGroups(ref.read(groupsProvider));
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) {
                // 首次开启时默认选中第一个策略组，避免开启后什么都不显示。
                final name =
                    value && state.trayStatusGroupName.isEmpty && groups.isNotEmpty
                    ? groups.first.name
                    : state.trayStatusGroupName;
                return state.copyWith(
                  trayStatusGroupEnable: value,
                  trayStatusGroupName: name,
                );
              });
        },
      ),
    );
  }
}

class TrayStatusGroupNameItem extends ConsumerWidget {
  const TrayStatusGroupNameItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(
      appSettingProvider.select((state) => state.trayStatusGroupName),
    );
    // BETTBOX-CUSTOM: GLOBAL 只在全局模式使用且该模式下固定显示，不作为选项。
    final groups = trayStatusSelectableGroups(ref.watch(groupsProvider));
    final hiddenNames = {
      for (final group in groups)
        if (group.hidden == true) group.name,
    };
    final names = [for (final group in groups) group.name];
    final subtitle = name.isEmpty
        ? appLocalizations.trayStatusGroupNotSelected
        : names.contains(name)
        ? name
        : '$name（${appLocalizations.trayStatusGroupMissing}）';
    String textBuilder(String value) => hiddenNames.contains(value)
        ? '$value ${appLocalizations.trayStatusGroupHidden}'
        : value;
    return ListItem<String>.options(
      title: Text(appLocalizations.trayStatusGroupName),
      subtitle: Text(subtitle),
      delegate: OptionsDelegate<String>(
        title: appLocalizations.trayStatusGroupName,
        options: names,
        value: name,
        textBuilder: textBuilder,
        onChanged: (value) {
          if (value == null) return;
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(trayStatusGroupName: value));
        },
      ),
    );
  }
}

class _TrayStatusCheckboxItem extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final bool Function(AppSettingProps state) select;
  final AppSettingProps Function(AppSettingProps state, bool value) update;

  const _TrayStatusCheckboxItem({
    required this.title,
    this.subtitle,
    required this.select,
    required this.update,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(appSettingProvider.select(select));
    return ListItem.checkbox(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      delegate: CheckboxDelegate(
        value: value,
        onChanged: (checked) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => update(state, checked ?? false));
        },
      ),
    );
  }
}

class TrayStatusPositionItem extends ConsumerWidget {
  const TrayStatusPositionItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final before = ref.watch(
      appSettingProvider.select((state) => state.trayStatusBeforeSpeed),
    );
    String textBuilder(bool value) => value
        ? appLocalizations.trayStatusBeforeSpeed
        : appLocalizations.trayStatusAfterSpeed;
    return ListItem<bool>.options(
      title: Text(appLocalizations.trayStatusPosition),
      subtitle: Text(textBuilder(before)),
      delegate: OptionsDelegate<bool>(
        title: appLocalizations.trayStatusPosition,
        options: const [false, true],
        value: before,
        textBuilder: textBuilder,
        onChanged: (value) {
          if (value == null) return;
          ref
              .read(appSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(trayStatusBeforeSpeed: value),
              );
        },
      ),
    );
  }
}

/// 托盘显示策略组及其联动子项：开启后才显示选择与显示项，网速开启时才显示位置。
class TrayStatusGroupSection extends ConsumerWidget {
  const TrayStatusGroupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enable = ref.watch(
      appSettingProvider.select((state) => state.trayStatusGroupEnable),
    );
    final speedEnabled = ref.watch(
      vpnSettingProvider.select((state) => state.enableTraySpeed),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TrayStatusGroupItem(),
        if (enable) ...[
          const TrayStatusGroupNameItem(),
          _TrayStatusCheckboxItem(
            title: appLocalizations.trayStatusShowName,
            select: (state) => state.trayStatusShowName,
            update: (state, value) =>
                state.copyWith(trayStatusShowName: value),
          ),
          _TrayStatusCheckboxItem(
            title: appLocalizations.trayStatusShowNode,
            subtitle: appLocalizations.trayStatusShowNodeDesc,
            select: (state) => state.trayStatusShowNode,
            update: (state, value) =>
                state.copyWith(trayStatusShowNode: value),
          ),
          _TrayStatusCheckboxItem(
            title: appLocalizations.trayStatusShowChain,
            subtitle: appLocalizations.trayStatusShowChainDesc,
            select: (state) => state.trayStatusShowChain,
            update: (state, value) =>
                state.copyWith(trayStatusShowChain: value),
          ),
          _TrayStatusCheckboxItem(
            title: appLocalizations.trayStatusShowDelay,
            subtitle: appLocalizations.trayStatusShowDelayDesc,
            select: (state) => state.trayStatusShowDelay,
            update: (state, value) =>
                state.copyWith(trayStatusShowDelay: value),
          ),
          if (speedEnabled) const TrayStatusPositionItem(),
          const TrayStatusPreviewItem(),
        ],
      ],
    );
  }
}

/// BETTBOX-CUSTOM: 按当前设置与选中节点预览托盘最终效果，网速为示例数据。
/// macOS 模拟菜单栏：图标、两行网速、分隔线、策略组标签，间距与原生绘制一致；
/// Windows 模拟悬浮提示：应用名、网速、策略组标签逐行拼接。
class TrayStatusPreviewItem extends ConsumerWidget {
  const TrayStatusPreviewItem({super.key});

  static const _sampleMacSpeed = ['12K/s', '1.5M/s'];
  static const _sampleWindowsSpeed = '↑ 12.0 K/s\n↓ 1.5 M/s';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(appSettingProvider);
    final speedEnabled = ref.watch(
      vpnSettingProvider.select((state) => state.enableTraySpeed),
    );
    final groups = ref.watch(groupsProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    // BETTBOX-CUSTOM: 当前模式画完整预览，其余两种模式用文字列出各自的显示结果。
    String labelFor(Mode target) {
      final groupName = trayStatusEffectiveGroupName(
        target,
        setting.trayStatusGroupName,
      );
      final group = groups.getGroup(groupName);
      var delayText = '';
      if (setting.trayStatusShowDelay && group != null) {
        final delay = ref.watch(
          getDelayProvider(proxyName: group.name, testUrl: group.testUrl),
        );
        delayText = trayStatusDelayText(
          delay,
          timeoutText: appLocalizations.trayStatusDelayTimeout,
        );
      }
      return trayStatusGroupLabel(
        groupName: groupName,
        groups: groups,
        selectedMap: selectedMap,
        showName: setting.trayStatusShowName,
        showNode: setting.trayStatusShowNode,
        showChain: setting.trayStatusShowChain,
        delayText: delayText,
      );
    }

    final label = labelFor(mode);
    final otherModes = [
      for (final target in Mode.values)
        if (target != mode) target,
    ];
    final before = setting.trayStatusBeforeSpeed;
    return ListItem(
      title: Text(appLocalizations.trayStatusPreview),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(appLocalizations.trayStatusPreviewDesc),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: system.isWindows
                ? _buildWindowsPreview(context, label, speedEnabled, before)
                : _buildMacPreview(context, label, speedEnabled, before),
          ),
          if (label.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              appLocalizations.trayStatusPreviewEmpty,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            appLocalizations.trayStatusOtherModes,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          for (final target in otherModes)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${_modeName(target)}  ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: () {
                        final text = labelFor(target);
                        return text.isEmpty
                            ? appLocalizations.trayStatusModeNothing
                            : text;
                      }(),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(appLocalizations.trayStatusModeDesc),
        ],
      ),
    );
  }

  static String _modeName(Mode mode) => switch (mode) {
    Mode.rule => appLocalizations.rule,
    Mode.global => appLocalizations.global,
    Mode.direct => appLocalizations.direct,
  };

  Widget _buildMacPreview(
    BuildContext context,
    String label,
    bool speedEnabled,
    bool before,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : Colors.black87;
    final speed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final line in _sampleMacSpeed)
          Text(
            line,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.05,
              fontFamily: 'monospace',
              color: foreground,
            ),
          ),
      ],
    );
    final labelWidget = Flexible(
      child: Text.rich(
        _lockedSpan(label, TextStyle(fontSize: 13, color: foreground)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final separator = Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: foreground.withValues(alpha: 0.35),
    );
    final hasLabel = label.isNotEmpty;
    final segments = <Widget>[
      if (hasLabel && speedEnabled && before) ...[labelWidget, separator, speed],
      if (hasLabel && speedEnabled && !before) ...[speed, separator, labelWidget],
      if (hasLabel && !speedEnabled) labelWidget,
      if (!hasLabel && speedEnabled) speed,
    ];
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2B2E) : const Color(0xFFE9E9EC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/icon_template.png',
            width: 16,
            height: 16,
            color: foreground,
          ),
          if (segments.isNotEmpty) const SizedBox(width: 6),
          ...segments,
        ],
      ),
    );
  }

  Widget _buildWindowsPreview(
    BuildContext context,
    String label,
    bool speedEnabled,
    bool before,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final speed = speedEnabled ? _sampleWindowsSpeed : '';
    final lines = [
      appName,
      if (before) ...[label, speed] else ...[speed, label],
    ].where((line) => line.isNotEmpty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text.rich(
        _lockedSpan(
          lines.join('\n'),
          TextStyle(fontSize: 12, color: colorScheme.onSurface),
        ),
      ),
    );
  }

  /// BETTBOX-CUSTOM: 预览中把锁标记（被固定的策略组 / 节点）替换为单色锁图标，
  /// 与 macOS / Windows 托盘的实际绘制一致。
  static InlineSpan _lockedSpan(String text, TextStyle style) {
    final parts = text.split(trayLockMark);
    return TextSpan(
      style: style,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Icon(
                  Icons.lock_outline,
                  size: (style.fontSize ?? 13) * 0.9,
                  color: style.color,
                ),
              ),
            ),
          if (parts[i].isNotEmpty) TextSpan(text: parts[i]),
        ],
      ],
    );
  }
}

class OtherSettingView extends StatefulWidget {
  const OtherSettingView({super.key});

  @override
  State<OtherSettingView> createState() => _OtherSettingViewState();
}

class _OtherSettingViewState extends State<OtherSettingView>
    with WidgetsBindingObserver {
  bool _showBatteryOptimization = false;
  bool _isWaitingForSettings = false;

  @override
  void initState() {
    super.initState();
    if (!system.isAndroid) return;
    WidgetsBinding.instance.addObserver(this);
    _checkBatteryOptimization();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final maxRetries = _isWaitingForSettings ? 3 : 1;
    _isWaitingForSettings = false;
    _checkBatteryOptimization(maxRetries: maxRetries);
  }

  Future<void> _checkBatteryOptimization({int maxRetries = 1}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final isIgnoring = await app.isIgnoringBatteryOptimizations();
        if (!mounted) return;
        if (_showBatteryOptimization == isIgnoring) {
          setState(() => _showBatteryOptimization = !isIgnoring);
        }
        if (isIgnoring || attempt >= maxRetries - 1) return;
        await Future.delayed(const Duration(milliseconds: 666));
      } catch (e) {
        commonPrint.warn('Battery optimization check error: $e');
        return;
      }
    }
  }

  Future<void> _requestBatteryOptimization() async {
    _isWaitingForSettings = true;
    try {
      await app.requestIgnoreBatteryOptimizations();
    } catch (e) {
      commonPrint.warn('Battery optimization error: $e');
      _isWaitingForSettings = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [
      const SmartAutoStopSection(),
      if (system.isAndroid) const DozeSuspendItem(),
      if (system.isAndroid) const QuickResponseItem(),
      if (system.isAndroid) const StoreFixItem(),
      const LoopbackProtectionItem(),
      const DisableQuicSection(),
      if (system.isAndroid) const HighPriorityNotificationItem(),
      if (system.isAndroid) const NetworkSpeedNotificationItem(),
      // BETTBOX-CUSTOM: macOS 与 Windows 共用托盘点击行为、实时速率、状态策略组与链路设置。
      if (system.isMacOS || system.isWindows) const TrayClickBehaviorItem(),
      if (system.isMacOS || system.isWindows) const EnableTraySpeedItem(),
      if (system.isMacOS || system.isWindows) const TrayStatusGroupSection(),
      if (system.isMacOS || system.isWindows) const TrayShowProxyChainItem(),
      if (system.isWindows) const HighPriorityItem(),
      if (system.isWindows) const NetworkFixItem(),
      if (system.isDesktop) const CloseConnectionsItem(),
      if (_showBatteryOptimization)
        BatteryOptimizationItem(onRequest: _requestBatteryOptimization),
    ];

    if (items.isEmpty) {
      return const Center(child: Text('No settings available'));
    }

    return generateListView(generateSection(items: items));
  }
}
