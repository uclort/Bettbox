import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';

// BETTBOX-CUSTOM: 托盘策略组右侧展示当前选中目标，一级与二级菜单规则一致。
// 默认（`showChain: false`）：选中项仍是策略组时，用括号补充沿链路解析出的最终
// 节点，例如 `Fallback (FC-香港 6)`。开启「托盘显示完整节点链路」
// （`AppSettingProps.trayShowProxyChain`）后改为逐级列出，例如
// `Fallback → Other → FC-香港 6`。
const trayProxyChainSeparator = ' → ';

// BETTBOX-CUSTOM: 文本内的「已固定」标记。规则：被固定的自动组带锁，它固定到的
// 目标（节点或策略组）也带锁；其余（包括被隐藏的中间层）不带。锁统一放在名称前，
// 避免前后混放时两把锁隔着箭头挨在一起。例如 URLTest 固定到 A 时完整链路为
// `Fallback → Other → 🔒URLTest → 🔒A`，隐藏中间链路为 `Fallback (🔒A)`；
// Fallback 固定到 Other 时为 `🔒Fallback → 🔒Other → URLTest → A`，隐藏中间链路
// 只剩 `🔒Fallback` 与动态选出的 `A`（不带锁）。macOS / Windows 原生绘制时替换为
// 单色锁图标，Windows 悬浮提示是纯文本，直接显示该字符；设置页预览同样替换为图标。
const trayLockMark = '🔒';

/// 右侧说明：[groupName] 是行自身（一级菜单行组名前已由原生画锁，这里只标它固定的目标）。
String trayGroupSelectionLabel({
  required String groupName,
  required List<Group> groups,
  required SelectedMap selectedMap,
  bool showChain = false,
}) {
  final selected = _selectedNameOf(groupName, groups, selectedMap);
  if (selected.isEmpty) {
    return '';
  }
  final chain = _isGroupLike(selected, groups)
      ? resolveTrayProxyChain(
          proxyName: selected,
          groups: groups,
          selectedMap: selectedMap,
        )
      : [selected];
  final locks = _chainLocks(groupName, chain, groups, selectedMap);
  String at(int i) => _withLock(chain[i], locks[i]);
  if (chain.length < 2) {
    return at(0);
  }
  if (showChain) {
    return [
      for (var i = 0; i < chain.length; i++) at(i),
    ].join(trayProxyChainSeparator);
  }
  return '${at(0)} (${at(chain.length - 1)})';
}

/// 名称带锁：被固定的策略组本身。用于子菜单里作为节点出现的策略组行名称。
String trayLockedGroupName(
  String name,
  List<Group> groups,
  SelectedMap selectedMap,
) => _withLock(name, _isPinnedName(name, groups, selectedMap));

/// [chain] 每一项是否带锁：自身是被固定的自动组，或是上一级固定的目标；
/// chain[0] 的上一级是 [parent]。
List<bool> _chainLocks(
  String parent,
  List<String> chain,
  List<Group> groups,
  SelectedMap selectedMap,
) {
  final locks = <bool>[];
  var previous = parent;
  for (final name in chain) {
    locks.add(
      _isPinnedName(name, groups, selectedMap) ||
          _isPinTarget(previous, name, groups, selectedMap),
    );
    previous = name;
  }
  return locks;
}

bool _isPinTarget(
  String groupName,
  String name,
  List<Group> groups,
  SelectedMap selectedMap,
) =>
    _isPinnedName(groupName, groups, selectedMap) &&
    selectedMap[groupName] == name;

String _withLock(String name, bool locked) =>
    locked ? '$trayLockMark$name' : name;

bool _isPinnedName(String name, List<Group> groups, SelectedMap selectedMap) {
  final group = groups.getGroup(name);
  return group != null && isTrayGroupPinned(group, selectedMap);
}

