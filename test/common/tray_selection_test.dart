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

  test('一级菜单选中策略组时括号补充最终节点', () {
    expect(
      trayGroupSelectionLabel(
        groupName: 'Global',
        groups: groups,
        selectedMap: const {},
      ),
      'Fallback (FC-日本 1)',
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

  test('开启完整链路时逐级显示到最终节点', () {
    expect(
      trayGroupSelectionLabel(
        groupName: 'Global',
        groups: groups,
        selectedMap: const {},
        showChain: true,
      ),
      'Fallback → Other → FC-日本 1',
    );
    expect(
      trayGroupSelectionLabel(
        groupName: 'Global',
        groups: groups,
        selectedMap: const {'Other': 'FC-香港 6'},
        showChain: true,
      ),
      'Fallback → Other → FC-香港 6',
    );
  });

  test('开启完整链路时直接选中节点仍只显示节点名', () {
    expect(
      trayGroupSelectionLabel(
        groupName: 'Other',
        groups: groups,
        selectedMap: const {},
        showChain: true,
      ),
      'FC-日本 1',
    );
  });

  test('完整链路遇到循环引用时截断', () {
    expect(
      resolveTrayProxyChain(
        proxyName: 'LoopA',
        groups: groups,
        selectedMap: const {},
      ),
      ['LoopA', 'LoopB'],
    );
  });

  group('托盘显示策略组标签', () {
    String label({
      String groupName = 'Global',
      bool showName = false,
      bool showNode = false,
      bool showChain = false,
      SelectedMap selectedMap = const {},
    }) => trayStatusGroupLabel(
      groupName: groupName,
      groups: groups,
      selectedMap: selectedMap,
      showName: showName,
      showNode: showNode,
      showChain: showChain,
    );

    test('只显示具体节点时取链路末端的真实节点', () {
      expect(label(showNode: true), 'FC-日本 1');
    });

    test('组名与具体节点以分隔符连接', () {
      expect(label(showName: true, showNode: true), 'Global · FC-日本 1');
    });

    test('完整链路从选中项逐级到真实节点，并包含具体节点', () {
      expect(label(showChain: true), 'Fallback → Other → FC-日本 1');
      expect(
        label(showName: true, showNode: true, showChain: true),
        'Global · Fallback → Other → FC-日本 1',
      );
    });

    test('可指定隐藏组并跟随本地选择', () {
      expect(
        label(
          groupName: 'Other',
          showName: true,
          showNode: true,
          selectedMap: const {'Other': 'FC-香港 6'},
        ),
        'Other · FC-香港 6',
      );
    });

    test('只勾选组名时只显示组名', () {
      expect(label(showName: true), 'Global');
    });

    test('延迟以括号附加在整段末尾', () {
      String withDelay({
        bool showName = false,
        bool showNode = false,
        bool showChain = false,
        String delayText = '86ms',
      }) => trayStatusGroupLabel(
        groupName: 'Global',
        groups: groups,
        selectedMap: const {},
        showName: showName,
        showNode: showNode,
        showChain: showChain,
        delayText: delayText,
      );
      expect(withDelay(showNode: true), 'FC-日本 1 (86ms)');
      expect(
        withDelay(showName: true, showNode: true),
        'Global · FC-日本 1 (86ms)',
      );
      expect(
        withDelay(showChain: true),
        'Fallback → Other → FC-日本 1 (86ms)',
      );
      expect(withDelay(showName: true), 'Global (86ms)');
      expect(withDelay(showNode: true, delayText: ''), 'FC-日本 1');
      // 没有可显示的内容时，单独的延迟也不显示。
      expect(withDelay(), isEmpty);
    });

    test('延迟文本：未测速与测速中为空，超时显示提示', () {
      expect(trayStatusDelayText(null, timeoutText: '超时'), isEmpty);
      expect(trayStatusDelayText(0, timeoutText: '超时'), isEmpty);
      expect(trayStatusDelayText(-1, timeoutText: '超时'), '超时');
      expect(trayStatusDelayText(86, timeoutText: '超时'), '86ms');
    });

    test('三项都不勾选或策略组不存在时不显示', () {
      expect(label(), isEmpty);
      expect(label(groupName: 'missing', showName: true), isEmpty);
      expect(label(groupName: '', showNode: true), isEmpty);
    });
  });

  test('右侧说明拼接选中项与延迟', () {
    expect(joinTrayDetail('Fallback', '169ms'), 'Fallback  169ms');
    expect(joinTrayDetail('', '169ms'), '169ms');
    expect(joinTrayDetail('DIRECT', ''), 'DIRECT');
    expect(joinTrayDetail('', ''), isEmpty);
  });

  // BETTBOX-CUSTOM: 被固定的自动组在托盘菜单里显示锁，避免误以为按顺序选择。
  test('自动组被固定时标记为锁定，Selector 不算固定', () {
    final fallback = groups.getGroup('Fallback')!;
    final selector = groups.getGroup('Other')!;
    expect(isTrayGroupPinned(fallback, const {}), isFalse);
    expect(
      isTrayGroupPinned(fallback, const {'Fallback': 'FC-香港 6'}),
      isTrue,
    );
    expect(
      isTrayGroupPinned(selector, const {'Other': 'FC-香港 6'}),
      isFalse,
    );
  });

  test('只有 Selector 组的节点可在托盘手动选择', () {
    for (final type in GroupType.values) {
      expect(
        isTrayGroupManuallySelectable(Group(type: type, name: type.name)),
        type == GroupType.Selector,
        reason: type.name,
      );
    }
  });
}
