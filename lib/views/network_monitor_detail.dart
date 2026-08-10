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
            onPressed: _refresh,
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
    const tabs = ['通用', '计时 & 日志', '请求报头', '响应报头', '请求数据', '响应数据'];
    return SizedBox(
      height: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
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
                  avatar: Icon(
                    _connections.any((e) => e.id == item.id)
                        ? Icons.circle
                        : Icons.history,
                    size: 10,
                    color: _connections.any((e) => e.id == item.id)
                        ? Colors.amber
                        : Colors.blue,
                  ),
                  label: Text(
                    _connections.any((e) => e.id == item.id) ? '活跃' : '已完成',
                  ),
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
            _infoCard(context, '规则与策略', [
              '规则：${monitorRuleName(item)}',
              '策略：${monitorPolicyName(item)}',
            ], width: 250),
            _infoCard(context, 'IP 地址', [
              '出站：${item.metadata.sourceIP}:${item.metadata.sourcePort}',
              '远程：${item.metadata.destinationIP}:${item.metadata.destinationPort}',
              '地区：${item.metadata.destinationGeoIP.join(' ')}',
              'ASN：${item.metadata.destinationIPASN}',
            ], width: 250),
            _infoCard(context, '进程', [
              '名称：${monitorClientName(item)}',
              '路径：${item.metadata.processPath}',
            ], width: 320),
          ],
        ),
      );
    }
    if (_detailTab == 1) {
      final keys = [
        item.id,
        item.metadata.host,
        item.metadata.process,
      ].where((value) => value.isNotEmpty).map((value) => value.toLowerCase());
      final logs = _logs
          .where((log) {
            final payload = log.payload.toLowerCase();
            return keys.any(payload.contains);
          })
          .toList()
          .reversed;
      if (logs.isEmpty) return const Center(child: Text('当前连接没有可关联的日志'));
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final log in logs)
            SelectableText('${log.dateTime} [${log.level}] ${log.payload}'),
        ],
      );
    }
    return const Center(child: Text('Mihomo 当前未提供该连接的 HTTP 报头或正文数据'));
  }

  Widget _infoCard(
    BuildContext context,
    String title,
    List<String> lines, {
    double width = 180,
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
        ],
      ),
    );
  }
}
