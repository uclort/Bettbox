import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> _handleNetworkConfigChange(WidgetRef ref) async {
  if (system.isAndroid) {
    final isVpnEnabled = ref.read(vpnSettingProvider).enable;
    final isCoreRunning = ref.read(runTimeProvider) != null;
    if (isVpnEnabled && isCoreRunning) {
      globalState.showNotifier(
        appLocalizations.vpnTip,
        actionLabel: appLocalizations.restart,
        showCountdown: true,
        onAction: () async {
          await globalState.appController.restartCore();
          globalState.showNotifier(appLocalizations.success);
        },
      );
      return;
    }
  }
  globalState.appController.updateClashConfig();
}

class VPNItem extends ConsumerWidget {
  const VPNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final enable = ref.watch(
      vpnSettingProvider.select((state) => state.enable),
    );
    return ListItem.switchItem(
      title: const Text('VPN'),
      subtitle: Text(appLocalizations.vpnEnableDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(enable: value));
        },
      ),
    );
  }
}

class TUNItem extends ConsumerWidget {
  const TUNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final enable = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.tun),
      subtitle: Text(appLocalizations.tunDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) async {
          await globalState.appController.updateTun(value);
        },
      ),
    );
  }
}

class AllowBypassItem extends ConsumerWidget {
  const AllowBypassItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final allowBypass = ref.watch(
      vpnSettingProvider.select((state) => state.allowBypass),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.allowBypass),
      subtitle: Text(appLocalizations.allowBypassDesc),
      delegate: SwitchDelegate(
        value: allowBypass,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(allowBypass: value));
          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

class VpnSystemProxyItem extends ConsumerWidget {
  const VpnSystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final systemProxy = ref.watch(
      vpnSettingProvider.select((state) => state.systemProxy),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.systemProxy),
      subtitle: Text(appLocalizations.vpnSystemProxyDesc),
      delegate: SwitchDelegate(
        value: systemProxy,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(systemProxy: value));
          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

class SystemProxyItem extends ConsumerWidget {
  const SystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final systemProxy = ref.watch(
      networkSettingProvider.select((state) => state.systemProxy),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.systemProxy),
      subtitle: Text(appLocalizations.systemProxyDesc),
      delegate: SwitchDelegate(
        value: systemProxy,
        onChanged: (bool value) async {
          await globalState.appController.updateSystemProxy(value);
        },
      ),
    );
  }
}

class AutoSetSystemDnsItem extends ConsumerWidget {
  const AutoSetSystemDnsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSet =
        ref.watch(runTimeProvider.select((state) => state != null)) &&
        ref.watch(realTunEnableProvider);
    final autoSetSystemDns = ref.watch(
      networkSettingProvider.select((state) => state.autoSetSystemDns),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoSetSystemDns),
      delegate: SwitchDelegate(
        value: autoSetSystemDns,
        onChanged: canSet
            ? (bool value) async {
                ref
                    .read(networkSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(autoSetSystemDns: value),
                    );
              }
            : null,
      ),
    );
  }
}

