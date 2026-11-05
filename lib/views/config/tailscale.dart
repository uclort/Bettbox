import 'dart:async';
import 'package:flutter/services.dart';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// BETTBOX-CUSTOM: Tailscale 接入（App 共存 / 内置节点）。DNS、前置规则与节点需要重建配置，网段与系统代理例外会随状态热更新。
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

Widget _tailscaleListEntry({
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

/// 两种方式共用的 Tailnet 网段与域名。
List<Widget> _tailnetSharedEntries() => [
  _tailscaleListEntry(
    title: appLocalizations.tailscaleRouteExclude,
    subtitle: appLocalizations.tailscaleRouteExcludeDesc,
    select: (state) => state.routeExcludeAddress,
    update: (state, items) => state.copyWith(routeExcludeAddress: items),
  ),
  _tailscaleListEntry(
    title: appLocalizations.tailscaleDnsDomains,
    subtitle: appLocalizations.tailscaleDnsDomainsDesc,
    select: (state) => state.dnsDomains,
    update: (state, items) => state.copyWith(dnsDomains: items),
  ),
];

Widget _tailscaleResetAction() {
  return Consumer(
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
  );
}

Widget _tailscaleSwitchTitle(
  BuildContext context,
  String title,
  VoidCallback onEdit,
) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: Text(title)),
      Tooltip(
        message: appLocalizations.edit,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            radius: 16,
            highlightShape: BoxShape.circle,
            onTap: onEdit,
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
  );
}

class TailscaleItem extends ConsumerWidget {
  const TailscaleItem({super.key});

