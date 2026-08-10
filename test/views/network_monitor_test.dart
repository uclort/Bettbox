import 'package:bett_box/common/navigation.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/views/network_monitor_data.dart';
import 'package:flutter_test/flutter_test.dart';

TrackerInfo _tracker({
  required String id,
  required String process,
  required int upload,
}) {
  return TrackerInfo(
    id: id,
    upload: upload,
    start: DateTime.utc(2026, 8, 10),
    metadata: Metadata(process: process),
    chains: const ['代理'],
    rule: 'MATCH',
    rulePayload: '',
  );
}

void main() {
  test('导航使用统一网络面板替换旧请求、连接和日志入口', () {
    final items = navigation.getItems(hasProxies: true);
    final labels = items.map((item) => item.label).toSet();

    expect(labels, contains(PageLabel.networkMonitor));
    expect(
      labels.intersection({
        PageLabel.requests,
        PageLabel.connections,
        PageLabel.logs,
      }),
      isEmpty,
    );
    final monitor = items.singleWhere(
      (item) => item.label == PageLabel.networkMonitor,
    );
    expect(
      monitor.modes,
      containsAll([NavigationItemMode.desktop, NavigationItemMode.more]),
    );
    expect(monitor.modes, isNot(contains(NavigationItemMode.mobile)));
  });

  test('表头重复点击切换方向，切换列使用合理默认方向', () {
    const initial = MonitorSortState(MonitorSortColumn.date, false);

    expect(initial.toggle(MonitorSortColumn.date).ascending, isTrue);
    expect(initial.toggle(MonitorSortColumn.upload).ascending, isFalse);
    expect(initial.toggle(MonitorSortColumn.id).ascending, isTrue);
  });

  test('连接列表按选定字段执行升序和降序', () {
    final slow = _tracker(id: '1', process: 'A', upload: 1);
    final fast = _tracker(id: '2', process: 'B', upload: 2);

    expect(
      compareMonitorTrackers(
        slow,
        fast,
        const MonitorSortState(MonitorSortColumn.upload, true),
      ),
      lessThan(0),
    );
    expect(
      compareMonitorTrackers(
        slow,
        fast,
        const MonitorSortState(MonitorSortColumn.upload, false),
      ),
      greaterThan(0),
    );
  });

  test('连接流量按实际刷新间隔换算为每秒速率', () {
    expect(
      monitorBytesPerSecond(2048, 1024, const Duration(milliseconds: 250)),
      4096,
    );
    expect(monitorBytesPerSecond(1024, 2048, Duration.zero), 0);
  });

  test('拖拽表头调整列宽并限制极端宽度', () {
    expect(monitorResizedColumnWidth(100, 20), 120);
    expect(monitorResizedColumnWidth(60, -20), 48);
    expect(monitorResizedColumnWidth(580, 40), 600);
  });
}
