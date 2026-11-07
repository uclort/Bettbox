// ignore_for_file: invalid_annotation_target

import 'dart:io' show InternetAddress, Platform;

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:material_ui/material_ui.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'models.dart';

part 'generated/config.freezed.dart';
part 'generated/config.g.dart';

const defaultBypassDomain = [
  '*.jd.com',
  '*.zhihu.com',
  '*.zhimg.com',
  '*.360buyimg.com',
  'localhost',
  '127.*',
  '[::1]',
  '*.local',
  '10.*',
  '172.16.*',
  '172.17.*',
  '172.18.*',
  '172.19.*',
  '172.20.*',
  '172.21.*',
  '172.22.*',
  '172.23.*',
  '172.24.*',
  '172.25.*',
  '172.26.*',
  '172.27.*',
  '172.28.*',
  '172.29.*',
  '172.30.*',
  '172.31.*',
  '192.168.*',
];

// BETTBOX-CUSTOM: Tailscale 共存默认值，可在网络设置中自定义并一键恢复。
const defaultTailscaleRouteExcludeAddress = [
  '100.64.0.0/10',
  'fd7a:115c:a1e0::/48',
];
const defaultTailscaleDnsDomains = ['ts.net'];
const defaultTailscaleDnsServer = '100.100.100.100';
const defaultTailscaleBypassDomain = ['*.ts.net', '100.64.0.0/10'];
const defaultTailscaleProps = TailscaleProps();

// BETTBOX-CUSTOM: 内置 Tailscale 节点在内核中的名称，前置规则与 tailscale:// DNS 都引用它。
const tailscaleNodeName = 'Bettbox-Tailscale';

// BETTBOX-CUSTOM: 旧版代理通道节点。升级后迁移为一个 Tailscale 策略组（state-id proxy，身份目录不变）。
const tailscaleProxyNodeName = 'Bettbox-Tailscale-Proxy';
const tailscaleLegacyProxyStateId = 'proxy';

/// BETTBOX-CUSTOM: Tailnet 兜底规则的目标占位名，内核换成实际选定的默认组（与 core/patch_tailscale.go 一致）。
const tailscaleDefaultTarget = 'BETTBOX-TAILSCALE-DEFAULT';

/// 自定义规则只接受「类型,值[,no-resolve|src]」，目标由所在策略组决定；逻辑规则与 MATCH 不支持。
const _tailscaleRuleOptions = {'no-resolve', 'src'};
const _tailscaleUnsupportedRuleTypes = {
  'MATCH',
  'AND',
  'OR',
  'NOT',
  'SUB-RULE',
  'FINAL',
};

/// 规范化一条自定义规则（不含目标），无效时返回 null。
String? normalizeTailscaleRule(String raw) {
  final parts = raw.split(',').map((e) => e.trim()).toList();
  if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
  final type = parts[0].toUpperCase();
  if (_tailscaleUnsupportedRuleTypes.contains(type)) return null;
  final options = parts.skip(2).where(_tailscaleRuleOptions.contains);
  return [type, parts[1], ...options].join(',');
}

// BETTBOX-CUSTOM: Tailscale 策略组。每个组是内核里的一个 mihomo type: tailscale 节点，在 Tailnet 中各是一台设备
// （各自的身份目录；同一个 key 也会注册成两台设备，共用身份会让两个会话互相顶替）。默认组承接 Tailnet 兜底规则
// 与 MagicDNS；其他组只接管勾选的设备和自定义规则，可经代理连接（dialer-proxy，与 Surge underlying-proxy 相同）。
// profile 为 true 的是配置文件里的同名节点：override 开启时运行时整体替换为这里的参数。
class TailscaleGroup {
  const TailscaleGroup({
    this.id = '',
    this.name = '',
    this.profile = false,
    this.overridden = false,
    this.hostname = '',
    this.useAuthKey = false,
    this.authKey = '',
    this.exitNode = '',
    this.acceptRoutes = true,
    this.via = '',
    this.devices = const [],
    this.rules = const [],
  });

  factory TailscaleGroup.fromJson(Map<String, dynamic> json) {
    List<String> list(Object? value) =>
        (value as List?)?.whereType<String>().toList() ?? const [];
    return TailscaleGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profile: json['profile'] as bool? ?? false,
      overridden: json['override'] as bool? ?? false,
      hostname: json['hostname'] as String? ?? '',
      useAuthKey: json['useAuthKey'] as bool? ?? false,
      authKey: json['authKey'] as String? ?? '',
      exitNode: json['exitNode'] as String? ?? '',
      acceptRoutes: json['acceptRoutes'] as bool? ?? true,
      via: json['via'] as String? ?? '',
      devices: list(json['devices']),
      rules: list(json['rules']),
    );
  }

  /// 身份目录标识：空为默认组（tailscale/bettbox），新建组以 g- 开头，配置文件覆写以 p- 开头。
  final String id;
  final String name;
  final bool profile;

  /// 配置文件节点是否开启覆写。不能命名为 override：字段会遮住 @override 注解导致编译失败。
  final bool overridden;
  final String hostname;
  final bool useAuthKey;

  /// 留空时使用默认组的 key（非默认组）。
  final String authKey;
  final String exitNode;
  final bool acceptRoutes;

  /// 经此策略组 / 节点连接（dialer-proxy），空为直连。
  final String via;

  /// 经此组连接的设备（TailscaleProxyDevice.encoded）。
  final List<String> devices;

  /// 自定义规则（不含目标），见 normalizeTailscaleRule。
  final List<String> rules;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'profile': profile,
    'override': overridden,
    'hostname': hostname,
    'useAuthKey': useAuthKey,
    'authKey': authKey,
    'exitNode': exitNode,
    'acceptRoutes': acceptRoutes,
    'via': via,
    'devices': devices,
    'rules': rules,
  };

  TailscaleGroup copyWith({
    String? id,
    String? name,
    bool? profile,
    bool? overridden,
    String? hostname,
    bool? useAuthKey,
    String? authKey,
    String? exitNode,
    bool? acceptRoutes,
    String? via,
    List<String>? devices,
    List<String>? rules,
  }) => TailscaleGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    profile: profile ?? this.profile,
    overridden: overridden ?? this.overridden,
    hostname: hostname ?? this.hostname,
    useAuthKey: useAuthKey ?? this.useAuthKey,
    authKey: authKey ?? this.authKey,
    exitNode: exitNode ?? this.exitNode,
    acceptRoutes: acceptRoutes ?? this.acceptRoutes,
    via: via ?? this.via,
    devices: devices ?? this.devices,
    rules: rules ?? this.rules,
  );

  List<TailscaleProxyDevice> get proxyDevices => [
    for (final raw in devices)
      if (TailscaleProxyDevice.parse(raw) case final d when !d.isEmpty) d,
  ];

  /// 配置文件里的节点只有开启覆写后才由 Bettbox 接管。
  bool get managed => !profile || overridden;

  List<String> get validRules => [
    for (final raw in rules) ?normalizeTailscaleRule(raw),
  ];

  /// 设备规则在前，自定义规则在后，目标都是本组。
  List<String> get prependRules => [
    for (final device in proxyDevices) ...device.rules(name),
    for (final rule in validRules)
      () {
        final parts = rule.split(',');
        return [parts[0], parts[1], name, ...parts.skip(2)].join(',');
      }(),
  ];

  @override
  bool operator ==(Object other) =>
      other is TailscaleGroup &&
      const DeepCollectionEquality().equals(toJson(), other.toJson());

  @override
  int get hashCode => const DeepCollectionEquality().hash(toJson());
}

