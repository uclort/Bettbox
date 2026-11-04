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

  group('链路中被固定的自动组带锁标记', () {
    // Fallback 被固定到 Other，Global 选中 Fallback。
    const pinned = {'Fallback': 'Other'};

    test('隐藏中间链路时锁放在最终节点前', () {
      expect(
        trayGroupSelectionLabel(
          groupName: 'Global',
          groups: groups,
          selectedMap: pinned,
        ),
        'Fallback (${trayLockMark}FC-日本 1)',
      );
    });

    test('完整链路时锁紧跟被固定的组名', () {
      expect(
        trayGroupSelectionLabel(
          groupName: 'Global',
          groups: groups,
          selectedMap: pinned,
          showChain: true,
        ),
        'Fallback$trayLockMark → Other → FC-日本 1',
      );
    });

    test('行自身被固定：一级菜单不重复，子菜单行写进说明', () {
      String label({bool markSelfPin = false, bool showChain = false}) =>
          trayGroupSelectionLabel(
            groupName: 'Fallback',
            groups: groups,
            selectedMap: pinned,
            markSelfPin: markSelfPin,
            showChain: showChain,
          );
      expect(label(), 'Other (FC-日本 1)');
      expect(label(markSelfPin: true), 'Other (${trayLockMark}FC-日本 1)');
      expect(
        label(markSelfPin: true, showChain: true),
        '${trayLockMark}Other → FC-日本 1',
      );
    });

    test('未固定时不带锁', () {
      expect(
        trayGroupSelectionLabel(
          groupName: 'Global',
          groups: groups,
          selectedMap: const {},
          showChain: true,
        ),
        isNot(contains(trayLockMark)),
      );
    });

    test('托盘显示策略组：组名、节点、链路各自对应位置加锁', () {
      String status(
        String groupName, {
        bool showName = false,
        bool showNode = false,
        bool showChain = false,
      }) => trayStatusGroupLabel(
        groupName: groupName,
        groups: groups,
        selectedMap: pinned,
        showName: showName,
        showNode: showNode,
        showChain: showChain,
      );
      expect(
        status('Global', showName: true, showNode: true),
        'Global · ${trayLockMark}FC-日本 1',
      );
      expect(
        status('Global', showChain: true),
        'Fallback$trayLockMark → Other → FC-日本 1',
      );
      expect(
        status('Fallback', showName: true, showNode: true),
        'Fallback$trayLockMark · FC-日本 1',
      );
      expect(status('Fallback', showNode: true), '${trayLockMark}FC-日本 1');
      expect(
        status('Fallback', showChain: true),
        '${trayLockMark}Other → FC-日本 1',
      );
      expect(status('Fallback', showName: true), 'Fallback$trayLockMark');
    });
  });
}
