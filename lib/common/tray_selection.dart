import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';

// BETTBOX-CUSTOM: 托盘策略组右侧展示当前选中目标，一级与二级菜单规则一致。
// 默认（`showChain: false`）：选中项仍是策略组时，用括号补充沿链路解析出的最终
// 节点，例如 `Fallback (FC-香港 6)`。开启「托盘显示完整节点链路」
// （`AppSettingProps.trayShowProxyChain`）后改为逐级列出，例如
// `Fallback → Other → FC-香港 6`。
const trayProxyChainSeparator = ' → ';

String trayGroupSelectionLabel({
  required String groupName,
  required List<Group> groups,
  required SelectedMap selectedMap,
  bool showChain = false,
}) {
  final selected = _selectedNameOf(groupName, groups, selectedMap);
  if (selected.isEmpty || !_isGroupLike(selected, groups)) {
    return selected;
  }
  final chain = resolveTrayProxyChain(
    proxyName: selected,
    groups: groups,
    selectedMap: selectedMap,
  );
  if (chain.length < 2) {
    return selected;
  }
  if (showChain) {
    return chain.join(trayProxyChainSeparator);
  }
  return '$selected (${chain.last})';
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

String trayStatusGroupLabel({
  required String groupName,
  required List<Group> groups,
  required SelectedMap selectedMap,
  required bool showName,
  required bool showNode,
  required bool showChain,
  String delayText = '',
}) {
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
  var detail = '';
  if ((showChain || showNode) && selected.isNotEmpty) {
    final chain = resolveTrayProxyChain(
      proxyName: selected,
      groups: groups,
      selectedMap: selectedMap,
    );
    if (chain.isNotEmpty) {
      detail = showChain ? chain.join(trayProxyChainSeparator) : chain.last;
    }
  }
  return [
    if (showName) groupName,
    if (detail.isNotEmpty) detail,
  ].join(trayStatusNameSeparator);
}

// BETTBOX-CUSTOM: 托盘菜单中「已锁定」标记。URLTest / Fallback 这类自动组被手动
// 指定节点后内核会一直用它（fixed），菜单里在组名后画一把锁，与策略组卡片的锁一致。
// 借用 MenuItem.icon 把标记传给原生层，两端据此自绘锁图标。
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

// BETTBOX-CUSTOM: 托盘只允许手动选择 Selector 组的节点；Fallback、URLTest、
// LoadBalance、Relay 等由内核自动决定的组，节点行置灰且点击不响应、不关闭菜单。
bool isTrayGroupManuallySelectable(Group group) =>
    group.type == GroupType.Selector;

/// 托盘右侧灰色说明：选中项与延迟之间留小间距，任一为空时只保留另一项。
String joinTrayDetail(String selection, String delay) {
  if (selection.isEmpty) return delay;
  if (delay.isEmpty) return selection;
  return '$selection  $delay';
}