  void _showEditPage(BuildContext context) {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.tailscaleCoexist,
        actions: [_tailscaleResetAction()],
        body: Consumer(
          builder: (_, ref, _) {
            final dnsServer = ref.watch(
              networkSettingProvider.select(
                (state) => state.tailscale.dnsServer,
              ),
            );
            return generateListView([
              ..._tailnetSharedEntries(),
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
              _tailscaleListEntry(
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
    final (:enable, :nodeEnable) = ref.watch(
      networkSettingProvider.select(
        (state) => (
          enable: state.tailscale.enable,
          nodeEnable: state.tailscale.nodeEnable,
        ),
      ),
    );
    return ListItem.switchItem(
      title: _tailscaleSwitchTitle(
        context,
        appLocalizations.tailscaleCoexist,
        () => _showEditPage(context),
      ),
      subtitle: Text(
        enable && nodeEnable
            ? appLocalizations.tailscaleNodeOverride
            : appLocalizations.tailscaleCoexistDesc,
      ),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) =>
            _updateTailscale(ref, (state) => state.copyWith(enable: value)),
      ),
    );
  }
}

class TailscaleNodeItem extends ConsumerWidget {
  const TailscaleNodeItem({super.key});

  void _showEditPage(BuildContext context) {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.tailscaleNode,
        actions: [_tailscaleResetAction()],
        body: const _TailscaleNodeSettings(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final enable = ref.watch(
      networkSettingProvider.select((state) => state.tailscale.nodeEnable),
    );
    return ListItem.switchItem(
      title: _tailscaleSwitchTitle(
        context,
        appLocalizations.tailscaleNode,
        () => _showEditPage(context),
      ),
      subtitle: Text(appLocalizations.tailscaleNodeDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) =>
            _updateTailscale(ref, (state) => state.copyWith(nodeEnable: value)),
      ),
    );
  }
}

class _TailscaleNodeSettings extends ConsumerStatefulWidget {
  const _TailscaleNodeSettings();

  @override
  ConsumerState<_TailscaleNodeSettings> createState() =>
      _TailscaleNodeSettingsState();
}

class _TailscaleNodeSettingsState
    extends ConsumerState<_TailscaleNodeSettings> {
  TailscaleNodeStatus? _status;
  // BETTBOX-CUSTOM: 代理通道节点状态（只在 proxyNodeActive 时查询）。
  TailscaleNodeStatus? _proxyStatus;
  bool _loading = false;
  Timer? _loginPoll;
  Timer? _autoRefresh;
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    if (ref.read(networkSettingProvider).tailscale.nodeEnable) {
      _refresh();
      // 页面打开期间定时刷新设备在线状态。
      _autoRefresh = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_status?.running == true) _refresh(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _loginPoll?.cancel();
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_loading) return;
    if (!silent) setState(() => _loading = true);
    _loading = true;
    final status = await clashCore.getTailscaleStatus();
    final props = ref.read(networkSettingProvider).tailscale;
    final proxyStatus = props.proxyNodeActive
        ? await clashCore.getTailscaleStatus(tailscaleProxyNodeName)
        : null;
    if (!mounted) return;
    setState(() {
      _status = status;
      _proxyStatus = proxyStatus;
      _loading = false;
    });
    // 经代理连接的设备 IP 变化时按 DNS 名更新规则。
    if (status.running) {
      final synced = ref
          .read(networkSettingProvider)
          .tailscale
          .syncProxyPeers(status.peers);
      if (synced != null) _updateTailscale(ref, (_) => synced);
    }
    if (status.running && (proxyStatus == null || proxyStatus.running)) {
      _loginPoll?.cancel();
    }
  }

  Future<void> _setProxyPeer(TailscalePeer peer, bool value) async {
    await _updateTailscale(ref, (state) => state.toggleProxyPeer(peer, value));
    if (value) _startPoll();
  }

  Future<void> _removeProxyDevice(TailscaleProxyDevice device) async {
    await _updateTailscale(
      ref,
      (state) => state.copyWith(
        nodeProxyDevices: [
          for (final d in state.proxyDevices)
            if (!d.matches(device)) d.encoded,
        ],
      ),
    );
  }

  Future<void> _addProxyDevice(String raw) async {
    final device = TailscaleProxyDevice.parse(raw);
    if (device.isEmpty) return;
    await _updateTailscale(
      ref,
      (state) => state.copyWith(
        nodeProxyDevices: [
          for (final d in state.proxyDevices)
            if (!d.matches(device)) d.encoded,
          device.encoded,
        ],
      ),
    );
    _startPoll();
  }

  Future<void> _changeProxyVia(String value) async {
    await _updateTailscale(ref, (state) => state.copyWith(nodeProxyVia: value));
    if (!mounted) return;
    setState(() => _proxyStatus = null);
    _startPoll();
  }

  Future<void> _login(String url) async {
    await globalState.openUrl(url);
    _startPoll();
  }

  /// 等待登录、注册或切换方式完成：每 3 秒刷新状态，最多约 3 分钟，连上即停。
  void _startPoll() {
    _loginPoll?.cancel();
    _pollCount = 0;
    _loginPoll = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || ++_pollCount > 60) {
        timer.cancel();
        return;
      }
      _refresh(silent: true);
    });
  }

  /// 当前身份有效（在线、正在连接或等待管理员批准）时，切换或换 key 需要先确认。
  /// 还没拿到状态时按有效处理，宁可多问一次。
  bool _identityValid(TailscaleProps props) {
    if (!props.nodeActive) return false;
    final status = _status;
    if (status == null) return true;
    return status.running ||
        status.state == 'Starting' ||
        status.state == 'NeedsMachineAuth';
  }

  Future<bool> _confirm(String title, String tip, TailscaleProps props) async {
    if (!_identityValid(props)) return true;
    final res = await globalState.showMessage(
      title: title,
      message: TextSpan(text: tip),
    );
    return res == true;
  }

  Future<void> _applyNodeChange(
    TailscaleProps Function(TailscaleProps state) builder,
  ) async {
    await _updateTailscale(ref, builder);
    if (!mounted) return;
    setState(() => _status = null);
    _startPoll();
  }

  Future<void> _switchAuthMode(bool useAuthKey, TailscaleProps props) async {
    if (useAuthKey == props.nodeUseAuthKey) return;
    final ok = await _confirm(
      appLocalizations.tailscaleNodeAuthMode,
      appLocalizations.tailscaleNodeSwitchModeTip,
      props,
    );
    if (!ok) return;
    await _applyNodeChange(
      (state) => state.copyWith(nodeUseAuthKey: useAuthKey),
    );
  }

  Future<void> _changeAuthKey(String value, TailscaleProps props) async {
    if (value == props.nodeAuthKey.trim()) return;
    final ok = await _confirm(
      appLocalizations.tailscaleNodeAuthKey,
      appLocalizations.tailscaleNodeAuthKeyChangeTip,
      props,
    );
    if (!ok) return;
    await _applyNodeChange((state) => state.copyWith(nodeAuthKey: value));
  }

  /// Auth Key 方式：退出当前身份后内核会用当前 key 重新注册。
  Future<void> _reRegister(
    TailscaleProps props, [
    String name = tailscaleNodeName,
  ]) async {
    final ok = await _confirm(
      appLocalizations.tailscaleNodeReRegister,
      appLocalizations.tailscaleNodeReRegisterTip,
      props,
    );
    if (!ok) return;
    final error = await clashCore.tailscaleLogout(name);
    if (error.isNotEmpty) globalState.showNotifier(error);
    if (!mounted) return;
    setState(() {
      if (name == tailscaleNodeName) {
        _status = null;
      } else {
        _proxyStatus = null;
      }
    });
    _startPoll();
  }

  Future<void> _logout([String name = tailscaleNodeName]) async {
    final res = await globalState.showMessage(
      title: appLocalizations.tailscaleNodeLogout,
      message: TextSpan(text: appLocalizations.tailscaleNodeLogoutTip),
    );
    if (res != true) return;
    final error = await clashCore.tailscaleLogout(name);
    if (error.isNotEmpty) globalState.showNotifier(error);
    await _refresh();
  }

  /// 登录 / 退出登录 / 重新注册按钮，主节点与代理通道节点共用。
  List<Widget> _nodeActions(
    TailscaleProps props,
    TailscaleNodeStatus? status,
    String name,
  ) => [
    if (!props.nodeUseAuthKey && status != null && status.needsLogin)
      ListItem(
        leading: const Icon(Icons.login),
        title: Text(appLocalizations.tailscaleNodeLogin),
        onTap: () => _login(status.authUrl),
      ),
    if (!props.nodeUseAuthKey && status != null && status.running)
      ListItem(
        leading: const Icon(Icons.logout),
        title: Text(appLocalizations.tailscaleNodeLogout),
        onTap: () => _logout(name),
      ),
    if (props.nodeActive &&
        props.nodeUseAuthKey &&
        status != null &&
        (status.running || status.state == 'NeedsLogin'))
      ListItem(
        leading: const Icon(Icons.autorenew),
        title: Text(appLocalizations.tailscaleNodeReRegister),
        subtitle: Text(appLocalizations.tailscaleNodeReRegisterTip),
        onTap: () => _reRegister(props, name),
      ),
  ];

  List<Widget> _proxyChannelSection(TailscaleProps props) {
    final devices = props.proxyDevices;
    final groups = ref
        .watch(groupsProvider)
        .map((group) => group.name)
        .where(
          (name) =>
              name != GroupName.GLOBAL.name &&
              name != tailscaleNodeName &&
              name != tailscaleProxyNodeName,
        )
        .toList();
    final via = props.nodeProxyVia.trim();
    final options = [if (via.isNotEmpty && !groups.contains(via)) via, ...groups];
    final proxyStatus = _proxyStatus;
    return [
      ListHeader(title: appLocalizations.tailscaleProxyChannel),
      ListItem(
        title: Text(appLocalizations.tailscaleProxyChannel),
        subtitle: Text(appLocalizations.tailscaleProxyChannelDesc),
      ),
      ListItem.options(
        title: Text(appLocalizations.tailscaleProxyVia),
        subtitle: Text(
          via.isEmpty ? appLocalizations.tailscaleProxyViaMissing : via,
        ),
        delegate: OptionsDelegate<String>(
          title: appLocalizations.tailscaleProxyVia,
          value: via,
          options: options,
          textBuilder: (value) => value,
          onChanged: (value) {
            if (value == null || value == via) return;
            _changeProxyVia(value);
          },
        ),
      ),
      if (devices.isNotEmpty) ...[
        _TailscaleNodeStatusPanel(
          status: proxyStatus,
          loading: _loading,
          onRefresh: _refresh,
          statusText: props.proxyViaMissing
              ? appLocalizations.tailscaleProxyViaMissing
              : _statusText(props, proxyStatus),
        ),
        if (props.proxyNodeActive)
          ..._nodeActions(props, proxyStatus, tailscaleProxyNodeName),
      ],
      ListItem.input(
        leading: const Icon(Icons.add),
        title: Text(appLocalizations.tailscaleProxyAddDevice),
        subtitle: Text(appLocalizations.tailscaleProxyAddDeviceDesc),
        delegate: InputDelegate(
          title: appLocalizations.tailscaleProxyAddDevice,
          value: '',
          hintText: 'rex.tailxxxx.ts.net, 100.x.y.z',
          onChanged: (value) {
            if (value == null) return;
            _addProxyDevice(value);
          },
        ),
      ),
      if (devices.isNotEmpty) ...[
        ListHeader(
          title: '${appLocalizations.tailscaleProxyDevices} (${devices.length})',
        ),
        for (final device in devices)
          ListItem(
            leading: const Icon(Icons.vpn_lock_outlined, size: 20),
            title: Text(device.displayName),
            subtitle: Text(
              [
                if (device.dnsName.isNotEmpty) device.dnsName,
                ...device.ips,
              ].join(' · '),
            ),
            trailing: IconButton(
              tooltip: appLocalizations.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeProxyDevice(device),
            ),
          ),
      ],
    ];
  }

  String _statusText(TailscaleProps props, TailscaleNodeStatus? status) {
    if (props.nodeAuthKeyMissing) {
      return appLocalizations.tailscaleNodeAuthKeyRequired;
    }
    if (status == null) return appLocalizations.tailscaleNodeStarting;
    // BETTBOX-CUSTOM: 设备名、IP、账号由状态面板分行显示，这里只给状态词。
    if (status.running) return appLocalizations.tailscaleNodeRunning;
    if (status.state == 'NeedsLogin') {
      if (props.nodeUseAuthKey) {
        return [
          appLocalizations.tailscaleNodeAuthKeyFailed,
          if (status.error.isNotEmpty) status.error,
        ].join('\n');
      }
      return appLocalizations.tailscaleNodeNeedsLogin;
    }
    final error = status.error;
    if (error.contains('not found') || error.contains('not initialized')) {
      return appLocalizations.tailscaleNodeNotLoaded;
    }
    if (error.isNotEmpty) return error;
    return '${appLocalizations.tailscaleNodeStarting} (${status.state})';
  }

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(
      networkSettingProvider.select((state) => state.tailscale),
    );
    final status = _status;
    return generateListView([
      if (props.nodeEnable) ...[
        _TailscaleNodeStatusPanel(
          status: status,
          loading: _loading,
          onRefresh: _refresh,
          statusText: _statusText(props, status),
        ),
        ..._nodeActions(props, status, tailscaleNodeName),
      ],
      ListItem.options(
        title: Text(appLocalizations.tailscaleNodeAuthMode),
        subtitle: Text(
          '${props.nodeUseAuthKey ? appLocalizations.tailscaleNodeAuthModeAuthKey : appLocalizations.tailscaleNodeAuthModeLogin}\n${appLocalizations.tailscaleNodeAuthModeDesc}',
        ),
        delegate: OptionsDelegate<bool>(
          title: appLocalizations.tailscaleNodeAuthMode,
          value: props.nodeUseAuthKey,
          options: const [false, true],
          textBuilder: (value) => value
              ? appLocalizations.tailscaleNodeAuthModeAuthKey
              : appLocalizations.tailscaleNodeAuthModeLogin,
          onChanged: (value) {
            if (value == null) return;
            _switchAuthMode(value, props);
          },
        ),
      ),
      ListItem.input(
        title: Text(appLocalizations.tailscaleNodeHostname),
        subtitle: Text(
          props.nodeHostname.isEmpty
              ? '${appLocalizations.tailscaleNodeHostnameDesc}: ${props.effectiveNodeHostname}'
              : props.effectiveNodeHostname,
        ),
        delegate: InputDelegate(
          title: appLocalizations.tailscaleNodeHostname,
          value: props.nodeHostname,
          resetValue: '',
          hintText: props.effectiveNodeHostname,
          onChanged: (value) {
            if (value == null) return;
            _updateTailscale(
              ref,
              (state) => state.copyWith(nodeHostname: value.trim()),
            );
          },
        ),
      ),
      if (props.nodeUseAuthKey)
        ListItem.input(
          title: Text(appLocalizations.tailscaleNodeAuthKey),
          subtitle: Text(
            props.nodeAuthKey.isEmpty
                ? appLocalizations.tailscaleNodeAuthKeyDesc
                : '${props.nodeAuthKey.length > 12 ? props.nodeAuthKey.substring(0, 12) : props.nodeAuthKey}••••\n${appLocalizations.tailscaleNodeAuthKeyDesc}',
          ),
          delegate: InputDelegate(
            title: appLocalizations.tailscaleNodeAuthKey,
            value: props.nodeAuthKey,
            resetValue: '',
            hintText: 'tskey-auth-…',
            onChanged: (value) {
              if (value == null) return;
              _changeAuthKey(value.trim(), props);
            },
          ),
        ),
      ListItem.input(
        title: Text(appLocalizations.tailscaleNodeExitNode),
        subtitle: Text(
          props.nodeExitNode.isEmpty
              ? appLocalizations.tailscaleNodeExitNodeDesc
              : props.nodeExitNode,
        ),
        delegate: InputDelegate(
          title: appLocalizations.tailscaleNodeExitNode,
          value: props.nodeExitNode,
          resetValue: '',
          onChanged: (value) {
            if (value == null) return;
            _updateTailscale(
              ref,
              (state) => state.copyWith(nodeExitNode: value.trim()),
            );
          },
        ),
      ),
      ListItem.switchItem(
        title: Text(appLocalizations.tailscaleNodeAcceptRoutes),
        subtitle: Text(appLocalizations.tailscaleNodeAcceptRoutesDesc),
        delegate: SwitchDelegate(
          value: props.nodeAcceptRoutes,
          onChanged: (value) => _updateTailscale(
            ref,
            (state) => state.copyWith(nodeAcceptRoutes: value),
          ),
        ),
      ),
      ..._tailnetSharedEntries(),
      ListItem(
        title: Text(appLocalizations.tailscaleNodeConflicts),
        subtitle: Text(appLocalizations.tailscaleNodeConflictsDesc),
      ),
      if (props.nodeEnable) ..._proxyChannelSection(props),
      if (props.nodeEnable && status != null && status.peers.isNotEmpty) ...[
        ListHeader(
          title:
              '${appLocalizations.tailscaleNodeDevices} (${status.peers.where((peer) => peer.online).length}/${status.peers.length})',
        ),
        for (final peer in status.peers)
          _TailscalePeerItem(
            peer: peer,
            viaProxy: props.isProxyPeer(peer),
            onViaProxyChanged: peer.dnsName.isEmpty && peer.ips.isEmpty
                ? null
                : (value) => _setProxyPeer(peer, value),
          ),
      ],
    ]);
  }
}

