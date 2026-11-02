import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';

// BETTBOX-CUSTOM: 托盘策略组右侧展示当前选中目标。
// 一级菜单只显示直接选中项（`includeFinal: false`）；二级菜单中选中项仍是
// 策略组时，用括号补充沿链路解析出的最终节点，例如 `Other (FC-香港 6)`。
String trayGroupSelectionLabel({
  required String groupName,
  required List<Group> groups,
  required SelectedMap selectedMap,
  bool includeFinal = true,
}) {
  final selected = _selectedNameOf(groupName, groups, selectedMap);
  if (!includeFinal || selected.isEmpty || !_isGroupLike(selected, groups)) {
    return selected;
  }
  final finalName = resolveTrayFinalProxyName(
    proxyName: selected,
    groups: groups,
    selectedMap: selectedMap,
  );
  if (finalName.isEmpty || finalName == selected) {
    return selected;
  }
  return '$selected ($finalName)';
}

/// 沿策略组选择链解析最终节点；遇到循环引用时停在最后一个未重复的名称。
String resolveTrayFinalProxyName({
  required String proxyName,
  required List<Group> groups,
  required SelectedMap selectedMap,
}) {
  var current = proxyName;
  final visited = <String>{};
  while (current.isNotEmpty && visited.add(current)) {
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
  return current;
}

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