class StrictRouteItem extends ConsumerWidget {
  const StrictRouteItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strictRoute = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.strictRoute),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.strictRoute),
      subtitle: Text(appLocalizations.strictRouteDesc),
      delegate: SwitchDelegate(
        value: strictRoute,
        onChanged: (value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState((state) => state.copyWith.tun(strictRoute: value));

          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

class IcmpForwardingItem extends ConsumerWidget {
  const IcmpForwardingItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: inverted because disableIcmpForwarding=true means disabled
    // UI shows "Enable ICMP forwarding"
    final icmpForwarding = ref.watch(
      patchClashConfigProvider.select(
        (state) => !state.tun.disableIcmpForwarding,
      ),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.icmpForwarding),
      subtitle: Text(appLocalizations.icmpForwardingDesc),
      delegate: SwitchDelegate(
        value: icmpForwarding,
        onChanged: (value) async {
          // Invert before passing to core
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState(
                (state) => state.copyWith.tun(disableIcmpForwarding: !value),
              );

          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

class DnsHijackItem extends ConsumerWidget {
  const DnsHijackItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dnsHijack = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.tun.dnsHijack.isNotEmpty,
      ),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.dnsHijack),
      subtitle: Text(appLocalizations.dnsHijackDesc),
      delegate: SwitchDelegate(
        value: dnsHijack,
        onChanged: (value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState(
                (state) => state.copyWith.tun(
                  dnsHijack: value ? ['any:53', 'tcp://any:53'] : [],
                ),
              );
          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

class EndpointIndependentNatItem extends ConsumerWidget {
  const EndpointIndependentNatItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endpointIndependentNat = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.tun.endpointIndependentNat,
      ),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.endpointIndependentNat),
      subtitle: Text(appLocalizations.endpointIndependentNatDesc),
      delegate: SwitchDelegate(
        value: endpointIndependentNat,
        onChanged: (value) async {
          if (value) {
            final res = await globalState.showMessage(
              title: appLocalizations.tip,
              message: TextSpan(
                text: appLocalizations.endpointIndependentNatConfirmDesc,
              ),
            );
            if (res != true) return;
          }
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState(
                (state) => state.copyWith.tun(endpointIndependentNat: value),
              );
          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

class TunStackItem extends ConsumerWidget {
  const TunStackItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final stack = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.stack),
    );

    return ListItem.options(
      title: Text(appLocalizations.stackMode),
      subtitle: Text(stack.name),
      delegate: OptionsDelegate<TunStack>(
        value: stack,
        options: TunStack.values,
        textBuilder: (value) => value.name,
        onChanged: (value) async {
          if (value == null || value == stack) return;
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState((state) => state.copyWith.tun(stack: value));
          if (system.isDesktop) {
            await globalState.appController.restartCore();
            return;
          }
          await _handleNetworkConfigChange(ref);
        },
        title: appLocalizations.stackMode,
      ),
    );
  }
}

class TunCongestionControllerItem extends ConsumerWidget {
  const TunCongestionControllerItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (stack, congestionController) = ref.watch(
      patchClashConfigProvider.select(
        (state) => (state.tun.stack, state.tun.congestionController),
      ),
    );

    if (stack != TunStack.mips) {
      return const SizedBox.shrink();
    }

    return ListItem.options(
      title: Text(appLocalizations.congestionController),
      subtitle: Text(congestionController.name),
      delegate: OptionsDelegate<CongestionController>(
        value: congestionController,
        options: CongestionController.values,
        textBuilder: (value) => value.name,
        onChanged: (value) async {
          if (value == null) {
            return;
          }
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState(
                (state) => state.copyWith.tun(congestionController: value),
              );
          await _handleNetworkConfigChange(ref);
        },
        title: appLocalizations.congestionController,
      ),
    );
  }
}

class MtuItem extends ConsumerWidget {
  const MtuItem({super.key});

  Future<void> _showCustomMtuDialog(
    BuildContext context,
    WidgetRef ref,
    int currentMtu,
  ) async {
    String inputValue = '$currentMtu';
    String? errorText;
    final controller = TextEditingController(text: inputValue);

    final result = await globalState.showCommonDialog<bool>(
      child: StatefulBuilder(
        builder: (context, setState) {
          return CommonDialog(
            title: 'MTU',
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text(appLocalizations.cancel),
              ),
              TextButton(
                onPressed: errorText == null && inputValue.isNotEmpty
                    ? () {
                        Navigator.of(context).pop(true);
                      }
                    : null,
                child: Text(appLocalizations.confirm),
              ),
            ],
            child: IdleFocusBuilder(
              builder: (_, focusNode) => TextField(
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'MTU',
                  errorText: errorText,
                  hintText: '1280-65535',
                ),
                onChanged: (value) {
                  inputValue = value;
                  // Real-time validation
                  if (value.isEmpty) {
                    setState(() {
                      errorText = appLocalizations.emptyTip('MTU');
                    });
                  } else {
                    final intValue = int.tryParse(value);
                    if (intValue == null) {
                      setState(() {
                        errorText = appLocalizations.numberTip('MTU');
                      });
                    } else if (intValue < 1280 || intValue > 65535) {
                      setState(() {
                        errorText = 'MTU Must be 1280-65535';
                      });
                    } else {
                      setState(() {
                        errorText = null;
                      });
                    }
                  }
                },
                onSubmitted: (value) {
                  if (errorText == null && value.isNotEmpty) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ),
          );
        },
      ),
    );

    // Clean up controller
    controller.dispose();

    if (result == true && inputValue.isNotEmpty) {
      final intValue = int.tryParse(inputValue);
      if (intValue != null && intValue >= 1280 && intValue <= 65535) {
        ref
            .read(patchClashConfigProvider.notifier)
            .updateState((state) => state.copyWith.tun(mtu: intValue));
        await _handleNetworkConfigChange(ref);
      }
    }
  }

  @override
  Widget build(BuildContext context, ref) {
    final mtu = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.mtu),
    );

    // Preset options
    final presetOptions = [9000, 4064];
    final isCustom = !presetOptions.contains(mtu);

    return ListItem.options(
      title: const Text('MTU'),
      subtitle: Text(isCustom ? '$mtu (${appLocalizations.custom})' : '$mtu'),
      delegate: OptionsDelegate<String>(
        value: isCustom ? 'custom' : '$mtu',
        options: ['9000', '4064', 'custom'],
        textBuilder: (value) {
          if (value == 'custom') {
            return '${appLocalizations.custom}...';
          }
          return value;
        },
        onChanged: (value) async {
          if (value == null) return;

          // If custom option selected
          if (value == 'custom') {
            await _showCustomMtuDialog(context, ref, mtu);
          } else {
            // Apply preset value directly
            final intValue = int.parse(value);
            ref
                .read(patchClashConfigProvider.notifier)
                .updateState((state) => state.copyWith.tun(mtu: intValue));
            await _handleNetworkConfigChange(ref);
          }
        },
        title: 'MTU',
      ),
    );
  }
}

