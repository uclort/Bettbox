import 'package:bett_box/common/system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses DNS servers from macOS DHCP summary output', () {
    expect(parseMacOSDhcpDnsServers('{10.255.18.3, 10.255.18.4}'), [
      '10.255.18.3',
      '10.255.18.4',
    ]);
    expect(parseMacOSDhcpDnsServers('not-an-address'), isEmpty);
  });

  test('parses enabled macOS network services by device', () {
    const output = '''
(1) Wi-Fi
(Hardware Port: Wi-Fi, Device: en0)

(2) USB LAN
(Hardware Port: USB LAN, Device: en5)

(*) Disabled LAN
(Hardware Port: Ethernet, Device: en7)
''';

    expect(parseMacOSNetworkServices(output), {
      'en0': 'Wi-Fi',
      'en5': 'USB LAN',
    });
  });

  test('includes secondary interfaces in the macOS network fingerprint', () {
    const wifi = MacOSNetworkInterfaceState(
      device: 'en0',
      serviceName: 'Wi-Fi',
      address: '192.168.0.63',
      gateway: '192.168.0.1',
      connectionId: 'wifi-a',
      dhcpServer: '192.168.0.1',
      dhcpDns: '{192.168.0.1}',
    );
    const ethernetBefore = MacOSNetworkInterfaceState(
      device: 'en5',
      serviceName: 'USB LAN',
      address: '10.47.12.3',
      gateway: '10.47.12.1',
      connectionId: 'ethernet-a',
      dhcpServer: '10.53.192.250',
      dhcpDns: '{10.255.18.3, 10.255.18.4}',
    );
    const ethernetAfter = MacOSNetworkInterfaceState(
      device: 'en5',
      serviceName: 'USB LAN',
      address: '10.47.12.8',
      gateway: '10.47.12.1',
      connectionId: 'ethernet-b',
      dhcpServer: '10.53.192.250',
      dhcpDns: '{10.255.18.3, 10.255.18.4}',
    );

    final before = buildMacOSNetworkFingerprint(
      defaultDevice: 'en0',
      defaultGateway: '192.168.0.1',
      interfaces: [wifi, ethernetBefore],
    );
    final after = buildMacOSNetworkFingerprint(
      defaultDevice: 'en0',
      defaultGateway: '192.168.0.1',
      interfaces: [wifi, ethernetAfter],
    );

    expect(after, isNot(before));
  });

  test('removes only the DNS server managed by Bettbox', () {
    expect(
      sanitizeMacOSOriginalDnsServers([
        '10.255.18.3',
        macOSManagedDns,
        '10.255.18.4',
      ]),
      ['10.255.18.3', '10.255.18.4'],
    );
    expect(sanitizeMacOSOriginalDnsServers([macOSManagedDns]), isEmpty);
  });

  group('macOS runtime DNS fallback', () {
    const networkState = MacOSNetworkState(
      device: 'en0',
      serviceName: 'Wi-Fi',
      dhcpDnsServers: ['10.255.18.3', '10.255.18.4'],
      fingerprint: 'network',
    );

    test('prepends DHCP DNS to bootstrap and direct resolvers', () {
      final patched = applyMacOSRuntimeDnsFallback({
        'dns': {
          'enable': true,
          'default-nameserver': ['223.5.5.5', '119.29.29.29'],
          'direct-nameserver': ['system', '223.5.5.5'],
          'nameserver': ['https://dns.cloudflare.com/dns-query'],
        },
      }, networkState);

      expect(patched['dns']['default-nameserver'], [
        '10.255.18.3#en0',
        '10.255.18.4#en0',
        '223.5.5.5',
        '119.29.29.29',
      ]);
      expect(patched['dns']['direct-nameserver'], [
        '10.255.18.3#en0',
        '10.255.18.4#en0',
        'system',
        '223.5.5.5',
      ]);
      expect(patched['dns']['nameserver'], [
        'https://dns.cloudflare.com/dns-query',
      ]);
    });

    test('does not create a direct resolver override when none exists', () {
      final patched = applyMacOSRuntimeDnsFallback({
        'dns': {
          'enable': true,
          'default-nameserver': ['223.5.5.5'],
          'direct-nameserver': <String>[],
        },
      }, networkState);

      expect(patched['dns']['direct-nameserver'], isEmpty);
    });

    test('leaves disabled DNS configuration untouched', () {
      final config = {
        'dns': {
          'enable': false,
          'default-nameserver': ['223.5.5.5'],
        },
      };

      expect(
        identical(applyMacOSRuntimeDnsFallback(config, networkState), config),
        isTrue,
      );
    });
  });
}