/// 沿策略组选择链解析最终节点；遇到循环引用时停在最后一个未重复的名称。
String resolveTrayFinalProxyName({
  required String proxyName,
  required List<Group> groups,
  required SelectedMap selectedMap,
}) {
  final chain = resolveTrayProxyChain(
    proxyName: proxyName,
    groups: groups,
    selectedMap: selectedMap,
  );
  return chain.isEmpty ? '' : chain.last;
}

/// 从 [proxyName] 开始逐级记录选择链（含起点），遇到循环引用时停止。
List<String> resolveTrayProxyChain({
  required String proxyName,
  required List<Group> groups,
  required SelectedMap selectedMap,
}) {
  final chain = <String>[];
  var current = proxyName;
  final visited = <String>{};
  while (current.isNotEmpty && visited.add(current)) {
    chain.add(current);
    final String next;
    if (groups.getGroup(current) != null) {
      next = _selectedNameOf(current, groups, selectedMap);
    } else {
      next = groups.getRematchProxy(current)?.now ?? '';
    }
    if (next.isEmpty || visited.contains(next)) {
      break;
    }
    current = next;
  }
  return chain;
}

// BETTBOX-CUSTOM: 托盘图标旁显示指定策略组。三项均可选：组名、具体节点
// （链路末端的真实节点）、完整链路（从选中项逐级到真实节点，已含具体节点）。
// 组名与后半段以 ` · ` 分隔，例如 `Global · Fallback → Other → FC-日本 1`。
// 开启「显示节点延迟」后，在整段末尾用括号附加最终节点的延迟，例如
// `Global · FC-日本 1 (86ms)`；括号与 ` · `、` → ` 都不冲突，延迟一眼可辨。
// 策略组不存在（如切换配置后）或三项都未勾选时返回空串，表示不显示。
const trayStatusNameSeparator = ' · ';

// BETTBOX-CUSTOM: 托盘显示策略组跟随出站模式：全局模式固定显示 GLOBAL；直连模式
// 固定显示 DIRECT（不是策略组，没有链路、锁和延迟）；规则模式用用户选择的组。
// GLOBAL 在规则模式下永远不会被用到，不出现在设置选项中；老配置里存的 GLOBAL
// 在规则模式下视为不存在。只在解析时替换，不改写已保存的选择。
const trayStatusDirectName = 'DIRECT';

String trayStatusEffectiveGroupName(Mode mode, String savedName) =>
    switch (mode) {
      Mode.global => GroupName.GLOBAL.name,
      Mode.direct => trayStatusDirectName,
      Mode.rule => savedName == GroupName.GLOBAL.name ? '' : savedName,
    };

/// 设置页可选的策略组（不含 GLOBAL）。
List<Group> trayStatusSelectableGroups(List<Group> groups) =>
    groups.where((group) => group.name != GroupName.GLOBAL.name).toList();

String trayStatusGroupLabel({
  required String groupName,
  required List<Group> groups,
  required SelectedMap selectedMap,
  required bool showName,
  required bool showNode,
  required bool showChain,
  String delayText = '',
}) {
  if (groupName == trayStatusDirectName && groups.getGroup(groupName) == null) {
    return showName || showNode || showChain ? trayStatusDirectName : '';
  }
  if (groupName.isEmpty || groups.getGroup(groupName) == null) {
    return '';
  }
  final label = _trayStatusBaseLabel(
    groupName: groupName,
    groups: groups,
    selectedMap: selectedMap,
    showName: showName,
    showNode: showNode,
    showChain: showChain,
  );
  if (label.isEmpty || delayText.isEmpty) {
    return label;
  }
  return '$label ($delayText)';
}

/// BETTBOX-CUSTOM: 托盘显示策略组的延迟文本，括号由 [trayStatusGroupLabel] 添加。
/// 未测速（null）和测速中（0）返回空串（测速中由调用方沿用上次结果，避免菜单栏
/// 宽度来回跳动）；超时显示 [timeoutText]。
String trayStatusDelayText(int? delay, {required String timeoutText}) {
  if (delay == null || delay == 0) return '';
  if (delay < 0) return timeoutText;
  return '${delay}ms';
}

