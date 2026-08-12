import 'dart:convert';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter/foundation.dart';

enum MonitorPage {
  requests,
  connections,
  dns,
  devices,
  traffic,
  logs,
  subStore,
}

enum MonitorRuleSource { domain, ip, process, transport }

enum MonitorRuleType {
  domain,
  domainSuffix,
  domainKeyword,
  ipCidr,
  ipCidr6,
  sourceIpCidr,
  processName,
  processPath,
  processNameRegex,
  destinationPort,
  sourcePort,
  network,
}

const monitorSubStoreRulesVariable = 'BETTBOX_CUSTOM_RULES';

typedef MonitorSubStoreRule = ({String rule, String note});

Uri monitorSubStoreFileApiUri(
  String address,
  String apiKey, {
  required bool wholeFile,
}) {
  final uri = Uri.parse(address.trim());
  if (!uri.hasScheme || !{'http', 'https'}.contains(uri.scheme)) {
    throw const FormatException('Sub-Store 文件地址必须是 HTTP(S) URL');
  }
  final segments = [...uri.pathSegments];
  final apiIndex = segments.indexOf('api');
  if (apiIndex < 0 ||
      apiIndex + 2 >= segments.length ||
      !{'file', 'wholeFile'}.contains(segments[apiIndex + 1])) {
    throw const FormatException('文件地址必须包含 /api/file/文件名');
  }
  final keySegments = apiKey
      .trim()
      .split('/')
      .where((part) => part.isNotEmpty)
      .toList();
  final prefix = segments.take(apiIndex).toList();
  final hasKey =
      keySegments.isEmpty ||
      (prefix.length >= keySegments.length &&
          listEquals(
            prefix.sublist(prefix.length - keySegments.length),
            keySegments,
          ));
  if (!hasKey) segments.insertAll(apiIndex, keySegments);
  final resolvedApiIndex = segments.indexOf('api');
  segments[resolvedApiIndex + 1] = wholeFile ? 'wholeFile' : 'file';
  return uri.replace(pathSegments: segments);
}

RegExpMatch _monitorSubStoreRulesMatch(String script) {
  final match = RegExp(
    'const\\s+$monitorSubStoreRulesVariable\\s*=\\s*\\[(.*?)\\];',
    dotAll: true,
  ).firstMatch(script);
  if (match == null) {
    throw StateError('脚本缺少 $monitorSubStoreRulesVariable 变量');
  }
  return match;
}

List<MonitorSubStoreRule> monitorReadSubStoreRules(String script) {
  final body = _monitorSubStoreRulesMatch(script).group(1)!.trim();
  if (body.isEmpty) return [];
  final rules = <MonitorSubStoreRule>[];
  var note = '';
  for (final rawLine in const LineSplitter().convert(body)) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('//')) {
      if (line.startsWith('// 说明：')) note = line.substring(6).trim();
      continue;
    }
    try {
      final decoded = jsonDecode(line.replaceFirst(RegExp(r',\s*$'), ''));
      if (decoded is! String) throw const FormatException();
      rules.add((rule: decoded, note: note));
      note = '';
    } catch (_) {
      throw StateError('$monitorSubStoreRulesVariable 必须每行使用一条 JSON 字符串规则');
    }
  }
  return rules;
}

String monitorReplaceSubStoreRules(
  String script,
  List<MonitorSubStoreRule> rules,
) {
  final match = _monitorSubStoreRulesMatch(script);
  final newline = script.contains('\r\n') ? '\r\n' : '\n';
  final content = rules
      .map((item) {
        final note = item.note.replaceAll(RegExp(r'\s+'), ' ').trim();
        final rule = '  ${jsonEncode(item.rule)},';
        return note.isEmpty ? rule : '  // 说明：$note$newline$rule';
      })
      .join(newline);
  final replacement =
      'const $monitorSubStoreRulesVariable = [$newline'
      '${content.isEmpty ? '' : '$content$newline'}];';
  return script.replaceRange(match.start, match.end, replacement);
}

String monitorAppendSubStoreRule(String script, String rule) {
  final rules = monitorReadSubStoreRules(script);
  if (rules.any((item) => item.rule == rule)) {
    throw StateError('该固定规则已存在');
  }
  return monitorReplaceSubStoreRules(script, [
    (rule: rule, note: ''),
    ...rules,
  ]);
}

