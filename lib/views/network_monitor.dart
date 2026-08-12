import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/common/external_control.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/connection/item.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'network_monitor_data.dart';

part 'network_monitor_detail.dart';
part 'network_monitor_mobile.dart';
part 'network_monitor_rule.dart';

const _monitorSubStoreUrlsKey = 'network_monitor_sub_store_urls';
const _monitorSubStoreApiKeysKey = 'network_monitor_sub_store_api_keys';

Future<Map<String, Object?>> _addMonitorOverrideRule(
  WidgetRef ref,
  Map<String, Object?> arguments,
) async {
  final value = arguments['rule']?.toString().trim() ?? '';
  if (value.isEmpty) throw StateError('规则不能为空');
  final type = arguments['type'] == OverrideRuleType.override.name
      ? OverrideRuleType.override
      : OverrideRuleType.added;
  final force = arguments['force'] == true;
  final profileId = ref.read(currentProfileIdProvider);
  final profile = ref.read(profilesProvider).getProfile(profileId);
  if (profileId == null || profile == null) throw StateError('当前没有可用配置');

  var rule = profile.overrideData.rule;
  var rules = type == OverrideRuleType.override
      ? [...rule.overrideRules]
      : [...rule.addedRules];
  if (type == OverrideRuleType.override && rules.isEmpty) {
    final raw = await globalState.getProfileConfig(profileId);
    rules = [...ClashConfigSnippet.fromJson(raw).rule];
  }
  final duplicate = rules.any((item) => item.value.trim() == value);
  if (duplicate && !force) return {'duplicate': true};
  rules.insert(0, Rule.value(value));
  rule = type == OverrideRuleType.override
      ? rule.copyWith(type: type, overrideRules: rules)
      : rule.copyWith(type: type, addedRules: rules);
  ref
      .read(profilesProvider.notifier)
      .updateProfile(
        profileId,
        (item) =>
            item.copyWith(overrideData: item.overrideData.copyWith(rule: rule)),
      );
  globalState.appController.setupClashConfigDebounce();
  return {'duplicate': duplicate, 'added': true};
}

Future<Map<String, Object?>> _monitorSubStoreHistory() async {
  final prefs = await preferences.sharedPreferencesCompleter.future;
  return {
    'urls': prefs?.getStringList(_monitorSubStoreUrlsKey) ?? const <String>[],
    'keys':
        prefs?.getStringList(_monitorSubStoreApiKeysKey) ?? const <String>[],
  };
}

Future<void> _saveMonitorSubStoreHistory(String url, String apiKey) async {
  final prefs = await preferences.sharedPreferencesCompleter.future;
  if (prefs == null) return;
  List<String> updated(String key, String value) {
    final values = prefs.getStringList(key) ?? <String>[];
    values.remove(value);
    values.insert(0, value);
    return values.take(10).toList();
  }

  await prefs.setStringList(
    _monitorSubStoreUrlsKey,
    updated(_monitorSubStoreUrlsKey, url),
  );
  await prefs.setStringList(
    _monitorSubStoreApiKeysKey,
    updated(_monitorSubStoreApiKeysKey, apiKey),
  );
}

Future<String> _monitorHttpBody(HttpClientResponse response) =>
    response.transform(utf8.decoder).join();

String _monitorSubStoreError(String body, int statusCode) {
  try {
    final data = normalizeMonitorMap(jsonDecode(body));
    final error = normalizeMonitorMap(data['error'] ?? const {});
    return error['message']?.toString() ?? 'HTTP $statusCode';
  } catch (_) {
    return 'HTTP $statusCode';
  }
}

Future<String> _readMonitorSubStoreScript(String url, String apiKey) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final response = await (await client.getUrl(
      monitorSubStoreFileApiUri(url, apiKey, wholeFile: true),
    )).close();
    final body = await _monitorHttpBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_monitorSubStoreError(body, response.statusCode));
    }
    final payload = normalizeMonitorMap(jsonDecode(body));
    final file = normalizeMonitorMap(payload['data'] ?? const {});
    return file['content']?.toString() ??
        (throw StateError('Sub-Store 文件响应缺少 content'));
  } finally {
    client.close(force: true);
  }
}

