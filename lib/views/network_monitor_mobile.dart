part of 'network_monitor.dart';

extension _NetworkMonitorMobile on _NetworkMonitorViewState {
  Widget _buildMobileMonitor(BuildContext context) {
    return Column(
      children: [
        if (_error != null) _buildError(context),
        if (_page != MonitorPage.subStore) _buildMobileSearch(context),
        if (_page != MonitorPage.subStore) _buildMobileFilters(context),
        Expanded(child: _buildMobilePage(context)),
        if (_page != MonitorPage.subStore) _buildMobileActions(context),
      ],
    );
  }

  Widget _buildMobileFilters(BuildContext context) {
    if (_page == MonitorPage.requests || _page == MonitorPage.connections) {
      return SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          children: [
            _mobileFilterChip(
              context,
              label: '全部',
              selected: _trackerFilter == null,
              onSelected: () => _update(() => _trackerFilter = null),
            ),
            for (final facet in MonitorTrackerFacet.values)
              _mobileFilterChip(
                context,
                label: facet == _trackerFacet && _trackerFilter != null
                    ? '${monitorTrackerFacetLabel(facet)} · $_trackerFilter'
                    : monitorTrackerFacetLabel(facet),
                selected: facet == _trackerFacet && _trackerFilter != null,
                onSelected: () => _showMobileTrackerFilter(context, facet),
              ),
          ],
        ),
      );
    }
    final filters = switch (_page) {
      MonitorPage.dns => const ['全部', '配置 DNS', 'Hosts', '运行缓存', 'Fake-IP'],
      _ =>
        (monitorStaticSidebarSections[_page] ?? const [])
            .expand((section) => section.items)
            .toSet()
            .toList(),
    };
    if (filters.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        children: [
          for (final filter in filters)
            _mobileFilterChip(
              context,
              label: filter,
              selected: _sidebarFilter == filter,
              onSelected: () => _update(() => _sidebarFilter = filter),
            ),
        ],
      ),
    );
  }

  Widget _mobileFilterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        selected: selected,
        showCheckmark: selected,
        checkmarkColor: colors.primary,
        selectedColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: selected ? colors.primary : colors.outline),
        labelStyle: TextStyle(
          color: selected ? colors.primary : colors.onSurface,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }

  Future<void> _showMobileTrackerFilter(
    BuildContext context,
    MonitorTrackerFacet facet,
  ) async {
    final activeIds = _connections.map((item) => item.id).toSet();
    final values =
        _pageTrackers
            .where((item) => !monitorIsInternalTracker(item))
            .map((item) => monitorTrackerFacetValue(item, facet, activeIds))
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text('全部${monitorTrackerFacetLabel(facet)}'),
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final value in values)
              ListTile(
                title: Text(value),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    _update(() {
      _trackerFacet = facet;
      _trackerFilter = selected.isEmpty ? null : selected;
    });
  }

  Widget _buildMobileSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: TextField(
        onChanged: (value) => _update(() => _query = value),
        decoration: InputDecoration(
          isDense: true,
          hintText: '搜索当前页面',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildMobilePage(BuildContext context) => switch (_page) {
    MonitorPage.requests ||
    MonitorPage.connections => _buildMobileTrackers(context),
    MonitorPage.dns => _buildMobileDns(context),
    MonitorPage.devices => _buildMobileDevices(context),
    MonitorPage.traffic => _buildMobileTraffic(context),
    MonitorPage.logs => _buildMobileLogs(context),
    MonitorPage.subStore => _buildSubStorePage(context),
  };

  Widget _buildMobileTrackers(BuildContext context) {
    final items = _visibleTrackers;
    final activeIds = _connections.map((item) => item.id).toSet();
    if (items.isEmpty) return const Center(child: Text('暂无数据'));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final status = monitorTrackerStatus(item, activeIds);
        final color = _monitorStatusColor(context, status);
        final policy = monitorPolicyName(item);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onSecondaryTapDown: widget.mobile
              ? null
              : (details) => _showTrackerContextMenu(context, item, details),
          onTap: () => widget.mobile
              ? _openMobileTrackerDetail(context, item)
              : _selectTracker(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                ProcessIcon(
                  key: ValueKey(
                    '${item.metadata.process}\n${item.metadata.processPath}',
                  ),
                  process: item.metadata.process,
                  processPath: item.metadata.processPath,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          '↓ ${monitorBytes(item.download)}',
                          '↑ ${monitorBytes(item.upload)}',
                          if (policy.isNotEmpty) policy,
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        monitorAddress(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _mobileStatusChip(
                            context,
                            _monitorStatusLabel(status),
                            color,
                          ),
                          Text(
                            '${monitorClientName(item)}  ·  ${monitorMethodName(item)}  ·  ${monitorClock(item.start)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  widget.mobile
                      ? Icons.chevron_right
                      : Icons.vertical_align_bottom,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mobileStatusChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }

  List<MonitorDnsEntry> get _mobileDnsEntries {
    return _dnsEntries.where((item) {
      return monitorDnsMatchesFilter(item, _sidebarFilter) &&
          _matchesQuery([
            item.source,
            item.category,
            item.name,
            item.value,
            item.detail,
          ]);
    }).toList();
  }

  Widget _buildMobileDns(BuildContext context) {
    final items = _mobileDnsEntries;
    if (items.isEmpty) return const Center(child: Text('暂无 DNS 数据'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Card.filled(
            child: ListTile(
              leading: const Icon(Icons.cached),
              title: Text('当前可见运行缓存 ${_runtimeDnsEntries.length} 条'),
              subtitle: const Text('清除后，下次访问将由 Mihomo 重新解析'),
              trailing: TextButton(
                onPressed: () => _clearDnsCache(context),
                child: const Text('清除'),
              ),
            ),
          );
        }
        index--;
        final item = items[index];
        return Card.filled(
          child: ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(item.name),
            subtitle: Text(
              [
                item.value,
                [
                  item.source,
                  item.category,
                  item.detail,
                ].where((value) => value.isNotEmpty).join(' · '),
              ].where((value) => value.isNotEmpty).join('\n'),
            ),
            trailing: item.lastActivity.isEmpty
                ? null
                : Text(item.lastActivity),
          ),
        );
      },
    );
  }

  void _openMobileTrackerDetail(BuildContext context, TrackerInfo item) {
    _detailTab = 0;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => StatefulBuilder(
          builder: (routeContext, updateRoute) => Scaffold(
            body: SafeArea(
              child: _buildMobileDetail(
                routeContext,
                item,
                onBack: () => Navigator.pop(routeContext),
                onTabChanged: (index) => updateRoute(() => _detailTab = index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDevices(BuildContext context) {
    final activeIds = _connections.map((item) => item.id).toSet();
    final grouped = <String, List<TrackerInfo>>{};
    for (final item in _allTrackers) {
      grouped.putIfAbsent(monitorDeviceKey(item), () => []).add(item);
    }
    final entries = grouped.entries.where((entry) {
      final item = entry.value.first;
      final source = monitorDeviceSource(item);
      final visible = switch (_sidebarFilter) {
        '本机进程' || '网络来源' || '未识别' => source == _sidebarFilter,
        '活动' => entry.value.any((item) => activeIds.contains(item.id)),
        '历史' => entry.value.any((item) => !activeIds.contains(item.id)),
        _ => true,
      };
      return visible &&
          _matchesQuery([
            entry.key,
            item.metadata.sourceIP,
            item.metadata.processPath,
          ]);
    }).toList()..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return const Center(child: Text('暂无设备数据'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final item = entry.value.reduce(
          (current, next) => next.start.isAfter(current.start) ? next : current,
        );
        final active = entry.value
            .where((item) => activeIds.contains(item.id))
            .length;
        final networks = entry.value
            .map((item) => item.metadata.network.toUpperCase())
            .where((value) => value.isNotEmpty)
            .toSet()
            .join(' / ');
        return Card.filled(
          child: ListTile(
            leading: ProcessIcon(
              key: ValueKey(
                '${item.metadata.process}\n${item.metadata.processPath}',
              ),
              process: item.metadata.process,
              processPath: item.metadata.processPath,
              size: 34,
            ),
            title: Text(entry.key),
            subtitle: Text(
              [
                monitorDeviceSource(item),
                item.metadata.sourceIP,
                networks,
              ].where((value) => value.isNotEmpty).join(' · '),
            ),
            trailing: Text('活动 $active\n历史 ${entry.value.length - active}'),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildMobileTraffic(BuildContext context) {
    final groups = <String, int>{};
    for (final item in _allTrackers) {
      final key = monitorTrafficGroupValue(item, _sidebarFilter);
      groups.update(
        key,
        (value) => value + item.upload + item.download,
        ifAbsent: () => item.upload + item.download,
      );
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _mobileMetric(context, '实时上传', '${monitorBytes(_trafficUp)}/s'),
            _mobileMetric(context, '实时下载', '${monitorBytes(_trafficDown)}/s'),
            _mobileMetric(context, '累计上传', monitorBytes(_totalTrafficUp)),
            _mobileMetric(context, '累计下载', monitorBytes(_totalTrafficDown)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '按$_sidebarFilter统计',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final entry in entries)
          ListTile(
            leading: const Icon(Icons.data_usage_outlined),
            title: Text(entry.key),
            trailing: Text(monitorBytes(entry.value)),
          ),
      ],
    );
  }

  Widget _mobileMetric(BuildContext context, String title, String value) {
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLogs(BuildContext context) {
    final query = _query.toLowerCase().trim();
    final logs = _logs
        .where((log) {
          return (_sidebarFilter == '全部' || log.level == _sidebarFilter) &&
              (query.isEmpty ||
                  '${log.dateTime} ${log.level} ${log.payload}'
                      .toLowerCase()
                      .contains(query));
        })
        .toList()
        .reversed
        .toList();
    if (logs.isEmpty) return const Center(child: Text('暂无日志'));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = logs[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    log.level.toUpperCase(),
                    style: TextStyle(color: _logColor(log.level)),
                  ),
                  const Spacer(),
                  Text(
                    log.dateTime,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              SelectableText(log.payload),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileActions(BuildContext context) {
    final actions = <Widget>[
      if (_page == MonitorPage.requests)
        TextButton.icon(
          onPressed: () => _invoke('clearRequests'),
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('清空'),
        ),
      if (_page == MonitorPage.connections)
        TextButton.icon(
          onPressed: () => _invoke('closeConnections'),
          icon: const Icon(Icons.link_off),
          label: const Text('关闭全部'),
        ),
      if (_page == MonitorPage.logs)
        TextButton.icon(
          onPressed: () => _invoke('clearLogs'),
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('清空'),
        ),
      if (_page == MonitorPage.dns)
        TextButton.icon(
          onPressed: () => _clearDnsCache(context),
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('清除缓存'),
        ),
      TextButton.icon(
        onPressed: _reload,
        icon: const Icon(Icons.refresh),
        label: const Text('重新载入'),
      ),
    ];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: actions,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDetail(
    BuildContext context,
    TrackerInfo item, {
    VoidCallback? onBack,
    ValueChanged<int>? onTabChanged,
  }) {
    final status = monitorTrackerStatus(
      item,
      _connections.map((item) => item.id).toSet(),
    );
    const tabs = ['通用', 'Mihomo 链路'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
          child: Row(
            children: [
              IconButton(
                tooltip: '返回列表',
                onPressed: onBack ?? () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  monitorAddress(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '更多操作',
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'generateRule') {
                    await _showRuleDialog(context, item);
                  } else if (value == 'copyDetail' && context.mounted) {
                    await _copyDetail(
                      context,
                      item,
                      _monitorStatusLabel(status),
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'generateRule',
                    child: ListTile(
                      leading: Icon(Icons.rule_outlined),
                      title: Text('生成规则'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'copyDetail',
                    child: ListTile(
                      leading: Icon(Icons.copy_outlined),
                      title: Text('复制详情'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _mobileStatusChip(
                context,
                _monitorStatusLabel(status),
                _monitorStatusColor(context, status),
              ),
              const Spacer(),
              for (var index = 0; index < tabs.length; index++)
                InkWell(
                  onTap: () =>
                      (onTabChanged ??
                      (value) => _update(() => _detailTab = value))(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _detailTab == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      tabs[index],
                      style: TextStyle(
                        color: _detailTab == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: _detailTab == index
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildDetailBody(context, item)),
      ],
    );
  }
}