extension MonitorRuleSourceExt on MonitorRuleSource {
  String get label => switch (this) {
    MonitorRuleSource.domain => '域名',
    MonitorRuleSource.ip => 'IP',
    MonitorRuleSource.process => '进程',
    MonitorRuleSource.transport => '端口 / 网络',
  };
}

extension MonitorRuleTypeExt on MonitorRuleType {
  String get clashName => switch (this) {
    MonitorRuleType.domain => 'DOMAIN',
    MonitorRuleType.domainSuffix => 'DOMAIN-SUFFIX',
    MonitorRuleType.domainKeyword => 'DOMAIN-KEYWORD',
    MonitorRuleType.ipCidr => 'IP-CIDR',
    MonitorRuleType.ipCidr6 => 'IP-CIDR6',
    MonitorRuleType.sourceIpCidr => 'SRC-IP-CIDR',
    MonitorRuleType.processName => 'PROCESS-NAME',
    MonitorRuleType.processPath => 'PROCESS-PATH',
    MonitorRuleType.processNameRegex => 'PROCESS-NAME-REGEX',
    MonitorRuleType.destinationPort => 'DST-PORT',
    MonitorRuleType.sourcePort => 'SRC-PORT',
    MonitorRuleType.network => 'NETWORK',
  };

  MonitorRuleSource get source => switch (this) {
    MonitorRuleType.domain ||
    MonitorRuleType.domainSuffix ||
    MonitorRuleType.domainKeyword => MonitorRuleSource.domain,
    MonitorRuleType.ipCidr ||
    MonitorRuleType.ipCidr6 ||
    MonitorRuleType.sourceIpCidr => MonitorRuleSource.ip,
    MonitorRuleType.processName ||
    MonitorRuleType.processPath ||
    MonitorRuleType.processNameRegex => MonitorRuleSource.process,
    _ => MonitorRuleSource.transport,
  };

  bool get supportsNoResolve =>
      this == MonitorRuleType.ipCidr ||
      this == MonitorRuleType.ipCidr6 ||
      this == MonitorRuleType.sourceIpCidr;
}

List<MonitorRuleType> monitorRuleTypes(MonitorRuleSource source) =>
    MonitorRuleType.values.where((type) => type.source == source).toList();

Map<String, Object?> monitorRulePolicies(List<Group> groups) {
  final groupNames = groups
      .map((group) => monitorCompactWhitespace(group.name))
      .where((name) => name.isNotEmpty);
  final proxyNames = groups.expand(
    (group) => group.all.map((proxy) => monitorCompactWhitespace(proxy.name)),
  );
  return {
    'groups': (groupNames.toSet().toList()..sort()),
    'proxies': (proxyNames.where((name) => name.isNotEmpty).toSet().toList()
      ..sort()),
  };
}

String monitorRuleDefaultValue(TrackerInfo item, MonitorRuleType type) {
  String cidr(String value, int bits) {
    value = monitorSocketHost(value);
    if (value.isEmpty || value.contains('/')) return value;
    return '$value/$bits';
  }

  final targetIp = monitorTargetIP(item);
  final directIp = monitorIsDirect(item)
      ? monitorSocketHost(monitorOutboundRemoteAddress(item))
      : '';
  return switch (type) {
    MonitorRuleType.domain ||
    MonitorRuleType.domainSuffix ||
    MonitorRuleType.domainKeyword => item.metadata.host.trim(),
    MonitorRuleType.ipCidr => cidr(
      item.metadata.dnsMode == DnsMode.fakeIp ? directIp : targetIp,
      32,
    ),
    MonitorRuleType.ipCidr6 => cidr(
      targetIp.contains(':') ? targetIp : directIp,
      128,
    ),
    MonitorRuleType.sourceIpCidr => cidr(
      item.metadata.sourceIP,
      item.metadata.sourceIP.contains(':') ? 128 : 32,
    ),
    MonitorRuleType.processName => item.metadata.process.trim(),
    MonitorRuleType.processPath => item.metadata.processPath.trim(),
    MonitorRuleType.processNameRegex => item.metadata.process.trim(),
    MonitorRuleType.destinationPort => item.metadata.destinationPort.trim(),
    MonitorRuleType.sourcePort => item.metadata.sourcePort.trim(),
    MonitorRuleType.network => item.metadata.network.trim().toLowerCase(),
  };
}

