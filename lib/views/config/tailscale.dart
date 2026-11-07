import 'dart:async';
import 'package:flutter/services.dart';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
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
        // BETTBOX-CUSTOM: 关闭时先把迁移出的策略组写回，再标记已迁移；全新安装开启时列表为空，
        // 不会凭空出现 Bettbox-Tailscale（配置文件里有节点就显示配置文件里的）。
        onChanged: (value) => _updateTailscale(
          ref,
          (state) => state.copyWith(
            nodeEnable: value,
            groups: value ? state.groups : state.nodeGroups,
            groupsVersion: 1,
          ),
        ),
      ),
    );
  }
}

// BETTBOX-CUSTOM: 预读取全部配置文件（含覆写脚本结果），找出自定义的 Tailscale 节点。
Future<List<TailscaleProfileScan>> _scanTailscaleProfiles() async {
  final config = globalState.config;
  final scans = <TailscaleProfileScan>[];
  for (final profile in config.profiles) {
    try {
      final raw = await globalState.getProfileConfig(
        profile.id,
        effective: true,
      );
      scans.add(
        TailscaleProfileScan.fromConfig(
          profileId: profile.id,
          label: profile.label ?? profile.id,
          current: profile.id == config.currentProfileId,
          config: raw,
        ),
      );
    } catch (_) {}
  }
  return scans;
}

/// 配置文件里的节点在列表中的条目：已保存的覆写设置，或按配置文件参数生成的只读组。
class _TailscaleGroupEntry {
  const _TailscaleGroupEntry(this.group, [this.node]);

  final TailscaleGroup group;

  /// 当前配置文件中的同名节点（不在当前配置文件中时为 null）。
  final TailscaleProfileNode? node;
}

List<_TailscaleGroupEntry> _groupEntries(
  TailscaleProps props,
  List<TailscaleProfileNode> profileNodes,
) {
  final stored = {
    for (final g in props.nodeGroups)
      if (g.profile) g.name: g,
  };
  return [
    for (final g in props.nodeGroups)
      if (!g.profile) _TailscaleGroupEntry(g),
    for (final node in profileNodes)
      _TailscaleGroupEntry(
        stored[node.name] ?? node.toGroup().copyWith(overridden: false),
        node,
      ),
    for (final g in stored.values)
      if (!profileNodes.any((n) => n.name == g.name)) _TailscaleGroupEntry(g),
  ];
}