Future<void> _writeMonitorSubStoreScript(
  String url,
  String apiKey,
  String script,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.patchUrl(
      monitorSubStoreFileApiUri(url, apiKey, wholeFile: false),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'content': script}));
    final response = await request.close();
    final body = await _monitorHttpBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_monitorSubStoreError(body, response.statusCode));
    }
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, Object?>> _appendMonitorSubStoreRule(
  Map<String, Object?> arguments,
) async {
  final url = arguments['url']?.toString().trim() ?? '';
  final apiKey = arguments['apiKey']?.toString().trim() ?? '';
  final rule = arguments['rule']?.toString().trim() ?? '';
  if (url.isEmpty || apiKey.isEmpty || rule.isEmpty) {
    throw StateError('文件地址、API Key 和规则不能为空');
  }
  final script = await _readMonitorSubStoreScript(url, apiKey);
  await _writeMonitorSubStoreScript(
    url,
    apiKey,
    monitorAppendSubStoreRule(script, rule),
  );
  await _saveMonitorSubStoreHistory(url, apiKey);
  return {'added': true};
}

Future<Map<String, Object?>> _readMonitorSubStoreRules(
  Map<String, Object?> arguments,
) async {
  final url = arguments['url']?.toString().trim() ?? '';
  final apiKey = arguments['apiKey']?.toString().trim() ?? '';
  if (url.isEmpty || apiKey.isEmpty) {
    throw StateError('文件地址和 API Key 不能为空');
  }
  final rules = monitorReadSubStoreRules(
    await _readMonitorSubStoreScript(url, apiKey),
  );
  await _saveMonitorSubStoreHistory(url, apiKey);
  return {
    'rules': [
      for (final item in rules) {'rule': item.rule, 'note': item.note},
    ],
  };
}

Future<Map<String, Object?>> _replaceMonitorSubStoreRules(
  Map<String, Object?> arguments,
) async {
  final url = arguments['url']?.toString().trim() ?? '';
  final apiKey = arguments['apiKey']?.toString().trim() ?? '';
  final rules = (arguments['rules'] as List? ?? const []).map((item) {
    final value = normalizeMonitorMap(item);
    return (
      rule: value['rule']?.toString().trim() ?? '',
      note: value['note']?.toString().trim() ?? '',
    );
  }).toList();
  if (url.isEmpty || apiKey.isEmpty) {
    throw StateError('文件地址和 API Key 不能为空');
  }
  if (rules.any((item) => item.rule.isEmpty)) throw StateError('规则不能为空');
  final latest = await _readMonitorSubStoreScript(url, apiKey);
  await _writeMonitorSubStoreScript(
    url,
    apiKey,
    monitorReplaceSubStoreRules(latest, rules),
  );
  await _saveMonitorSubStoreHistory(url, apiKey);
  return {'updated': true};
}

String _monitorStatusLabel(MonitorTrackerStatus status) => switch (status) {
  MonitorTrackerStatus.failed => '失败',
  MonitorTrackerStatus.blocked => '已拦截',
  MonitorTrackerStatus.connecting => '建立中',
  MonitorTrackerStatus.connected => '已连接',
  MonitorTrackerStatus.closed => '已结束',
  MonitorTrackerStatus.unknown => '未知',
};

Color _monitorStatusColor(BuildContext context, MonitorTrackerStatus status) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    MonitorTrackerStatus.failed || MonitorTrackerStatus.blocked =>
      dark ? const Color(0xFFFF6B6B) : const Color(0xFFB42318),
    MonitorTrackerStatus.connecting =>
      dark ? const Color(0xFFFFC247) : const Color(0xFF8A5700),
    MonitorTrackerStatus.connected =>
      dark ? const Color(0xFF64B5F6) : const Color(0xFF146CB8),
    MonitorTrackerStatus.closed =>
      dark ? const Color(0xFF69D17D) : const Color(0xFF237A3B),
    MonitorTrackerStatus.unknown => Theme.of(context).colorScheme.outline,
  };
}

TextSpan _monitorCompactTextSpan(String value, {TextStyle? style}) {
  return TextSpan(text: monitorCompactWhitespace(value), style: style);
}

Widget _compactMonitorText(
  String value, {
  int? maxLines,
  TextOverflow? overflow,
}) => Text.rich(
  _monitorCompactTextSpan(value),
  maxLines: maxLines,
  overflow: overflow,
);

