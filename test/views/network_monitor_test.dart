import 'package:bett_box/common/navigation.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/views/connection/item.dart';
import 'package:bett_box/views/network_monitor_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  testWidgets('相同进程图标的并发请求只调用一次原生接口', (tester) async {
    const channel = MethodChannel('app');
    const processPath =
        '/Applications/Bettbox-Icon-Dedup-Test.app/Contents/MacOS/Test';
    var processIconCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getPackageIcon' &&
              (call.arguments as Map)['processPath'] == processPath) {
            processIconCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            ProcessIcon(process: 'Test', processPath: processPath),
            ProcessIcon(process: 'Test', processPath: processPath),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(processIconCalls, 1);
  });

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
    expect(initial.toggle(MonitorSortColumn.status).ascending, isTrue);
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
          chains: const ['OWO-🇺🇸\u3000 US\u00a0 DMIT   CORONA'],
        ),
      ),
      'OWO-🇺🇸 US DMIT CORONA',
    );
  });

  test('DNS 模式与有效解析地址按 Mihomo 元数据映射', () {
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

    expect(monitorDnsMode(dns(DnsMode.hosts, '127.0.0.1')), 'hosts');
    expect(monitorDnsMode(dns(DnsMode.normal, '1.1.1.1')), 'normal');
    expect(monitorDnsMode(dns(DnsMode.fakeIp, '198.18.0.1')), 'fake-ip');
    expect(monitorDnsAddress(dns(DnsMode.normal, '')), isEmpty);
  });

  test('DNS 数据按生效配置、配置 Hosts 和系统 Hosts 分类', () {
    final entries = monitorConfiguredDnsEntries({
      'dns': {
        'nameserver': ['https://dns.example/dns-query'],
        'fallback': ['1.1.1.1'],
        'nameserver-policy': {
          '+.example.com': ['system://'],
        },
      },
      'hosts': {
        'profile.example': ['10.0.0.2'],
      },
    }, '127.0.0.1 localhost local.test # 注释');

    expect(
      entries.map((item) => item.source).toSet(),
      containsAll(['配置', '系统']),
    );
    expect(
      entries.any(
        (item) =>
            item.source == '配置' &&
            item.category == 'nameserver' &&
            item.name == '主 DNS' &&
            item.value == 'https://dns.example/dns-query',
      ),
      isTrue,
    );
    expect(
      entries.any(
        (item) => item.name == 'local.test' && item.value == '127.0.0.1',
      ),
      isTrue,
    );
  });

  test('仅隐藏没有进程和来源的 Mihomo 内部连接', () {
    final internal = _tracker(
      id: 'internal',
      process: '',
      upload: 0,
      metadata: const Metadata(
        destinationIP: '223.5.5.5',
        destinationPort: '443',
        sourcePort: '0',
      ),
    );
    final rejected = _tracker(
      id: 'rejected',
      process: 'syspolicyd',
      upload: 0,
      chains: const ['REJECT'],
    );

    expect(monitorIsInternalTracker(internal), isTrue);
    expect(monitorIsInternalTracker(rejected), isFalse);
  });

  test('不同页面使用可实际筛选的侧栏分类', () {
    final dnsItems = monitorStaticSidebarSections[MonitorPage.dns]!.expand(
      (section) => section.items,
    );
    expect(
      dnsItems,
      containsAll([
        '全部',
        '配置 · nameserver',
        '配置 · hosts',
        '系统 · hosts',
        '运行时 · fake-ip',
      ]),
    );
    expect(
      monitorStaticSidebarSections[MonitorPage.devices]!.expand(
        (section) => section.items,
      ),
      containsAll(['本机进程', '网络来源', '未识别', '活动', '历史']),
    );
    expect(monitorDefaultSidebarFilter(MonitorPage.traffic), '出站链');
    expect(monitorStaticSidebarSections[MonitorPage.logs]!.first.items, [
      '全部',
      'error',
      'warning',
      'info',
      'debug',
    ]);
  });

  test('请求和连接分类直接使用 Mihomo TrackerInfo 字段', () {
    final item = _tracker(
      id: 'facet',
      process: 'Bettbox',
      upload: 0,
      metadata: const Metadata(
        process: 'Bettbox',
        sourceIP: '127.0.0.1',
        host: 'example.com',
        network: 'tcp',
      ),
      chains: const ['Proxy', 'GLOBAL'],
      rule: 'DOMAIN-SUFFIX',
    );

    expect(
      monitorTrackerFacetValue(item, MonitorTrackerFacet.process),
      'Bettbox',
    );
    expect(
      monitorTrackerFacetValue(item, MonitorTrackerFacet.source),
      '127.0.0.1',
    );
    expect(
      monitorTrackerFacetValue(item, MonitorTrackerFacet.target),
      'example.com',
    );
    expect(monitorTrackerFacetValue(item, MonitorTrackerFacet.network), 'TCP');
    expect(
      monitorTrackerFacetValue(item, MonitorTrackerFacet.rule),
      'DOMAIN-SUFFIX',
    );
    expect(
      monitorTrackerFacetValue(item, MonitorTrackerFacet.outbound),
      'Proxy → GLOBAL',
    );
  });

  test('设备和流量分类不再伪造 Surge 字段', () {
    final process = _tracker(id: 'process', process: 'Bettbox', upload: 0);
    final source = _tracker(
      id: 'source',
      process: '',
      upload: 0,
      metadata: const Metadata(sourceIP: '192.168.1.2', network: 'udp'),
    );

    expect(monitorDeviceSource(process), '本机进程');
    expect(monitorDeviceSource(source), '网络来源');
    expect(monitorDeviceKey(source), '192.168.1.2');
    expect(monitorTrafficGroupValue(source, '网络协议'), 'UDP');
    expect(monitorTrafficGroupValue(source, '来源地址'), '192.168.1.2');
  });
}
