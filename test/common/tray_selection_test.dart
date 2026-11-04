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

  test('Selector 与 URLTest / Fallback 的节点可在托盘点选', () {
    for (final type in GroupType.values) {
      expect(
        isTrayGroupManuallySelectable(Group(type: type, name: type.name)),
        type == GroupType.Selector ||
            type == GroupType.URLTest ||
            type == GroupType.Fallback,
        reason: type.name,
      );
    }
  });

  // BETTBOX-CUSTOM: 托盘点击自动组节点与窗口卡片一致：点击即固定，再点恢复自动。
  test('自动组点击已固定节点解除固定，其他节点改为固定', () {
    final fallback = groups.getGroup('Fallback')!;
    final selector = groups.getGroup('Other')!;
    const pinned = {'Fallback': 'FC-香港 6'};
    expect(trayPinnedProxyName(fallback, const {}), isEmpty);
    expect(trayPinnedProxyName(fallback, pinned), 'FC-香港 6');
    expect(trayNextSelection(fallback, const {}, 'FC-香港 6'), 'FC-香港 6');
    expect(trayNextSelection(fallback, pinned, 'FC-香港 6'), isEmpty);
    expect(trayNextSelection(fallback, pinned, 'Other'), 'Other');
    expect(
      trayNextSelection(selector, const {'Other': 'FC-日本 1'}, 'FC-日本 1'),
      'FC-日本 1',
    );
  });

  group('被固定的组与它固定的目标带锁，中间动态层不带', () {
    // Fallback 被固定到 Other（Other 是 Selector，内部动态选出 FC-日本 1）。
    const pinnedToGroup = {'Fallback': 'Other'};
    // URLTest 固定到节点 A，内核 now 即为 A。
    final nested = <Group>[
      const Group(
        type: GroupType.Selector,
        name: 'Global',
        now: 'Auto',
        all: [Proxy(name: 'Auto', type: 'URLTest')],
      ),
      const Group(
        type: GroupType.URLTest,
        name: 'Auto',
        now: 'A',
        all: [
          Proxy(name: 'A', type: 'Trojan'),
          Proxy(name: 'B', type: 'Trojan'),
        ],
      ),
    ];
    const pinnedToNode = {'Auto': 'A'};

    String label(
      String groupName,
      List<Group> source,
      SelectedMap selectedMap, {
      bool showChain = false,
    }) => trayGroupSelectionLabel(
      groupName: groupName,
      groups: source,
      selectedMap: selectedMap,
      showChain: showChain,
    );

    String status(
      String groupName,
      List<Group> source,
      SelectedMap selectedMap, {
      bool showName = false,
      bool showNode = false,
      bool showChain = false,
    }) => trayStatusGroupLabel(
      groupName: groupName,
      groups: source,
      selectedMap: selectedMap,
      showName: showName,
      showNode: showNode,
      showChain: showChain,
    );

    test('固定到节点：组与节点的锁都在名称前', () {
      expect(
        label('Global', nested, pinnedToNode),
        '${trayLockMark}Auto (${trayLockMark}A)',
      );
      expect(
        label('Global', nested, pinnedToNode, showChain: true),
        '${trayLockMark}Auto → ${trayLockMark}A',
      );
      // 一级菜单 Auto 行组名前已画锁（原生绘制），说明只标固定的目标。
      expect(label('Auto', nested, pinnedToNode), '${trayLockMark}A');
    });

    test('固定到策略组：组与目标组带锁，动态选出的节点不带', () {
      expect(
        label('Global', groups, pinnedToGroup),
        '${trayLockMark}Fallback (FC-日本 1)',
      );
      expect(
        label('Global', groups, pinnedToGroup, showChain: true),
        '${trayLockMark}Fallback → ${trayLockMark}Other → FC-日本 1',
      );
      expect(
        label('Fallback', groups, pinnedToGroup),
        '${trayLockMark}Other (FC-日本 1)',
      );
    });

    test('未固定时不带锁', () {
      expect(
        label('Global', groups, const {}, showChain: true),
        isNot(contains(trayLockMark)),
      );
      expect(
        label('Global', nested, const {}, showChain: true),
        isNot(contains(trayLockMark)),
      );
    });

    test('子菜单中作为节点出现的策略组被固定时名称带锁', () {
      expect(
        trayLockedGroupName('Fallback', groups, pinnedToGroup),
        '${trayLockMark}Fallback',
      );
      expect(
        trayLockedGroupName('FC-香港 6', groups, pinnedToGroup),
        'FC-香港 6',
      );
      expect(trayLockedGroupName('Other', groups, pinnedToGroup), 'Other');
    });

    test('托盘显示策略组：组名与节点分别按规则带锁', () {
      expect(
        status('Global', nested, pinnedToNode, showName: true, showNode: true),
        'Global · ${trayLockMark}A',
      );
      expect(
        status('Auto', nested, pinnedToNode, showName: true, showNode: true),
        '${trayLockMark}Auto · ${trayLockMark}A',
      );
      expect(
        status(
          'Fallback',
          groups,
          pinnedToGroup,
          showName: true,
          showNode: true,
        ),
        '${trayLockMark}Fallback · FC-日本 1',
      );
      expect(
        status('Global', groups, pinnedToGroup, showNode: true),
        'FC-日本 1',
      );
      expect(
        status('Global', groups, pinnedToGroup, showChain: true),
        '${trayLockMark}Fallback → ${trayLockMark}Other → FC-日本 1',
      );
      expect(
        status('Fallback', groups, pinnedToGroup, showName: true),
        '${trayLockMark}Fallback',
      );
    });
  });

  group('托盘显示策略组跟随出站模式', () {
    final modeGroups = [
      const Group(
        type: GroupType.Selector,
        name: 'GLOBAL',
        now: 'Global',
        all: [Proxy(name: 'Global', type: 'Selector')],
      ),
      ...groups,
    ];

    test('全局模式固定显示 GLOBAL，直连模式固定显示 DIRECT', () {
      expect(trayStatusEffectiveGroupName(Mode.global, 'Other'), 'GLOBAL');
      expect(trayStatusEffectiveGroupName(Mode.direct, 'Other'), 'DIRECT');
      expect(trayStatusEffectiveGroupName(Mode.rule, 'Other'), 'Other');
    });

    test('规则模式下老配置存的 GLOBAL 视为不存在', () {
      expect(trayStatusEffectiveGroupName(Mode.rule, 'GLOBAL'), '');
      expect(
        trayStatusGroupLabel(
          groupName: trayStatusEffectiveGroupName(Mode.rule, 'GLOBAL'),
          groups: modeGroups,
          selectedMap: const {},
          showName: true,
          showNode: true,
          showChain: false,
        ),
        '',
      );
    });

    test('全局模式按 GLOBAL 解析链路', () {
      expect(
        trayStatusGroupLabel(
          groupName: trayStatusEffectiveGroupName(Mode.global, 'Other'),
          groups: modeGroups,
          selectedMap: const {},
          showName: true,
          showNode: true,
          showChain: false,
        ),
        'GLOBAL · FC-日本 1',
      );
    });

    test('直连模式只显示 DIRECT，不附加延迟；三项都未勾选时为空', () {
      String direct({bool any = true}) => trayStatusGroupLabel(
        groupName: trayStatusDirectName,
        groups: modeGroups,
        selectedMap: const {},
        showName: any,
        showNode: any,
        showChain: any,
        delayText: '86ms',
      );
      expect(direct(), 'DIRECT');
      expect(direct(any: false), '');
    });

    test('设置选项不含 GLOBAL', () {
      expect(
        trayStatusSelectableGroups(modeGroups).map((group) => group.name),
        isNot(contains('GLOBAL')),
      );
    });
  });
}