Future<void> openNetworkMonitorWindow() => networkMonitorProcess.open();

Future<List<Map<String, Object?>>> _readMonitorDnsSnapshot(
  WidgetRef ref,
) async {
  final rawConfig = await globalState.patchRawConfig(
    patchConfig: ref.read(patchClashConfigProvider),
  );
  var systemHosts = '';
  if (system.isMacOS || system.isLinux) {
    final file = File('/etc/hosts');
    if (await file.exists()) systemHosts = await file.readAsString();
  }
  return monitorConfiguredDnsEntries(
    rawConfig,
    systemHosts,
  ).map((item) => item.toJson()).toList();
}

Future<void> runNetworkMonitorProcess() async {
  await windowManager.ensureInitialized();
  await windowManager.setTitleBarStyle(TitleBarStyle.normal);
  if (system.isWindows) {
    await windowManager.setIcon(
      '${appPath.appDirPath}/data/flutter_assets/assets/images/network_monitor_icon.ico',
    );
  } else if (system.isLinux) {
    await windowManager.setIcon(
      '${appPath.appDirPath}/data/flutter_assets/assets/images/network_monitor_icon.png',
    );
  }
  const options = WindowOptions(
    size: Size(1280, 760),
    minimumSize: Size(900, 560),
    center: true,
    title: 'Bettbox 网络面板',
    titleBarStyle: TitleBarStyle.normal,
  );
  unawaited(
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    }),
  );
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((
    command,
  ) {
    if (command == 'show') {
      unawaited(() async {
        await windowManager.show();
        await windowManager.focus();
      }());
    } else if (command == 'exit') {
      exit(0);
    }
  }, onDone: () => exit(0));
  runApp(const ProviderScope(child: NetworkMonitorApp()));
}

class NetworkMonitorHost extends ConsumerStatefulWidget {
  final Widget child;

  const NetworkMonitorHost({super.key, required this.child});

  @override
  ConsumerState<NetworkMonitorHost> createState() => _NetworkMonitorHostState();
}

class _NetworkMonitorHostState extends ConsumerState<NetworkMonitorHost> {
  final _snapshotReader = NetworkMonitorSnapshotReader();
  ProviderSubscription<List<TrackerInfo>>? _requestsSubscription;
  ProviderSubscription<Log?>? _logsSubscription;

  @override
  void initState() {
    super.initState();
    ExternalControl.setNetworkMonitorHandler(_handleMethodCall);
    _requestsSubscription = ref.listenManual(
      requestsProvider.select((state) => state.list),
      (_, _) => unawaited(_notifyDataChanged()),
    );
    _logsSubscription = ref.listenManual(
      logsProvider.select(
        (state) => state.list.isEmpty ? null : state.list.last,
      ),
      (_, _) => unawaited(_notifyDataChanged()),
    );
  }

  Future<void> _notifyDataChanged() async {
    await ExternalControl.notifyNetworkMonitorChanged();
  }

  @override
  void dispose() {
    _requestsSubscription?.close();
    _logsSubscription?.close();
    ExternalControl.setNetworkMonitorHandler(null);
    super.dispose();
  }

  Future<Map<String, Object?>> _snapshot({bool includeTraffic = false}) async {
    return _snapshotReader.read(
      requests: ref.read(requestsProvider).list,
      logs: ref.read(logsProvider).list,
      includeTraffic: includeTraffic,
    );
  }