/// 配置文件里定义的 Tailscale 节点（预读取结果）。
class TailscaleProfileNode {
  const TailscaleProfileNode({
    required this.name,
    this.hostname = '',
    this.stateDir = '',
    this.authKey = '',
    this.exitNode = '',
    this.acceptRoutes = true,
    this.dialerProxy = '',
  });

  factory TailscaleProfileNode.fromProxy(Map proxy) {
    String str(String key) => (proxy[key]?.toString() ?? '').trim();
    return TailscaleProfileNode(
      name: str('name'),
      hostname: str('hostname'),
      stateDir: str('state-dir'),
      authKey: str('auth-key'),
      exitNode: str('exit-node'),
      acceptRoutes: proxy['accept-routes'] as bool? ?? true,
      dialerProxy: str('dialer-proxy'),
    );
  }

  final String name;
  final String hostname;
  final String stateDir;
  final String authKey;
  final String exitNode;
  final bool acceptRoutes;
  final String dialerProxy;

  /// 开启覆写时用配置文件的参数作为初始值。
  TailscaleGroup toGroup() => TailscaleGroup(
    id: 'p-${tailscaleSlug(name)}',
    name: name,
    profile: true,
    overridden: true,
    hostname: hostname,
    useAuthKey: authKey.isNotEmpty,
    authKey: authKey,
    exitNode: exitNode,
    acceptRoutes: acceptRoutes,
    via: dialerProxy,
  );
}

/// 一个配置文件的预读取结果与可能影响内置节点的项。
class TailscaleProfileScan {
  const TailscaleProfileScan({
    required this.profileId,
    required this.label,
    this.current = false,
    this.nodes = const [],
    this.ruleTargets = const {},
  });

  final String profileId;
  final String label;
  final bool current;
  final List<TailscaleProfileNode> nodes;

  /// 指向 Tailscale 节点的规则数（按节点名）。
  final Map<String, int> ruleTargets;

  /// 从运行配置（getProfileConfig 结果）读取 Tailscale 节点和指向它们的规则。
  factory TailscaleProfileScan.fromConfig({
    required String profileId,
    required String label,
    required bool current,
    required Map<String, dynamic> config,
  }) {
    final nodes = [
      for (final proxy in (config['proxies'] as List?) ?? const [])
        if (proxy is Map && proxy['type'] == 'tailscale')
          TailscaleProfileNode.fromProxy(proxy),
    ].where((node) => node.name.isNotEmpty).toList();
    final names = {for (final node in nodes) node.name};
    final targets = <String, int>{};
    for (final rule in (config['rules'] as List?) ?? const []) {
      if (rule is! String) continue;
      final parts = rule.split(',').map((e) => e.trim()).toList();
      for (final part in parts.skip(1)) {
        if (names.contains(part)) {
          targets[part] = (targets[part] ?? 0) + 1;
          break;
        }
      }
    }
    return TailscaleProfileScan(
      profileId: profileId,
      label: label,
      current: current,
      nodes: nodes,
      ruleTargets: targets,
    );
  }
}

String tailscaleSlug(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isNotEmpty) return slug;
  // 名称没有 ASCII 字符（如中文）时用稳定的 FNV-1a 哈希，保证每次启动得到相同的身份目录。
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return 'n${hash.toRadixString(16)}';
}

/// 经代理连接的设备。持久化为 `DNS名,IP,IP`（手动添加时可以只有 DNS 名或只有 IP）。
class TailscaleProxyDevice {
  const TailscaleProxyDevice({this.dnsName = '', this.ips = const []});

  factory TailscaleProxyDevice.parse(String raw) {
    var dnsName = '';
    final ips = <String>[];
    for (final part in raw.split(',')) {
      final value = part.trim();
      if (value.isEmpty) continue;
      if (InternetAddress.tryParse(value) != null) {
        if (!ips.contains(value)) ips.add(value);
      } else if (dnsName.isEmpty) {
        dnsName = normalizeTailscaleDomain(value);
      }
    }
    return TailscaleProxyDevice(dnsName: dnsName, ips: ips);
  }

  factory TailscaleProxyDevice.fromPeer(TailscalePeer peer) =>
      TailscaleProxyDevice(
        dnsName: normalizeTailscaleDomain(peer.dnsName),
        ips: peer.ips,
      );

  final String dnsName;
  final List<String> ips;

  bool get isEmpty => dnsName.isEmpty && ips.isEmpty;

  String get encoded => [if (dnsName.isNotEmpty) dnsName, ...ips].join(',');

  String get displayName {
    final short = dnsName.split('.').first;
    return short.isNotEmpty ? short : ips.join(', ');
  }

  /// 同一台设备：DNS 名相同，或任一 IP 相同。
  bool matches(TailscaleProxyDevice other) {
    if (dnsName.isNotEmpty && dnsName == other.dnsName) return true;
    return ips.any(other.ips.contains);
  }

  bool matchesPeer(TailscalePeer peer) =>
      matches(TailscaleProxyDevice.fromPeer(peer));

  List<String> rules(String target) => [
    if (dnsName.isNotEmpty) 'DOMAIN,$dnsName,$target',
    for (final ip in ips)
      ip.contains(':')
          ? 'IP-CIDR6,$ip/128,$target,no-resolve'
          : 'IP-CIDR,$ip/32,$target,no-resolve',
  ];
}

const defaultAppSettingProps = AppSettingProps();
const defaultVpnProps = VpnProps();
const defaultNetworkProps = NetworkProps();
const defaultProxiesStyle = ProxiesStyle();
const defaultWindowProps = WindowProps();
const defaultAccessControl = AccessControl();
const defaultThemeProps = ThemeProps();

const List<DashboardWidget> defaultDashboardWidgets = [
  DashboardWidget.networkSpeed,
  DashboardWidget.systemProxyButton,
  DashboardWidget.tunButton,
  DashboardWidget.outboundMode,
  DashboardWidget.networkDetection,
  DashboardWidget.intranetIp,
  DashboardWidget.trafficUsage,
  DashboardWidget.memoryInfo,
  DashboardWidget.connectionsCount,
  DashboardWidget.startButton,
];

const List<DashboardWidget> defaultAndroidDashboardWidgets = [
  DashboardWidget.outboundModeV2,
  DashboardWidget.networkSpeed,
  DashboardWidget.trafficUsage,
  DashboardWidget.networkDetection,
  DashboardWidget.connectionsCount,
  DashboardWidget.memoryInfo,
  DashboardWidget.startButton,
];

final _dashboardWidgetNames = {
  for (final entry in _$DashboardWidgetEnumMap.entries) entry.value: entry.key,
};

List<DashboardWidget> _decodeDashboardWidgets(List<dynamic> values) => [
  for (final value in values) ?_dashboardWidgetNames[value],
];

List<DashboardWidget> dashboardWidgetsSafeFromJson(
  List<dynamic>? dashboardWidgets,
) {
  if (dashboardWidgets == null) {
    return system.isAndroid
        ? defaultAndroidDashboardWidgets
        : defaultDashboardWidgets;
  }
  return _decodeDashboardWidgets(dashboardWidgets);
}

