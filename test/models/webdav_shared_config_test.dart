import 'dart:convert';

import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const script = Script(id: 'script', label: '覆写', content: 'content');
  final profile = Profile(
    id: 'profile',
    label: '配置',
    currentGroupName: '代理',
    autoUpdateDuration: const Duration(hours: 24),
    selectedMap: const {'代理': '节点'},
    unfoldSet: const {'代理'},
  );

  test('WebDAV 只导出配置与覆写脚本，不导出本机选择和设置', () {
    final config = Config(
      profiles: [profile],
      currentProfileId: profile.id,
      scriptProps: const ScriptProps(currentId: 'script', scripts: [script]),
      themeProps: defaultThemeProps,
      networkProps: const NetworkProps(systemProxy: true),
      vpnProps: const VpnProps(enable: true),
    );

    final json = jsonDecode(jsonEncode(webDavSharedConfigJson(config))) as Map;

    expect(json.keys, unorderedEquals(['profiles', 'scriptProps']));
    expect(json['currentProfileId'], isNull);
    expect(json['networkProps'], isNull);
    expect(json['vpnProps'], isNull);
    expect(json['scriptProps']['currentId'], isNull);
    expect(json['profiles'][0]['currentGroupName'], isNull);
    expect(json['profiles'][0]['selectedMap'], isEmpty);
    expect(json['profiles'][0]['unfoldSet'], isEmpty);
  });

  test('WebDAV 恢复保留本机节点、展开状态和脚本选择', () {
    final incomingProfile = profile.copyWith(
      label: '远端配置',
      currentGroupName: null,
      selectedMap: const {},
      unfoldSet: const {},
    );
    final mergedProfiles = mergeWebDavProfiles([incomingProfile], [profile]);
    final mergedScripts = mergeWebDavScripts(
      const ScriptProps(scripts: [script]),
      const ScriptProps(currentId: 'script', scripts: [script]),
    );

    expect(mergedProfiles.single.label, '远端配置');
    expect(mergedProfiles.single.currentGroupName, profile.currentGroupName);
    expect(mergedProfiles.single.selectedMap, profile.selectedMap);
    expect(mergedProfiles.single.unfoldSet, profile.unfoldSet);
    expect(mergedScripts.currentId, 'script');
  });
}