String monitorGeneratedRule(
  MonitorRuleType type,
  String value,
  String policy, {
  bool noResolve = false,
}) {
  value = value.trim();
  policy = monitorCompactWhitespace(policy);
  if (value.isEmpty || policy.isEmpty) return '';
  return [
    type.clashName,
    value,
    policy,
    if (noResolve && type.supportsNoResolve) 'no-resolve',
  ].join(',');
}

enum MonitorTrackerFacet {
  process,
  source,
  target,
  network,
  rule,
  outbound,
  status,
}

enum MonitorTrackerStatus {
  failed,
  blocked,
  connecting,
  connected,
  closed,
  unknown,
}

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
      title: '运行缓存',
      items: [
        '运行缓存 · fake-ip',
        '运行缓存 · redir-host',
        '运行缓存 · hosts',
        '运行缓存 · normal',
        '运行缓存 · 未知',
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
      'requests': requests.map(monitorTrackerToJson).toList(),
      'connections': withSpeed.map(monitorTrackerToJson).toList(),
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
}

Map<String, Object?> monitorTrackerToJson(TrackerInfo tracker) => {
  ...tracker.toJson(),
  'metadata': tracker.metadata.toJson(),
};

String monitorClientName(TrackerInfo item) {
  return item.metadata.process.isNotEmpty
      ? item.metadata.process
      : item.metadata.sourceIP;
}

List<TrackerInfo> monitorRestoreProcessPaths(Iterable<TrackerInfo> trackers) {
  final items = trackers.toList();
  final paths = <String, String>{};
  for (final item in items) {
    final process = item.metadata.process.trim().toLowerCase();
    final path = item.metadata.processPath.trim();
    if (process.isEmpty || path.isEmpty) continue;
    final current = paths[process] ?? '';
    if (current.isEmpty ||
        (!current.toLowerCase().contains('.app/') &&
            path.toLowerCase().contains('.app/'))) {
      paths[process] = path;
    }
  }
  return items.map((item) {
    if (item.metadata.processPath.trim().isNotEmpty) return item;
    final path = paths[item.metadata.process.trim().toLowerCase()] ?? '';
    return path.isEmpty
        ? item
        : item.copyWith(metadata: item.metadata.copyWith(processPath: path));
  }).toList();
}

TrackerInfo? monitorUpdatedSelection(
  TrackerInfo? selected,
  Iterable<TrackerInfo> requests,
  Iterable<TrackerInfo> connections,
) {
  if (selected == null) return null;
  for (final item in [...requests, ...connections]) {
    if (item.id == selected.id) return item;
  }
  return selected;
}

String monitorTrackerFacetLabel(MonitorTrackerFacet facet) => switch (facet) {
  MonitorTrackerFacet.process => '进程',
  MonitorTrackerFacet.source => '来源地址',
  MonitorTrackerFacet.target => '目标地址',
  MonitorTrackerFacet.network => '网络协议',
  MonitorTrackerFacet.rule => '规则类型',
  MonitorTrackerFacet.outbound => '出站链',
  MonitorTrackerFacet.status => '状态',
};

String monitorTrackerFacetValue(
  TrackerInfo item,
  MonitorTrackerFacet facet, [
  Set<String> activeIds = const {},
]) => switch (facet) {
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
  MonitorTrackerFacet.status => switch (monitorTrackerStatus(item, activeIds)) {
    MonitorTrackerStatus.failed => '失败',
    MonitorTrackerStatus.blocked => '已拦截',
    MonitorTrackerStatus.connecting => '建立中',
    MonitorTrackerStatus.connected => '已连接',
    MonitorTrackerStatus.closed => '已结束',
    MonitorTrackerStatus.unknown => '未知',
  },
};

