import 'package:bett_box/common/system.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';

import 'network_monitor.dart';
import 'network_monitor_data.dart';

class NetworkMonitorNavigationView extends StatelessWidget {
  const NetworkMonitorNavigationView({super.key});

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
            embedded: true,
            mobile: true,
            initialPage: page,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!system.isDesktop) {
      return CommonScaffold(
        title: '工具',
        body: ListView(
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
                        child: Icon(_pages[index].$4, color: _pages[index].$5),
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
      );
    }
    return CommonScaffold(
      title: '网络面板',
      body: Center(
        child: FilledButton.icon(
          onPressed: openNetworkMonitorWindow,
          icon: const Icon(Icons.open_in_new),
          label: const Text('打开网络面板'),
        ),
      ),
    );
  }
}
