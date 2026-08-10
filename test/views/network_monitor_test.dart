import 'package:bett_box/common/navigation.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/views/network_monitor_data.dart';
import 'package:flutter_test/flutter_test.dart';

TrackerInfo _tracker({
  required String id,
  required String process,
  required int upload,
  Metadata? metadata,
  List<String> chains = const ['代理'],
  String rule = 'MATCH',
}) {
  return TrackerInfo(
    id: id,
    upload: upload,
    start: DateTime.utc(2026, 8, 10),
    metadata: metadata ?? Metadata(process: process),
    chains: chains,
    rule: rule,
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

  test('状态点按错误、活动、结束和其他映射', () {
    final active = _tracker(id: 'active', process: 'A', upload: 0);
    final rejected = _tracker(
      id: 'rejected',
      process: 'B',
      upload: 0,
      chains: const ['REJECT'],
    );
    final finished = _tracker(
      id: 'finished',
      process: 'C',
      upload: 0,
      metadata: const Metadata(process: 'C', host: 'example.com'),
    );
    final other = _tracker(id: 'other', process: 'D', upload: 0);

    expect(
      monitorTrackerStatus(active, {'active'}),
      MonitorTrackerStatus.active,
    );
    expect(
      monitorTrackerStatus(rejected, const {}),
      MonitorTrackerStatus.error,
    );
    expect(
      monitorTrackerStatus(finished, const {}),
      MonitorTrackerStatus.finished,
    );
    expect(monitorTrackerStatus(other, const {}), MonitorTrackerStatus.other);
  });

  test('时间按本机时区显示，策略名称压缩连续空白', () {
    final utc = DateTime.utc(2026, 8, 10, 5, 42, 54);
    final local = utc.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');

    expect(
      monitorClock(utc),
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}',
    );
    expect(
      monitorPolicyName(
        _tracker(
          id: 'policy',
          process: 'A',
          upload: 0,
          chains: const ['OWO-🇺🇸   US  DMIT   CORONA'],
        ),
      ),
      'OWO-🇺🇸 US DMIT CORONA',
    );
  });

  test('DNS 类型与有效解析地址按 Mihomo 元数据映射', () {
    TrackerInfo dns(DnsMode mode, String address) => _tracker(
      id: mode.name,
      process: 'A',
      upload: 0,
      metadata: Metadata(
        process: 'A',
        host: 'example.com',
        destinationIP: address,
        dnsMode: mode,
      ),
    );

    expect(monitorDnsType(dns(DnsMode.hosts, '127.0.0.1')), '本地');
    expect(monitorDnsType(dns(DnsMode.normal, '1.1.1.1')), '系统');
    expect(monitorDnsType(dns(DnsMode.fakeIp, '198.18.0.1')), '动态');
    expect(monitorDnsAddress(dns(DnsMode.normal, '')), isEmpty);
  });

  test('不同页面使用可实际筛选的侧栏分类', () {
    expect(monitorStaticSidebarSections[MonitorPage.dns]!.first.items, [
      '全部',
      '本地',
      '系统',
      '动态',
    ]);
    expect(
      monitorStaticSidebarSections[MonitorPage.devices]!.expand(
        (section) => section.items,
      ),
      containsAll(['已分配', '未指派', '网关', '代理', '无', '已启用', '不活跃']),
    );
    expect(monitorDefaultSidebarFilter(MonitorPage.traffic), '策略');
    expect(monitorStaticSidebarSections[MonitorPage.logs]!.first.items, [
      '全部',
      '错误',
      '警告',
      '信息',
      '调试',
      '静默',
    ]);
  });
}
