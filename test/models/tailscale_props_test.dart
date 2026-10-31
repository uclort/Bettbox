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
}