List<DashboardWidget> mobileDashboardWidgetsSafeFromJson(
  List<dynamic>? dashboardWidgets,
) {
  if (dashboardWidgets == null) {
    return defaultAndroidDashboardWidgets;
  }
  return _decodeDashboardWidgets(dashboardWidgets);
}

List<DashboardWidget> desktopDashboardWidgetsSafeFromJson(
  List<dynamic>? dashboardWidgets,
) {
  if (dashboardWidgets == null) {
    return defaultDashboardWidgets;
  }
  return _decodeDashboardWidgets(dashboardWidgets);
}

const List<SidebarFlyoutEntry> defaultSidebarFlyoutEntries = [
  SidebarFlyoutEntry.resources,
  SidebarFlyoutEntry.script,
  SidebarFlyoutEntry.toolbox,
  SidebarFlyoutEntry.theme,
  SidebarFlyoutEntry.basicConfig,
  SidebarFlyoutEntry.otherSettings,
  SidebarFlyoutEntry.application,
  SidebarFlyoutEntry.about,
];

List<SidebarFlyoutEntry> sidebarFlyoutEntriesSafeFromJson(
  List<dynamic>? sidebarFlyoutEntries,
) {
  try {
    return sidebarFlyoutEntries
            ?.map((e) => $enumDecode(_$SidebarFlyoutEntryEnumMap, e))
            .toList() ??
        defaultSidebarFlyoutEntries;
  } catch (_) {
    return defaultSidebarFlyoutEntries;
  }
}

const List<MediaPlatform> defaultPinnedMediaPlatforms = [
  MediaPlatform.reddit,
  MediaPlatform.gemini,
  MediaPlatform.cloudflare,
];

List<MediaPlatform> pinnedMediaPlatformsSafeFromJson(
  List<dynamic>? pinnedMediaPlatforms,
) {
  try {
    if (pinnedMediaPlatforms == null) return defaultPinnedMediaPlatforms;
    final list = <MediaPlatform>[];
    for (final e in pinnedMediaPlatforms) {
      final str = e.toString();
      if (str == 'chatgpt') {
        list.add(MediaPlatform.openai);
        continue;
      }
      if (str == 'qqnews') {
        list.add(MediaPlatform.tencent);
        continue;
      }
      if (str == 'alidnsprobe') {
        list.add(MediaPlatform.alibaba);
        continue;
      }
      if (str == 'bytedance') {
        list.add(MediaPlatform.douyin);
        continue;
      }
      final p = MediaPlatform.values.where((v) => v.name == str).firstOrNull;
      if (p != null) list.add(p);
    }
    return list.isEmpty ? defaultPinnedMediaPlatforms : list;
  } catch (_) {
    return defaultPinnedMediaPlatforms;
  }
}

@freezed
abstract class AppSettingProps with _$AppSettingProps {
  const factory AppSettingProps({
    String? locale,
    @Default(defaultDashboardWidgets)
    @JsonKey(fromJson: dashboardWidgetsSafeFromJson)
    List<DashboardWidget> dashboardWidgets,
    @Default(defaultAndroidDashboardWidgets)
    @JsonKey(fromJson: mobileDashboardWidgetsSafeFromJson)
    List<DashboardWidget> mobileDashboardWidgets,
    @Default(defaultDashboardWidgets)
    @JsonKey(fromJson: desktopDashboardWidgetsSafeFromJson)
    List<DashboardWidget> desktopDashboardWidgets,
    @Default(defaultPinnedMediaPlatforms)
    @JsonKey(fromJson: pinnedMediaPlatformsSafeFromJson)
    List<MediaPlatform> pinnedMediaPlatforms,
    @Default(false) bool mediaUnlockMoreStreamingPlatforms,
    @Default(false) bool mediaUnlockExtraDetails,
    @Default(true) bool mediaUnlockRefreshOnNodeChange,
    @Default(true) bool mediaUnlockColorfulIcons,
    @Default(true) bool mediaUnlockRefreshByCategory,
    @Default(true) bool onlyStatisticsProxy,
    @Default(false) bool autoLaunch,
    @Default(false) bool silentLaunch,
    @Default(false) bool smartDelayLaunch,
    @Default(false) bool autoRun,
    @Default(true) bool openLogs,
    @Default(true) bool closeConnections,
    @Default(true) bool logAiSearch,
    @Default(defaultTestUrl) String testUrl,
    @Default(true) bool showStartSwitch,
    @Default(StartSwitchStyle.outlined) StartSwitchStyle startSwitchStyle,
    String? startSwitchOnLabel,
    String? startSwitchOffLabel,
    @Default(true) bool enableNavBarHapticFeedback,
    @Default(true) bool autoCheckUpdate,
    // BETTBOX-CUSTOM: 自定义更新通道；开启后同时接收预览版（pre-release）更新。
    @Default(false) bool receivePreRelease,
    // BETTBOX-CUSTOM: 托盘策略组右侧逐级显示完整节点链路，默认只补最终节点。
    @Default(false) bool trayShowProxyChain,
    // BETTBOX-CUSTOM: 托盘图标旁显示指定策略组（可含隐藏组）的名称 / 节点 / 链路，
    // 位置可在网速前或后；网速关闭时占用网速的位置。
    @Default(false) bool trayStatusGroupEnable,
    @Default('') String trayStatusGroupName,
    @Default(false) bool trayStatusShowName,
    @Default(true) bool trayStatusShowNode,
    @Default(false) bool trayStatusShowChain,
    // BETTBOX-CUSTOM: 末端节点后以括号附加延迟，例如 `FC-日本 1 (86ms)`。
    @Default(false) bool trayStatusShowDelay,
    @Default(false) bool trayStatusBeforeSpeed,
    @Default(false) bool showLabel,
    @Default(false) bool disclaimerAccepted,
    @Default(true) bool minimizeOnExit,
    @Default(false) bool hidden,
    @Default(false) bool developerMode,
    @Default(RecoveryStrategy.compatible) RecoveryStrategy recoveryStrategy,
    @Default('') String backupPassword,
    @Default(false) bool enableHighPriority,
    @Default(true) bool sidebarCollapsed,
    @Default(false) bool sidebarFlyout,
    @Default(false) bool sidebarFlyoutOutsideTools,
    @Default(SidebarFlyoutDelay.standard) SidebarFlyoutDelay sidebarFlyoutDelay,
    @Default(defaultSidebarFlyoutEntries)
    @JsonKey(fromJson: sidebarFlyoutEntriesSafeFromJson)
    List<SidebarFlyoutEntry> sidebarFlyoutEntries,
    String? dashboardTitle,
    @Default(<String>[]) List<String> toolboxTiles,
    @JsonKey(unknownEnumValue: MrsTapAction.viewRules)
    @Default(MrsTapAction.viewRules)
    MrsTapAction mrsTapAction,
    @Default(true) bool mrsResolveDns,
    @Default(false) bool ipRiskDetail,
    @Default(true) bool ipRiskAlert,
    @Default(IperfOptions()) IperfOptions iperfOptions,
    @Default(LocalPingOptions()) LocalPingOptions localPingOptions,
    @Default(<String, String>{}) Map<String, String> mobileDashboardSizes,
    @Default(<String, String>{}) Map<String, String> desktopDashboardSizes,
  }) = _AppSettingProps;

