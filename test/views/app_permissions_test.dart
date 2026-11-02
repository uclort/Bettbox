import 'package:bett_box/views/app_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('解析原生权限状态并计算可申请项', () {
    final states = parseAppPermissionStates([
      {
        'id': 'localNetwork',
        'kind': 'runtime',
        'applicable': true,
        'granted': false,
      },
      {
        'id': 'notification',
        'kind': 'runtime',
        'applicable': true,
        'granted': true,
      },
      {
        'id': 'installPackages',
        'kind': 'special',
        'applicable': true,
        'granted': false,
      },
      {
        'id': 'internet',
        'kind': 'install',
        'applicable': true,
        'granted': false,
      },
      {'id': '', 'kind': 'runtime'},
      {'kind': 'runtime'},
    ]);

    expect(states.map((state) => state.id), [
      'localNetwork',
      'notification',
      'installPackages',
      'internet',
    ]);
    expect(states[0].canRequest, isTrue);
    expect(states[1].canRequest, isFalse);
    expect(states[2].kind, AppPermissionKind.special);
    expect(states[2].canRequest, isTrue);
    // 安装时权限即使检查失败也不提供申请按钮。
    expect(states[3].canRequest, isFalse);
  });

  test('当前系统不需要的权限视为已满足且不可申请', () {
    final state = AppPermissionState.fromMap({
      'id': 'localNetwork',
      'kind': 'runtime',
      'applicable': false,
      'granted': false,
    })!;
    expect(state.applicable, isFalse);
    expect(state.granted, isTrue);
    expect(state.canRequest, isFalse);
  });

  test('未知权限 ID 使用兜底文案，未知 kind 按系统设置处理', () {
    final state = AppPermissionState.fromMap({
      'id': 'future',
      'kind': 'unknown',
      'granted': false,
    })!;
    expect(state.kind, AppPermissionKind.special);
    expect(appPermissionInfoOf('future').title, 'future');
    expect(appPermissionInfoOf('localNetwork').title, '本地网络');
  });
}
