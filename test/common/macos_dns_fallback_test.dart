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