  factory AppSettingProps.fromJson(Map<String, Object?> json) =>
      _$AppSettingPropsFromJson(json);

  factory AppSettingProps.safeFromJson(Map<String, Object?>? json) {
    var props = json == null
        ? defaultAppSettingProps
        : AppSettingProps.fromJson(json);

    if (json != null) {
      final oldWidgets = json['dashboardWidgets'];
      if (oldWidgets is List) {
        final parsedOld = dashboardWidgetsSafeFromJson(oldWidgets);
        if (json['mobileDashboardWidgets'] == null) {
          props = props.copyWith(mobileDashboardWidgets: parsedOld);
        }
        if (json['desktopDashboardWidgets'] == null) {
          props = props.copyWith(desktopDashboardWidgets: parsedOld);
        }
      }
    } else if (system.isAndroid) {
      props = props.copyWith(
        mobileDashboardWidgets: defaultAndroidDashboardWidgets,
      );
    }

    return props.copyWith(minimizeOnExit: true, openLogs: true);
  }
}

@freezed
abstract class AccessControl with _$AccessControl {
  const factory AccessControl({
    @Default(false) bool enable,
    @Default(AccessControlMode.rejectSelected) AccessControlMode mode,
    @Default([]) List<String> acceptList,
    @Default([]) List<String> rejectList,
    @Default([]) List<String> manualList,
    @JsonKey(unknownEnumValue: AccessSortType.none)
    @Default(AccessSortType.none)
    AccessSortType sort,
    @Default(false) bool isFilterSystemApp,
    @Default(false) bool isFilterNonInternetApp,
  }) = _AccessControl;

  factory AccessControl.fromJson(Map<String, Object?> json) =>
      _$AccessControlFromJson(json);
}

extension AccessControlExt on AccessControl {
  List<String> get currentList => switch (mode) {
    AccessControlMode.acceptSelected => acceptList,
    AccessControlMode.rejectSelected => rejectList,
  };
}

@freezed
abstract class WindowProps with _$WindowProps {
  const factory WindowProps({
    @Default(910) double width,
    @Default(620) double height,
    double? top,
    double? left,
    @Default(false) bool isPinned,
    @Default(1.0) double scaleFactor,
  }) = _WindowProps;

  factory WindowProps.fromJson(Map<String, Object?>? json) =>
      json == null ? const WindowProps() : _$WindowPropsFromJson(json);
}

@freezed
abstract class VpnProps with _$VpnProps {
  const factory VpnProps({
    @Default(true) bool enable,
    @Default(false) bool systemProxy,
    @Default(false) bool allowBypass,
    @Default(true) bool bypassPrivateRoute,
    @Default(true) bool dozeSuspend,
    @Default(false) bool smartAutoStop,
    @Default('') String smartAutoStopNetworks,
    @Default(false) bool storeFix,
    @Default(false) bool networkFix,
    @Default(false) bool loopbackProtection,
    @Default(false) bool disableQuic,
    @Default(false) bool highPriorityNotification,
    @Default(false) bool networkSpeedNotification,
    @Default(false) bool excludeChina,
    @Default(false) bool trayEnhancement,
    @Default(TrayClickBehavior.showPanel)
    TrayClickBehavior trayLeftClickBehavior,
    @Default(TrayClickBehavior.showMenu)
    TrayClickBehavior trayRightClickBehavior,
    @Default(false) bool enableTraySpeed,
    @Default(true) bool alwaysShowTitleBar,
    @Default(true) bool quickResponse,
    @Default(defaultAccessControl) AccessControl accessControl,
  }) = _VpnProps;

  factory VpnProps.fromJson(Map<String, Object?> json) =>
      _$VpnPropsFromJson(json);

  factory VpnProps.safeFromJson(Map<String, Object?>? json) {
    return json == null ? defaultVpnProps : VpnProps.fromJson(json);
  }
}

List<String> bypassDomainSafeFromJson(List<dynamic>? bypassDomain) {
  try {
    return bypassDomain
            ?.map((e) => e.toString())
            .where((e) => e != '::1')
            .toList() ??
        defaultBypassDomain;
  } catch (_) {
    return defaultBypassDomain;
  }
}

int concurrencyLimitFromJson(Object? value) {
  if (value is! int || value > 32) return maxDelayTestConcurrency;
  return value < 1 ? 1 : value;
}

@freezed
abstract class NetworkProps with _$NetworkProps {
  const factory NetworkProps({
    @Default(false) bool systemProxy,
    @Default(defaultBypassDomain)
    @JsonKey(fromJson: bypassDomainSafeFromJson)
    List<String> bypassDomain,
    @Default(true) bool bypassPrivateRoute,
    @Default([]) List<String> bypassPrivateRouteAddress,
    @Default(defaultTailscaleProps) TailscaleProps tailscale,
    @Default(ProfileSwitchMode.hotReload) ProfileSwitchMode profileSwitchMode,
  }) = _NetworkProps;

  factory NetworkProps.fromJson(Map<String, Object?>? json) =>
      json == null ? const NetworkProps() : _$NetworkPropsFromJson(json);
}

// BETTBOX-CUSTOM: Tailscale 接入，两种方式：
// - App 共存（enable，桌面端）：Tailnet 网段不进 TUN、MagicDNS 交给 100.100.100.100、系统代理绕过，流量由 Tailscale App 承载。
// - 内置节点（nodeEnable）：内核注入 mihomo type: tailscale 节点，Tailnet 域名与网段经前置规则转给它，不依赖 App。
// 两者同时开启时以内置节点为准；routeExcludeAddress / dnsDomains 作为两种方式共用的 Tailnet 网段与域名。
// 内置节点有两种接入方式（nodeUseAuthKey）：浏览器登录只认登录状态；Auth Key 只认 key。两种方式在内核里
// 用不同 state-dir，切换不会清空另一种方式的身份，在 Tailnet 中是两台设备。
@freezed
abstract class TailscaleProps with _$TailscaleProps {
  const factory TailscaleProps({
    @Default(false) bool enable,
    @Default(defaultTailscaleRouteExcludeAddress)
    List<String> routeExcludeAddress,
    @Default(defaultTailscaleDnsDomains) List<String> dnsDomains,
    @Default(defaultTailscaleDnsServer) String dnsServer,
    @Default(defaultTailscaleBypassDomain) List<String> bypassDomain,
    @Default(false) bool nodeEnable,
    @Default('') String nodeHostname,
    @Default('') String nodeAuthKey,
    @Default('') String nodeExitNode,
    @Default(true) bool nodeAcceptRoutes,
    @Default(false) bool nodeUseAuthKey,
    // BETTBOX-CUSTOM: 旧版代理通道（经代理连接的设备与所用代理），只用于迁移到 groups。
    @Default([]) List<String> nodeProxyDevices,
    @Default('') String nodeProxyVia,
    // BETTBOX-CUSTOM: Tailscale 策略组（自己添加的组与开启过覆写的配置文件节点）。不再内置默认组：
    // 全新安装为空；旧版只开过内置节点的配置由 node* 旧字段迁移（见 nodeGroups）。
    @Default([]) List<TailscaleGroup> groups,
    // 手动指定的默认组名（可以是配置文件里的节点）；空为自动：配置文件里第一个 Tailscale 节点，
    // 没有时为第一个自己添加的组。实际选择在内核合并配置时完成（只有内核知道当前配置里有哪些节点）。
    @Default('') String defaultGroup,
    // 配置版本：全新安装为 1；旧版配置缺少该字段时按 0 读入，只有 0 才从 node* 旧字段迁移。
    @JsonKey(defaultValue: 0) @Default(1) int groupsVersion,
  }) = _TailscaleProps;

