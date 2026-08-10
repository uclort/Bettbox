import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter/foundation.dart';

enum MonitorPage { requests, connections, dns, devices, traffic, logs }

enum MonitorTrackerFacet { process, source, target, network, rule, outbound }

enum MonitorTrackerStatus { error, active, finished, other }

typedef MonitorSidebarSection = ({String title, List<String> items});

const monitorStaticSidebarSections = <MonitorPage, List<MonitorSidebarSection>>{
  MonitorPage.dns: [
    (
      title: 'Mihomo 配置',
      items: [
        '全部',
        '配置 · default-nameserver',
        '配置 · nameserver',
        '配置 · fallback',
        '配置 · proxy-server-nameserver',
        '配置 · direct-nameserver',
        '配置 · nameserver-policy',
      ],
    ),
    (title: 'Hosts', items: ['配置 · hosts', '系统 · hosts']),
    (
      title: '运行时解析',
      items: [
        '运行时 · fake-ip',
        '运行时 · redir-host',
        '运行时 · hosts',
        '运行时 · normal',
        '运行时 · 未知',
      ],
    ),
  ],
  MonitorPage.devices: [
    (title: 'Mihomo 来源', items: ['全部', '本机进程', '网络来源', '未识别']),
    (title: '连接状态', items: ['活动', '历史']),
  ],
  MonitorPage.traffic: [
    (title: '聚合字段', items: ['出站链', '规则类型', '进程', '来源地址', '网络协议', '目标主机']),
  ],
  MonitorPage.logs: [
    (title: 'Mihomo 日志级别', items: ['全部', 'error', 'warning', 'info', 'debug']),
  ],
};

String monitorDefaultSidebarFilter(MonitorPage page) {
  final sections = monitorStaticSidebarSections[page];
  return sections == null ? '' : sections.first.items.first;
}

class NetworkMonitorSnapshotReader {
  Map<String, TrackerInfo> _previousConnections = const {};
  DateTime? _previousConnectionsAt;

  Future<Map<String, Object?>> read({
    required List<TrackerInfo> requests,
    required List<Log> logs,
    bool includeTraffic = false,
  }) async {
    final connectionsFuture = clashCore.getConnections();
    final connections = await connectionsFuture;
    final traffic = includeTraffic ? await clashCore.getTraffic() : null;
    final totalTraffic = includeTraffic
        ? await clashCore.getTotalTraffic()
        : null;
    final now = DateTime.now();
    final elapsed = now.difference(_previousConnectionsAt ?? now);
    final current = <String, TrackerInfo>{};
    final withSpeed = connections.map((item) {
      final old = _previousConnections[item.id];
      final next = item.copyWith(
        uploadSpeed: old == null
            ? 0
            : monitorBytesPerSecond(item.upload, old.upload, elapsed),
        downloadSpeed: old == null
            ? 0
            : monitorBytesPerSecond(item.download, old.download, elapsed),
      );
      current[item.id] = item;
      return next;
    }).toList();
    _previousConnections = current;
    _previousConnectionsAt = now;
    return {
      'requests': requests.map(_trackerToJson).toList(),
      'connections': withSpeed.map(_trackerToJson).toList(),
      'logs': logs.map((log) => log.toJson()).toList(),
      if (traffic != null)
        'traffic': {'up': traffic.up.value, 'down': traffic.down.value},
      if (totalTraffic != null)
        'totalTraffic': {
          'up': totalTraffic.up.value,
          'down': totalTraffic.down.value,
        },
    };
  }

  Map<String, Object?> _trackerToJson(TrackerInfo tracker) {
    return <String, Object?>{
      ...tracker.toJson(),
      'metadata': tracker.metadata.toJson(),
    };
  }
}

enum MonitorSortColumn {
  status,
  date,
  client,
  rule,
  policy,
  upload,
  download,
  duration,
  method,
  address,
}

@immutable
class MonitorSortState {
  final MonitorSortColumn column;
  final bool ascending;

  const MonitorSortState(this.column, this.ascending);

  MonitorSortState toggle(MonitorSortColumn next) {
    if (column == next) return MonitorSortState(next, !ascending);
    return MonitorSortState(next, next == MonitorSortColumn.status);
  }
}