  Future<Object?> _handleMethodCall(String method, Object? arguments) async {
    switch (method) {
      case 'snapshot':
        return _snapshot(includeTraffic: arguments == true);
      case 'connectionsSnapshot':
        return (await clashCore.getConnections())
            .map(monitorTrackerToJson)
            .toList();
      case 'dnsSnapshot':
        return _readMonitorDnsSnapshot(ref);
      case 'countryCode':
        return (await clashCore.getCountryCode(
              arguments as String,
            ))?.countryCode ??
            '';
      case 'rulePolicies':
        return monitorRulePolicies(ref.read(groupsProvider));
      case 'addOverrideRule':
        return _addMonitorOverrideRule(ref, normalizeMonitorMap(arguments));
      case 'subStoreRuleHistory':
        return _monitorSubStoreHistory();
      case 'appendSubStoreRule':
        return _appendMonitorSubStoreRule(normalizeMonitorMap(arguments));
      case 'readSubStoreRules':
        return _readMonitorSubStoreRules(normalizeMonitorMap(arguments));
      case 'replaceSubStoreRules':
        return _replaceMonitorSubStoreRules(normalizeMonitorMap(arguments));
      case 'flushDnsCache':
        return await clashCore.flushDnsCache() && await clashCore.flushFakeIP();
      case 'clearRequests':
        ref.read(requestsProvider.notifier).clearRequests();
        return true;
      case 'clearLogs':
        ref.read(logsProvider.notifier).clearLogs();
        return true;
      case 'closeConnection':
        clashCore.closeConnection(arguments as String);
        return true;
      case 'closeConnections':
        return clashCore.closeConnections();
      default:
        throw UnsupportedError('未知网络面板方法：$method');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class NetworkMonitorApp extends StatefulWidget {
  const NetworkMonitorApp({super.key});

  @override
  State<NetworkMonitorApp> createState() => _NetworkMonitorAppState();
}

class _NetworkMonitorAppState extends State<NetworkMonitorApp>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() => exit(0);

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0A84FF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bettbox 网络面板',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        fontFamily: 'HarmonyOS_Sans',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        fontFamily: 'HarmonyOS_Sans',
      ),
      home: const NetworkMonitorView(),
    );
  }
}

class NetworkMonitorToolsView extends StatelessWidget {
  final bool embedded;

  const NetworkMonitorToolsView({super.key, required this.embedded});

  static const _pages = <(MonitorPage, String, String, IconData, Color)>[
    (
      MonitorPage.requests,
      '最近请求',
      '查看 Mihomo 最近处理的连接',
      Icons.receipt_long_outlined,
      Colors.red,
    ),
    (MonitorPage.connections, '活动连接', '查看并关闭当前连接', Icons.link, Colors.green),
    (
      MonitorPage.dns,
      'DNS',
      '配置、Hosts 与运行时解析',
      Icons.dns_outlined,
      Colors.blue,
    ),
    (
      MonitorPage.devices,
      '设备',
      '按进程和来源查看连接',
      Icons.devices_outlined,
      Colors.teal,
    ),
    (
      MonitorPage.traffic,
      '流量统计',
      '实时速度、累计流量与策略统计',
      Icons.monitor_heart_outlined,
      Colors.orange,
    ),
    (
      MonitorPage.logs,
      '日志',
      '查看 Mihomo 内核运行日志',
      Icons.article_outlined,
      Colors.purple,
    ),
    (
      MonitorPage.subStore,
      'Sub-Store',
      '管理远端固定自定义规则',
      Icons.cloud_outlined,
      Colors.indigo,
    ),
  ];