String _tailscaleStatusText(
  TailscaleProps props,
  TailscaleGroup group,
  TailscaleNodeStatus? status,
) {
  if (group.managed && props.groupAuthKeyMissing(group)) {
    return appLocalizations.tailscaleNodeAuthKeyRequired;
  }
  if (status == null) return appLocalizations.tailscaleNodeStarting;
  // BETTBOX-CUSTOM: 设备名、IP、账号由状态面板分行显示，这里只给状态词。
  if (status.running) return appLocalizations.tailscaleNodeRunning;
  if (status.state == 'NeedsLogin') {
    if (group.useAuthKey) {
      // BETTBOX-CUSTOM: 只有控制面明确拒绝 key 时才提示换 key；连不上控制面 / DERP 等网络原因
      // 不是 key 的问题，提示「注册未完成」并给出真实错误（会自动重试）。
      final keyRejected = RegExp(
        r'invalid key|key.*(expired|not valid|invalid)|unauthorized|not authorized|authkey',
        caseSensitive: false,
      ).hasMatch(status.error);
      return [
        keyRejected
            ? appLocalizations.tailscaleNodeAuthKeyFailed
            : appLocalizations.tailscaleNodeAuthKeyPending,
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

Widget _statusDot(BuildContext context, TailscaleNodeStatus? status) {
  final color = status == null
      ? context.colorScheme.outline
      : status.running
      ? Colors.green
      : status.needsLogin
      ? Colors.orange
      : context.colorScheme.error;
  return Icon(Icons.circle, size: 10, color: color);
}

/// 设备的唯一标识：MagicDNS 名，没有时用 IP。
String tailscalePeerKey(TailscalePeer peer) {
  final dns = normalizeTailscaleDomain(peer.dnsName);
  return dns.isNotEmpty ? dns : peer.ips.join(',');
}

// BETTBOX-CUSTOM: 节点状态查询、登录轮询与登录 / 退出 / 重新注册，策略组列表页与详情页共用。
mixin _TailscaleStatusMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  final Map<String, TailscaleNodeStatus> statuses = {};
  bool statusLoading = false;
  Timer? _statusPoll;
  Timer? _statusAuto;
  int _statusPollCount = 0;

  /// 需要查询状态的节点名。
  List<String> get statusNames;

  void onStatusesUpdated() {}

  /// Tailnet 全部设备：合并各已连接节点看到的设备，并补上 Bettbox 节点自身
  /// （节点的设备列表不含它自己，只取一个节点时会漏掉本组自己的设备）。在线优先，同状态按名称排序。
  List<TailscalePeer> allPeers() {
    final byKey = <String, TailscalePeer>{};
    for (final status in statuses.values.where((s) => s.running)) {
      for (final peer in status.peers) {
        final key = tailscalePeerKey(peer);
        if (key.isNotEmpty) byKey.putIfAbsent(key, () => peer);
      }
    }
    for (final self in selfPeers().values) {
      byKey.putIfAbsent(tailscalePeerKey(self), () => self);
    }
    final peers = byKey.values.toList()
      ..sort((a, b) {
        if (a.online != b.online) return a.online ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });
    return peers;
  }

  /// 本机 Bettbox 节点自身（策略组名 → 设备）。
  Map<String, TailscalePeer> selfPeers() => {
    for (final MapEntry(key: name, value: status) in statuses.entries)
      if (status.running && (status.dnsName.isNotEmpty || status.ips.isNotEmpty))
        name: TailscalePeer(
          dnsName: status.dnsName,
          ips: status.ips,
          online: true,
          os: system.isMacOS ? 'macOS' : '',
        ),
  };

  /// 设备是本机哪个 Bettbox 策略组的节点，不是时为 null。
  String? selfGroupOf(TailscalePeer peer, Map<String, TailscalePeer> selfs) {
    final key = tailscalePeerKey(peer);
    for (final MapEntry(key: name, value: self) in selfs.entries) {
      if (tailscalePeerKey(self) == key) return name;
    }
    return null;
  }

  void startAutoRefresh() {
    _statusAuto?.cancel();
    // 页面打开期间定时刷新设备在线状态。
    _statusAuto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (statuses.values.any((s) => s.running)) refreshStatus(silent: true);
    });
  }

  void disposeStatus() {
    _statusPoll?.cancel();
    _statusAuto?.cancel();
  }

  Future<void> refreshStatus({bool silent = false}) async {
    if (statusLoading) return;
    statusLoading = true;
    if (!silent && mounted) setState(() {});
    final names = List.of(statusNames);
    // BETTBOX-CUSTOM: 各节点并行查询、到一个显示一个；连不上控制面的节点要等满超时（约 30 秒），
    // 逐个等待会让已连上节点的状态和设备列表一直出不来。
    final result = <String, TailscaleNodeStatus>{};
    await Future.wait(
      names.map((name) async {
        final status = await clashCore.getTailscaleStatus(name);
        result[name] = status;
        if (mounted) setState(() => statuses[name] = status);
      }),
    );
    if (!mounted) return;
    setState(() {
      statuses.removeWhere((name, _) => !result.containsKey(name));
      statusLoading = false;
    });
    onStatusesUpdated();
    if (result.isNotEmpty && result.values.every((s) => s.running)) {
      _statusPoll?.cancel();
    }
  }

  /// 等待登录、注册或切换方式完成：每 3 秒刷新状态，最多约 3 分钟，连上即停。
  void startPoll() {
    _statusPoll?.cancel();
    _statusPollCount = 0;
    _statusPoll = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || ++_statusPollCount > 60) {
        timer.cancel();
        return;
      }
      refreshStatus(silent: true);
    });
  }

  void resetStatus(String name) {
    if (!mounted) return;
    setState(() => statuses.remove(name));
    startPoll();
  }

  /// 当前身份有效（在线、正在连接或等待管理员批准）时，切换或换 key 需要先确认。
  /// 还没拿到状态时按有效处理，宁可多问一次。
  bool identityValid(String name, bool active) {
    if (!active) return false;
    final status = statuses[name];
    if (status == null) return true;
    return status.running ||
        status.state == 'Starting' ||
        status.state == 'NeedsMachineAuth';
  }

  Future<bool> confirmChange(
    String name,
    bool active,
    String title,
    String tip,
  ) async {
    if (!identityValid(name, active)) return true;
    final res = await globalState.showMessage(
      title: title,
      message: TextSpan(text: tip),
    );
    return res == true;
  }

  Future<void> _login(String url) async {
    await globalState.openUrl(url);
    startPoll();
  }

  Future<void> _logout(String name) async {
    final res = await globalState.showMessage(
      title: appLocalizations.tailscaleNodeLogout,
      message: TextSpan(text: appLocalizations.tailscaleNodeLogoutTip),
    );
    if (res != true) return;
    final error = await clashCore.tailscaleLogout(name);
    if (error.isNotEmpty) globalState.showNotifier(error);
    await refreshStatus();
  }

  /// Auth Key 方式：退出当前身份后内核会用当前 key 重新注册。
  Future<void> _reRegister(String name, bool active) async {
    final ok = await confirmChange(
      name,
      active,
      appLocalizations.tailscaleNodeReRegister,
      appLocalizations.tailscaleNodeReRegisterTip,
    );
    if (!ok) return;
    final error = await clashCore.tailscaleLogout(name);
    if (error.isNotEmpty) globalState.showNotifier(error);
    // BETTBOX-CUSTOM: 内核已标记该实例不再复用，重载配置让它新建实例并用 key 注册
    // （进程内再注册对卡住的实例无效，新建实例才可靠）。
    globalState.appController.setupClashConfigDebounce();
    resetStatus(name);
  }

  /// 登录 / 退出登录 / 重新注册按钮。
  List<Widget> nodeActions({
    required String name,
    required bool useAuthKey,
    required bool active,
  }) {
    final status = statuses[name];
    return [
      if (!useAuthKey && status != null && status.needsLogin)
        ListItem(
          leading: const Icon(Icons.login),
          title: Text(appLocalizations.tailscaleNodeLogin),
          onTap: () => _login(status.authUrl),
        ),
      if (!useAuthKey && status != null && status.running)
        ListItem(
          leading: const Icon(Icons.logout),
          title: Text(appLocalizations.tailscaleNodeLogout),
          onTap: () => _logout(name),
        ),
      if (active &&
          useAuthKey &&
          status != null &&
          (status.running || status.state == 'NeedsLogin'))
        ListItem(
          leading: const Icon(Icons.autorenew),
          title: Text(appLocalizations.tailscaleNodeReRegister),
          subtitle: Text(appLocalizations.tailscaleNodeReRegisterTip),
          onTap: () => _reRegister(name, active),
        ),
    ];
  }
}

