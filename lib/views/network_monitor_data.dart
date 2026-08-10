import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter/foundation.dart';

enum MonitorPage { requests, connections, dns, devices, traffic, logs }

enum MonitorClientMode { client, host }

class NetworkMonitorSnapshotReader {
  Map<String, TrackerInfo> _previousConnections = const {};
  DateTime? _previousConnectionsAt;

  Future<Map<String, Object?>> read({
    required List<TrackerInfo> requests,
    required List<Log> logs,
  }) async {
    final connections = await clashCore.getConnections();
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
  id,
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
    return MonitorSortState(next, next == MonitorSortColumn.id);
  }
}

int compareMonitorTrackers(
  TrackerInfo a,
  TrackerInfo b,
  MonitorSortState sort,
) {
  final result = switch (sort.column) {
    MonitorSortColumn.id => a.id.compareTo(b.id),
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

String monitorRuleName(TrackerInfo item) {
  return [item.rule, item.rulePayload].where((e) => e.isNotEmpty).join(' ');
}

String monitorPolicyName(TrackerInfo item) => item.chains.join(' → ');

String monitorMethodName(TrackerInfo item) {
  if (item.metadata.destinationPort == '443') return 'HTTPS';
  if (item.metadata.destinationPort == '80') return 'HTTP';
  return item.metadata.network.toUpperCase();
}

String monitorAddress(TrackerInfo item) {
  final host = item.metadata.host.isNotEmpty
      ? item.metadata.host
      : item.metadata.destinationIP;
  return '$host:${item.metadata.destinationPort}';
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

String monitorShortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

String monitorClock(DateTime value) {
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