  factory TailscaleProps.fromJson(Map<String, Object?> json) =>
      _$TailscalePropsFromJson(json);
}

extension TailscalePropsExt on TailscaleProps {
  bool get appActive => enable && system.isDesktop;

  /// 全部已保存的策略组（自己添加的组与开启过覆写的配置文件节点）。
  /// 旧版配置（groupsVersion 0）且开过内置节点、还没写入 groups 时由旧字段迁移：主节点（身份目录不变）
  /// 与旧代理通道（state-id proxy，目录不变），升级后无需重新登录。全新安装不再内置任何组。
  List<TailscaleGroup> get nodeGroups {
    if (groupsVersion > 0 || groups.any((g) => !g.profile) || !nodeEnable) {
      return groups;
    }
    return [
      TailscaleGroup(
        name: tailscaleNodeName,
        hostname: nodeHostname,
        useAuthKey: nodeUseAuthKey,
        authKey: nodeAuthKey,
        exitNode: nodeExitNode,
        acceptRoutes: nodeAcceptRoutes,
      ),
      if (nodeProxyDevices.isNotEmpty || nodeProxyVia.trim().isNotEmpty)
        TailscaleGroup(
          id: tailscaleLegacyProxyStateId,
          name: tailscaleProxyNodeName,
          useAuthKey: nodeUseAuthKey,
          acceptRoutes: nodeAcceptRoutes,
          via: nodeProxyVia.trim(),
          devices: nodeProxyDevices,
        ),
      ...groups,
    ];
  }

  /// 实际的默认组名（与内核的选择规则一致）：手动指定且可用的组 → 配置文件里第一个 Tailscale 节点 →
  /// 第一个生效的自己添加的组；都没有时为 null（不生成 Tailnet 兜底规则）。
  /// profileNodes 是当前配置文件里的 Tailscale 节点名（设置页预读取得到）。
  String? effectiveDefaultName([List<String> profileNodes = const []]) {
    final ownActive = [
      for (final g in nodeGroups)
        if (!g.profile && groupActive(g)) g.name,
    ];
    final preferred = defaultGroup.trim();
    if (preferred.isNotEmpty &&
        (profileNodes.contains(preferred) || ownActive.contains(preferred))) {
      return preferred;
    }
    return profileNodes.firstOrNull ?? ownActive.firstOrNull;
  }

  bool isDefaultGroup(
    TailscaleGroup group, [
    List<String> profileNodes = const [],
  ]) => group.name == effectiveDefaultName(profileNodes);

  /// 写回策略组列表（同时标记已迁移，之后不再读取旧字段）。手动指定的默认组被删除或改名时跟着更新。
  TailscaleProps withGroups(List<TailscaleGroup> value, {String? defaultName}) {
    return copyWith(
      groups: value,
      defaultGroup: defaultName ?? defaultGroup,
      groupsVersion: 1,
    );
  }

  /// 按身份标识替换（或追加）策略组（名称可能与配置文件节点重名，id 唯一）。
  /// 改名时如果它是手动指定的默认组，默认组名跟着改。
  TailscaleProps updateGroup(String id, TailscaleGroup group) {
    final list = nodeGroups;
    final index = list.indexWhere((g) => g.id == id);
    final updated = [...list];
    String? defaultName;
    if (index < 0) {
      updated.add(group);
    } else {
      if (list[index].name == defaultGroup) defaultName = group.name;
      updated[index] = group;
    }
    return withGroups(updated, defaultName: defaultName);
  }

  /// 删除策略组；删的是手动指定的默认组时改回自动选择。
  TailscaleProps removeGroup(String id) {
    final removed = groupById(id);
    if (removed == null) return this;
    return withGroups(
      nodeGroups.where((g) => g.id != id).toList(),
      defaultName: removed.name == defaultGroup ? '' : null,
    );
  }

  /// 手动指定默认组（自己添加的组或配置文件里的节点，按名称）；空为自动。
  TailscaleProps setDefaultGroup(String name) =>
      withGroups(nodeGroups, defaultName: name);

  TailscaleGroup? groupById(String id) =>
      nodeGroups.where((g) => g.id == id).firstOrNull;

  /// key 留空时借用手动指定的默认组的 key，没有时用第一个填了 key 的自己添加的组
  /// （同一个 key 在 Tailnet 中仍是两台设备）。
  String effectiveAuthKey(TailscaleGroup group) {
    final own = group.authKey.trim();
    if (own.isNotEmpty) return own;
    final candidates = [
      for (final g in nodeGroups)
        if (g.name == defaultGroup && g.id != group.id) g,
      for (final g in nodeGroups)
        if (!g.profile && g.id != group.id) g,
    ];
    return candidates
            .map((g) => g.authKey.trim())
            .where((key) => key.isNotEmpty)
            .firstOrNull ??
        '';
  }

  /// Auth Key 方式没填 key 时不注入节点（没有可用的注册方式）。
  bool groupAuthKeyMissing(TailscaleGroup group) =>
      group.useAuthKey && effectiveAuthKey(group).isEmpty;

  /// 策略组在本次运行配置中生效：内置节点开启、由 Bettbox 管理、注册方式可用。
  bool groupActive(TailscaleGroup group) =>
      nodeEnable && group.managed && !groupAuthKeyMissing(group);

  List<TailscaleGroup> get activeGroups =>
      nodeGroups.where(groupActive).toList();

  /// 内置节点模式开启。是否真有可用节点（自己添加的组或配置文件里的节点）由内核决定，
  /// 一个都没有时不生成 Tailnet 兜底规则。
  bool get nodeActive => nodeEnable;

  /// 明确指定了这台设备的组（包括默认组），未指定时为 null。
  TailscaleGroup? assignedGroupOfPeer(TailscalePeer peer) => nodeGroups
      .where((g) => g.proxyDevices.any((device) => device.matchesPeer(peer)))
      .firstOrNull;

  /// 把设备指定给某个组（同一台设备只在一个组里）。默认组也可以明确指定，规则同样排在兜底规则之前；
  /// groupName 为 null 时取消指定，交回默认组兜底。
  TailscaleProps assignPeer(TailscalePeer peer, String? groupName) =>
      assignDevice(TailscaleProxyDevice.fromPeer(peer), groupName);

  TailscaleProps assignDevice(TailscaleProxyDevice device, String? groupName) {
    if (device.isEmpty) return this;
    final updated = [
      for (final group in nodeGroups)
        () {
          final rest = [
            for (final d in group.proxyDevices)
              if (!d.matches(device)) d.encoded,
          ];
          final add = groupName != null && group.name == groupName;
          return group.copyWith(devices: [...rest, if (add) device.encoded]);
        }(),
    ];
    return withGroups(updated);
  }