  void _openPage(BuildContext context, MonitorPage page, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommonScaffold(
          title: title,
          body: NetworkMonitorView(
            embedded: embedded,
            mobile: true,
            initialPage: page,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: system.isDesktop ? 'Bettbox 网络面板' : '工具',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text('网络与诊断', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var index = 0; index < _pages.length; index++) ...[
                      ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _pages[index].$5.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _pages[index].$4,
                            color: _pages[index].$5,
                          ),
                        ),
                        title: Text(_pages[index].$2),
                        subtitle: Text(_pages[index].$3),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openPage(
                          context,
                          _pages[index].$1,
                          _pages[index].$2,
                        ),
                      ),
                      if (index != _pages.length - 1)
                        const Divider(height: 1, indent: 64),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NetworkMonitorView extends ConsumerStatefulWidget {
  final bool embedded;
  final bool mobile;
  final MonitorPage initialPage;

  const NetworkMonitorView({
    super.key,
    this.embedded = false,
    this.mobile = false,
    this.initialPage = MonitorPage.requests,
  });

  @override
  ConsumerState<NetworkMonitorView> createState() => _NetworkMonitorViewState();
}

class _NetworkMonitorViewState extends ConsumerState<NetworkMonitorView> {
  static const _detailHeightPreferenceKey = 'networkMonitor.detailHeight';
  final _snapshotReader = NetworkMonitorSnapshotReader();
  Timer? _fallbackTimer;
  Timer? _connectionsTimer;
  Timer? _trafficTimer;
  Timer? _eventRefreshTimer;
  StreamSubscription<void>? _networkMonitorSubscription;
  ProviderSubscription<List<TrackerInfo>>? _requestsSubscription;
  ProviderSubscription<Log?>? _logsSubscription;
  List<TrackerInfo> _requests = const [], _connections = const [];
  List<MonitorLog> _logs = const [];
  List<MonitorDnsEntry> _dnsSources = const [];
  MonitorPage _page = MonitorPage.requests;
  MonitorTrackerFacet _trackerFacet = MonitorTrackerFacet.process;
  TrackerInfo? _selected;
  String? _trackerFilter;
  String _sidebarFilter = '';
  String _query = '';
  int _trafficUp = 0;
  int _trafficDown = 0;
  int _totalTrafficUp = 0;
  int _totalTrafficDown = 0;
  int _detailTab = 0;
  double _detailHeight = 260;
  DateTime? _dnsCacheClearedAt;
  bool _loading = false;
  bool _connectionsLoading = false;
  bool _dnsLoading = false;
  bool _refreshPending = false;
  String? _error;
  final _detailScrollController = ScrollController();
  final Map<String, Future<String>> _countryCodes = {};

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _sidebarFilter = monitorDefaultSidebarFilter(_page);
    unawaited(_restorePreferences());
    if (widget.embedded) {
      _requestsSubscription = ref.listenManual(
        requestsProvider.select((state) => state.list),
        (_, _) => _handleDataChanged(),
      );
      _logsSubscription = ref.listenManual(
        logsProvider.select(
          (state) => state.list.isEmpty ? null : state.list.last,
        ),
        (_, _) => _handleDataChanged(),
      );
    } else {
      _networkMonitorSubscription = ExternalControl.networkMonitorChanges
          .listen((_) => _handleDataChanged());
    }
    unawaited(_refresh());
    if (_page == MonitorPage.dns) unawaited(_refreshDnsSources());
    _fallbackTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refresh());
    });
    _connectionsTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_page == MonitorPage.connections) {
        unawaited(_refreshConnections());
      }
    });
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_page == MonitorPage.traffic) unawaited(_refresh());
    });
  }

  void _handleDataChanged() {
    if (_eventRefreshTimer?.isActive == true) return;
    _eventRefreshTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_refresh()),
    );
  }

  void _update(VoidCallback change) => setState(change);

  Future<void> _restorePreferences() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    if (!mounted || prefs == null) return;
    final detailHeight = prefs.getDouble(_detailHeightPreferenceKey);
    if (detailHeight != null) setState(() => _detailHeight = detailHeight);
  }

  void _saveDetailHeight() {
    unawaited(() async {
      final prefs = await preferences.sharedPreferencesCompleter.future;
      await prefs?.setDouble(_detailHeightPreferenceKey, _detailHeight);
    }());
  }

  @override
  void dispose() {
    _networkMonitorSubscription?.cancel();
    _requestsSubscription?.close();
    _logsSubscription?.close();
    _fallbackTimer?.cancel();
    _connectionsTimer?.cancel();
    _trafficTimer?.cancel();
    _eventRefreshTimer?.cancel();
    _detailScrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading) {
      _refreshPending = true;
      return;
    }
    _loading = true;
    try {
      final raw = widget.embedded
          ? await _snapshotReader.read(
              requests: ref.read(requestsProvider).list,
              logs: ref.read(logsProvider).list,
              includeTraffic: _page == MonitorPage.traffic,
            )
          : await ExternalControl.request(
              'snapshot',
              _page == MonitorPage.traffic,
            );
      if (!mounted || raw == null) return;
      final map = normalizeMonitorMap(raw);
      var requests = (map['requests'] as List? ?? const [])
          .map((item) => TrackerInfo.fromJson(normalizeMonitorMap(item)))
          .toList();
      var connections = (map['connections'] as List? ?? const [])
          .map((item) => TrackerInfo.fromJson(normalizeMonitorMap(item)))
          .toList();
      final trackers = monitorRestoreProcessPaths([
        ...requests,
        ...connections,
      ]);
      requests = trackers.take(requests.length).toList();
      connections = trackers.skip(requests.length).toList();
      final logs = (map['logs'] as List? ?? const [])
          .map(MonitorLog.fromJson)
          .toList();
      final traffic = normalizeMonitorMap(map['traffic'] ?? const {});
      final totalTraffic = normalizeMonitorMap(map['totalTraffic'] ?? const {});
      setState(() {
        _requests = requests;
        _connections = connections;
        _logs = logs;
        _trafficUp = (traffic['up'] as num?)?.toInt() ?? 0;
        _trafficDown = (traffic['down'] as num?)?.toInt() ?? 0;
        _totalTrafficUp = (totalTraffic['up'] as num?)?.toInt() ?? 0;
        _totalTrafficDown = (totalTraffic['down'] as num?)?.toInt() ?? 0;
        _selected = monitorUpdatedSelection(_selected, requests, connections);
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '读取数据失败：$error');
    } finally {
      _loading = false;
      if (_refreshPending && mounted) {
        _refreshPending = false;
        unawaited(_refresh());
      }
    }
  }

  Future<void> _refreshConnections() async {
    if (_connectionsLoading) return;
    _connectionsLoading = true;
    try {
      final raw = widget.embedded
          ? await clashCore.getConnections()
          : await ExternalControl.request('connectionsSnapshot');
      if (!mounted || raw == null) return;
      final connections = widget.embedded
          ? raw as List<TrackerInfo>
          : (raw as List)
                .map((item) => TrackerInfo.fromJson(normalizeMonitorMap(item)))
                .toList();
      final trackers = monitorRestoreProcessPaths([
        ..._requests,
        ...connections,
      ]);
      final resolvedConnections = trackers.skip(_requests.length).toList();
      setState(() {
        _connections = resolvedConnections;
        _selected = monitorUpdatedSelection(
          _selected,
          _requests,
          resolvedConnections,
        );
      });
    } catch (error) {
      if (mounted) setState(() => _error = '读取活动连接失败：$error');
    } finally {
      _connectionsLoading = false;
    }
  }

  Future<bool> _invoke(String method, [Object? arguments]) async {
    try {
      if (widget.embedded) {
        switch (method) {
          case 'clearRequests':
            ref.read(requestsProvider.notifier).clearRequests();
          case 'clearLogs':
            ref.read(logsProvider.notifier).clearLogs();
          case 'closeConnection':
            clashCore.closeConnection(arguments as String);
          case 'closeConnections':
            await clashCore.closeConnections();
          case 'flushDnsCache':
            if (!await clashCore.flushDnsCache() ||
                !await clashCore.flushFakeIP()) {
              throw StateError('清除 DNS 缓存失败');
            }
        }
      } else {
        await ExternalControl.request(method, arguments);
      }
      await _refresh();
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = '操作失败：$error');
      return false;
    }
  }

  Future<String> _lookupCountryCode(String ip) {
    return _countryCodes.putIfAbsent(ip, () async {
      try {
        if (widget.embedded) {
          return (await clashCore.getCountryCode(ip))?.countryCode ?? '';
        }
        return (await ExternalControl.request('countryCode', ip))?.toString() ??
            '';
      } catch (_) {
        return '';
      }
    });
  }

  Future<void> _refreshDnsSources() async {
    if (_dnsLoading) return;
    _dnsLoading = true;
    try {
      final raw = widget.embedded
          ? await _readMonitorDnsSnapshot(ref)
          : await ExternalControl.request('dnsSnapshot');
      if (!mounted || raw == null) return;
      final list = raw as List;
      setState(() {
        _dnsSources = list.map(MonitorDnsEntry.fromJson).toList();
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '读取 DNS 配置失败：$error');
    } finally {
      _dnsLoading = false;
    }
  }

  Future<void> _reload() async {
    await _refresh();
    if (_page == MonitorPage.dns) await _refreshDnsSources();
  }

  List<TrackerInfo> get _pageTrackers => switch (_page) {
    MonitorPage.connections => _connections,
    _ => _requests,
  };

  List<TrackerInfo> get _allTrackers {
    final values = <String, TrackerInfo>{};
    for (final item in [..._requests, ..._connections]) {
      values[item.id] = item;
    }
    return values.values
        .where((item) => !monitorIsInternalTracker(item))
        .toList();
  }

  List<TrackerInfo> get _visibleTrackers {
    final query = _query.toLowerCase().trim();
    final activeIds = _connections.map((item) => item.id).toSet();
    final filtered = _pageTrackers.where((item) {
      if (monitorIsInternalTracker(item)) return false;
      final sideValue = monitorTrackerFacetValue(
        item,
        _trackerFacet,
        activeIds,
      );
      if (_trackerFilter != null && sideValue != _trackerFilter) return false;
      if (query.isEmpty) return true;
      return [
        item.id,
        monitorClientName(item),
        monitorRuleName(item),
        monitorPolicyName(item),
        monitorAddress(item),
        item.metadata.sourceIP,
        item.metadata.destinationIP,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    filtered.sort((a, b) => b.start.compareTo(a.start));
    return filtered;
  }

  Map<String, TrackerInfo> get _sidebarTrackers {
    final values = <String, TrackerInfo>{};
    final activeIds = _connections.map((item) => item.id).toSet();
    for (final item in _pageTrackers) {
      if (monitorIsInternalTracker(item)) continue;
      final value = monitorTrackerFacetValue(item, _trackerFacet, activeIds);
      if (value.isEmpty) continue;
      final currentPath = values[value]?.metadata.processPath ?? '';
      final nextPath = item.metadata.processPath;
      if (!values.containsKey(value) ||
          (currentPath.isEmpty && nextPath.isNotEmpty) ||
          (!currentPath.toLowerCase().contains('.app/') &&
              nextPath.toLowerCase().contains('.app/'))) {
        values[value] = item;
      }
    }
    return Map.fromEntries(
      values.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  List<MonitorDnsEntry> get _runtimeDnsEntries {
    final latest = <String, TrackerInfo>{};
    for (final item in _allTrackers) {
      if (_dnsCacheClearedAt != null &&
          !item.start.isAfter(_dnsCacheClearedAt!)) {
        continue;
      }
      final host = item.metadata.host.trim();
      if (host.isEmpty || monitorDnsAddress(item).isEmpty) continue;
      final previous = latest[host];
      if (previous == null || item.start.isAfter(previous.start)) {
        latest[host] = item;
      }
    }
    return latest.values
        .map(
          (item) => MonitorDnsEntry(
            source: '运行缓存',
            category: monitorDnsMode(item),
            name: item.metadata.host,
            value: monitorDnsAddress(item),
            detail: item.metadata.network.toUpperCase(),
            lastActivity: monitorClock(item.start),
          ),
        )
        .toList();
  }

  List<MonitorDnsEntry> get _dnsEntries => [
    ..._dnsSources,
    ..._runtimeDnsEntries,
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.mobile) return _buildMobileMonitor(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
              children: [
                if (_error != null) _buildError(context),
                Expanded(child: _buildMobilePage(context)),
                if (_page != MonitorPage.subStore) _buildActionBar(context),
                if (_selected != null) _buildDetail(context),
              ],
            );
            return Column(
              children: [
                _buildTopBar(context),
                const Divider(height: 1),
                Expanded(
                  child:
                      constraints.maxWidth < 720 ||
                          _page == MonitorPage.subStore
                      ? content
                      : Row(
                          children: [
                            _buildSidebar(context),
                            const VerticalDivider(width: 1),
                            Expanded(child: content),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    const labels = {
      MonitorPage.requests: '最近请求',
      MonitorPage.connections: '活动连接',
      MonitorPage.dns: 'DNS',
      MonitorPage.devices: '设备',
      MonitorPage.traffic: '流量统计',
      MonitorPage.logs: '日志',
      MonitorPage.subStore: 'Sub-Store',
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      for (final page in MonitorPage.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: _page == page
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer
                                  : null,
                              foregroundColor: _page == page
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _page = page;
                                _selected = null;
                                _trackerFilter = null;
                                _sidebarFilter = monitorDefaultSidebarFilter(
                                  page,
                                );
                              });
                              if (page == MonitorPage.dns) {
                                unawaited(_refreshDnsSources());
                              } else if (page == MonitorPage.traffic) {
                                unawaited(_refresh());
                              }
                            },
                            child: Text(labels[page]!),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (constraints.maxWidth >= 900 && _page != MonitorPage.subStore)
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 220,
                    height: 38,
                    child: TextField(
                      maxLines: 1,
                      textAlignVertical: TextAlignVertical.center,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '搜索',
                        prefixIcon: Icon(Icons.search, size: 20),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 9),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    if (_page != MonitorPage.requests && _page != MonitorPage.connections) {
      return _buildStaticSidebar(context);
    }
    final facetLabel = monitorTrackerFacetLabel(_trackerFacet);
    return Container(
      width: 220,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mihomo 字段', style: Theme.of(context).textTheme.labelMedium),
          DropdownButton<MonitorTrackerFacet>(
            value: _trackerFacet,
            isExpanded: true,
            items: [
              for (final facet in MonitorTrackerFacet.values)
                DropdownMenuItem(
                  value: facet,
                  child: Text(monitorTrackerFacetLabel(facet)),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _trackerFacet = value;
                _trackerFilter = null;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(facetLabel, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          _sidebarButton(
            context,
            label: '全部$facetLabel',
            selected: _trackerFilter == null,
            leading: _trackerFacetIcon(),
            onTap: () => setState(() => _trackerFilter = null),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildTrackerSidebarList(context)),
        ],
      ),
    );
  }

  Widget _buildTrackerSidebarList(BuildContext context) {
    final entries = _sidebarTrackers.entries.toList();
    return ListView.builder(
      itemCount: entries.length,
      itemExtent: 42,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final item = entry.value;
        return _sidebarButton(
          context,
          label: entry.key,
          selected: _trackerFilter == entry.key,
          leading: _trackerFacetIcon(item),
          onTap: () => setState(() => _trackerFilter = entry.key),
        );
      },
    );
  }

  Widget _trackerFacetIcon([TrackerInfo? item]) {
    if (_trackerFacet == MonitorTrackerFacet.process &&
        item != null &&
        system.isMacOS) {
      return ProcessIcon(
        key: ValueKey('${item.metadata.process}\n${item.metadata.processPath}'),
        process: item.metadata.process,
        processPath: item.metadata.processPath,
        size: 20,
      );
    }
    final icon = switch (_trackerFacet) {
      MonitorTrackerFacet.process => Icons.apps_outlined,
      MonitorTrackerFacet.source => Icons.lan_outlined,
      MonitorTrackerFacet.target => Icons.language_outlined,
      MonitorTrackerFacet.network => Icons.swap_horiz_outlined,
      MonitorTrackerFacet.rule => Icons.rule_outlined,
      MonitorTrackerFacet.outbound => Icons.alt_route_outlined,
      MonitorTrackerFacet.status => Icons.circle_outlined,
    };
    return Icon(icon, size: 18);
  }

  Widget _buildStaticSidebar(BuildContext context) {
    final sections = monitorStaticSidebarSections[_page] ?? const [];
    return Container(
      width: 220,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          for (
            var sectionIndex = 0;
            sectionIndex < sections.length;
            sectionIndex++
          ) ...[
            if (sectionIndex > 0) const SizedBox(height: 12),
            if (sections[sectionIndex].title.isNotEmpty) ...[
              Text(
                sections[sectionIndex].title,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
            ],
            for (final item in sections[sectionIndex].items)
              _sidebarButton(
                context,
                label: item,
                selected: _sidebarFilter == item,
                onTap: () => setState(() => _sidebarFilter = item),
              ),
          ],
        ],
      ),
    );
  }

  Widget _sidebarButton(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Widget? leading,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: selected
              ? BorderSide(color: Theme.of(context).colorScheme.primary)
              : BorderSide.none,
        ),
        child: ListTile(
          dense: true,
          minTileHeight: 38,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: leading,
          title: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return MaterialBanner(
      content: Text(_error!),
      actions: [TextButton(onPressed: _reload, child: const Text('重试'))],
    );
  }

  void _selectTracker(TrackerInfo item) => setState(() {
    _selected = item;
    _detailTab = 0;
  });

  Color _logColor(String level) => switch (level) {
    'error' => Colors.red,
    'warning' => Colors.orange,
    'debug' => Colors.blueGrey,
    _ => Colors.blue,
  };

  bool _matchesQuery(Iterable<Object?> values) {
    final query = _query.toLowerCase().trim();
    return query.isEmpty || values.join(' ').toLowerCase().contains(query);
  }
}
