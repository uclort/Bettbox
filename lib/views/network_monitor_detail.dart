part of 'network_monitor.dart';

extension _NetworkMonitorDetail on _NetworkMonitorViewState {
  Widget _buildActionBar(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Row(
        children: [
          if (_page == MonitorPage.requests)
            TextButton.icon(
              onPressed: () => _invoke('clearRequests'),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('清空'),
            ),
          if (_page == MonitorPage.logs)
            TextButton.icon(
              onPressed: () => _invoke('clearLogs'),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('清空'),
            ),
          if (_page == MonitorPage.connections)
            TextButton.icon(
              onPressed: () => _invoke('closeConnections'),
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('关闭全部连接'),
            ),
          if (_page == MonitorPage.dns)
            TextButton.icon(
              onPressed: () => _clearDnsCache(context),
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: Text('清除 DNS 缓存（${_runtimeDnsEntries.length}）'),
            ),
          TextButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新载入'),
          ),
          if (_page == MonitorPage.connections && _selected != null)
            TextButton.icon(
              onPressed: () => _invoke('closeConnection', _selected!.id),
              icon: const Icon(Icons.block, size: 18),
              label: const Text('关闭当前连接'),
            ),
          const Spacer(),
          if (_selected != null)
            IconButton(
              tooltip: '收起详情',
              onPressed: () => _update(() => _selected = null),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
        ],
      ),
    );
  }

  Future<void> _clearDnsCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除 DNS 缓存'),
        content: Text(
          '将同时清除 Mihomo 运行中的 DNS 结果和 Fake-IP 映射。'
          '\n面板当前可见 ${_runtimeDnsEntries.length} 条，下次访问会重新解析。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (await _invoke('flushDnsCache') && context.mounted) {
      _update(() => _dnsCacheClearedAt = DateTime.now());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('DNS 缓存已清除')));
    }
  }

  Widget _buildDetail(BuildContext context) {
    final item = _selected!;
    final status = monitorTrackerStatus(
      item,
      _connections.map((item) => item.id).toSet(),
    );
    final statusColor = _monitorStatusColor(context, status);
    final statusLabel = _monitorStatusLabel(status);
    const tabs = ['通用', 'Mihomo 链路'];
    final maxHeight = (MediaQuery.sizeOf(context).height * .65)
        .clamp(220.0, 620.0)
        .toDouble();
    return SizedBox(
      height: _detailHeight.clamp(180.0, maxHeight).toDouble(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.resizeRow,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                _update(() {
                  _detailHeight = (_detailHeight - details.delta.dy)
                      .clamp(180.0, maxHeight)
                      .toDouble();
                });
              },
              onVerticalDragEnd: (_) => _saveDetailHeight(),
              onVerticalDragCancel: _saveDetailHeight,
              child: SizedBox(
                height: 8,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SelectionArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  if (system.isMacOS)
                    ProcessIcon(
                      key: ValueKey(
                        '${item.metadata.process}\n${item.metadata.processPath}',
                      ),
                      process: item.metadata.process,
                      processPath: item.metadata.processPath,
                      size: 28,
                    )
                  else
                    const Icon(Icons.apps, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          monitorClientName(item),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(monitorAddress(item)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '复制详情',
                    onPressed: () => _copyDetail(context, item, statusLabel),
                    icon: const Icon(Icons.copy_outlined, size: 19),
                  ),
                  Chip(
                    avatar: Icon(
                      status == MonitorTrackerStatus.unknown
                          ? Icons.circle_outlined
                          : Icons.circle,
                      size: 10,
                      color: statusColor,
                    ),
                    label: Text(statusLabel),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (_, index) => TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _detailTab == index
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  foregroundColor: _detailTab == index
                      ? Theme.of(context).colorScheme.onPrimary
                      : null,
                ),
                onPressed: () => _update(() => _detailTab = index),
                child: Text(tabs[index]),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildDetailBody(context, item)),
        ],
      ),
    );
  }

  Widget _buildDetailBody(BuildContext context, TrackerInfo item) {
    if (_detailTab == 0) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final connection = _infoCard(context, '连接', [
            '方法：${monitorMethodName(item)}',
            '网络：${item.metadata.network}',
            '时长：${monitorDuration(item.start)}',
          ]);
          final traffic = _infoCard(context, '流量', [
            '上传：${monitorBytes(item.upload)}',
            '下载：${monitorBytes(item.download)}',
            '实时：↑${monitorBytes(item.uploadSpeed ?? 0)}/s  ↓${monitorBytes(item.downloadSpeed ?? 0)}/s',
          ]);
          final rule = _infoCard(
            context,
            '规则与策略',
            ['规则：${monitorRuleName(item)}'],
            monospace: true,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('策略：'),
                  Expanded(child: _compactMonitorText(monitorPolicyName(item))),
                ],
              ),
            ],
          );
          final summary = constraints.maxWidth >= 760
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: connection),
                    const SizedBox(width: 8),
                    Expanded(child: traffic),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: rule),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    connection,
                    const SizedBox(height: 8),
                    traffic,
                    const SizedBox(height: 8),
                    rule,
                  ],
                );
          return SelectionArea(
            child: Scrollbar(
              controller: _detailScrollController,
              thumbVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _detailScrollController,
                padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: 8),
                      _ipInfoCard(context, item),
                      const SizedBox(height: 8),
                      _infoCard(context, '进程', [
                        '名称：${monitorClientName(item)}',
                        if (item.metadata.processPath.isNotEmpty)
                          '路径：${item.metadata.processPath}',
                      ], monospace: true),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
    return _buildMihomoFlow(context, item);
  }

  Widget _ipInfoCard(BuildContext context, TrackerInfo item) {
    final remoteAddress = monitorOutboundRemoteAddress(item);
    final remoteIP = monitorSocketHost(remoteAddress);
    final targetIP = monitorTargetIP(item);
    final targetRegion = item.metadata.destinationGeoIP.join(' ');
    final dnsMode = monitorDnsMode(item);

    Widget buildCard(String remoteRegion) {
      final lines = <String>[
        if (item.metadata.sourceIP.isNotEmpty)
          '客户端地址：${monitorEndpoint(item.metadata.sourceIP, item.metadata.sourcePort)}',
        if (monitorAddress(item).isNotEmpty) '目标地址：${monitorAddress(item)}',
        if (targetIP.isNotEmpty && item.metadata.host.isNotEmpty)
          '${dnsMode == 'fake-ip' ? '内核目标（Fake-IP）' : '目标 IP'}：${monitorEndpoint(targetIP, item.metadata.destinationPort)}',
        if (monitorOutboundLocalAddress(item).isNotEmpty)
          '出站地址：${monitorOutboundLocalAddress(item)}',
        if (remoteAddress.isNotEmpty)
          '${monitorIsDirect(item) ? '直连目标地址' : '代理入口地址'}：$remoteAddress',
        if (item.metadata.dnsMode != null) 'DNS 模式：$dnsMode',
        if (item.metadata.sourceGeoIP.isNotEmpty)
          '客户端地区：${item.metadata.sourceGeoIP.join(' ')}',
        if (item.metadata.sourceIPASN.isNotEmpty)
          '客户端 ASN：${item.metadata.sourceIPASN}',
        if (targetRegion.isNotEmpty) '目标地区：$targetRegion',
        if (item.metadata.destinationIPASN.isNotEmpty)
          '目标 ASN：${item.metadata.destinationIPASN}',
        if (remoteRegion.isNotEmpty && remoteRegion != targetRegion)
          '远端地区：$remoteRegion',
      ];
      return _infoCard(context, 'IP 地址', lines, monospace: true);
    }

    if (remoteIP.isEmpty) return buildCard('');
    return FutureBuilder<String>(
      future: _lookupCountryCode(remoteIP),
      builder: (_, snapshot) => buildCard(snapshot.data ?? ''),
    );
  }

  Widget _buildMihomoFlow(BuildContext context, TrackerInfo item) {
    final trace = monitorConnectionTrace(item);
    if (trace.isNotEmpty) {
      final targetResolution = monitorTargetResolutionSummary(item);
      final titleWidth = _flowTitleWidth(context, [
        '请求目标',
        if (targetResolution.isNotEmpty) '目标解析方式',
        ...trace.map((event) => monitorTraceTitleForTracker(event, item)),
      ]);
      return SelectionArea(
        child: Scrollbar(
          controller: _detailScrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView(
            controller: _detailScrollController,
            padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
            children: [
              _flowStep(
                context,
                Icons.language,
                '请求目标',
                monitorAddress(item),
                titleWidth: titleWidth,
                leading: monitorClock(item.start),
              ),
              if (targetResolution.isNotEmpty)
                _flowStep(
                  context,
                  Icons.dns_outlined,
                  '目标解析方式',
                  targetResolution,
                  titleWidth: titleWidth,
                  leading: monitorClock(item.start),
                ),
              for (final event in trace)
                _flowStep(
                  context,
                  _traceIcon(event.stage),
                  monitorTraceTitleForTracker(event, item),
                  monitorTraceDetailForTracker(event, item),
                  titleWidth: titleWidth,
                  leading: monitorTraceClock(event.timestamp),
                  color: switch (event.status) {
                    'error' => Colors.red,
                    'pending' => Colors.amber,
                    _ => Theme.of(context).colorScheme.primary,
                  },
                ),
            ],
          ),
        ),
      );
    }

    final source = monitorEndpoint(
      item.metadata.sourceIP,
      item.metadata.sourcePort,
    );
    final remote = monitorOutboundRemoteAddress(item);
    final dnsMode = monitorDnsMode(item);
    final destinationIP = item.metadata.destinationIP.trim();
    final logs = _logs.where((log) => monitorLogBelongsToTracker(log, item));
    final steps = <({IconData icon, String title, String value})>[
      if (source.isNotEmpty)
        (
          icon: Icons.input,
          title: '入站',
          value: '${item.metadata.network.toUpperCase()} $source',
        ),
      if (item.metadata.host.isNotEmpty)
        (
          icon: Icons.dns_outlined,
          title: 'DNS 处理',
          value: destinationIP.isEmpty
              ? '${item.metadata.host}${dnsMode == '未知' ? '' : ' · $dnsMode'}'
              : '${item.metadata.host} → $destinationIP${dnsMode == '未知' ? '' : ' · $dnsMode'}',
        )
      else if (destinationIP.isNotEmpty)
        (icon: Icons.language, title: '目标识别', value: destinationIP),
      if (monitorRouteChain(item).isNotEmpty)
        (icon: Icons.alt_route, title: '完整策略链', value: monitorRouteChain(item)),
      if (remote.isNotEmpty)
        (
          icon: Icons.link,
          title: '建立出站',
          value:
              '$remote · ${monitorClock(item.start)} · ${monitorDuration(item.start)}',
        ),
    ];
    final titleWidth = _flowTitleWidth(
      context,
      steps.map((step) => step.title),
    );
    return SelectionArea(
      child: Scrollbar(
        controller: _detailScrollController,
        thumbVisibility: true,
        interactive: true,
        child: ListView(
          controller: _detailScrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
          children: [
            for (final step in steps)
              _flowStep(
                context,
                step.icon,
                step.title,
                step.value,
                titleWidth: titleWidth,
              ),
            if (logs.isNotEmpty) ...[
              const Divider(height: 24),
              Text('兼容内核记录', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              for (final log in logs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _compactMonitorText(
                    '${log.dateTime} [${log.level}] ${log.payload}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _flowStep(
    BuildContext context,
    IconData icon,
    String title,
    String value, {
    Color? color,
    required double titleWidth,
    String leading = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: titleWidth,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          if (leading.isNotEmpty) ...[
            SizedBox(width: 112, child: Text(leading, maxLines: 1)),
            const SizedBox(width: 8),
          ],
          Expanded(child: _compactMonitorText(value)),
        ],
      ),
    );
  }

  double _flowTitleWidth(BuildContext context, Iterable<String> titles) {
    final style = Theme.of(context).textTheme.labelMedium;
    final scaler = MediaQuery.textScalerOf(context);
    var width = 72.0;
    for (final title in titles) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > width) width = painter.width;
    }
    return (width + 8).clamp(80.0, 180.0);
  }

  IconData _traceIcon(String stage) => switch (stage) {
    'dns' => Icons.dns_outlined,
    'rule' => Icons.rule_outlined,
    'outbound' => Icons.alt_route,
    'connect' => Icons.link,
    _ => Icons.input,
  };

  Widget _infoCard(
    BuildContext context,
    String title,
    List<String> lines, {
    bool monospace = false,
    List<Widget> children = const [],
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          for (final line in lines)
            Text(
              line,
              style: monospace
                  ? const TextStyle(fontFamily: 'monospace')
                  : null,
            ),
          ...children,
        ],
      ),
    );
  }

  Future<void> _copyDetail(
    BuildContext context,
    TrackerInfo item,
    String statusLabel,
  ) async {
    final lines = <String>[
      '状态：$statusLabel',
      '客户端：${monitorClientName(item)}',
      '目标：${monitorAddress(item)}',
      '方法：${monitorMethodName(item)}',
      '网络：${item.metadata.network}',
      '时长：${monitorDuration(item.start)}',
      '上传：${monitorBytes(item.upload)}',
      '下载：${monitorBytes(item.download)}',
      '规则：${monitorRuleName(item)}',
      '策略：${monitorPolicyName(item)}',
      if (item.metadata.sourceIP.isNotEmpty)
        '客户端地址：${monitorEndpoint(item.metadata.sourceIP, item.metadata.sourcePort)}',
      if (monitorTargetIP(item).isNotEmpty)
        '内核目标：${monitorEndpoint(monitorTargetIP(item), item.metadata.destinationPort)}',
      if (monitorOutboundLocalAddress(item).isNotEmpty)
        '出站地址：${monitorOutboundLocalAddress(item)}',
      if (monitorOutboundRemoteAddress(item).isNotEmpty)
        '${monitorIsDirect(item) ? '直连目标地址' : '代理入口地址'}：${monitorOutboundRemoteAddress(item)}',
      'DNS 模式：${monitorDnsMode(item)}',
      if (item.metadata.processPath.isNotEmpty)
        '进程路径：${item.metadata.processPath}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('详情已复制')));
  }
}
