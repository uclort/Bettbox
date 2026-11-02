import 'package:bett_box/common/tray_selection.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hk = Proxy(name: 'FC-香港 6', type: 'Trojan');
  const jp = Proxy(name: 'FC-日本 1', type: 'Trojan');
  final groups = <Group>[
    const Group(
      type: GroupType.Selector,
      name: 'Global',
      now: 'Fallback',
      all: [
        Proxy(name: 'Fallback', type: 'Fallback'),
        Proxy(name: 'Other', type: 'Selector'),
        hk,
      ],
    ),
    const Group(
      type: GroupType.Fallback,
      name: 'Fallback',
      now: 'Other',
      all: [Proxy(name: 'Other', type: 'Selector'), hk],
    ),
    const Group(
      type: GroupType.Selector,
      name: 'Other',
      now: 'FC-日本 1',
      hidden: true,
      all: [hk, jp],
    ),
    const Group(type: GroupType.Selector, name: 'LoopA', now: 'LoopB'),
    const Group(type: GroupType.Selector, name: 'LoopB', now: 'LoopA'),
  ];

  test('一级菜单只显示直接选中的策略组', () {
    expect(
      trayGroupSelectionLabel(
        groupName: 'Global',
        groups: groups,
        selectedMap: const {},
        includeFinal: false,
      ),
      'Fallback',
    );
  });

  test('二级策略组选中节点时直接显示节点名', () {
    expect(
      trayGroupSelectionLabel(
        groupName: 'Other',
        groups: groups,
        selectedMap: const {},
      ),
      'FC-日本 1',
    );
  });

  test('选中项仍是策略组时括号补充最终节点，并经过隐藏组', () {
    expect(
      trayGroupSelectionLabel(
        groupName: 'Fallback',
        groups: groups,
        selectedMap: const {},
      ),
      'Other (FC-日本 1)',
    );
  });

  test('Selector 优先使用本地选择记录', () {
    expect(
      trayGroupSelectionLabel(
        groupName: 'Fallback',
        groups: groups,
        selectedMap: const {'Other': 'FC-香港 6'},
      ),
      'Other (FC-香港 6)',
    );
  });

  test('单节点与未知名称不显示', () {
    for (final name in ['FC-香港 6', 'missing']) {
      expect(
        trayGroupSelectionLabel(
          groupName: name,
          groups: groups,
          selectedMap: const {},
        ),
        isEmpty,
      );
    }
  });

  test('循环引用不会死循环', () {
    expect(
      resolveTrayFinalProxyName(
        proxyName: 'LoopA',
        groups: groups,
        selectedMap: const {},
      ),
      'LoopB',
    );
  });

  test('右侧说明拼接选中项与延迟', () {
    expect(joinTrayDetail('Fallback', '169ms'), 'Fallback  169ms');
    expect(joinTrayDetail('', '169ms'), '169ms');
    expect(joinTrayDetail('DIRECT', ''), 'DIRECT');
    expect(joinTrayDetail('', ''), isEmpty);
  });
}
