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

  Widget _buildDetail(BuildContext context) {
    final item = _selected!;
    final status = monitorTrackerStatus(
      item,
      _connections.map((item) => item.id).toSet(),
    );
    final statusColor = switch (status) {
      MonitorTrackerStatus.error => Colors.red,
      MonitorTrackerStatus.active => Colors.amber,
      MonitorTrackerStatus.finished => Colors.green,
      MonitorTrackerStatus.other => Theme.of(context).colorScheme.outline,
    };
    final statusLabel = switch (status) {
      MonitorTrackerStatus.error => '错误',
      MonitorTrackerStatus.active => '活跃',
      MonitorTrackerStatus.finished => '已完成',
      MonitorTrackerStatus.other => '其他',
    };
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
          Padding(
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
                Chip(
                  avatar: Icon(Icons.circle, size: 10, color: statusColor),
                  label: Text(statusLabel),
                ),
              ],
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
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _infoCard(context, '连接', [
              '方法：${monitorMethodName(item)}',
              '网络：${item.metadata.network}',
              '时长：${monitorDuration(item.start)}',
            ]),
            _infoCard(context, '流量', [
              '上传：${monitorBytes(item.upload)}',
              '下载：${monitorBytes(item.download)}',
              '实时：↑${monitorBytes(item.uploadSpeed ?? 0)}/s  ↓${monitorBytes(item.downloadSpeed ?? 0)}/s',
            ]),
            _infoCard(
              context,
              '规则与策略',
              ['规则：${monitorRuleName(item)}'],
              width: 250,
              children: [
                Row(
                  children: [
                    const Text('策略：'),
                    Expanded(
                      child: _compactMonitorText(
                        monitorPolicyName(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _ipInfoCard(context, item),
            _infoCard(context, '进程', [
              '名称：${monitorClientName(item)}',
              if (item.metadata.processPath.isNotEmpty)
                '路径：${item.metadata.processPath}',
            ], width: 320),
          ],
        ),
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
          '远端地址（${monitorIsDirect(item) ? '直连目标' : '代理节点'}）：$remoteAddress',
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
      return _infoCard(context, 'IP 地址', lines, width: 300);
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
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final event in trace)
            _flowStep(
              context,
              _traceIcon(event.stage),
              event.title,
              [
                monitorTraceClock(event.timestamp),
                event.detail,
              ].where((value) => value.isNotEmpty).join(' · '),
              color: switch (event.status) {
                'error' => Colors.red,
                'pending' => Colors.amber,
                _ => Theme.of(context).colorScheme.primary,
              },
            ),
        ],
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
      if (monitorRuleName(item).isNotEmpty)
        (
          icon: Icons.rule_outlined,
          title: '规则匹配',
          value: monitorRuleName(item),
        ),
      if (monitorPolicyChain(item).isNotEmpty)
        (icon: Icons.alt_route, title: '出站路径', value: monitorPolicyChain(item)),
      if (remote.isNotEmpty)
        (
          icon: Icons.link,
          title: '建立出站',
          value:
              '$remote · ${monitorClock(item.start)} · ${monitorDuration(item.start)}',
        ),
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final step in steps)
          _flowStep(context, step.icon, step.title, step.value),
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
    );
  }

  Widget _flowStep(
    BuildContext context,
    IconData icon,
    String title,
    String value, {
    Color? color,
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
            width: 72,
            child: Text(title, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: _compactMonitorText(value)),
        ],
      ),
    );
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
    double width = 180,
    List<Widget> children = const [],
  }) {
    return Container(
      width: width,
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
            Text(line, maxLines: 1, overflow: TextOverflow.ellipsis),
          ...children,
        ],
      ),
    );
  }
}