  /// 设备 IP 变化时按 DNS 名用最新状态更新，返回 null 表示无变化。
  TailscaleProps? syncProxyPeers(List<TailscalePeer> peers) {
    var changed = false;
    final updated = [
      for (final group in nodeGroups)
        group.copyWith(
          devices: [
            for (final device in group.proxyDevices)
              () {
                final peer = device.dnsName.isEmpty
                    ? null
                    : peers
                          .where(
                            (p) =>
                                normalizeTailscaleDomain(p.dnsName) ==
                                device.dnsName,
                          )
                          .firstOrNull;
                if (peer != null &&
                    peer.ips.isNotEmpty &&
                    peer.ips.join(',') != device.ips.join(',')) {
                  changed = true;
                  return TailscaleProxyDevice.fromPeer(peer).encoded;
                }
                return device.encoded;
              }(),
          ],
        ),
    ];
    return changed ? withGroups(updated) : null;
  }

  /// 新建策略组用的唯一名称与身份目录标识。
  TailscaleGroup newGroup(String name) {
    final ids = {for (final g in nodeGroups) g.id};
    final base = 'g-${tailscaleSlug(name)}';
    var id = base;
    for (var i = 2; ids.contains(id); i++) {
      id = '$base-$i';
    }
    // 沿用上一个自己添加的组的接入方式，第一个组默认浏览器登录。
    final last = nodeGroups.where((g) => !g.profile).lastOrNull;
    return TailscaleGroup(
      id: id,
      name: name,
      useAuthKey: last?.useAuthKey ?? false,
      acceptRoutes: last?.acceptRoutes ?? true,
    );
  }

  /// 任一方式开启：内核补充 Tailscale 服务域名真实 IP、Tailnet 域名 DNS 与前置规则。
  bool get active => appActive || nodeActive;

  /// 仅 App 共存生效时才让 Tailnet 绕开 TUN；内置节点需要 TUN 把 100.x 流量交给内核。
  bool get appRouting => appActive && !nodeActive;

  /// 策略组在 Tailnet 中的设备名，留空时自动生成：新建的组为「本机名-组标识」；旧版迁移来的主节点
  /// （id 为空）仍是「本机名-bettbox」，旧代理通道为「本机名-bettbox-proxy」，保持原设备名。
  /// Auth Key 方式加 `-key` 后缀：两种方式是两台设备，同名时后注册的会被控制面改成 `-1`，
  /// 离线设备也会一直占着名字。
  String effectiveHostname(TailscaleGroup group) {
    var base = group.hostname.trim();
    if (base.isEmpty) {
      if (group.id.isEmpty) {
        // 旧版主节点：设备名固定为「本机名-bettbox」。
        base = '$_machineHostname-bettbox';
      } else {
        final custom = _customHostnameBase;
        final host = custom ?? _machineHostname;
        if (group.id == tailscaleLegacyProxyStateId) {
          // 旧版代理通道：沿用主节点设备名加 -proxy。
          base = custom == null ? '$host-bettbox-proxy' : '$host-proxy';
        } else {
          final suffix = group.id.replaceFirst(RegExp(r'^[gp]-'), '');
          base = '$host-${suffix.isEmpty ? tailscaleSlug(group.name) : suffix}';
        }
      }
    }
    if (!group.useAuthKey || base.endsWith('-key')) return base;
    return '$base-key';
  }

