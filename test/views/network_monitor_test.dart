import 'dart:convert';

import 'package:bett_box/common/fixed.dart';
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
  String outboundLocalAddress = '',
  String outboundRemoteAddress = '',
  List<Map<String, Object?>> trace = const [],
}) {
  return TrackerInfo(
    id: id,
    upload: upload,
    start: DateTime.utc(2026, 8, 10),
    metadata: metadata ?? Metadata(process: process),
    chains: chains,
    rule: rule,
    rulePayload: '',
    outboundLocalAddress: outboundLocalAddress,
    outboundRemoteAddress: outboundRemoteAddress,
    trace: trace,
  );
}

void main() {
  testWidgets('相同进程图标的并发请求只调用一次原生接口', (tester) async {
    const channel = MethodChannel('app');
    const processPath =
        '/Applications/Bettbox-Icon-Dedup-Test.app/Contents/MacOS/Test';
    final icon = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/wHwAEAQH/CFoLAAAAAElFTkSuQmCC',
    );
    var processIconCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getPackageIcon' &&
              (call.arguments as Map)['processPath'] == processPath) {
            processIconCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return icon;
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

  testWidgets('首屏进程图标稍后可用时无需滚动即可替换占位图', (tester) async {
    const channel = MethodChannel('app');
    const processPath =
        '/Applications/Bettbox-Icon-Retry-Test.app/Contents/MacOS/Test';
    final icon = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/wHwAEAQH/CFoLAAAAAElFTkSuQmCC',
    );
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'getPackageIcon' ||
              (call.arguments as Map)['processPath'] != processPath) {
            return null;
          }
          calls++;
          return calls == 1 ? null : icon;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ProcessIcon(process: 'Test', processPath: processPath),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.apps_outlined), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 130));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byIcon(Icons.apps_outlined), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('macOS 无进程路径时仍交给原生层按进程名查找图标', (tester) async {
    const channel = MethodChannel('app');
    const process = 'Bettbox-Running-App-Icon-Test';
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getPackageIcon' &&
              (call.arguments as Map)['packageName'] == process &&
              (call.arguments as Map)['processPath'] == '') {
            calls++;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ProcessIcon(process: process)),
    );
    await tester.pump(const Duration(milliseconds: 130));

    expect(calls, 2);
  });

  testWidgets('复用进程图标组件时立即清除上一行图标', (tester) async {
    const channel = MethodChannel('app');
    const oldPath = '/Applications/Bettbox-Old-Icon.app/Contents/MacOS/Test';
    const newPath = '/Applications/Bettbox-No-Icon.app/Contents/MacOS/Test';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    var path = oldPath;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ProcessIcon(process: 'Test', processPath: path);
          },
        ),
      ),
    );
    expect(find.byKey(const ValueKey('Test\n$oldPath')), findsOneWidget);

    update(() => path = newPath);
    await tester.pump();
    expect(find.byKey(const ValueKey('Test\n$oldPath')), findsNothing);
    expect(find.byKey(const ValueKey('Test\n$newPath')), findsOneWidget);
    expect(find.byIcon(Icons.apps_outlined), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump();
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
    expect(PageLabel.networkMonitor.localizedName, '面板');
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

  test('连接状态按建立、连接、关闭、拦截、失败和未知映射', () {
    final connecting = _tracker(id: 'connecting', process: 'A', upload: 0);
    final connected = _tracker(
      id: 'connected',
      process: 'B',
      upload: 0,
      outboundRemoteAddress: '1.1.1.1:443',
    );
    final rejected = _tracker(
      id: 'rejected',
      process: 'C',
      upload: 0,
      chains: const ['REJECT'],
    );
    final failed = _tracker(
      id: 'failed',
      process: 'D',
      upload: 0,
      metadata: const Metadata(process: 'D', host: 'failed.example'),
      trace: const [
        {
          'stage': 'connect',
          'title': '建立出站',
          'detail': 'connection refused',
          'status': 'error',
        },
      ],
    );
    final closed = _tracker(
      id: 'closed',
      process: 'E',
      upload: 0,
      metadata: const Metadata(process: 'E', host: 'example.com'),
    );
    final unknown = _tracker(id: 'unknown', process: 'F', upload: 0);

    expect(
      monitorTrackerStatus(connecting, {'connecting'}),
      MonitorTrackerStatus.connecting,
    );
    expect(
      monitorTrackerStatus(connected, {'connected'}),
      MonitorTrackerStatus.connected,
    );
    expect(
      monitorTrackerStatus(rejected, const {}),
      MonitorTrackerStatus.blocked,
    );
    expect(monitorTrackerStatus(failed, const {}), MonitorTrackerStatus.failed);
    expect(monitorTrackerStatus(closed, const {}), MonitorTrackerStatus.closed);
    expect(
      monitorTrackerStatus(unknown, const {}),
      MonitorTrackerStatus.unknown,
    );
  });

  test('规则生成支持固定类型、手动策略和 no-resolve', () {
    expect(
      monitorGeneratedRule(
        MonitorRuleType.domainSuffix,
        'chatgpt.com',
        '自定义策略',
      ),
      'DOMAIN-SUFFIX,chatgpt.com,自定义策略',
    );
    expect(
      monitorGeneratedRule(
        MonitorRuleType.ipCidr,
        '1.1.1.1/32',
        'DIRECT',
        noResolve: true,
      ),
      'IP-CIDR,1.1.1.1/32,DIRECT,no-resolve',
    );
    expect(monitorGeneratedRule(MonitorRuleType.domain, '', 'DIRECT'), isEmpty);
    expect(
      monitorGeneratedRule(
        MonitorRuleType.domain,
        'example.com',
        'OWO-🇺🇸\u3000 US\u00a0 DMIT   CORONA',
      ),
      'DOMAIN,example.com,OWO-🇺🇸 US DMIT CORONA',
    );
  });

  test('规则策略选项合并策略组和节点并去重', () {
    final options = monitorRulePolicies(const [
      Group(
        name: '自动\u3000选择',
        type: GroupType.Selector,
        all: [
          Proxy(name: '节点\u00a0 A', type: 'ss'),
          Proxy(name: '节点   A', type: 'ss'),
        ],
      ),
    ]);

    expect(options['groups'], ['自动 选择']);
    expect(options['proxies'], ['节点 A']);
  });

  test('Sub-Store 文件 API 地址补齐 key 并切换 wholeFile 接口', () {
    expect(
      monitorSubStoreFileApiUri(
        'https://sub.example.com/api/file/fx.js',
        'secret-path',
        wholeFile: true,
      ).toString(),
      'https://sub.example.com/secret-path/api/wholeFile/fx.js',
    );
    expect(
      monitorSubStoreFileApiUri(
        'https://sub.example.com/secret-path/api/file/fx.js',
        'secret-path',
        wholeFile: false,
      ).toString(),
      'https://sub.example.com/secret-path/api/file/fx.js',
    );
  });

  test('Sub-Store 固定规则只向专用变量顶部添加一次', () {
    const script = '''
const BETTBOX_CUSTOM_RULES = [
  "DOMAIN,old.example,DIRECT",
];
''';
    final updated = monitorAppendSubStoreRule(
      script,
      'DOMAIN,new.example,Global',
    );

    expect(
      updated.indexOf('DOMAIN,new.example,Global'),
      lessThan(updated.indexOf('DOMAIN,old.example,DIRECT')),
    );
    expect(
      () => monitorAppendSubStoreRule(updated, 'DOMAIN,new.example,Global'),
      throwsStateError,
    );
  });

  test('Sub-Store 自定义规则可读取、修改、删除和排序', () {
    const script = '''
const before = true;
const BETTBOX_CUSTOM_RULES = [
  "DOMAIN,first.example,DIRECT",
  "DOMAIN,second.example,Global",
];
const after = true;
''';

    expect(monitorReadSubStoreRules(script), [
      'DOMAIN,first.example,DIRECT',
      'DOMAIN,second.example,Global',
    ]);
    final updated = monitorReplaceSubStoreRules(script, [
      'DOMAIN,second.example,DIRECT',
    ]);

    expect(monitorReadSubStoreRules(updated), ['DOMAIN,second.example,DIRECT']);
    expect(updated, contains('const before = true;'));
    expect(updated, contains('const after = true;'));
    expect(updated, isNot(contains('first.example')));
  });

  test('DNS 缓存命中明确说明本次没有发起查询', () {
    const event = MonitorConnectionTraceEvent(
      timestamp: 1,
      stage: 'dns_cache',
      title: '缓存命中',
      detail: 'example.com → 1.1.1.1',
      status: 'success',
    );

    expect(monitorTraceDisplayTitle(event), 'DNS 缓存命中');
    expect(
      monitorTraceDisplayDetail(event),
      'example.com → 1.1.1.1 · 本次未发起 DNS 查询',
    );
  });

  test('时间按本机时区显示，列表只显示最终策略并保留完整链路', () {
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
          chains: const [
            'OWO-🇺🇸\u3000 US\u00a0 DMIT   CORONA',
            'Fallback',
            'Global',
          ],
        ),
      ),
      'OWO-🇺🇸 US DMIT CORONA',
    );
    expect(
      monitorPolicyChain(
        _tracker(
          id: 'policy-chain',
          process: 'A',
          upload: 0,
          chains: const ['节点', 'Fallback', 'Global'],
        ),
      ),
      '节点 → Fallback → Global',
    );
  });

  test('详情日志只按当前请求的源端口和目标关联', () {
    final selected = _tracker(
      id: 'selected',
      process: 'codex',
      upload: 0,
      metadata: const Metadata(
        process: 'codex',
        sourceIP: '198.18.0.1',
        sourcePort: '63246',
        host: 'chatgpt.com',
        destinationPort: '443',
        remoteDestination: '69.63.197.145',
      ),
      outboundRemoteAddress: '69.63.197.145:443',
    );
    const current = MonitorLog(
      level: 'info',
      dateTime: '2026-08-10 16:39:12',
      payload:
          '[TCP] 198.18.0.1:63246(codex) --> chatgpt.com:443 match RuleSet(ai)',
    );
    const other = MonitorLog(
      level: 'info',
      dateTime: '2026-08-10 16:39:12',
      payload:
          '[TCP] 198.18.0.1:63247(codex) --> chatgpt.com:443 match RuleSet(ai)',
    );

    expect(monitorOutboundRemoteAddress(selected), '69.63.197.145:443');
    expect(monitorLogBelongsToTracker(current, selected), isTrue);
    expect(monitorLogBelongsToTracker(other, selected), isFalse);
  });

  test('连接地址与结构化链路按 Mihomo 字段映射', () {
    final selected = _tracker(
      id: 'selected',
      process: 'codex',
      upload: 0,
      metadata: const Metadata(process: 'codex', destinationIP: '198.18.0.1'),
      chains: const ['代理节点', '自动选择'],
      outboundLocalAddress: '192.168.0.2:52000',
      outboundRemoteAddress: '69.63.197.145:443',
      trace: const [
        {
          'timestamp': 1786352400123,
          'stage': 'dns',
          'title': '查询  A',
          'detail': 'example.com  ·  1.1.1.1',
          'status': 'pending',
        },
      ],
    );

    expect(monitorTargetIP(selected), '198.18.0.1');
    expect(monitorOutboundLocalAddress(selected), '192.168.0.2:52000');
    expect(monitorOutboundRemoteAddress(selected), '69.63.197.145:443');
    expect(monitorSocketHost('[2001:db8::1]:443'), '2001:db8::1');
    expect(monitorConnectionTrace(selected).single.title, '查询 A');
    expect(
      monitorConnectionTrace(selected).single.detail,
      'example.com · 1.1.1.1',
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
      'Proxy',
    );
  });

  test('连接状态回传按 ID 更新同一条请求且复用已知 App 路径', () {
    const appPath = '/Applications/ChatGPT.app/Contents/Resources/codex';
    final completed = _tracker(id: 'completed', process: 'codex', upload: 1);
    final active = _tracker(
      id: 'active',
      process: 'codex',
      upload: 2,
      metadata: const Metadata(process: 'codex', processPath: appPath),
    );
    final updated = active.copyWith(upload: 3);
    final requests = FixedList<TrackerInfo>(10)
      ..add(completed)
      ..add(active)
      ..addOrReplace(updated, (item) => item.id == updated.id);

    final restored = monitorRestoreProcessPaths(requests.list);

    expect(requests.length, 2);
    expect(requests.list.singleWhere((item) => item.id == 'active').upload, 3);
    expect(
      restored
          .singleWhere((item) => item.id == 'completed')
          .metadata
          .processPath,
      appPath,
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
