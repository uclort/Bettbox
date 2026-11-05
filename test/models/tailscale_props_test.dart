import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

// BETTBOX-CUSTOM: Tailscale 共存默认关闭；开启后合并 TUN 排除、系统代理例外与前置规则。
void main() {
  test('Tailscale 共存默认关闭且不改变 TUN 与系统代理例外', () {
    const props = NetworkProps();
    expect(props.tailscale.enable, isFalse);
    expect(props.realBypassDomain, props.bypassDomain);
    const tun = Tun(routeExcludeAddress: ['172.16.0.0/12']);
    expect(props.tailscale.applyToTun(tun), tun);
    expect(props.tailscale.patchJson, isNull);
  });

  test('开启后合并 Tailnet 网段、代理例外与前置规则', () {
    const props = NetworkProps(
      bypassDomain: ['localhost', '*.ts.net'],
      tailscale: TailscaleProps(
        enable: true,
        dnsDomains: ['+.ts.net', 'corp.example.'],
      ),
    );
    final tun = props.tailscale.applyToTun(
      const Tun(routeExcludeAddress: ['100.64.0.0/10', '172.16.0.0/12']),
    );
    expect(tun.routeExcludeAddress, [
      '100.64.0.0/10',
      '172.16.0.0/12',
      'fd7a:115c:a1e0::/48',
    ]);
    expect(props.realBypassDomain, ['localhost', '*.ts.net', '100.64.0.0/10']);
    expect(props.tailscale.prependRules, [
      'DOMAIN-SUFFIX,ts.net,DIRECT',
      'DOMAIN-SUFFIX,corp.example,DIRECT',
      'IP-CIDR,100.64.0.0/10,DIRECT,no-resolve',
      'IP-CIDR6,fd7a:115c:a1e0::/48,DIRECT,no-resolve',
    ]);
    expect(props.tailscale.patchJson, {
      'dns-domains': ['+.ts.net', 'corp.example.'],
      'dns-server': '100.100.100.100',
    });
  }, skip: !system.isDesktop);

  test('恢复默认保留开关状态', () {
    const props = TailscaleProps(
      enable: true,
      dnsServer: '',
      routeExcludeAddress: [],
      dnsDomains: ['a.b'],
      bypassDomain: [],
    );
    expect(props.reset(), defaultTailscaleProps.copyWith(enable: true));
    expect(const TailscaleProps().reset(), defaultTailscaleProps);
  });

  test('旧配置缺少 tailscale 字段时使用默认值', () {
    final props = NetworkProps.fromJson({'systemProxy': true});
    expect(props.tailscale, defaultTailscaleProps);
    final restored = NetworkProps.fromJson(
      const NetworkProps(tailscale: TailscaleProps(enable: true)).toJson().map(
        (k, v) => MapEntry(k, v is TailscaleProps ? v.toJson() : v),
      ),
    );
    expect(restored.tailscale.enable, isTrue);
  });

  // BETTBOX-CUSTOM: 内置 Tailscale 节点：Tailnet 进 TUN 交给节点，不加系统代理例外。
  test('内置节点把 Tailnet 规则指向节点并下发节点参数', () {
    const props = NetworkProps(
      tailscale: TailscaleProps(
        nodeEnable: true,
        nodeHostname: 'mac-bettbox',
        nodeAuthKey: ' tskey-auth-x ',
        nodeExitNode: 'oracle',
      ),
    );
    const tun = Tun(routeExcludeAddress: ['172.16.0.0/12']);
    expect(props.tailscale.applyToTun(tun), tun);
    expect(props.realBypassDomain, props.bypassDomain);
    expect(props.tailscale.prependRules, [
      'DOMAIN-SUFFIX,ts.net,$tailscaleNodeName',
      'IP-CIDR,100.64.0.0/10,$tailscaleNodeName,no-resolve',
      'IP-CIDR6,fd7a:115c:a1e0::/48,$tailscaleNodeName,no-resolve',
    ]);
    // 登录方式只认登录状态，填过的 key 也不下发。
    expect(props.tailscale.patchJson?['default-node'], tailscaleNodeName);
    expect(props.tailscale.patchJson?['nodes'], [
      {
        'name': tailscaleNodeName,
        'state-id': '',
        'hostname': 'mac-bettbox',
        'auth-mode': 'login',
        'exit-node': 'oracle',
        'accept-routes': true,
      },
    ]);
    expect(props.tailscale.patchJson?['ranges'], defaultTailscaleRouteExcludeAddress);
  });

  // BETTBOX-CUSTOM: Auth Key 方式：只下发 key，设备名加 -key 后缀，未填 key 时不注入节点。
  test('Auth Key 方式下发 key 并区分设备名', () {
    const props = TailscaleProps(
      nodeEnable: true,
      nodeUseAuthKey: true,
      nodeHostname: 'mac-bettbox',
      nodeAuthKey: ' tskey-auth-x ',
    );
    expect(props.effectiveNodeHostname, 'mac-bettbox-key');
    expect(props.copyWith(nodeHostname: 'mac-key').effectiveNodeHostname, 'mac-key');
    expect(props.copyWith(nodeUseAuthKey: false).effectiveNodeHostname, 'mac-bettbox');
    expect(const TailscaleProps(nodeUseAuthKey: true).effectiveNodeHostname, endsWith('-bettbox-key'));
    final node = (props.patchJson?['nodes'] as List).first as Map;
    expect(node['auth-mode'], 'auth-key');
    expect(node['auth-key'], 'tskey-auth-x');
    expect(node['hostname'], 'mac-bettbox-key');

    final missing = props.copyWith(nodeAuthKey: ' ');
    expect(missing.nodeActive, isFalse);
    expect(missing.nodeAuthKeyMissing, isTrue);
    expect(missing.patchJson, isNull);
  });

  // BETTBOX-CUSTOM: 内置节点开启时去掉让 Tailnet 绕开节点的 TUN 排除与系统代理例外。
  test('内置节点忽略 Tailnet 的 TUN 排除与系统代理例外', () {
    const props = NetworkProps(
      bypassDomain: ['localhost', '*.ts.net', 'vps.tail1.ts.net', '100.64.0.0/10', '*.lan'],
      tailscale: TailscaleProps(nodeEnable: true),
    );
    expect(props.realBypassDomain, ['localhost', '*.lan']);
    final tun = props.tailscale.applyToTun(
      const Tun(routeExcludeAddress: ['100.64.0.0/10', '172.16.0.0/12']),
    );
    expect(tun.routeExcludeAddress, ['172.16.0.0/12']);
    // 只开 App 共存时保留
    const app = NetworkProps(
      bypassDomain: ['*.ts.net'],
      tailscale: TailscaleProps(enable: true),
    );
    expect(app.realBypassDomain, contains('*.ts.net'));
  });

  test('两个开关同时开启时以内置节点为准', () {
    const props = NetworkProps(
      tailscale: TailscaleProps(enable: true, nodeEnable: true),
    );
    expect(props.tailscale.appRouting, isFalse);
    const tun = Tun(routeExcludeAddress: ['172.16.0.0/12']);
    expect(props.tailscale.applyToTun(tun), tun);
    expect(props.realBypassDomain, props.bypassDomain);
    expect(
      props.tailscale.prependRules.first,
      'DOMAIN-SUFFIX,ts.net,$tailscaleNodeName',
    );
  });

  test('设备名留空时使用本机名-bettbox 且只含合法字符', () {
    final hostname = const TailscaleProps().effectiveNodeHostname;
    expect(hostname, endsWith('-bettbox'));
    expect(RegExp(r'^[a-z0-9-]+$').hasMatch(hostname), isTrue);
  });

  test('恢复默认保留两个开关与策略组设置', () {
    const props = TailscaleProps(
      enable: true,
      nodeEnable: true,
      nodeAuthKey: 'k',
      nodeUseAuthKey: true,
      nodeHostname: 'x',
      nodeAcceptRoutes: false,
      dnsDomains: ['a.b'],
    );
    expect(props.reset(), props.copyWith(dnsDomains: defaultTailscaleDnsDomains));
  });

  // BETTBOX-CUSTOM: 旧版代理通道迁移为策略组：身份目录（state-id）与设备名不变，升级后无需重新登录。
  test('旧版代理通道迁移为 Tailscale 策略组', () {
    const legacy = TailscaleProps(
      nodeEnable: true,
      nodeHostname: 'mac-bettbox',
      nodeProxyDevices: ['rex.tailc7e14e.ts.net,100.121.3.59'],
      nodeProxyVia: 'Global',
    );
    final groups = legacy.nodeGroups;
    expect(groups.map((g) => g.name), [tailscaleNodeName, tailscaleProxyNodeName]);
    expect(legacy.defaultNodeGroup.id, '');
    expect(groups.last.id, tailscaleLegacyProxyStateId);
    expect(legacy.effectiveHostname(groups.last), 'mac-bettbox-proxy');
    final nodes = legacy.patchJson?['nodes'] as List;
    expect(nodes.last, {
      'name': tailscaleProxyNodeName,
      'state-id': 'proxy',
      'hostname': 'mac-bettbox-proxy',
      'auth-mode': 'login',
      'exit-node': '',
      'accept-routes': true,
      'dialer-proxy': 'Global',
    });
    expect(legacy.prependRules.take(3), [
      'DOMAIN,rex.tailc7e14e.ts.net,$tailscaleProxyNodeName',
      'IP-CIDR,100.121.3.59/32,$tailscaleProxyNodeName,no-resolve',
      'DOMAIN-SUFFIX,ts.net,$tailscaleNodeName',
    ]);
    final keyed = legacy.copyWith(nodeUseAuthKey: true, nodeAuthKey: 'k');
    expect(keyed.effectiveHostname(keyed.nodeGroups.last), 'mac-bettbox-proxy-key');
    // 非默认组 key 留空时用默认组的 key
    expect((keyed.patchJson?['nodes'] as List).last['auth-key'], 'k');
    // 第一次写入后不再读取旧字段
    final saved = legacy.withGroups(legacy.nodeGroups);
    expect(saved.groups, hasLength(2));
    expect(saved.defaultGroup, tailscaleNodeName);
    expect(saved.copyWith(nodeProxyVia: 'Other').nodeGroups.last.via, 'Global');
  });

  // BETTBOX-CUSTOM: 设备指定给策略组，规则排在默认组兜底规则之前；同一台设备只在一个组里。
  test('Tailscale 策略组的设备、自定义规则与默认组', () {
    const rex = TailscalePeer(
      dnsName: 'rex.tailc7e14e.ts.net.',
      ips: ['100.121.3.59', 'fd7a:115c:a1e0::1'],
    );
    var props = const TailscaleProps(nodeEnable: true, nodeHostname: 'mac');
    final proxy = props.newGroup('Tailscale-Proxy').copyWith(
      via: 'Global',
      rules: ['domain-suffix, corp.example', 'IP-CIDR,100.100.1.0/24,no-resolve', 'MATCH,x', 'bad'],
    );
    expect(proxy.id, 'g-tailscale-proxy');
    props = props.updateGroup(proxy.id, proxy);
    final other = props.newGroup('Other');
    props = props.updateGroup(other.id, other);
    expect(props.groupOfPeer(rex).name, tailscaleNodeName);

    props = props.assignPeer(rex, 'Tailscale-Proxy');
    expect(props.groupOfPeer(rex).name, 'Tailscale-Proxy');
    // 改指定到另一个组时从原来的组移除
    expect(props.assignPeer(rex, 'Other').groupById(proxy.id)!.devices, isEmpty);
    expect(props.prependRules.take(6), [
      'DOMAIN,rex.tailc7e14e.ts.net,Tailscale-Proxy',
      'IP-CIDR,100.121.3.59/32,Tailscale-Proxy,no-resolve',
      'IP-CIDR6,fd7a:115c:a1e0::1/128,Tailscale-Proxy,no-resolve',
      'DOMAIN-SUFFIX,corp.example,Tailscale-Proxy',
      'IP-CIDR,100.100.1.0/24,Tailscale-Proxy,no-resolve',
      'DOMAIN-SUFFIX,ts.net,$tailscaleNodeName',
    ]);
    expect(props.effectiveHostname(props.groupById(proxy.id)!), 'mac-tailscale-proxy');
    expect(props.patchJson?['nodes'], hasLength(3));

    // IP 变化时按 DNS 名同步；无变化返回 null
    const moved = TailscalePeer(dnsName: 'rex.tailc7e14e.ts.net', ips: ['100.121.3.60']);
    expect(props.syncProxyPeers([rex]), isNull);
    expect(props.syncProxyPeers([moved])?.groupById(proxy.id)?.devices, [
      'rex.tailc7e14e.ts.net,100.121.3.60',
    ]);

    // 指定回默认组即恢复兜底规则
    expect(props.assignPeer(rex, tailscaleNodeName).groupById(proxy.id)!.devices, isEmpty);
    // 设为默认组：兜底规则与 MagicDNS 交给它，默认组不能删除
    final switched = props.setDefaultGroup(proxy.id);
    expect(switched.defaultNodeGroup.name, 'Tailscale-Proxy');
    expect(switched.groupById(proxy.id)!.devices, isEmpty);
    expect(switched.patchJson?['default-node'], 'Tailscale-Proxy');
    expect(switched.removeGroup(proxy.id), switched);
    expect(switched.removeGroup('').nodeGroups, hasLength(2));

    final manual = TailscaleProxyDevice.parse(' 100.1.2.3 , Rex.Tail.ts.net. ');
    expect(manual.encoded, 'rex.tail.ts.net,100.1.2.3');
    expect(TailscaleProxyDevice.parse('100.1.2.3').rules('X'), [
      'IP-CIDR,100.1.2.3/32,X,no-resolve',
    ]);

    // 只开 App 共存时不生效
    final app = props.copyWith(enable: true, nodeEnable: false);
    expect(app.prependRules.first, 'DOMAIN-SUFFIX,ts.net,DIRECT');
    expect(app.patchJson?['nodes'], isNull);
  }, skip: !system.isDesktop);

  // BETTBOX-CUSTOM: 配置文件里的 Tailscale 节点：预读取、覆写后下发 override，规则指向原名。
  test('配置文件 Tailscale 节点的预读取与覆写', () {
    final scan = TailscaleProfileScan.fromConfig(
      profileId: '1',
      label: 'Uclort',
      current: true,
      config: {
        'proxies': [
          {'name': 'hk', 'type': 'ss'},
          {
            'name': 'Tailscale-Proxy',
            'type': 'tailscale',
            'hostname': 'surge-like',
            'state-dir': './ts',
            'auth-key': 'tskey-file',
            'dialer-proxy': 'Global',
          },
        ],
        'rules': ['DOMAIN,rex.tail.ts.net,Tailscale-Proxy', 'MATCH,hk'],
      },
    );
    expect(scan.nodes.map((n) => n.name), ['Tailscale-Proxy']);
    expect(scan.ruleTargets, {'Tailscale-Proxy': 1});
    final group = scan.nodes.single.toGroup();
    expect(group.profile, isTrue);
    expect(group.useAuthKey, isTrue);
    expect(group.via, 'Global');
    var props = const TailscaleProps(nodeEnable: true).updateGroup(group.id, group);
    // 配置文件节点不能成为默认组
    expect(props.defaultNodeGroup.name, tailscaleNodeName);
    props = props.assignDevice(TailscaleProxyDevice.parse('rex.tail.ts.net'), 'Tailscale-Proxy');
    final nodes = props.patchJson?['nodes'] as List;
    expect(nodes.last['override'], isTrue);
    expect(nodes.last['state-id'], 'p-tailscale-proxy');
    expect(props.prependRules.first, 'DOMAIN,rex.tail.ts.net,Tailscale-Proxy');
    // 关闭覆写：不下发、不生成规则，但保留设置
    final off = props.updateGroup(group.id, props.groupById(group.id)!.copyWith(overridden: false));
    expect((off.patchJson?['nodes'] as List), hasLength(1));
    expect(off.prependRules.first, 'DOMAIN-SUFFIX,ts.net,$tailscaleNodeName');
    expect(off.groupById(group.id)!.devices, isNotEmpty);
    expect(tailscaleSlug('代理'), startsWith('n'));
    expect(tailscaleSlug('代理'), tailscaleSlug('代理'));
  });

  test('节点状态解析', () {
    final status = TailscaleNodeStatus.fromJson({
      'state': 'NeedsLogin',
      'auth-url': 'https://login.tailscale.com/a/x',
    });
    expect(status.needsLogin, isTrue);
    expect(status.running, isFalse);
    final running = TailscaleNodeStatus.fromJson({
      'state': 'Running',
      'dns-name': 'mac-bettbox.tail.ts.net',
      'ips': ['100.1.2.3'],
    });
    expect(running.running, isTrue);
    expect(running.ips, ['100.1.2.3']);
    expect(running.peers, isEmpty);
  });

  test('解析 Tailnet 设备列表', () {
    final status = TailscaleNodeStatus.fromJson({
      'state': 'Running',
      'peers': [
        {
          'host-name': 'M1-13',
          'dns-name': 'm1-13-rex.tailc7e14e.ts.net',
          'ips': ['100.86.107.101'],
          'online': true,
          'active': true,
          'cur-addr': '1.2.3.4:41641',
        },
        {'host-name': 'iPhone', 'online': false},
      ],
    });
    expect(status.peers, hasLength(2));
    expect(status.peers.first.displayName, 'm1-13-rex');
    expect(status.peers.first.online, isTrue);
    expect(status.peers.first.curAddr, '1.2.3.4:41641');
    expect(status.peers.last.displayName, 'iPhone');
    expect(status.peers.last.ips, isEmpty);
  });
}
