import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/common/external_control.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'network_monitor_data.dart';

part 'network_monitor_detail.dart';

Future<void> openNetworkMonitorWindow() => networkMonitorProcess.open();

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
  ProviderSubscription<TrackerInfo?>? _requestsSubscription;
  ProviderSubscription<Log?>? _logsSubscription;

  @override
  void initState() {
    super.initState();
    ExternalControl.setNetworkMonitorHandler(_handleMethodCall);
    _requestsSubscription = ref.listenManual(
      requestsProvider.select(
        (state) => state.list.isEmpty ? null : state.list.last,
      ),
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
    ExternalControl.notifyNetworkMonitorChanged();
  }

  @override
  void dispose() {
    _requestsSubscription?.close();
    _logsSubscription?.close();
    ExternalControl.setNetworkMonitorHandler(null);
    super.dispose();
  }

  Future<Map<String, Object?>> _snapshot() async {
    return _snapshotReader.read(
      requests: ref.read(requestsProvider).list,
      logs: ref.read(logsProvider).list,
    );
  }

  Future<Object?> _handleMethodCall(String method, Object? arguments) async {
    switch (method) {
      case 'snapshot':
        return _snapshot();
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

class NetworkMonitorView extends ConsumerStatefulWidget {
  final bool embedded;

  const NetworkMonitorView({super.key, this.embedded = false});

  @override
  ConsumerState<NetworkMonitorView> createState() => _NetworkMonitorViewState();
}

class _NetworkMonitorViewState extends ConsumerState<NetworkMonitorView> {
  final _snapshotReader = NetworkMonitorSnapshotReader();
  Timer? _fallbackTimer;
  Timer? _connectionsTimer;
  StreamSubscription<void>? _networkMonitorSubscription;
  ProviderSubscription<TrackerInfo?>? _requestsSubscription;
  ProviderSubscription<Log?>? _logsSubscription;
  List<TrackerInfo> _requests = const [], _connections = const [];
  List<MonitorLog> _logs = const [];
  MonitorPage _page = MonitorPage.requests;
  MonitorClientMode _clientMode = MonitorClientMode.client;
  MonitorSortState _sort = const MonitorSortState(
    MonitorSortColumn.date,
    false,
  );
  TrackerInfo? _selected;
  String? _clientFilter;
  String _sidebarFilter = '';
  String _query = '';
  int _detailTab = 0;
  bool _loading = false;
  bool _refreshPending = false;
  String? _error;
  final _trackerVerticalController = ScrollController();
  final _trackerHorizontalController = ScrollController();
  final Map<MonitorSortColumn, double> _columnWidths = {
    MonitorSortColumn.id: 80,
    MonitorSortColumn.date: 72,
    MonitorSortColumn.client: 120,
    MonitorSortColumn.rule: 105,
    MonitorSortColumn.policy: 125,
    MonitorSortColumn.upload: 64,
    MonitorSortColumn.download: 64,
    MonitorSortColumn.duration: 68,
    MonitorSortColumn.method: 72,
    MonitorSortColumn.address: 275,
  };

  @override
  void initState() {
    super.initState();
    if (widget.embedded) {
      _requestsSubscription = ref.listenManual(
        requestsProvider.select(
          (state) => state.list.isEmpty ? null : state.list.last,
        ),
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
    _fallbackTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refresh());
    });
    _connectionsTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_page == MonitorPage.connections) unawaited(_refresh());
    });
  }

  void _handleDataChanged() => unawaited(_refresh());

  void _update(VoidCallback change) => setState(change);

  @override
  void dispose() {
    _networkMonitorSubscription?.cancel();
    _requestsSubscription?.close();
    _logsSubscription?.close();
    _fallbackTimer?.cancel();
    _connectionsTimer?.cancel();
    _trackerVerticalController.dispose();
    _trackerHorizontalController.dispose();
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
            )
          : await ExternalControl.request('snapshot');
      if (!mounted || raw == null) return;
      final map = normalizeMonitorMap(raw);
      final requests = (map['requests'] as List? ?? const [])
          .map((item) => TrackerInfo.fromJson(normalizeMonitorMap(item)))
          .toList();
      final connections = (map['connections'] as List? ?? const [])
          .map((item) => TrackerInfo.fromJson(normalizeMonitorMap(item)))
          .toList();
      final logs = (map['logs'] as List? ?? const [])
          .map(MonitorLog.fromJson)
          .toList();
      setState(() {
        _requests = requests;
        _connections = connections;
        _logs = logs;
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

  Future<void> _invoke(String method, [Object? arguments]) async {
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
        }
      } else {
        await ExternalControl.request(method, arguments);
      }
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = '操作失败：$error');
    }
  }

  List<TrackerInfo> get _pageTrackers => switch (_page) {
    MonitorPage.connections => _connections,
    _ => _requests,
  };

  List<TrackerInfo> get _visibleTrackers {
    final query = _query.toLowerCase().trim();
    final filtered = _pageTrackers.where((item) {
      final sideValue = _clientMode == MonitorClientMode.client
          ? monitorClientName(item)
          : item.metadata.host;
      if (_clientFilter != null && sideValue != _clientFilter) return false;
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
    filtered.sort((a, b) => compareMonitorTrackers(a, b, _sort));
    return filtered;
  }

  List<String> get _sidebarItems {
    final values =
        _pageTrackers
            .map(
              (item) => _clientMode == MonitorClientMode.client
                  ? monitorClientName(item)
                  : item.metadata.host,
            )
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
              children: [
                if (_error != null) _buildError(context),
                Expanded(child: _buildPage(context)),
                _buildActionBar(context),
                if (_selected != null) _buildDetail(context),
              ],
            );
            return Column(
              children: [
                _buildTopBar(context),
                const Divider(height: 1),
                Expanded(
                  child: constraints.maxWidth < 720
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
      MonitorPage.requests: '最近的请求',
      MonitorPage.connections: '活动连接',
      MonitorPage.dns: 'DNS',
      MonitorPage.devices: '设备',
      MonitorPage.traffic: '流量统计',
      MonitorPage.logs: '日志',
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
                                _clientFilter = null;
                                _sidebarFilter = monitorDefaultSidebarFilter(
                                  page,
                                );
                              });
                            },
                            child: Text(labels[page]!),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (constraints.maxWidth >= 900)
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
    return Container(
      width: 220,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<MonitorClientMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: MonitorClientMode.client,
                label: Text('按客户端'),
              ),
              ButtonSegment(value: MonitorClientMode.host, label: Text('按主机名')),
            ],
            selected: {_clientMode},
            onSelectionChanged: (value) {
              setState(() {
                _clientMode = value.first;
                _clientFilter = null;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            _clientMode == MonitorClientMode.client ? '客户端' : '主机名',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          _sidebarButton(
            context,
            label: _clientMode == MonitorClientMode.client ? '所有客户端' : '所有主机名',
            selected: _clientFilter == null,
            icon: _clientMode == MonitorClientMode.client
                ? Icons.apps_outlined
                : Icons.language_outlined,
            onTap: () => setState(() => _clientFilter = null),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                for (final item in _sidebarItems)
                  _sidebarButton(
                    context,
                    label: item,
                    selected: _clientFilter == item,
                    icon: _clientMode == MonitorClientMode.client
                        ? Icons.apps_outlined
                        : Icons.language_outlined,
                    onTap: () => setState(() => _clientFilter = item),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          minTileHeight: 38,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: icon == null ? null : Icon(icon, size: 18),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return MaterialBanner(
      content: Text(_error!),
      actions: [TextButton(onPressed: _refresh, child: const Text('重试'))],
    );
  }

  Widget _buildPage(BuildContext context) {
    return switch (_page) {
      MonitorPage.requests ||
      MonitorPage.connections => _buildTrackerTable(context),
      MonitorPage.dns => _buildDnsTable(context),
      MonitorPage.devices => _buildDevicesTable(context),
      MonitorPage.traffic => _buildTraffic(context),
      MonitorPage.logs => _buildLogs(context),
    };
  }

  Widget _buildTrackerTable(BuildContext context) {
    final items = _visibleTrackers;
    final activeIds = _connections.map((item) => item.id).toSet();
    final columns = <(String, MonitorSortColumn)>[
      ('ID', MonitorSortColumn.id),
      ('日期', MonitorSortColumn.date),
      ('客户端', MonitorSortColumn.client),
      ('规则', MonitorSortColumn.rule),
      ('策略', MonitorSortColumn.policy),
      ('上传', MonitorSortColumn.upload),
      ('下载', MonitorSortColumn.download),
      ('时长', MonitorSortColumn.duration),
      ('方法', MonitorSortColumn.method),
      ('地址', MonitorSortColumn.address),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = columns.fold<double>(
          0,
          (width, column) => width + _columnWidths[column.$2]!,
        );
        return ClipRect(
          child: Scrollbar(
            controller: _trackerVerticalController,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.vertical,
            child: SingleChildScrollView(
              controller: _trackerVerticalController,
              child: Scrollbar(
                controller: _trackerHorizontalController,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _trackerHorizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth < constraints.maxWidth
                        ? constraints.maxWidth
                        : tableWidth,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowHeight: 36,
                      dataRowMinHeight: 34,
                      dataRowMaxHeight: 34,
                      horizontalMargin: 0,
                      columnSpacing: 0,
                      columns: [
                        for (final column in columns)
                          DataColumn(
                            label: _resizableHeader(
                              context,
                              column.$1,
                              column.$2,
                            ),
                          ),
                      ],
                      rows: [
                        for (final item in items)
                          DataRow(
                            selected: _selected?.id == item.id,
                            onSelectChanged: (_) => setState(() {
                              _selected = item;
                              _detailTab = 0;
                            }),
                            cells: [
                              _idDataCell(
                                context,
                                item,
                                monitorTrackerStatus(item, activeIds),
                              ),
                              _textDataCell(
                                MonitorSortColumn.date,
                                monitorClock(item.start),
                              ),
                              _textDataCell(
                                MonitorSortColumn.client,
                                monitorClientName(item),
                              ),
                              _textDataCell(
                                MonitorSortColumn.rule,
                                monitorRuleName(item),
                              ),
                              _textDataCell(
                                MonitorSortColumn.policy,
                                monitorPolicyName(item),
                              ),
                              _textDataCell(
                                MonitorSortColumn.upload,
                                monitorBytes(item.upload),
                              ),
                              _textDataCell(
                                MonitorSortColumn.download,
                                monitorBytes(item.download),
                              ),
                              _textDataCell(
                                MonitorSortColumn.duration,
                                monitorDuration(item.start),
                              ),
                              DataCell(
                                SizedBox(
                                  width:
                                      _columnWidths[MonitorSortColumn.method],
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _methodChip(
                                      context,
                                      monitorMethodName(item),
                                    ),
                                  ),
                                ),
                              ),
                              _textDataCell(
                                MonitorSortColumn.address,
                                monitorAddress(item),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _resizableHeader(
    BuildContext context,
    String label,
    MonitorSortColumn column,
  ) {
    final width = _columnWidths[column]!;
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Positioned.fill(
            right: 9,
            child: Semantics(
              button: true,
              label: '$label，点击排序',
              child: InkWell(
                onTap: () => setState(() => _sort = _sort.toggle(column)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_sort.column == column)
                        Icon(
                          _sort.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 14,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 0,
            bottom: 5,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _columnWidths[column] = monitorResizedColumnWidth(
                      width,
                      details.delta.dx,
                    );
                  });
                },
                child: SizedBox(
                  width: 9,
                  child: VerticalDivider(
                    width: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataCell _textDataCell(MonitorSortColumn column, String value) {
    return DataCell(
      SizedBox(
        width: _columnWidths[column],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  DataCell _idDataCell(
    BuildContext context,
    TrackerInfo item,
    MonitorTrackerStatus status,
  ) {
    final color = switch (status) {
      MonitorTrackerStatus.error => Colors.red,
      MonitorTrackerStatus.active => Colors.amber,
      MonitorTrackerStatus.finished => Colors.green,
      MonitorTrackerStatus.other => Theme.of(context).colorScheme.outline,
    };
    return DataCell(
      SizedBox(
        width: _columnWidths[MonitorSortColumn.id],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  monitorShortId(item.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodChip(BuildContext context, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: value == 'HTTPS'
            ? Colors.amber.withValues(alpha: 0.85)
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(value, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildDnsTable(BuildContext context) {
    final entries = <String, TrackerInfo>{};
    for (final item in [..._requests, ..._connections]) {
      final host = item.metadata.host.trim();
      if (host.isEmpty || monitorDnsAddress(item).isEmpty) continue;
      final previous = entries[host];
      if (previous == null || item.start.isAfter(previous.start)) {
        entries[host] = item;
      }
    }
    final items = entries.values.where((item) {
      final type = monitorDnsType(item);
      return (_sidebarFilter == '全部' || _sidebarFilter == type) &&
          _matchesQuery([
            item.metadata.host,
            monitorDnsAddress(item),
            item.metadata.dnsMode?.name,
          ]);
    }).toList()..sort((a, b) => b.start.compareTo(a.start));
    return _simpleTable(
      columns: const ['域名', '解析地址', '模式', '最后请求'],
      rows: items.map((item) {
        return [
          item.metadata.host,
          monitorDnsAddress(item),
          item.metadata.dnsMode?.name ?? '未知',
          monitorClock(item.start),
        ];
      }).toList(),
    );
  }

  Widget _buildDevicesTable(BuildContext context) {
    final entries = <String, List<TrackerInfo>>{};
    for (final item in [..._requests, ..._connections]) {
      final client = monitorClientName(item).trim();
      if (client.isEmpty) continue;
      entries.putIfAbsent(client, () => []).add(item);
    }
    final activeIds = _connections.map((item) => item.id).toSet();
    final items = entries.entries.where((entry) {
      final trackers = entry.value;
      final visible = switch (_sidebarFilter) {
        '已分配' => trackers.any((item) => item.metadata.sourceIP.isNotEmpty),
        '未指派' => trackers.every((item) => item.metadata.sourceIP.isEmpty),
        '代理' => trackers.any(
          (item) => item.chains.any((chain) => chain != 'DIRECT'),
        ),
        '网关' => trackers.any((item) => item.chains.contains('DIRECT')),
        '无' => trackers.every((item) => item.chains.isEmpty),
        '已启用' => trackers.any((item) => activeIds.contains(item.id)),
        '不活跃' => trackers.every((item) => !activeIds.contains(item.id)),
        _ => true,
      };
      final item = trackers.last;
      return visible &&
          _matchesQuery([
            entry.key,
            item.metadata.sourceIP,
            item.metadata.processPath,
          ]);
    });
    return _simpleTable(
      columns: const ['客户端', '来源地址', '进程路径', '请求数'],
      rows: items.map((entry) {
        final item = entry.value.last;
        return [
          entry.key,
          item.metadata.sourceIP,
          item.metadata.processPath,
          entry.value.length.toString(),
        ];
      }).toList(),
    );
  }

  Widget _simpleTable({
    required List<String> columns,
    required List<List<String>> rows,
  }) {
    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: [
            for (final column in columns) DataColumn(label: Text(column)),
          ],
          rows: [
            for (final row in rows)
              DataRow(cells: [for (final value in row) DataCell(Text(value))]),
          ],
        ),
      ),
    );
  }

  Widget _buildTraffic(BuildContext context) {
    final all = [..._requests, ..._connections];
    final upload = all.fold<int>(0, (sum, item) => sum + item.upload);
    final download = all.fold<int>(0, (sum, item) => sum + item.download);
    final byGroup = <String, int>{};
    for (final item in all) {
      final key = switch (_sidebarFilter) {
        '进程' => monitorClientName(item),
        '网络适配器' => item.metadata.network.toUpperCase(),
        '设备' => item.metadata.sourceIP,
        '主机名' => item.metadata.host,
        _ => monitorPolicyName(item),
      };
      if (key.isEmpty) continue;
      byGroup.update(
        key,
        (value) => value + item.upload + item.download,
        ifAbsent: () => item.upload + item.download,
      );
    }
    final groups =
        byGroup.entries.where((entry) => _matchesQuery([entry.key])).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard(context, '总上传', monitorBytes(upload), Icons.upload),
            _metricCard(context, '总下载', monitorBytes(download), Icons.download),
            _metricCard(
              context,
              '记录数',
              all.length.toString(),
              Icons.receipt_long,
            ),
            _metricCard(
              context,
              '活动连接',
              _connections.length.toString(),
              Icons.link,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '$_sidebarFilter流量',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final entry in groups.take(20))
          ListTile(
            dense: true,
            leading: const Icon(Icons.apps_outlined),
            title: Text(entry.key),
            trailing: Text(monitorBytes(entry.value)),
          ),
      ],
    );
  }

  Widget _metricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Card.filled(
      child: SizedBox(
        width: 190,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogs(BuildContext context) {
    final query = _query.toLowerCase().trim();
    final logs = _logs
        .where((log) {
          final type = monitorLogLevelLabel(log.level);
          return (_sidebarFilter == '全部' || _sidebarFilter == type) &&
              (query.isEmpty ||
                  '${log.dateTime} ${log.level} ${log.payload}'
                      .toLowerCase()
                      .contains(query));
        })
        .toList()
        .reversed;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final log = logs.elementAt(index);
        return ListTile(
          dense: true,
          leading: Text(
            log.level.toUpperCase(),
            style: TextStyle(color: _logColor(log.level)),
          ),
          title: SelectableText(log.payload),
          trailing: Text(log.dateTime),
        );
      },
    );
  }

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