String _trayStatusBaseLabel({
  required String groupName,
  required List<Group> groups,
  required SelectedMap selectedMap,
  required bool showName,
  required bool showNode,
  required bool showChain,
}) {
  final selected = _selectedNameOf(groupName, groups, selectedMap);
  // BETTBOX-CUSTOM: 锁规则与托盘菜单一致（锁在名称前）：组名被固定则带锁，节点 / 链路中被固定的
  // 组与固定目标带锁；只显示节点时，节点是固定目标才带锁。
  var detail = '';
  if ((showChain || showNode) && selected.isNotEmpty) {
    final chain = resolveTrayProxyChain(
      proxyName: selected,
      groups: groups,
      selectedMap: selectedMap,
    );
    if (chain.isNotEmpty) {
      final locks = _chainLocks(groupName, chain, groups, selectedMap);
      detail = showChain
          ? [
              for (var i = 0; i < chain.length; i++)
                _withLock(chain[i], locks[i]),
            ].join(trayProxyChainSeparator)
          : _withLock(chain.last, locks.last);
    }
  }
  return [
    if (showName) trayLockedGroupName(groupName, groups, selectedMap),
    if (detail.isNotEmpty) detail,
  ].join(trayStatusNameSeparator);
}

// BETTBOX-CUSTOM: 托盘菜单中「已锁定」标记。URLTest / Fallback 这类自动组被手动
// 指定节点后内核会一直用它（fixed），菜单里在组名前画一把锁，与策略组卡片的锁一致。
// 借用 MenuItem.icon 把标记传给原生层，两端据此自绘锁图标：策略组行（submenu）
// 画在名称前的勾选列，节点行（checkbox）画在勾选列、代替对号。
const trayMenuLockedIcon = 'lock';

bool isTrayGroupPinned(Group group, SelectedMap selectedMap) =>
    group.type.isComputedSelected &&
    (selectedMap[group.name] ?? '').isNotEmpty;

bool _isGroupLike(String name, List<Group> groups) {
  if (groups.getGroup(name) != null) {
    return true;
  }
  final now = groups.getRematchProxy(name)?.now;
  return now != null && now.isNotEmpty && now != name;
}

String _selectedNameOf(
  String groupName,
  List<Group> groups,
  SelectedMap selectedMap,
) {
  final group = groups.getGroup(groupName);
  if (group == null) {
    return '';
  }
  return group.getCurrentSelectedName(selectedMap[groupName] ?? '');
}

/// BETTBOX-CUSTOM: 自动组被固定到的节点；未固定（或不是自动组）时为空串。
String trayPinnedProxyName(Group group, SelectedMap selectedMap) =>
    isTrayGroupPinned(group, selectedMap) ? selectedMap[group.name]! : '';

/// BETTBOX-CUSTOM: 托盘点击节点后要写入的选择，与窗口策略组卡片一致：自动组点击
/// 已固定的节点返回空串（解除固定、恢复自动选择），点其他节点则固定到该节点。
String trayNextSelection(
  Group group,
  SelectedMap selectedMap,
  String proxyName,
) {
  if (group.type.isComputedSelected &&
      trayPinnedProxyName(group, selectedMap) == proxyName) {
    return '';
  }
  return proxyName;
}

// BETTBOX-CUSTOM: 托盘可点选 Selector 组的节点，以及 URLTest / Fallback 的节点
// （点击即固定，再点恢复自动选择）；LoadBalance、Relay 等由内核决定的组，节点行
// 置灰且点击不响应、不关闭菜单。
bool isTrayGroupManuallySelectable(Group group) =>
    group.type == GroupType.Selector || group.type.isComputedSelected;

/// 托盘右侧灰色说明：选中项与延迟之间留小间距，任一为空时只保留另一项。
String joinTrayDetail(String selection, String delay) {
  if (selection.isEmpty) return delay;
  if (delay.isEmpty) return selection;
  return '$selection  $delay';
}