  /// 第一个自己添加的组手动填过的设备名（其他组留空时在它后面加后缀），都没填时为 null。
  String? get _customHostnameBase {
    for (final g in nodeGroups) {
      if (g.profile) continue;
      final name = g.hostname.trim();
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  String get _machineHostname {
    var host = 'bettbox';
    try {
      host = Platform.localHostname;
    } catch (_) {}
    if (host.endsWith('.local')) host = host.substring(0, host.length - 6);
    if (system.isAndroid || host.isEmpty || host == 'localhost') {
      host = system.isAndroid ? 'android' : 'desktop';
    }
    final sanitized = host
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return sanitized.isEmpty ? 'device' : sanitized;
  }

  /// 把 Tailnet 网段并入 TUN 排除路由（桌面端 TUN 的 route-exclude-address）。
  Tun applyToTun(Tun tun) {
    if (nodeActive) {
      // 内置节点需要 Tailnet 流量进 TUN：去掉手动加过的 Tailnet 排除网段（内核还会按网段重叠再清理一次）。
      final tailnet = {for (final a in routeExcludeAddress) a.trim()};
      final kept = tun.routeExcludeAddress
          .where((address) => !tailnet.contains(address.trim()))
          .toList();
      if (kept.length == tun.routeExcludeAddress.length) return tun;
      return tun.copyWith(routeExcludeAddress: kept);
    }
    if (!appRouting) return tun;
    final addresses = {
      ...tun.routeExcludeAddress,
      for (final address in routeExcludeAddress)
        if (address.trim().isNotEmpty) address.trim(),
    }.toList();
    return tun.copyWith(routeExcludeAddress: addresses);
  }

  Map<String, dynamic>? get patchJson => active
      ? {
          'dns-domains': dnsDomains,
          'dns-server': dnsServer.trim(),
          if (nodeActive) ...{
            'ranges': routeExcludeAddress,
            // 内置节点模式：一个节点都没有时内核不把 MagicDNS 交给 100.100.100.100。
            'node-mode': true,
            // 手动指定的默认组（可空）；内核按「它 → 配置文件里第一个 Tailscale 节点 → 第一个注入的组」选定。
            'default-node': defaultGroup.trim(),
            // 所有已保存的组名：当前配置里不存在的，指向它们的前置规则由内核去掉。
            'groups': [for (final g in nodeGroups) g.name],
            'nodes': [
              for (final group in activeGroups)
                {
                  'name': group.name,
                  'state-id': group.id,
                  if (group.profile) 'override': true,
                  'hostname': effectiveHostname(group),
                  'auth-mode': group.useAuthKey ? 'auth-key' : 'login',
                  if (group.useAuthKey) 'auth-key': effectiveAuthKey(group),
                  'exit-node': group.exitNode.trim(),
                  'accept-routes': group.acceptRoutes,
                  if (group.via.trim().isNotEmpty)
                    'dialer-proxy': group.via.trim(),
                },
            ],
          },
        }
      : null;

  /// 恢复默认值，保留开关状态与策略组（接入方式、key、设备与规则）。
  TailscaleProps reset() => defaultTailscaleProps.copyWith(
    enable: enable,
    nodeEnable: nodeEnable,
    nodeHostname: nodeHostname,
    nodeAuthKey: nodeAuthKey,
    nodeUseAuthKey: nodeUseAuthKey,
    nodeExitNode: nodeExitNode,
    nodeAcceptRoutes: nodeAcceptRoutes,
    nodeProxyDevices: nodeProxyDevices,
    nodeProxyVia: nodeProxyVia,
    groups: groups,
    defaultGroup: defaultGroup,
    groupsVersion: groupsVersion,
  );

  /// 内置节点开启时，系统代理例外里的 Tailnet 条目会让浏览器等走系统代理的应用直连 Tailnet，
  /// 没有 Tailscale App 时连不上，这里去掉（只影响生效值，不改用户设置）。
  bool isTailnetBypass(String entry) {
    final value = entry.trim();
    if (value.isEmpty) return false;
    if (bypassDomain.contains(value) || routeExcludeAddress.contains(value)) {
      return true;
    }
    final host = normalizeTailscaleDomain(value);
    return dnsDomains.any((item) {
      final domain = normalizeTailscaleDomain(item);
      return domain.isNotEmpty && (host == domain || host.endsWith('.$domain'));
    });
  }

  /// App 共存：Tailnet 直连（由系统路由交给 App）；内置节点：转给内核里的 Tailscale 节点。
  List<String> get prependRules {
    // 内置节点模式下兜底规则的目标是占位名，由内核换成实际选定的默认组；没有可用节点时内核去掉这些规则。
    final target = nodeActive ? tailscaleDefaultTarget : 'DIRECT';
    return [
      // 各组的设备规则与自定义规则按列表顺序排在兜底规则之前，不会被兜底规则覆盖。
      if (nodeActive)
        for (final group in activeGroups) ...group.prependRules,
      for (final domain in dnsDomains)
        if (normalizeTailscaleDomain(domain) case final d when d.isNotEmpty)
          'DOMAIN-SUFFIX,$d,$target',
      for (final address in routeExcludeAddress)
        if (address.trim().isNotEmpty)
          '${address.contains(':') ? 'IP-CIDR6' : 'IP-CIDR'},${address.trim()},$target,no-resolve',
    ];
  }
}

// BETTBOX-CUSTOM: 内核返回的内置 Tailscale 节点状态。
class TailscaleNodeStatus {
  const TailscaleNodeStatus({
    this.state = '',
    this.authUrl = '',
    this.dnsName = '',
    this.loginName = '',
    this.ips = const [],
    this.error = '',
    this.peers = const [],
  });

  factory TailscaleNodeStatus.fromJson(Map<String, dynamic> json) {
    return TailscaleNodeStatus(
      state: json['state'] as String? ?? '',
      authUrl: json['auth-url'] as String? ?? '',
      dnsName: json['dns-name'] as String? ?? '',
      loginName: json['login-name'] as String? ?? '',
      ips: (json['ips'] as List?)?.whereType<String>().toList() ?? const [],
      error: json['error'] as String? ?? '',
      peers:
          (json['peers'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(TailscalePeer.fromJson)
              .toList() ??
          const [],
    );
  }

  final String state;
  final String authUrl;
  final String dnsName;
  final String loginName;
  final List<String> ips;
  final String error;
  final List<TailscalePeer> peers;

  bool get running => state == 'Running';

  bool get needsLogin => state == 'NeedsLogin' && authUrl.isNotEmpty;
}

/// Tailnet 中的其他设备（内核 `TailscalePeer`）。
class TailscalePeer {
  const TailscalePeer({
    this.hostName = '',
    this.dnsName = '',
    this.os = '',
    this.ips = const [],
    this.online = false,
    this.active = false,
    this.exitNode = false,
    this.curAddr = '',
    this.relay = '',
  });

  factory TailscalePeer.fromJson(Map<String, dynamic> json) {
    return TailscalePeer(
      hostName: json['host-name'] as String? ?? '',
      dnsName: json['dns-name'] as String? ?? '',
      os: json['os'] as String? ?? '',
      ips: (json['ips'] as List?)?.whereType<String>().toList() ?? const [],
      online: json['online'] as bool? ?? false,
      active: json['active'] as bool? ?? false,
      exitNode: json['exit-node'] as bool? ?? false,
      curAddr: json['cur-addr'] as String? ?? '',
      relay: json['relay'] as String? ?? '',
    );
  }

  final String hostName;
  final String dnsName;
  final String os;
  final List<String> ips;
  final bool online;
  final bool active;
  final bool exitNode;
  final String curAddr;
  final String relay;

  /// 优先显示 MagicDNS 名（去掉 tailnet 后缀），与管理后台一致。
  String get displayName {
    final short = dnsName.split('.').first;
    return short.isNotEmpty ? short : hostName;
  }
}

String normalizeTailscaleDomain(String domain) {
  var value = domain.trim().toLowerCase();
  for (final prefix in const ['+.', '*.', '.']) {
    if (value.startsWith(prefix)) value = value.substring(prefix.length);
  }
  if (value.endsWith('.')) value = value.substring(0, value.length - 1);
  return value;
}

extension NetworkPropsExt on NetworkProps {
  /// 系统代理实际绕过列表：开启 Tailscale 共存时追加 Tailnet 例外。
  List<String> get realBypassDomain {
    if (tailscale.nodeActive) {
      return bypassDomain.where((e) => !tailscale.isTailnetBypass(e)).toList();
    }
    if (!tailscale.appRouting) return bypassDomain;
    return {...bypassDomain, ...tailscale.bypassDomain}.toList();
  }

  List<String> get realBypassPrivateRouteAddress {
    if (bypassPrivateRouteAddress.isNotEmpty) return bypassPrivateRouteAddress;
    return system.isDesktop
        ? defaultDesktopBypassPrivateRouteAddress
        : defaultBypassPrivateRouteAddress;
  }
}

@freezed
abstract class ProxiesStyle with _$ProxiesStyle {
  const factory ProxiesStyle({
    @Default(ProxiesType.tab) ProxiesType type,
    @Default(ProxiesSortType.none) ProxiesSortType sortType,
    @Default(ProxiesLayout.standard) ProxiesLayout layout,
    @Default(ProxiesIconStyle.none) ProxiesIconStyle iconStyle,
    @Default(ProxyCardType.expand) ProxyCardType cardType,
    @Default(DelayAnimationType.pulse) DelayAnimationType delayAnimation,
    @Default(true) bool syncDelayAnimation,
    @Default({}) Map<String, String> iconMap,
    @Default(maxDelayTestConcurrency)
    @JsonKey(fromJson: concurrencyLimitFromJson)
    int concurrencyLimit,
    @Default(false) bool autoStickyHeader,
    @Default(false) bool showHiddenItems,
    @Default(false) bool hideTimeoutProxies,
    @Default(false) bool hasCustomizedStyle,
  }) = _ProxiesStyle;

  factory ProxiesStyle.fromJson(Map<String, Object?>? json) =>
      json == null ? defaultProxiesStyle : _$ProxiesStyleFromJson(json);
}

@freezed
abstract class TextScale with _$TextScale {
  const factory TextScale({
    @Default(false) bool enable,
    @Default(1.0) double scale,
  }) = _TextScale;

  factory TextScale.fromJson(Map<String, Object?> json) =>
      _$TextScaleFromJson(json);
}

@freezed
abstract class ThemeProps with _$ThemeProps {
  const factory ThemeProps({
    int? primaryColor,
    @Default(defaultPrimaryColors) List<int> primaryColors,
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default(DynamicSchemeVariant.content) DynamicSchemeVariant schemeVariant,
    @Default(false) bool pureBlack,
    @Default(TextScale()) TextScale textScale,
    @Default(false) bool useDarkIcon,
    @Default(false) bool useHarmonyFont,
    @Default(false) bool invertTrayIcon,
  }) = _ThemeProps;

  factory ThemeProps.fromJson(Map<String, Object?> json) =>
      _$ThemePropsFromJson(json);

  factory ThemeProps.safeFromJson(Map<String, Object?>? json) {
    if (json == null) {
      return defaultThemeProps;
    }
    try {
      return ThemeProps.fromJson(json);
    } catch (_) {
      return defaultThemeProps;
    }
  }
}

@freezed
abstract class ScriptProps with _$ScriptProps {
  const factory ScriptProps({@Default([]) List<Script> scripts}) = _ScriptProps;

  factory ScriptProps.fromJson(Map<String, Object?> json) =>
      _$ScriptPropsFromJson(json);
}

extension ScriptPropsExt on ScriptProps {
  Script? findScript(String? id) =>
      scripts.where((script) => script.id == id).firstOrNull;

  Script? scriptOf(Profile profile) =>
      profile.isManaged ? null : findScript(profile.scriptId);

  Future<ScriptProps> externalize() async {
    if (scripts.every((script) => script.content.isEmpty)) return this;
    final next = <Script>[];
    for (final script in scripts) {
      if (script.content.isEmpty) {
        next.add(script);
        continue;
      }
      try {
        next.add(await script.writeContent(script.content));
      } catch (e) {
        commonPrint.error('Failed to store script ${script.label}: $e');
        next.add(script);
      }
    }
    return copyWith(scripts: next);
  }
}

@freezed
abstract class CustomRoute with _$CustomRoute {
  const factory CustomRoute({
    required String id,
    required String name,
    String? icon,
    @Default([]) List<String> sets,
    String? target,
    @Default(true) bool enabled,
  }) = _CustomRoute;

  factory CustomRoute.fromJson(Map<String, Object?> json) =>
      _$CustomRouteFromJson(json);
}

@freezed
abstract class ManagedProps with _$ManagedProps {
  const factory ManagedProps({
    @Default({}) Map<String, bool> options,
    String? syncedVersion,
    @Default([]) List<CustomRoute> routes,
    @Default([]) List<String> order,
    @Default([]) List<String> removed,
  }) = _ManagedProps;

  factory ManagedProps.fromJson(Map<String, Object?> json) =>
      _$ManagedPropsFromJson(json);
}

@freezed
abstract class Config with _$Config {
  const factory Config({
    @JsonKey(fromJson: AppSettingProps.safeFromJson)
    @Default(defaultAppSettingProps)
    AppSettingProps appSetting,
    @Default([]) List<Profile> profiles,
    @Default([]) List<HotKeyAction> hotKeyActions,
    String? currentProfileId,
    @Default(false) bool overrideNtp,
    @Default(false) bool overrideSniffer,
    @Default(false) bool overrideTunnel,
    @Default(false) bool overrideExperimental,
    @Default(true) bool overrideTestUrl,
    DAV? dav,
    @Default(defaultNetworkProps) NetworkProps networkProps,
    @JsonKey(fromJson: VpnProps.safeFromJson)
    @Default(defaultVpnProps)
    VpnProps vpnProps,
    @JsonKey(fromJson: ThemeProps.safeFromJson) required ThemeProps themeProps,
    @Default(defaultProxiesStyle) ProxiesStyle proxiesStyle,
    @Default(defaultTrafficStatsProps) TrafficStatsProps trafficStatsProps,
    @Default(defaultWindowProps) WindowProps windowProps,
    @JsonKey(fromJson: ClashConfig.safeFormJson)
    @Default(defaultClashConfig)
    ClashConfig patchClashConfig,
    @Default(ScriptProps()) ScriptProps scriptProps,
    @Default(ManagedProps()) ManagedProps managedProps,
    @Default('') String nodeExcludeFilter,
    @Default(5000) int healthCheckTimeout,
  }) = _Config;

  factory Config.fromJson(Map<String, Object?> json) => _$ConfigFromJson(json);

  factory Config.compatibleFromJson(Map<String, Object?> json) {
    try {
      final accessControlMap = json['accessControl'];
      final isAccessControl = json['isAccessControl'];
      if (accessControlMap != null) {
        (accessControlMap as Map)['enable'] = isAccessControl;
        if (json['vpnProps'] != null) {
          (json['vpnProps'] as Map)['accessControl'] = accessControlMap;
        }
      }
    } catch (_) {}

    // Migrate legacy AccessControl sort values: 'name' -> 'none', 'time' -> 'updateTime'
    try {
      void migrateSort(dynamic accessControl) {
        if (accessControl is Map) {
          final sort = accessControl['sort'];
          if (sort == 'name') {
            accessControl['sort'] = 'none';
          } else if (sort == 'time') {
            accessControl['sort'] = 'updateTime';
          }
        }
      }

      migrateSort(json['accessControl']);
      if (json['vpnProps'] is Map) {
        migrateSort((json['vpnProps'] as Map)['accessControl']);
      }
    } catch (_) {}

    // Migrate legacy int profile IDs to string
    try {
      final currentProfileId = json['currentProfileId'];
      if (currentProfileId != null && currentProfileId is int) {
        json['currentProfileId'] = currentProfileId.toString();
      }
    } catch (_) {}

    try {
      final profiles = json['profiles'];
      if (profiles != null && profiles is List) {
        for (final profile in profiles) {
          if (profile is Map) {
            final id = profile['id'];
            if (id != null && id is int) {
              profile['id'] = id.toString();
            }
          }
        }
      }
    } catch (_) {}

    try {
      final scriptProps = json['scriptProps'];
      final profiles = json['profiles'];
      if (scriptProps is Map && profiles is List) {
        final currentId = scriptProps.remove('currentId');
        for (final profile in profiles) {
          if (profile is! Map) continue;
          final enabled = profile.remove('useScriptOverride') != false;
          if (currentId is String &&
              enabled &&
              profile['scriptId'] == null &&
              profile['bundle'] == null) {
            profile['scriptId'] = currentId;
          }
        }
      }
    } catch (_) {}

    try {
      final themeProps = json['themeProps'];
      if (themeProps is Map &&
          themeProps['primaryColor'] != legacyPrimaryColors.last) {
        final colors = themeProps['primaryColors'];
        if (colors is List &&
            intListEquality.equals(colors.cast<int>(), legacyPrimaryColors)) {
          themeProps.remove('primaryColors');
        }
      }
    } catch (_) {}

    return Config.fromJson(json);
  }
}

extension ConfigExt on Config {
  Profile? get currentProfile {
    return profiles.getProfile(currentProfileId);
  }
}

Map<String, Object?> webDavSharedConfigJson(Config config) {
  return {
    'profiles': config.profiles
        .map(
          (profile) => profile.copyWith(
            currentGroupName: null,
            selectedMap: const {},
            unfoldSet: const {},
            // 上游 1.19.8 起覆写脚本按订阅选择（Profile.scriptId），仍属本机选择。
            scriptId: null,
          ),
        )
        .toList(),
    'scriptProps': config.scriptProps,
  };
}

List<Profile> mergeWebDavProfiles(List<Profile> incoming, List<Profile> local) {
  final localById = {for (final profile in local) profile.id: profile};
  return incoming.map((profile) {
    final localProfile = localById[profile.id];
    if (localProfile == null) return profile;
    return profile.copyWith(
      currentGroupName: localProfile.currentGroupName,
      selectedMap: localProfile.selectedMap,
      unfoldSet: localProfile.unfoldSet,
      scriptId: localProfile.scriptId,
    );
  }).toList();
}
