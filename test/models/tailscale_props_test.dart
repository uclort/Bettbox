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
    expect(props.tailscale.patchJson?['node'], {
      'name': tailscaleNodeName,
      'hostname': 'mac-bettbox',
      'auth-mode': 'login',
      'exit-node': 'oracle',
      'accept-routes': true,
    });
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
    final node = props.patchJson?['node'] as Map;
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

  test('恢复默认保留两个开关、接入方式与 auth key', () {
    const props = TailscaleProps(
      enable: true,
      nodeEnable: true,
      nodeAuthKey: 'k',
      nodeUseAuthKey: true,
      nodeHostname: 'x',
      nodeAcceptRoutes: false,
    );
    expect(
      props.reset(),
      defaultTailscaleProps.copyWith(
        enable: true,
        nodeEnable: true,
        nodeAuthKey: 'k',
        nodeUseAuthKey: true,
      ),
    );
  });

  // BETTBOX-CUSTOM: 指定设备经代理通道节点连接，规则排在通用 Tailnet 规则之前。
  test('经代理连接的设备注入代理通道节点与前置规则', () {
    const rex = TailscalePeer(
      dnsName: 'rex.tailc7e14e.ts.net.',
      ips: ['100.121.3.59', 'fd7a:115c:a1e0::1'],
    );
    var props = const TailscaleProps(
      nodeEnable: true,
      nodeHostname: 'mac-bettbox',
    ).toggleProxyPeer(rex, true);
    expect(props.nodeProxyDevices, [
      'rex.tailc7e14e.ts.net,100.121.3.59,fd7a:115c:a1e0::1',
    ]);
    expect(props.isProxyPeer(rex), isTrue);
    // 未选代理时不注入，规则不变
    expect(props.proxyViaMissing, isTrue);
    expect(props.proxyNodeActive, isFalse);
    expect(props.patchJson?['proxy-node'], isNull);
    expect(props.prependRules.first, 'DOMAIN-SUFFIX,ts.net,$tailscaleNodeName');

    props = props.copyWith(nodeProxyVia: 'Global');
    expect(props.proxyNodeActive, isTrue);
    expect(props.patchJson?['proxy-node'], {
      'name': tailscaleProxyNodeName,
      'hostname': 'mac-bettbox-proxy',
      'auth-mode': 'login',
      'exit-node': '',
      'accept-routes': true,
      'dialer-proxy': 'Global',
    });
    expect(props.prependRules.take(4), [
      'DOMAIN,rex.tailc7e14e.ts.net,$tailscaleProxyNodeName',
      'IP-CIDR,100.121.3.59/32,$tailscaleProxyNodeName,no-resolve',
      'IP-CIDR6,fd7a:115c:a1e0::1/128,$tailscaleProxyNodeName,no-resolve',
      'DOMAIN-SUFFIX,ts.net,$tailscaleNodeName',
    ]);
    expect(
      props.copyWith(nodeUseAuthKey: true, nodeAuthKey: 'k').effectiveProxyNodeHostname,
      'mac-bettbox-proxy-key',
    );

    // IP 变化时按 DNS 名同步；无变化返回 null
    const moved = TailscalePeer(dnsName: 'rex.tailc7e14e.ts.net', ips: ['100.121.3.60']);
    expect(props.syncProxyPeers([rex]), isNull);
    expect(props.syncProxyPeers([moved])?.nodeProxyDevices, [
      'rex.tailc7e14e.ts.net,100.121.3.60',
    ]);

    // 关闭后恢复；手动添加只有 IP 的设备也能生成规则
    expect(props.toggleProxyPeer(rex, false).nodeProxyDevices, isEmpty);
    final manual = TailscaleProxyDevice.parse(' 100.1.2.3 , Rex.Tail.ts.net. ');
    expect(manual.encoded, 'rex.tail.ts.net,100.1.2.3');
    expect(TailscaleProxyDevice.parse('100.1.2.3').rules('X'), [
      'IP-CIDR,100.1.2.3/32,X,no-resolve',
    ]);

    // 只开 App 共存时不生效
    const app = TailscaleProps(
      enable: true,
      nodeProxyDevices: ['rex.tail.ts.net'],
      nodeProxyVia: 'Global',
    );
    expect(app.proxyNodeActive, isFalse);
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