class _TailscaleNodeSettings extends ConsumerStatefulWidget {
  const _TailscaleNodeSettings();

  @override
  ConsumerState<_TailscaleNodeSettings> createState() =>
      _TailscaleNodeSettingsState();
}

class _TailscaleNodeSettingsState extends ConsumerState<_TailscaleNodeSettings>
    with _TailscaleStatusMixin<_TailscaleNodeSettings> {
  List<TailscaleProfileScan>? _scans;

  List<TailscaleProfileNode> get _profileNodes =>
      _scans?.where((scan) => scan.current).firstOrNull?.nodes ?? const [];

  @override
  List<String> get statusNames {
    final props = ref.read(networkSettingProvider).tailscale;
    final overridden = {
      for (final g in props.nodeGroups)
        if (g.profile && g.overridden) g.name,
    };
    return {
      for (final g in props.activeGroups) g.name,
      // 未覆写的配置文件节点由配置文件启动，同样可以查询状态和登录。
      for (final node in _profileNodes)
        if (!props.nodeEnable || !overridden.contains(node.name)) node.name,
    }.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadScans();
    if (ref.read(networkSettingProvider).tailscale.nodeEnable) {
      refreshStatus();
      startAutoRefresh();
    }
  }

  Future<void> _loadScans() async {
    final scans = await _scanTailscaleProfiles();
    if (!mounted) return;
    setState(() => _scans = scans);
    if (scans.any((scan) => scan.current && scan.nodes.isNotEmpty)) {
      refreshStatus(silent: true);
    }
  }

  @override
  void dispose() {
    disposeStatus();
    super.dispose();
  }

  @override
  void onStatusesUpdated() {
    // 指定过的设备 IP 变化时按 DNS 名更新规则（合并所有已连接组看到的设备）。
    final props = ref.read(networkSettingProvider).tailscale;
    final peers = allPeers();
    if (peers.isEmpty) return;
    final synced = props.syncProxyPeers(peers);
    if (synced != null) _updateTailscale(ref, (_) => synced);
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return appLocalizations.emptyTip(appLocalizations.name);
    final props = ref.read(networkSettingProvider).tailscale;
    final used = {
      for (final g in props.nodeGroups) g.name,
      for (final node in _profileNodes) node.name,
    };
    if (used.contains(name)) return appLocalizations.tailscaleGroupNameExists;
    return null;
  }

  Future<void> _addGroup(String name) async {
    if (_validateName(name) != null) return;
    await _updateTailscale(ref, (state) {
      final group = state.newGroup(name.trim());
      return state.updateGroup(group.id, group);
    });
    startPoll();
  }

  Future<void> _setOverride(_TailscaleGroupEntry entry, bool value) async {
    await _updateTailscale(ref, (state) {
      final stored = state.groupById(entry.group.id);
      final group = (stored ?? entry.node?.toGroup() ?? entry.group).copyWith(
        overridden: value,
      );
      return state.updateGroup(group.id, group);
    });
    resetStatus(entry.group.name);
  }

  /// 选择设备经哪个组连接；「未指定」交回默认组兜底。
  Future<void> _pickPeerGroup(
    TailscalePeer peer,
    TailscaleGroup? current,
    List<TailscaleGroup> options,
  ) async {
    const unassigned = '\u0000';
    final value = await globalState.showCommonDialog<String>(
      child: OptionsDialog<String>(
        title: appLocalizations.tailscalePeerGroup,
        options: [unassigned, for (final g in options) g.id],
        textBuilder: (id) => id == unassigned
            ? appLocalizations.tailscalePeerUnassigned
            : options.where((g) => g.id == id).firstOrNull?.name ?? id,
        value: current?.id ?? unassigned,
      ),
    );
    if (value == null || value == (current?.id ?? unassigned)) return;
    final target = options.where((g) => g.id == value).firstOrNull;
    await _updateTailscale(
      ref,
      (state) => state.assignPeer(peer, target?.name),
    );
    startPoll();
  }

  Widget _groupTile(TailscaleProps props, _TailscaleGroupEntry entry) {
    final group = entry.group;
    final isDefault = props.isDefaultGroup(group, [
      for (final node in _profileNodes) node.name,
    ]);
    final via = group.via.trim();
    final summary = [
      if (isDefault) appLocalizations.tailscaleGroupDefault,
      if (group.profile) appLocalizations.tailscaleGroupProfile,
      if (group.profile && group.overridden)
        appLocalizations.tailscaleGroupOverride,
      via.isEmpty
          ? appLocalizations.tailscaleGroupDirect
          : '${appLocalizations.tailscaleProxyVia} $via',
      if (group.managed && group.proxyDevices.isNotEmpty)
        '${appLocalizations.tailscaleNodeDevices} ${group.proxyDevices.length}',
      if (group.managed && group.validRules.isNotEmpty)
        '${appLocalizations.tailscaleGroupRules} ${group.validRules.length}',
      if (group.profile && entry.node == null)
        appLocalizations.tailscaleGroupNotInProfile,
    ].join(' · ');
    return ListItem.next(
      leading: _statusDot(context, statuses[group.name]),
      title: Text(group.name),
      subtitle: Text(summary),
      trailing: group.profile
          ? Switch(
              value: group.overridden,
              onChanged: (value) => _setOverride(entry, value),
            )
          : null,
      delegate: NextDelegate(
        blur: false,
        title: group.name,
        widget: _TailscaleGroupPage(
          id: group.id,
          profileNode: entry.node,
          profileNodes: _profileNodes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(
      networkSettingProvider.select((state) => state.tailscale),
    );
    final profileNames = [for (final node in _profileNodes) node.name];
    final defaultName = props.effectiveDefaultName(profileNames);
    final entries = _groupEntries(props, _profileNodes);
    // 只有被 Bettbox 接管的组能指定设备（未覆写的配置文件节点不能写入设备设置）。
    final peerGroups = [
      for (final entry in entries)
        if (entry.group.name == defaultName && entry.group.managed)
          entry.group,
      for (final entry in entries)
        if (entry.group.name != defaultName && entry.group.managed) entry.group,
    ];
    final peers = allPeers();
    final selfs = selfPeers();
    // BETTBOX-CUSTOM: 状态与登录 / 重新注册只在具体策略组页里显示，这里只列策略组（带状态圆点）。
    return generateListView([
      if (_scans != null)
        _TailscaleProfileWarning(props: props, scans: _scans!),
      ListHeader(title: appLocalizations.tailscaleGroups),
      ListItem(
        title: Text(appLocalizations.tailscaleGroupsDesc),
        titleTextStyle: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
      for (final entry in entries) _groupTile(props, entry),
      ListItem.input(
        leading: const Icon(Icons.add),
        title: Text(appLocalizations.tailscaleGroupAdd),
        delegate: InputDelegate(
          title: appLocalizations.tailscaleGroupAdd,
          value: '',
          hintText: 'Tailscale-Proxy',
          validator: _validateName,
          onChanged: (value) {
            if (value == null) return;
            _addGroup(value);
          },
        ),
      ),
      ..._tailnetSharedEntries(),
      ListItem(
        title: Text(appLocalizations.tailscaleNodeConflicts),
        subtitle: Text(appLocalizations.tailscaleNodeConflictsDesc),
      ),
      if (props.nodeEnable && peers.isNotEmpty) ...[
        ListHeader(
          title:
              '${appLocalizations.tailscaleNodeDevices} (${peers.where((peer) => peer.online).length}/${peers.length})',
        ),
        for (final peer in peers)
          () {
            final current = props.assignedGroupOfPeer(peer);
            final selfGroup = selfGroupOf(peer, selfs);
            final assignable =
                selfGroup == null &&
                (peer.dnsName.isNotEmpty || peer.ips.isNotEmpty);
            return _TailscalePeerItem(
              peer: peer,
              groupName: current?.name,
              selfGroup: selfGroup,
              onPickGroup: assignable
                  ? () => _pickPeerGroup(peer, current, peerGroups)
                  : null,
            );
          }(),
      ],
    ]);
  }
}

// BETTBOX-CUSTOM: 单个 Tailscale 策略组的设置。配置文件里的节点未开覆写时只读，只能登录 / 退出。
class _TailscaleGroupPage extends ConsumerStatefulWidget {
  const _TailscaleGroupPage({
    required this.id,
    this.profileNode,
    this.profileNodes = const [],
  });

  final String id;
  final TailscaleProfileNode? profileNode;
  final List<TailscaleProfileNode> profileNodes;

  @override
  ConsumerState<_TailscaleGroupPage> createState() =>
      _TailscaleGroupPageState();
}

class _TailscaleGroupPageState extends ConsumerState<_TailscaleGroupPage>
    with _TailscaleStatusMixin<_TailscaleGroupPage> {
  TailscaleGroup? _groupOf(TailscaleProps props) =>
      props.groupById(widget.id) ??
      widget.profileNode?.toGroup().copyWith(overridden: false);

  @override
  List<String> get statusNames {
    final props = ref.read(networkSettingProvider).tailscale;
    final group = _groupOf(props);
    if (group == null) return const [];
    final running = props.groupActive(group) || widget.profileNode != null;
    return {
      if (running) group.name,
      // 本组未连接时用其他组的设备列表选择设备。
      if (group.managed)
        for (final g in props.activeGroups) g.name,
    }.toList();
  }

  @override
  void initState() {
    super.initState();
    refreshStatus();
    startAutoRefresh();
  }

  @override
  void dispose() {
    disposeStatus();
    super.dispose();
  }

  Future<void> _update(
    TailscaleGroup Function(TailscaleGroup group) builder, {
    bool restart = false,
  }) async {
    final props = ref.read(networkSettingProvider).tailscale;
    final current = _groupOf(props);
    if (current == null) return;
    final updated = builder(current);
    await _updateTailscale(
      ref,
      (state) => state.updateGroup(widget.id, updated),
    );
    if (restart) resetStatus(updated.name);
  }

  String? _validateName(String? value, TailscaleGroup group) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return appLocalizations.emptyTip(appLocalizations.name);
    if (name == group.name) return null;
    final props = ref.read(networkSettingProvider).tailscale;
    final used = {
      for (final g in props.nodeGroups) g.name,
      for (final node in widget.profileNodes) node.name,
    };
    if (used.contains(name)) return appLocalizations.tailscaleGroupNameExists;
    return null;
  }

  Future<void> _switchAuthMode(
    bool useAuthKey,
    TailscaleGroup group,
    bool active,
  ) async {
    if (useAuthKey == group.useAuthKey) return;
    final ok = await confirmChange(
      group.name,
      active,
      appLocalizations.tailscaleNodeAuthMode,
      appLocalizations.tailscaleNodeSwitchModeTip,
    );
    if (!ok) return;
    await _update((g) => g.copyWith(useAuthKey: useAuthKey), restart: true);
  }

  Future<void> _changeAuthKey(
    String value,
    TailscaleGroup group,
    bool active,
  ) async {
    if (value == group.authKey.trim()) return;
    final ok = await confirmChange(
      group.name,
      active,
      appLocalizations.tailscaleNodeAuthKey,
      appLocalizations.tailscaleNodeAuthKeyChangeTip,
    );
    if (!ok) return;
    await _update((g) => g.copyWith(authKey: value), restart: true);
  }

  Future<void> _delete(TailscaleGroup group) async {
    final res = await globalState.showMessage(
      title: appLocalizations.tailscaleGroupDelete,
      message: TextSpan(text: appLocalizations.tailscaleGroupDeleteTip),
    );
    if (res != true) return;
    await _updateTailscale(ref, (state) => state.removeGroup(widget.id));
    if (mounted) Navigator.of(context).maybePop();
  }

  List<Widget> _readonlyItems(TailscaleProfileNode node) {
    final via = node.dialerProxy;
    return [
      ListItem(
        title: Text(appLocalizations.tailscaleGroupProfileReadonly),
        titleTextStyle: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      ListItem(
        title: Text(appLocalizations.tailscaleNodeAuthMode),
        subtitle: Text(
          node.authKey.isNotEmpty
              ? appLocalizations.tailscaleNodeAuthModeAuthKey
              : appLocalizations.tailscaleNodeAuthModeLogin,
        ),
      ),
      if (node.hostname.isNotEmpty)
        ListItem(
          title: Text(appLocalizations.tailscaleNodeHostname),
          subtitle: Text(node.hostname),
        ),
      ListItem(
        title: Text(appLocalizations.tailscaleProxyVia),
        subtitle: Text(
          via.isEmpty ? appLocalizations.tailscaleGroupDirect : via,
        ),
      ),
      if (node.exitNode.isNotEmpty)
        ListItem(
          title: Text(appLocalizations.tailscaleNodeExitNode),
          subtitle: Text(node.exitNode),
        ),
      if (node.stateDir.isNotEmpty)
        ListItem(title: const Text('state-dir'), subtitle: Text(node.stateDir)),
    ];
  }

  /// BETTBOX-CUSTOM: 本组的设备：一份完整的 Tailnet 设备列表（含本机 Bettbox 节点），右侧勾选即由本组接管；
  /// 列表里没有的设备放在底部「自定义设备」子组，可手动添加。
  List<Widget> _deviceItems(TailscaleProps props, TailscaleGroup group) {
    final peers = allPeers();
    final selfs = selfPeers();
    final devices = group.proxyDevices;
    final custom = devices
        .where((d) => !peers.any((peer) => d.matchesPeer(peer)))
        .toList();
    final isDefault = props.isDefaultGroup(group, [
      for (final node in widget.profileNodes) node.name,
    ]);
    final hintStyle = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
      height: 1.5,
    );
    Widget checkIcon(bool checked, {bool enabled = true}) => Icon(
      checked ? Icons.check_circle_rounded : Icons.circle_outlined,
      size: 24,
      color: !enabled
          ? context.colorScheme.outlineVariant
          : checked
          ? context.colorScheme.primary
          : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
    );
    void setChecked(TailscaleProxyDevice device, bool checked) {
      _updateTailscale(
        ref,
        (state) => state.assignDevice(device, checked ? group.name : null),
      );
      if (checked) startPoll();
    }

    return [
      ListHeader(
        title:
            '${appLocalizations.tailscaleGroupDevices} (${devices.length}/${peers.length + custom.length})',
      ),
      ListItem(
        title: Text(
          isDefault
              ? appLocalizations.tailscaleGroupDevicesDefaultDesc
              : appLocalizations.tailscaleGroupDevicesDesc,
        ),
        titleTextStyle: hintStyle,
      ),
      for (final peer in peers)
        () {
          final device = TailscaleProxyDevice.fromPeer(peer);
          final selfGroup = selfGroupOf(peer, selfs);
          final owner = props.assignedGroupOfPeer(peer);
          final checked = owner != null && owner.id == group.id;
          final enabled = selfGroup == null && !device.isEmpty;
          final note = selfGroup != null
              ? '${appLocalizations.tailscalePeerSelfNode} ($selfGroup)'
              : checked
              ? appLocalizations.tailscalePeerChecked
              : owner != null
              ? '${appLocalizations.tailscalePeerOwnedBy}: ${owner.name} · ${appLocalizations.tailscalePeerMoveHint}'
              : appLocalizations.tailscalePeerFallback;
          return ListItem(
            leading: Icon(
              Icons.circle,
              size: 10,
              color: peer.online ? Colors.green : context.colorScheme.outline,
            ),
            title: Text(
              peer.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                [
                  if (peer.ips.isNotEmpty) peer.ips.first,
                  if (peer.os.isNotEmpty) peer.os,
                ].join(' · '),
                note,
              ].where((e) => e.isNotEmpty).join('\n'),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: checkIcon(checked, enabled: enabled),
            ),
            onTap: enabled ? () => setChecked(device, !checked) : null,
          );
        }(),
      ListHeader(
        title:
            '${appLocalizations.tailscaleGroupCustomDevices} (${custom.length})',
      ),
      ListItem(
        title: Text(appLocalizations.tailscaleGroupCustomDevicesDesc),
        titleTextStyle: hintStyle,
      ),
      for (final device in custom)
        ListItem(
          leading: const Icon(Icons.edit_note, size: 20),
          title: Text(
            device.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (device.dnsName.isNotEmpty) device.dnsName,
              ...device.ips,
            ].join(' · '),
          ),
          trailing: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: checkIcon(true),
          ),
          onTap: () => setChecked(device, false),
        ),
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
            final device = TailscaleProxyDevice.parse(value);
            if (device.isEmpty) return;
            _updateTailscale(
              ref,
              (state) => state.assignDevice(device, group.name),
            );
            startPoll();
          },
        ),
      ),
    ];
  }

  Widget _rulesEntry(TailscaleGroup group) {
    final valid = group.validRules.length;
    return ListItem.next(
      leading: const Icon(Icons.rule),
      title: Text('${appLocalizations.tailscaleGroupRules} ($valid)'),
      subtitle: Text(appLocalizations.tailscaleGroupRulesDesc),
      delegate: NextDelegate(
        blur: false,
        title: appLocalizations.tailscaleGroupRules,
        widget: Consumer(
          builder: (_, ref, _) {
            final rules = ref.watch(
              networkSettingProvider.select(
                (state) =>
                    state.tailscale.groupById(widget.id)?.rules ?? const [],
              ),
            );
            return ListInputPage(
              title: appLocalizations.tailscaleGroupRules,
              items: rules,
              titleBuilder: (item) => Text(
                normalizeTailscaleRule(item) == null
                    ? '$item (${appLocalizations.tailscaleGroupRulesInvalid})'
                    : item,
              ),
              onChange: (items) => _updateTailscale(ref, (state) {
                final current = state.groupById(widget.id);
                if (current == null) return state;
                return state.updateGroup(
                  widget.id,
                  current.copyWith(rules: List.from(items)),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(
      networkSettingProvider.select((state) => state.tailscale),
    );
    final group = _groupOf(props);
    if (group == null) return const SizedBox();
    final profileNames = [for (final node in widget.profileNodes) node.name];
    final isDefault = props.isDefaultGroup(group, profileNames);
    final active = props.groupActive(group);
    final status = statuses[group.name];
    final profileNode = widget.profileNode;
    final useAuthKey = group.managed
        ? group.useAuthKey
        : (profileNode?.authKey.isNotEmpty ?? false);
    final tailscaleNames = {for (final g in props.nodeGroups) g.name};
    final proxyGroups = ref
        .watch(groupsProvider)
        .map((g) => g.name)
        .where(
          (name) =>
              name != GroupName.GLOBAL.name && !tailscaleNames.contains(name),
        )
        .toList();
    final via = group.via.trim();
    final viaOptions = [
      '',
      if (via.isNotEmpty && !proxyGroups.contains(via)) via,
      ...proxyGroups,
    ];
    return generateListView([
      if (props.nodeEnable || profileNode != null) ...[
        _TailscaleNodeStatusPanel(
          status: status,
          loading: statusLoading,
          onRefresh: refreshStatus,
          statusText: _tailscaleStatusText(props, group, status),
        ),
        ...nodeActions(name: group.name, useAuthKey: useAuthKey, active: active),
      ],
      if (group.profile) ...[
        ListItem.switchItem(
          title: Text(appLocalizations.tailscaleGroupOverride),
          subtitle: Text(
            profileNode == null
                ? appLocalizations.tailscaleGroupNotInProfile
                : appLocalizations.tailscaleGroupOverrideDesc,
          ),
          delegate: SwitchDelegate(
            value: group.overridden,
            onChanged: (value) => _update(
              (g) => g.copyWith(overridden: value),
              restart: true,
            ),
          ),
        ),
        if (!group.overridden && profileNode != null)
          ..._readonlyItems(profileNode),
      ],
      // BETTBOX-CUSTOM: 配置文件里的节点也可以直接当默认组，不要求先开覆写。
      if (!isDefault &&
          (group.profile ? profileNode != null : props.groupActive(group)))
        ListItem(
          leading: const Icon(Icons.star_outline),
          title: Text(appLocalizations.tailscaleGroupSetDefault),
          subtitle: Text(appLocalizations.tailscaleGroupSetDefaultDesc),
          onTap: () => _updateTailscale(
            ref,
            (state) => state.setDefaultGroup(group.name),
          ),
        ),
      if (group.managed) ...[
        if (!group.profile)
          ListItem.input(
            title: Text(appLocalizations.tailscaleGroupName),
            subtitle: Text('${group.name}\n${appLocalizations.tailscaleGroupNameDesc}'),
            delegate: InputDelegate(
              title: appLocalizations.tailscaleGroupName,
              value: group.name,
              validator: (value) => _validateName(value, group),
              onChanged: (value) {
                if (value == null || _validateName(value, group) != null) {
                  return;
                }
                if (value.trim() == group.name) return;
                _update((g) => g.copyWith(name: value.trim()), restart: true);
              },
            ),
          ),
        ListItem.options(
          title: Text(appLocalizations.tailscaleNodeAuthMode),
          subtitle: Text(
            '${group.useAuthKey ? appLocalizations.tailscaleNodeAuthModeAuthKey : appLocalizations.tailscaleNodeAuthModeLogin}\n${appLocalizations.tailscaleNodeAuthModeDesc}',
          ),
          delegate: OptionsDelegate<bool>(
            title: appLocalizations.tailscaleNodeAuthMode,
            value: group.useAuthKey,
            options: const [false, true],
            textBuilder: (value) => value
                ? appLocalizations.tailscaleNodeAuthModeAuthKey
                : appLocalizations.tailscaleNodeAuthModeLogin,
            onChanged: (value) {
              if (value == null) return;
              _switchAuthMode(value, group, active);
            },
          ),
        ),
        ListItem.input(
          title: Text(appLocalizations.tailscaleNodeHostname),
          subtitle: Text(
            group.hostname.isEmpty
                ? '${appLocalizations.tailscaleNodeHostnameDesc}: ${props.effectiveHostname(group)}'
                : props.effectiveHostname(group),
          ),
          delegate: InputDelegate(
            title: appLocalizations.tailscaleNodeHostname,
            value: group.hostname,
            resetValue: '',
            hintText: props.effectiveHostname(group),
            onChanged: (value) {
              if (value == null) return;
              _update((g) => g.copyWith(hostname: value.trim()));
            },
          ),
        ),
        if (group.useAuthKey)
          ListItem.input(
            title: Text(appLocalizations.tailscaleNodeAuthKey),
            subtitle: Text(
              [
                if (group.authKey.isNotEmpty)
                  '${group.authKey.length > 12 ? group.authKey.substring(0, 12) : group.authKey}••••',
                isDefault
                    ? appLocalizations.tailscaleNodeAuthKeyDesc
                    : appLocalizations.tailscaleGroupAuthKeyInherit,
              ].join('\n'),
            ),
            delegate: InputDelegate(
              title: appLocalizations.tailscaleNodeAuthKey,
              value: group.authKey,
              resetValue: '',
              hintText: 'tskey-auth-…',
              onChanged: (value) {
                if (value == null) return;
                _changeAuthKey(value.trim(), group, active);
              },
            ),
          ),
        ListItem.input(
          title: Text(appLocalizations.tailscaleNodeExitNode),
          subtitle: Text(
            group.exitNode.isEmpty
                ? appLocalizations.tailscaleNodeExitNodeDesc
                : group.exitNode,
          ),
          delegate: InputDelegate(
            title: appLocalizations.tailscaleNodeExitNode,
            value: group.exitNode,
            resetValue: '',
            onChanged: (value) {
              if (value == null) return;
              _update((g) => g.copyWith(exitNode: value.trim()));
            },
          ),
        ),
        ListItem.switchItem(
          title: Text(appLocalizations.tailscaleNodeAcceptRoutes),
          subtitle: Text(appLocalizations.tailscaleNodeAcceptRoutesDesc),
          delegate: SwitchDelegate(
            value: group.acceptRoutes,
            onChanged: (value) =>
                _update((g) => g.copyWith(acceptRoutes: value)),
          ),
        ),
        ListItem.options(
          title: Text(appLocalizations.tailscaleProxyVia),
          subtitle: Text(
            '${via.isEmpty ? appLocalizations.tailscaleGroupDirect : via}\n${appLocalizations.tailscaleGroupViaDesc}',
          ),
          delegate: OptionsDelegate<String>(
            title: appLocalizations.tailscaleProxyVia,
            value: via,
            options: viaOptions,
            textBuilder: (value) =>
                value.isEmpty ? appLocalizations.tailscaleGroupDirect : value,
            onChanged: (value) {
              if (value == null || value == via) return;
              _update((g) => g.copyWith(via: value), restart: true);
            },
          ),
        ),
        _rulesEntry(group),
        ..._deviceItems(props, group),
        // 默认组也可以删除：删掉后由 effectiveDefaultName 自动回退（配置文件节点 → 第一个自己添加的组）。
        if (!group.profile)
          ListItem(
            leading: Icon(
              Icons.delete_outline,
              color: context.colorScheme.error,
            ),
            title: Text(
              appLocalizations.tailscaleGroupDelete,
              style: TextStyle(color: context.colorScheme.error),
            ),
            onTap: () => _delete(group),
          ),
      ],
    ]);
  }
}

// BETTBOX-CUSTOM: 配置文件预读取告警：列出定义了 Tailscale 节点的配置文件，以及会影响内置节点的项。
class _TailscaleProfileWarning extends StatelessWidget {
  const _TailscaleProfileWarning({required this.props, required this.scans});

  final TailscaleProps props;
  final List<TailscaleProfileScan> scans;

  static bool _isBettboxStateDir(String dir) =>
      dir.replaceAll('\\', '/').contains('tailscale/bettbox');

  @override
  Widget build(BuildContext context) {
    final own = props.nodeGroups.where((g) => !g.profile).toList();
    final ownNames = {for (final g in own) g.name};
    final ownHosts = {
      if (props.nodeEnable)
        for (final g in own)
          if (props.groupActive(g)) props.effectiveHostname(g).toLowerCase(),
    };
    final sections = <(String, List<String>)>[
      for (final scan in scans)
        if (scan.nodes.isNotEmpty)
          (
            scan.current
                ? '${scan.label} (${appLocalizations.tailscaleProfileCurrent})'
                : scan.label,
            [
              for (final node in scan.nodes)
                () {
                  final issues = [
                    if (ownNames.contains(node.name))
                      appLocalizations.tailscaleProfileNameConflict,
                    if (_isBettboxStateDir(node.stateDir))
                      appLocalizations.tailscaleProfileStateDirConflict,
                    if (node.hostname.isNotEmpty &&
                        ownHosts.contains(node.hostname.toLowerCase()))
                      appLocalizations.tailscaleProfileHostnameConflict,
                    if (props.nodeActive && (scan.ruleTargets[node.name] ?? 0) > 0)
                      appLocalizations.tailscaleProfileRulesShadowed,
                  ];
                  return issues.isEmpty
                      ? node.name
                      : '${node.name}：${issues.join('；')}';
                }(),
            ],
          ),
    ];
    if (sections.isEmpty) return const SizedBox();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = colorScheme.onTertiaryContainer;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appLocalizations.tailscaleProfileWarning,
                  style: theme.textTheme.titleSmall?.copyWith(color: textColor),
                ),
              ),
            ],
          ),
          for (final (label, lines) in sections) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 26),
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 26),
                child: Text(
                  '· $line',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// BETTBOX-CUSTOM: 内置节点状态面板。Rex 等内嵌 Tailscale 或依赖系统网络访问
// Tailnet 的应用都经过这个节点，节点重连时它们会暂时解析不到主机；面板把状态、
// 节点名、IP、在线设备数放在一起，方便判断问题出在节点还是对端。
class _TailscaleNodeStatusPanel extends StatelessWidget {
  final String? title;
  final TailscaleNodeStatus? status;
  final bool loading;
  final VoidCallback onRefresh;
  final String statusText;

  const _TailscaleNodeStatusPanel({
    this.title,
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
      if (title != null) (appLocalizations.tailscaleGroups, title!),
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
    this.groupName,
    this.selfGroup,
    this.onPickGroup,
  });

  final TailscalePeer peer;
  // BETTBOX-CUSTOM: 明确接管的策略组（null 为未接管，由默认组兜底），点按整行可改。
  final String? groupName;
  // 本机 Bettbox 策略组自己的节点（不能被接管）。
  final String? selfGroup;
  final VoidCallback? onPickGroup;

  String get _ownerLine {
    if (selfGroup != null) {
      return '${appLocalizations.tailscalePeerSelfNode} ($selfGroup)';
    }
    if (groupName != null) {
      return '${appLocalizations.tailscalePeerOwnedBy}: $groupName';
    }
    return appLocalizations.tailscalePeerFallback;
  }

  String get _subtitle {
    return [
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
    // BETTBOX-CUSTOM: 名称单行，状态一行、接管情况一行；右侧只放复制 IP 的小图标，点整行选择接管的策略组，
    // 窄窗口下不再被按钮挤成竖排。
    return ListItem(
      leading: Icon(
        Icons.circle,
        size: 10,
        color: peer.online ? Colors.green : colorScheme.outline,
      ),
      title: Text(
        peer.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$_subtitle\n$_ownerLine',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: peer.ips.isEmpty
          ? null
          : IconButton(
              tooltip: appLocalizations.copy,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: peer.ips.first));
                globalState.showNotifier(appLocalizations.copySuccess);
              },
            ),
      onTap: onPickGroup,
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