bool monitorDnsMatchesFilter(MonitorDnsEntry item, String filter) =>
    switch (filter) {
      '' || '全部' => true,
      '配置 DNS' => item.source == '配置' && item.category != 'hosts',
      'Hosts' => item.category == 'hosts',
      '运行缓存' => item.source == '运行缓存',
      'Fake-IP' => item.source == '运行缓存' && item.category == 'fake-ip',
      _ => filter == monitorDnsFilterValue(item),
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

List<String> monitorPolicyParts(TrackerInfo item) => item.chains
    .map(monitorCompactWhitespace)
    .where((value) => value.isNotEmpty)
    .toList();

String monitorPolicyName(TrackerInfo item) {
  final policies = monitorPolicyParts(item);
  return policies.isEmpty ? '' : policies.first;
}

String monitorPolicyChain(TrackerInfo item) =>
    monitorPolicyParts(item).join(' → ');

String monitorCompactWhitespace(String value) => value
    .replaceAll(
      RegExp(
        r'[\s\u00A0\u1680\u2000-\u200B\u200E\u200F\u202A-\u202F\u205F\u2060-\u206F\u3000\uFEFF]+',
      ),
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
  final result = '${item.rule} ${item.chains.join(' ')}'.toUpperCase();
  if (result.contains('REJECT')) return MonitorTrackerStatus.blocked;
  final trace = monitorConnectionTrace(item);
  final established =
      monitorOutboundRemoteAddress(item).isNotEmpty ||
      item.upload > 0 ||
      item.download > 0 ||
      trace.any(
        (event) =>
            event.stage == 'connect' &&
            event.status != 'pending' &&
            event.status != 'error',
      );
  if (activeIds.contains(item.id)) {
    return established
        ? MonitorTrackerStatus.connected
        : MonitorTrackerStatus.connecting;
  }
  if (trace.isNotEmpty && trace.last.status == 'error') {
    return MonitorTrackerStatus.failed;
  }
  if (item.id.isNotEmpty &&
      (item.metadata.host.isNotEmpty ||
          item.metadata.destinationIP.isNotEmpty)) {
    return MonitorTrackerStatus.closed;
  }
  return MonitorTrackerStatus.unknown;
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

@immutable
class MonitorConnectionTraceEvent {
  final int timestamp;
  final String stage;
  final String title;
  final String detail;
  final String status;

  const MonitorConnectionTraceEvent({
    required this.timestamp,
    required this.stage,
    required this.title,
    required this.detail,
    required this.status,
  });

  factory MonitorConnectionTraceEvent.fromJson(Map<String, Object?> map) =>
      MonitorConnectionTraceEvent(
        timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
        stage: map['stage']?.toString() ?? '',
        title: monitorCompactWhitespace(map['title']?.toString() ?? ''),
        detail: monitorCompactWhitespace(map['detail']?.toString() ?? ''),
        status: map['status']?.toString() ?? '',
      );
}

List<MonitorConnectionTraceEvent> monitorConnectionTrace(TrackerInfo item) =>
    item.trace.map(MonitorConnectionTraceEvent.fromJson).toList();

bool monitorTraceIsDnsCacheHit(MonitorConnectionTraceEvent event) =>
    event.title == '缓存命中' ||
    (event.stage.toLowerCase().contains('dns') &&
        event.stage.toLowerCase().contains('cache'));

String monitorTraceDisplayTitle(MonitorConnectionTraceEvent event) =>
    monitorTraceIsDnsCacheHit(event) ? 'DNS 缓存命中' : event.title;

String monitorTraceDisplayDetail(MonitorConnectionTraceEvent event) =>
    monitorTraceIsDnsCacheHit(event)
    ? '${event.detail}${event.detail.isEmpty ? '' : ' · '}本次未发起 DNS 查询'
    : event.detail;

String monitorTraceClock(int timestamp) {
  if (timestamp <= 0) return '';
  final value = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.${value.millisecond.toString().padLeft(3, '0')}';
}

String monitorTargetIP(TrackerInfo item) => item.metadata.destinationIP.trim();

String monitorOutboundLocalAddress(TrackerInfo item) =>
    item.outboundLocalAddress.trim();

String monitorOutboundRemoteAddress(TrackerInfo item) {
  final socketAddress = item.outboundRemoteAddress.trim();
  return socketAddress.isNotEmpty
      ? socketAddress
      : item.metadata.remoteDestination.trim();
}

String monitorSocketHost(String address) {
  address = address.trim();
  if (address.startsWith('[')) {
    final end = address.indexOf(']');
    return end > 1 ? address.substring(1, end) : address;
  }
  final separator = address.lastIndexOf(':');
  return separator > 0 && address.indexOf(':') == separator
      ? address.substring(0, separator)
      : address;
}

bool monitorIsDirect(TrackerInfo item) =>
    monitorPolicyName(item).toUpperCase() == 'DIRECT';

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
      : item.metadata.destinationIP;
  final targets =
      {
            targetHost,
            item.metadata.destinationIP,
            monitorSocketHost(monitorOutboundRemoteAddress(item)),
          }
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