int compareMonitorTrackers(
  TrackerInfo a,
  TrackerInfo b,
  MonitorSortState sort, [
  Set<String> activeIds = const {},
]) {
  final result = switch (sort.column) {
    MonitorSortColumn.status => monitorTrackerStatus(
      a,
      activeIds,
    ).index.compareTo(monitorTrackerStatus(b, activeIds).index),
    MonitorSortColumn.date => a.start.compareTo(b.start),
    MonitorSortColumn.client => monitorClientName(
      a,
    ).compareTo(monitorClientName(b)),
    MonitorSortColumn.rule => monitorRuleName(a).compareTo(monitorRuleName(b)),
    MonitorSortColumn.policy => monitorPolicyName(
      a,
    ).compareTo(monitorPolicyName(b)),
    MonitorSortColumn.upload => a.upload.compareTo(b.upload),
    MonitorSortColumn.download => a.download.compareTo(b.download),
    MonitorSortColumn.duration => a.start.compareTo(b.start),
    MonitorSortColumn.method => monitorMethodName(
      a,
    ).compareTo(monitorMethodName(b)),
    MonitorSortColumn.address => monitorAddress(a).compareTo(monitorAddress(b)),
  };
  return sort.ascending ? result : -result;
}

String monitorClientName(TrackerInfo item) {
  return item.metadata.process.isNotEmpty
      ? item.metadata.process
      : item.metadata.sourceIP;
}

String monitorTrackerFacetLabel(MonitorTrackerFacet facet) => switch (facet) {
  MonitorTrackerFacet.process => '进程',
  MonitorTrackerFacet.source => '来源地址',
  MonitorTrackerFacet.target => '目标地址',
  MonitorTrackerFacet.network => '网络协议',
  MonitorTrackerFacet.rule => '规则类型',
  MonitorTrackerFacet.outbound => '出站链',
};

String monitorTrackerFacetValue(TrackerInfo item, MonitorTrackerFacet facet) =>
    switch (facet) {
      MonitorTrackerFacet.process =>
        item.metadata.process.trim().isEmpty
            ? '未知进程'
            : item.metadata.process.trim(),
      MonitorTrackerFacet.source =>
        item.metadata.sourceIP.trim().isEmpty
            ? '未知来源'
            : item.metadata.sourceIP.trim(),
      MonitorTrackerFacet.target => monitorTargetName(item),
      MonitorTrackerFacet.network =>
        item.metadata.network.trim().isEmpty
            ? '未知协议'
            : item.metadata.network.trim().toUpperCase(),
      MonitorTrackerFacet.rule =>
        item.rule.trim().isEmpty ? '未匹配规则' : item.rule.trim(),
      MonitorTrackerFacet.outbound =>
        monitorPolicyName(item).isEmpty ? '无出站链' : monitorPolicyName(item),
    };

String monitorTargetName(TrackerInfo item) {
  final host = item.metadata.host.trim();
  if (host.isNotEmpty) return host;
  final address = item.metadata.destinationIP.trim();
  return address.isEmpty ? '未知目标' : address;
}

String monitorDeviceSource(TrackerInfo item) {
  if (item.metadata.process.trim().isNotEmpty) return '本机进程';
  if (item.metadata.sourceIP.trim().isNotEmpty) return '网络来源';
  return '未识别';
}

String monitorDeviceKey(TrackerInfo item) {
  final process = item.metadata.process.trim();
  if (process.isNotEmpty) return process;
  final source = item.metadata.sourceIP.trim();
  return source.isEmpty ? '未识别' : source;
}

String monitorTrafficGroupValue(TrackerInfo item, String dimension) =>
    switch (dimension) {
      '规则类型' => item.rule.trim().isEmpty ? '未匹配规则' : item.rule.trim(),
      '进程' => monitorTrackerFacetValue(item, MonitorTrackerFacet.process),
      '来源地址' => monitorTrackerFacetValue(item, MonitorTrackerFacet.source),
      '网络协议' => monitorTrackerFacetValue(item, MonitorTrackerFacet.network),
      '目标主机' => monitorTargetName(item),
      _ => monitorTrackerFacetValue(item, MonitorTrackerFacet.outbound),
    };

String monitorRuleName(TrackerInfo item) {
  return [item.rule, item.rulePayload].where((e) => e.isNotEmpty).join(' ');
}

String monitorPolicyName(TrackerInfo item) => item.chains
    .map((value) => monitorCompactWhitespace(value))
    .where((value) => value.isNotEmpty)
    .join(' → ');