// BETTBOX-CUSTOM: 内置节点状态面板。Rex 等内嵌 Tailscale 或依赖系统网络访问
// Tailnet 的应用都经过这个节点，节点重连时它们会暂时解析不到主机；面板把状态、
// 节点名、IP、在线设备数放在一起，方便判断问题出在节点还是对端。
class _TailscaleNodeStatusPanel extends StatelessWidget {
  final TailscaleNodeStatus? status;
  final bool loading;
  final VoidCallback onRefresh;
  final String statusText;

  const _TailscaleNodeStatusPanel({
    required this.status,
    required this.loading,
    required this.onRefresh,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final running = status?.running == true;
    final needsLogin = status?.needsLogin == true;
    final indicatorColor = running
        ? Colors.green
        : needsLogin
        ? Colors.orange
        : colorScheme.error;
    final info = <(String, String)>[
      if (status != null && status!.dnsName.isNotEmpty)
        (appLocalizations.tailscaleNodeHostname, status!.dnsName),
      if (status != null && status!.ips.isNotEmpty)
        ('IP', status!.ips.join(', ')),
      if (status != null && status!.loginName.isNotEmpty)
        (appLocalizations.account, status!.loginName),
      if (status != null && status!.peers.isNotEmpty)
        (
          appLocalizations.tailscaleNodeDevices,
          '${status!.peers.where((peer) => peer.online).length}/${status!.peers.length} ${appLocalizations.tailscaleNodeOnline}',
        ),
    ];
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurface,
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: indicatorColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: onRefresh,
                  tooltip: appLocalizations.update,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
            ],
          ),
          for (final (label, value) in info)
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 6, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(label, style: labelStyle),
                  ),
                  Expanded(child: Text(value, style: valueStyle)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 6, top: 8),
            child: Text(
              appLocalizations.tailscaleNodePanelHint,
              style: labelStyle?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TailscalePeerItem extends StatelessWidget {
  const _TailscalePeerItem({
    required this.peer,
    this.viaProxy = false,
    this.onViaProxyChanged,
  });

  final TailscalePeer peer;
  // BETTBOX-CUSTOM: 该设备是否经代理通道连接。
  final bool viaProxy;
  final ValueChanged<bool>? onViaProxyChanged;

  String get _subtitle {
    return [
      if (viaProxy) appLocalizations.tailscaleProxyPeer,
      peer.online
          ? appLocalizations.tailscaleNodeOnline
          : appLocalizations.tailscaleNodeOffline,
      if (peer.exitNode) appLocalizations.tailscaleNodeExitNode,
      if (peer.ips.isNotEmpty) peer.ips.first,
      if (peer.os.isNotEmpty) peer.os,
      if (peer.online && peer.active)
        peer.curAddr.isNotEmpty
            ? '${appLocalizations.tailscaleNodeDirect} ${peer.curAddr}'
            : peer.relay.isNotEmpty
            ? '${appLocalizations.tailscaleNodeRelay} ${peer.relay}'
            : null,
    ].whereType<String>().join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: Icon(
        Icons.circle,
        size: 10,
        color: peer.online ? Colors.green : colorScheme.outline,
      ),
      title: Text(peer.displayName),
      subtitle: Text(_subtitle),
      trailing: onViaProxyChanged == null
          ? null
          : Tooltip(
              message: appLocalizations.tailscaleProxyPeer,
              child: Switch(value: viaProxy, onChanged: onViaProxyChanged),
            ),
      onTap: peer.ips.isEmpty
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: peer.ips.first));
              globalState.showNotifier(appLocalizations.copySuccess);
            },
    );
  }
}