class BypassDomainItem extends StatelessWidget {
  const BypassDomainItem({super.key});

  @override
  Widget build(BuildContext context) {
    return ListItem.next(
      title: Text(appLocalizations.bypassDomain),
      subtitle: Text(appLocalizations.bypassDomainDesc),
      delegate: NextDelegate(
        blur: false,
        actions: [
          Consumer(
            builder: (_, ref, _) {
              return IconButton(
                onPressed: () async {
                  final res = await globalState.showMessage(
                    title: appLocalizations.reset,
                    message: TextSpan(text: appLocalizations.resetTip),
                  );
                  if (res != true) {
                    return;
                  }
                  ref
                      .read(networkSettingProvider.notifier)
                      .updateState(
                        (state) =>
                            state.copyWith(bypassDomain: defaultBypassDomain),
                      );
                  await _handleNetworkConfigChange(ref);
                },
                tooltip: appLocalizations.reset,
                icon: const Icon(Icons.replay),
              );
            },
          ),
        ],
        title: appLocalizations.bypassDomain,
        widget: Consumer(
          builder: (_, ref, _) {
            final bypassDomain = ref.watch(
              networkSettingProvider.select((state) => state.bypassDomain),
            );
            return ListInputPage(
              title: appLocalizations.bypassDomain,
              items: bypassDomain,
              titleBuilder: (item) => Text(item),
              onChange: (items) async {
                ref
                    .read(networkSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(bypassDomain: List.from(items)),
                    );
                await _handleNetworkConfigChange(ref);
              },
            );
          },
        ),
      ),
    );
  }
}

class BypassPrivateRouteItem extends ConsumerWidget {
  const BypassPrivateRouteItem({super.key});