String monitorCompactWhitespace(String value) => value
    .replaceAll(
      RegExp(r'[\s\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000\uFEFF]+'),
      ' ',
    )
    .trim();

bool monitorIsInternalTracker(TrackerInfo item) {
  final metadata = item.metadata;
  if (metadata.process.trim().isNotEmpty ||
      metadata.processPath.trim().isNotEmpty) {
    return false;
  }
  final source = metadata.sourceIP.trim();
  final port = metadata.sourcePort.trim();
  return (source.isEmpty || source == '0.0.0.0' || source == '::') &&
      (port.isEmpty || port == '0');
}

MonitorTrackerStatus monitorTrackerStatus(
  TrackerInfo item,
  Set<String> activeIds,
) {
  if (activeIds.contains(item.id)) return MonitorTrackerStatus.active;
  final result = '${item.rule} ${item.chains.join(' ')}'.toUpperCase();
  if (result.contains('REJECT')) return MonitorTrackerStatus.error;
  if (item.id.isNotEmpty &&
      (item.metadata.host.isNotEmpty ||
          item.metadata.destinationIP.isNotEmpty)) {
    return MonitorTrackerStatus.finished;
  }
  return MonitorTrackerStatus.other;
}

String monitorDnsMode(TrackerInfo item) => switch (item.metadata.dnsMode) {
  DnsMode.hosts => 'hosts',
  DnsMode.fakeIp => 'fake-ip',
  DnsMode.redirHost => 'redir-host',
  DnsMode.normal => 'normal',
  null => '未知',
};

String monitorDnsAddress(TrackerInfo item) =>
    item.metadata.destinationIP.trim();

@immutable
class MonitorDnsEntry {
  final String source;
  final String category;
  final String name;
  final String value;
  final String detail;
  final String lastActivity;

  const MonitorDnsEntry({
    required this.source,
    required this.category,
    required this.name,
    required this.value,
    required this.detail,
    this.lastActivity = '',
  });

  factory MonitorDnsEntry.fromJson(Object? value) {
    final map = normalizeMonitorMap(value);
    return MonitorDnsEntry(
      source: map['source']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      detail: map['detail']?.toString() ?? '',
      lastActivity: map['lastActivity']?.toString() ?? '',
    );
  }

  Map<String, Object?> toJson() => {
    'source': source,
    'category': category,
    'name': name,
    'value': value,
    'detail': detail,
    'lastActivity': lastActivity,
  };
}

List<MonitorDnsEntry> monitorConfiguredDnsEntries(
  Map<String, dynamic> rawConfig,
  String systemHosts,
) {
  final entries = <MonitorDnsEntry>[];
  final dns = rawConfig['dns'];
  if (dns is Map) {
    const sections = <String, String>{
      'default-nameserver': '引导 DNS',
      'nameserver': '主 DNS',
      'fallback': '备用 DNS',
      'proxy-server-nameserver': '代理节点 DNS',
      'direct-nameserver': '直连 DNS',
    };
    for (final section in sections.entries) {
      for (final value in _monitorStringValues(dns[section.key])) {
        entries.add(
          MonitorDnsEntry(
            source: '配置',
            category: section.key,
            name: section.value,
            value: value,
            detail: '当前生效配置',
          ),
        );
      }
    }
    final policies = dns['nameserver-policy'];
    if (policies is Map) {
      for (final policy in policies.entries) {
        for (final value in _monitorStringValues(policy.value)) {
          entries.add(
            MonitorDnsEntry(
              source: '配置',
              category: 'nameserver-policy',
              name: policy.key.toString(),
              value: value,
              detail: '域名策略',
            ),
          );
        }
      }
    }
  }
  final hosts = rawConfig['hosts'];
  if (hosts is Map) {
    for (final host in hosts.entries) {
      for (final value in _monitorStringValues(host.value)) {
        entries.add(
          MonitorDnsEntry(
            source: '配置',
            category: 'hosts',
            name: host.key.toString(),
            value: value,
            detail: '当前生效配置',
          ),
        );
      }
    }
  }
  entries.addAll(monitorSystemHostsEntries(systemHosts));
  return entries;
}