class TailscaleGuideItem extends StatelessWidget {
  const TailscaleGuideItem({super.key});

  @override
  Widget build(BuildContext context) {
    // 移动端只有内置节点（系统只允许一个 VPN，无法与 Tailscale App 共存），说明随平台切换。
    final isDesktop = system.isDesktop;
    return ListItem.next(
      title: Text(appLocalizations.tailscaleGuide),
      subtitle: Text(
        isDesktop
            ? appLocalizations.tailscaleGuideDesc
            : appLocalizations.tailscaleGuideMobileDesc,
      ),
      delegate: NextDelegate(
        blur: false,
        title: appLocalizations.tailscaleGuide,
        widget: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            isDesktop
                ? appLocalizations.tailscaleGuideContent
                : appLocalizations.tailscaleGuideMobileContent,
            style: context.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ),
      ),
    );
  }
}


// BETTBOX-CUSTOM: Tailscale 独立页面，入口在「内核配置 → Tailscale」
// （App 共存仅桌面端；内置节点全平台）。
class TailscaleListView extends StatelessWidget {
  const TailscaleListView({super.key});

  @override
  Widget build(BuildContext context) {
    return generateListView(
      generateSection(
        items: [
          if (system.isDesktop) const TailscaleItem(),
          const TailscaleNodeItem(),
          const TailscaleGuideItem(),
        ],
      ),
    );
  }
}