  void _showEditPage(BuildContext context, WidgetRef ref) {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.bypassPrivateRoute,
        actions: [
          Consumer(
            builder: (_, ref, _) {
              return IconButton(
                onPressed: () async {
                  final res = await globalState.showMessage(
                    title: appLocalizations.reset,
                    message: TextSpan(text: appLocalizations.resetTip),
                  );
                  if (res != true) return;
                  ref
                      .read(networkSettingProvider.notifier)
                      .updateState(
                        (state) => state.copyWith(
                          bypassPrivateRouteAddress: system.isDesktop
                              ? defaultDesktopBypassPrivateRouteAddress
                              : defaultBypassPrivateRouteAddress,
                        ),
                      );
                  await _handleNetworkConfigChange(ref);
                },
                tooltip: appLocalizations.reset,
                icon: const Icon(Icons.replay),
              );
            },
          ),
        ],
        body: Consumer(
          builder: (_, ref, _) {
            final bypassPrivateRouteAddress = ref.watch(
              networkSettingProvider.select(
                (state) => state.realBypassPrivateRouteAddress,
              ),
            );
            return ListInputPage(
              title: appLocalizations.bypassPrivateRoute,
              items: bypassPrivateRouteAddress,
              titleBuilder: (item) => Text(item),
              onChange: (items) async {
                ref
                    .read(networkSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(
                        bypassPrivateRouteAddress: List.from(items),
                      ),
                    );
                await _handleNetworkConfigChange(ref);
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final bypassPrivateRoute = ref.watch(
      networkSettingProvider.select((state) => state.bypassPrivateRoute),
    );
    return ListItem.switchItem(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(appLocalizations.bypassPrivateRoute),
          Tooltip(
            message: appLocalizations.edit,
            child: Material(
              color: Colors.transparent,
              child: InkResponse(
                radius: 16,
                highlightShape: BoxShape.circle,
                onTap: () => _showEditPage(context, ref),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(appLocalizations.bypassPrivateRouteDesc),
      delegate: SwitchDelegate(
        value: bypassPrivateRoute,
        onChanged: (value) async {
          ref
              .read(networkSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(bypassPrivateRoute: value),
              );
          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

// BETTBOX-CUSTOM: Tailscale 共存。DNS 与前置规则需要重建配置，网段与系统代理例外会随状态热更新。
Future<void> _updateTailscale(
  WidgetRef ref,
  TailscaleProps Function(TailscaleProps state) builder,
) async {
  ref
      .read(networkSettingProvider.notifier)
      .updateState(
        (state) => state.copyWith(tailscale: builder(state.tailscale)),
      );
  globalState.appController.setupClashConfigDebounce();
}

class TailscaleItem extends ConsumerWidget {
  const TailscaleItem({super.key});

  Widget _listEntry({
    required String title,
    required String subtitle,
    required List<String> Function(TailscaleProps state) select,
    required TailscaleProps Function(TailscaleProps state, List<String> items)
    update,
  }) {
    return ListItem.next(
      title: Text(title),
      subtitle: Text(subtitle),
      delegate: NextDelegate(
        blur: false,
        title: title,
        widget: Consumer(
          builder: (_, ref, _) {
            final items = ref.watch(
              networkSettingProvider.select((state) => select(state.tailscale)),
            );
            return ListInputPage(
              title: title,
              items: items,
              titleBuilder: (item) => Text(item),
              onChange: (items) => _updateTailscale(
                ref,
                (state) => update(state, List.from(items)),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditPage(BuildContext context) {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.tailscaleCoexist,
        actions: [
          Consumer(
            builder: (_, ref, _) {
              return IconButton(
                onPressed: () async {
                  final res = await globalState.showMessage(
                    title: appLocalizations.reset,
                    message: TextSpan(text: appLocalizations.resetTip),
                  );
                  if (res != true) return;
                  await _updateTailscale(ref, (state) => state.reset());
                },
                tooltip: appLocalizations.reset,
                icon: const Icon(Icons.replay),
              );
            },
          ),
        ],
        body: Consumer(
          builder: (_, ref, _) {
            final dnsServer = ref.watch(
              networkSettingProvider.select(
                (state) => state.tailscale.dnsServer,
              ),
            );
            return generateListView([
              _listEntry(
                title: appLocalizations.tailscaleRouteExclude,
                subtitle: appLocalizations.tailscaleRouteExcludeDesc,
                select: (state) => state.routeExcludeAddress,
                update: (state, items) =>
                    state.copyWith(routeExcludeAddress: items),
              ),
              _listEntry(
                title: appLocalizations.tailscaleDnsDomains,
                subtitle: appLocalizations.tailscaleDnsDomainsDesc,
                select: (state) => state.dnsDomains,
                update: (state, items) => state.copyWith(dnsDomains: items),
              ),
              ListItem.input(
                title: Text(appLocalizations.tailscaleDnsServer),
                subtitle: Text(
                  dnsServer.isEmpty
                      ? appLocalizations.tailscaleDnsServerDesc
                      : dnsServer,
                ),
                delegate: InputDelegate(
                  title: appLocalizations.tailscaleDnsServer,
                  value: dnsServer,
                  resetValue: defaultTailscaleDnsServer,
                  hintText: defaultTailscaleDnsServer,
                  onChanged: (value) {
                    if (value == null) return;
                    _updateTailscale(
                      ref,
                      (state) => state.copyWith(dnsServer: value.trim()),
                    );
                  },
                ),
              ),
              _listEntry(
                title: appLocalizations.tailscaleBypassDomain,
                subtitle: appLocalizations.tailscaleBypassDomainDesc,
                select: (state) => state.bypassDomain,
                update: (state, items) => state.copyWith(bypassDomain: items),
              ),
            ]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final enable = ref.watch(
      networkSettingProvider.select((state) => state.tailscale.enable),
    );
    return ListItem.switchItem(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(appLocalizations.tailscaleCoexist),
          Tooltip(
            message: appLocalizations.edit,
            child: Material(
              color: Colors.transparent,
              child: InkResponse(
                radius: 16,
                highlightShape: BoxShape.circle,
                onTap: () => _showEditPage(context),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(appLocalizations.tailscaleCoexistDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) =>
            _updateTailscale(ref, (state) => state.copyWith(enable: value)),
      ),
    );
  }
}

class NetworkListView extends ConsumerWidget {
  const NetworkListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpnSystemProxy =
        system.isAndroid &&
        ref.watch(vpnSettingProvider.select((state) => state.systemProxy));
    final isMipsStack = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.tun.stack == TunStack.mips,
      ),
    );
    final networkItems = [
      if (system.isAndroid) ...generateSection(items: const [VPNItem()]),
      if (system.isAndroid)
        ...generateSection(
          title: 'VPN',
          items: [
            const AllowBypassItem(),
            const VpnSystemProxyItem(),
            if (vpnSystemProxy) const BypassDomainItem(),
          ],
        ),
      if (system.isDesktop)
        ...generateSection(
          title: appLocalizations.system,
          items: const [SystemProxyItem(), BypassDomainItem()],
        ),
      ...generateSection(
        title: appLocalizations.options,
        items: [
          if (system.isDesktop) const TUNItem(),
          if (system.isLinux) const AutoSetSystemDnsItem(),
          if (!system.isAndroid) const StrictRouteItem(),
          const IcmpForwardingItem(),
          const DnsHijackItem(),
          const EndpointIndependentNatItem(),
          const TunStackItem(),
          if (isMipsStack) const TunCongestionControllerItem(),
          const MtuItem(),
          const BypassPrivateRouteItem(),
          if (system.isDesktop) const TailscaleItem(),
        ],
      ),
    ];
    return generateListView(networkItems);
  }
}