List<MonitorDnsEntry> monitorSystemHostsEntries(String content) {
  final entries = <MonitorDnsEntry>[];
  for (final rawLine in content.split('\n')) {
    final line = rawLine.split('#').first.trim();
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    for (final host in parts.skip(1)) {
      entries.add(
        MonitorDnsEntry(
          source: '系统',
          category: 'hosts',
          name: host,
          value: parts.first,
          detail: '/etc/hosts',
        ),
      );
    }
  }
  return entries;
}

String monitorDnsFilterValue(MonitorDnsEntry item) =>
    '${item.source} · ${item.category}';

List<String> _monitorStringValues(Object? value) {
  if (value == null) return const [];
  if (value is Iterable) {
    return value
        .expand(_monitorStringValues)
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final text = monitorCompactWhitespace(value.toString());
  return text.isEmpty ? const [] : [text];
}

String monitorMethodName(TrackerInfo item) {
  if (item.metadata.destinationPort == '443') return 'HTTPS';
  if (item.metadata.destinationPort == '80') return 'HTTP';
  return item.metadata.network.toUpperCase();
}

String monitorAddress(TrackerInfo item) {
  final host = item.metadata.host.isNotEmpty
      ? item.metadata.host
      : item.metadata.destinationIP;
  return monitorEndpoint(host, item.metadata.destinationPort);
}

String monitorEndpoint(String host, String port) {
  host = host.trim();
  port = port.trim();
  if (host.isEmpty) return '';
  if (host.contains(':') && !host.startsWith('[')) host = '[$host]';
  return port.isEmpty ? host : '$host:$port';
}

Map<String, Object?> normalizeMonitorMap(Object? value) {
  final map = value as Map;
  return map.map(
    (key, item) => MapEntry(key.toString(), normalizeMonitorValue(item)),
  );
}

Object? normalizeMonitorValue(Object? value) {
  if (value is Map) return normalizeMonitorMap(value);
  if (value is List) return value.map(normalizeMonitorValue).toList();
  return value;
}

class MonitorLog {
  final String level;
  final String payload;
  final String dateTime;

  const MonitorLog({
    required this.level,
    required this.payload,
    required this.dateTime,
  });

  factory MonitorLog.fromJson(Object? value) {
    final map = normalizeMonitorMap(value);
    return MonitorLog(
      level: map['LogLevel']?.toString() ?? 'info',
      payload: map['Payload']?.toString() ?? '',
      dateTime: map['dateTime']?.toString() ?? '',
    );
  }
}

String monitorRemoteIP(TrackerInfo item) {
  final remote = item.metadata.remoteDestination.trim();
  return remote.isNotEmpty ? remote : item.metadata.destinationIP.trim();
}

bool monitorLogBelongsToTracker(MonitorLog log, TrackerInfo item) {
  final payload = log.payload.toLowerCase();
  if (item.id.isNotEmpty && payload.contains(item.id.toLowerCase())) {
    return true;
  }
  final source = monitorEndpoint(
    item.metadata.sourceIP,
    item.metadata.sourcePort,
  ).toLowerCase();
  if (source.isEmpty || !payload.contains(source)) return false;
  final targetHost = item.metadata.host.trim().isNotEmpty
      ? item.metadata.host
      : monitorRemoteIP(item);
  final targets =
      {targetHost, item.metadata.destinationIP, monitorRemoteIP(item)}
          .map(
            (target) => monitorEndpoint(target, item.metadata.destinationPort),
          )
          .toSet()
        ..removeWhere((target) => target.isEmpty);
  return targets.isEmpty || targets.any((target) => payload.contains(target));
}

String monitorClock(DateTime value) {
  value = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

String monitorDuration(DateTime start) {
  final seconds = DateTime.now().difference(start).inSeconds.clamp(0, 1 << 30);
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
  return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
}

String monitorBytes(int value) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var amount = value.toDouble();
  var unit = 0;
  while (amount >= 1024 && unit < units.length - 1) {
    amount /= 1024;
    unit++;
  }
  final digits = unit == 0 || amount >= 10 ? 0 : 1;
  return '${amount.toStringAsFixed(digits)} ${units[unit]}';
}

int monitorBytesPerSecond(int current, int previous, Duration elapsed) {
  if (current <= previous || elapsed.inMicroseconds <= 0) return 0;
  return ((current - previous) *
          Duration.microsecondsPerSecond /
          elapsed.inMicroseconds)
      .round();
}

double monitorResizedColumnWidth(double current, double delta) {
  return (current + delta).clamp(48, 600);
}
