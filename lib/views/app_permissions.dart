import 'package:bett_box/common/common.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

// BETTBOX-CUSTOM: 关于 → 应用权限。列出 Bettbox 在 Android 上所需的全部权限、
// 授权状态与申请入口；状态来自原生 AppPlugin.getAppPermissionStates。

enum AppPermissionKind {
  /// 运行时弹窗申请。
  runtime,

  /// 需要跳转系统设置页授权。
  special,

  /// 安装时自动授予，无需申请。
  install,
}

@immutable
class AppPermissionState {
  final String id;
  final AppPermissionKind kind;

  /// false 表示当前系统版本不需要该权限（例如 Android 17 以下的本地网络权限）。
  final bool applicable;
  final bool granted;

  const AppPermissionState({
    required this.id,
    required this.kind,
    required this.applicable,
    required this.granted,
  });

  bool get canRequest =>
      applicable && !granted && kind != AppPermissionKind.install;

  static AppPermissionState? fromMap(Map<String, Object?> map) {
    final id = map['id'];
    if (id is! String || id.isEmpty) return null;
    final kind = AppPermissionKind.values.firstWhere(
      (value) => value.name == map['kind'],
      orElse: () => AppPermissionKind.special,
    );
    final applicable = map['applicable'] != false;
    return AppPermissionState(
      id: id,
      kind: kind,
      applicable: applicable,
      granted: !applicable || map['granted'] == true,
    );
  }
}

List<AppPermissionState> parseAppPermissionStates(
  List<Map<String, Object?>> raw,
) {
  return [
    for (final item in raw) ?AppPermissionState.fromMap(item),
  ];
}

@immutable
class AppPermissionInfo {
  final String title;
  final String description;
  final IconData icon;

  const AppPermissionInfo({
    required this.title,
    required this.description,
    required this.icon,
  });
}

const _permissionInfos = <String, AppPermissionInfo>{
  'vpn': AppPermissionInfo(
    title: 'VPN',
    description: '建立虚拟网卡接管设备流量，代理功能必需',
    icon: Icons.vpn_key_outlined,
  ),
  'localNetwork': AppPermissionInfo(
    title: '本地网络',
    description:
        'Android 17 新增（ACCESS_LOCAL_NETWORK，属于“附近的设备”）。'
        '访问局域网地址、局域网设备通过本机 HTTP/SOCKS 代理上网时需要',
    icon: Icons.lan_outlined,
  ),
  'notification': AppPermissionInfo(
    title: '通知',
    description: '前台服务常驻通知、网速显示与应用更新进度',
    icon: Icons.notifications_outlined,
  ),
  'batteryOptimization': AppPermissionInfo(
    title: '忽略电池优化',
    description: '避免后台被系统休眠或杀死导致代理中断',
    icon: Icons.battery_saver_outlined,
  ),
  'packageList': AppPermissionInfo(
    title: '读取应用列表',
    description: '访问控制按应用分流时读取已安装应用；部分系统需单独授权',
    icon: Icons.apps_outlined,
  ),
  'installPackages': AppPermissionInfo(
    title: '安装未知应用',
    description: '应用内更新下载完成后调用系统安装器',
    icon: Icons.system_update_outlined,
  ),
  'camera': AppPermissionInfo(
    title: '相机',
    description: '扫描二维码导入订阅',
    icon: Icons.qr_code_scanner_outlined,
  ),
  'internet': AppPermissionInfo(
    title: '网络访问',
    description: '连接代理服务器与下载订阅',
    icon: Icons.public_outlined,
  ),
  'networkState': AppPermissionInfo(
    title: '读取网络状态',
    description: '识别网络切换并自动恢复连接',
    icon: Icons.network_check_outlined,
  ),
  'foregroundService': AppPermissionInfo(
    title: '前台服务',
    description: '保持代理服务在后台持续运行',
    icon: Icons.miscellaneous_services_outlined,
  ),
  'bootCompleted': AppPermissionInfo(
    title: '开机启动',
    description: '开机后按设置自动启动代理',
    icon: Icons.power_settings_new_outlined,
  ),
};

AppPermissionInfo appPermissionInfoOf(String id) {
  return _permissionInfos[id] ??
      AppPermissionInfo(
        title: id,
        description: '',
        icon: Icons.verified_user_outlined,
      );
}

class AppPermissionsView extends StatefulWidget {
  const AppPermissionsView({super.key});

  @override
  State<AppPermissionsView> createState() => _AppPermissionsViewState();
}

class _AppPermissionsViewState extends State<AppPermissionsView>
    with WidgetsBindingObserver {
  List<AppPermissionState>? _states;
  String? _requestingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置页返回后重新读取状态。
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      final raw = await app.getAppPermissionStates();
      if (!mounted) return;
      setState(() => _states = parseAppPermissionStates(raw));
    } catch (error) {
      commonPrint.log('读取应用权限失败：$error');
      if (mounted) setState(() => _states = const []);
    }
  }

  Future<void> _request(AppPermissionState state) async {
    if (_requestingId != null) return;
    setState(() => _requestingId = state.id);
    try {
      final granted = await app.requestAppPermission(state.id);
      if (!mounted) return;
      if (state.kind == AppPermissionKind.runtime && !granted) {
        // 被拒绝两次后系统不再弹窗，引导到系统设置手动开启。
        context.showSnackBar(
          '${appPermissionInfoOf(state.id).title}未授权，可在系统设置中手动开启',
          action: SnackBarAction(
            label: '去设置',
            onPressed: () => app.openAppSettings(),
          ),
        );
      }
    } catch (error) {
      commonPrint.log('申请权限 ${state.id} 失败：$error');
    } finally {
      if (mounted) setState(() => _requestingId = null);
      await _refresh();
    }
  }

  Widget _buildStatus(BuildContext context, AppPermissionState state) {
    final colorScheme = context.colorScheme;
    if (!state.applicable) {
      return Text(
        '当前系统无需',
        style: context.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (state.granted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '已授权',
            style: context.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ],
      );
    }
    final requesting = _requestingId == state.id;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '未授权',
          style: context.textTheme.labelMedium?.copyWith(
            color: colorScheme.error,
          ),
        ),
        if (state.canRequest) ...[
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _requestingId == null ? () => _request(state) : null,
            child: requesting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('申请'),
          ),
        ],
      ],
    );
  }

  Widget _buildItem(BuildContext context, AppPermissionState state) {
    final info = appPermissionInfoOf(state.id);
    return ListItem(
      leading: Icon(info.icon),
      title: Text(info.title),
      subtitle: info.description.isEmpty ? null : Text(info.description),
      trailing: _buildStatus(context, state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final states = _states;
    if (states == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final requested = states
        .where((state) => state.kind != AppPermissionKind.install)
        .toList();
    final installed = states
        .where((state) => state.kind == AppPermissionKind.install)
        .toList();
    return generateListView([
      ...generateSection(
        title: '需要授权',
        isFirst: true,
        items: [for (final state in requested) _buildItem(context, state)],
      ),
      if (installed.isNotEmpty)
        ...generateSection(
          title: '安装时授予',
          items: [for (final state in installed) _buildItem(context, state)],
        ),
      ...generateSection(
        items: [
          ListItem(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('打开系统应用设置'),
            subtitle: const Text('在系统设置中查看或撤销全部权限'),
            onTap: () => app.openAppSettings(),
          ),
        ],
      ),
    ]);
  }
}
