import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/common/external_control.dart';
import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/manager/hotkey_manager.dart';
import 'package:bett_box/manager/manager.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controller.dart';
import 'pages/pages.dart';
import 'views/network_monitor.dart';

bool shouldReconcileMacOSNetworkState({
  required String? previousFingerprint,
  required String currentFingerprint,
  bool force = false,
}) {
  return force || previousFingerprint != currentFingerprint;
}

@visibleForTesting
Future<void> runMacOSNetworkRecoveryWithRetry(
  Future<void> Function() recover, {
  Duration retryDelay = const Duration(seconds: 2),
}) async {
  try {
    await recover();
  } catch (error) {
    commonPrint.log('macOS 网络恢复首次失败，准备进行一次重试：$error');
    await Future.delayed(retryDelay);
    await recover();
  }
}

@visibleForTesting
class MacOSNetworkRecoveryRequest {
  final bool force;

  const MacOSNetworkRecoveryRequest({required this.force});
}

@visibleForTesting
class MacOSNetworkRecoveryCoordinator {
  bool _isProcessing = false;
  bool _hasPendingRequest = false;
  bool _hasForcedRequest = false;

  bool get isProcessing => _isProcessing;
  bool get hasPendingRequest => _hasPendingRequest;

  void schedule({bool force = false}) {
    _hasPendingRequest = true;
    _hasForcedRequest |= force;
  }

  MacOSNetworkRecoveryRequest? beginNext() {
    if (_isProcessing || !_hasPendingRequest) return null;

    _isProcessing = true;
    _hasPendingRequest = false;
    final request = MacOSNetworkRecoveryRequest(force: _hasForcedRequest);
    // 强制恢复只属于当前请求，恢复期间的新网络事件不能继承该标记。
    _hasForcedRequest = false;
    return request;
  }

  void completeCurrent() {
    _isProcessing = false;
  }

  void clearPending() {
    _hasPendingRequest = false;
    _hasForcedRequest = false;
  }
}

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application>
    with WidgetsBindingObserver {
  Timer? _autoUpdateGroupTaskTimer;
  Timer? _autoUpdateProfilesTaskTimer;
  Timer? _networkChangeDebounceTimer;
  final _macOSNetworkRecoveryCoordinator = MacOSNetworkRecoveryCoordinator();
  bool _macOSNetworkRecoveryReady = false;
  String? _lastMacOSNetworkFingerprint;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    int? primaryColor,
  }) {
    return ref.read(genColorSchemeProvider(brightness));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    globalState.backgroundMode.addListener(_syncAutoUpdateTasks);
    _syncAutoUpdateTasks();
    globalState.appController = AppController(context, ref);
    if (system.isMacOS) {
      app.onSystemWake = _handleMacOSSystemWake;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initApp());
    });
  }

  bool get _isForeground {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    return lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
  }

  Future<void> _initApp() async {
    final currentContext = globalState.navigatorKey.currentContext;
    if (currentContext != null && currentContext != context) {
      globalState.appController = AppController(currentContext, ref);
    }
    await globalState.appController.init();
    if (system.isMacOS) {
      final networkState = await macOS?.defaultNetworkState;
      if (!mounted) return;
      _lastMacOSNetworkFingerprint = networkState?.fingerprint;
      _macOSNetworkRecoveryReady = true;
    }
    try {
      await ExternalControl.start();
    } catch (e) {
      commonPrint.log('ExternalControl start failed: $e');
    }
    globalState.appController.initLink();
    if (system.isAndroid) {
      app.initShortcuts();
    }
    Future.delayed(const Duration(seconds: 3), () {
      globalState.warmupCommonDialog();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncAutoUpdateTasks();
    if (state == AppLifecycleState.resumed) {
      if (system.isAndroid &&
          globalState.config.appSetting.enableHighRefreshRate) {
        _restoreHighRefreshRate();
      }
    }
  }

  void _syncAutoUpdateTasks() {
    final shouldRun = _isForeground && !globalState.backgroundMode.value;
    if (!shouldRun) {
      _autoUpdateGroupTaskTimer?.cancel();
      _autoUpdateGroupTaskTimer = null;
      return;
    }
    if (_autoUpdateGroupTaskTimer == null) {
      _autoUpdateGroupTask();
    }
    if (_autoUpdateProfilesTaskTimer == null) {
      _autoUpdateProfilesTask();
    }
  }

  Future<void> _restoreHighRefreshRate() async {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      commonPrint.log('Failed to restore high refresh rate: $e');
    }
  }

  void _autoUpdateGroupTask() {
    _autoUpdateGroupTaskTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => globalState.appController.updateGroupsDebounce(),
    );
  }

  void _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer.periodic(
      const Duration(hours: 24),
      (_) => unawaited(globalState.appController.autoUpdateProfiles()),
    );
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    if (!system.isMacOS) {
      if (!results.contains(ConnectivityResult.vpn)) {
        unawaited(clashCore.closeConnections());
      }
      globalState.appController.updateLocalIp();
      globalState.appController.addCheckIpNumDebounce();
      return;
    }

    unawaited(globalState.appController.updateLocalIp());
    if (!_macOSNetworkRecoveryReady) return;
    _scheduleMacOSNetworkRecovery();
  }

  void _handleMacOSSystemWake() {
    if (!mounted || !system.isMacOS || !_macOSNetworkRecoveryReady) return;
    commonPrint.log('检测到 macOS 系统唤醒，准备恢复 TUN 与 DNS');
    _scheduleMacOSNetworkRecovery(force: true);
  }

  void _scheduleMacOSNetworkRecovery({bool force = false}) {
    _macOSNetworkRecoveryCoordinator.schedule(force: force);
    if (_macOSNetworkRecoveryCoordinator.isProcessing) return;

    _networkChangeDebounceTimer?.cancel();
    _networkChangeDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_drainMacOSNetworkRecoveryQueue()),
    );
  }

  Future<void> _drainMacOSNetworkRecoveryQueue() async {
    _networkChangeDebounceTimer = null;
    while (mounted) {
      final request = _macOSNetworkRecoveryCoordinator.beginNext();
      if (request == null) return;

      try {
        await runMacOSNetworkRecoveryWithRetry(
          () => _handleMacOSNetworkChange(request),
        );
      } catch (e, stackTrace) {
        commonPrint.log('macOS 网络恢复重试后仍失败：$e\n$stackTrace');
      } finally {
        _macOSNetworkRecoveryCoordinator.completeCurrent();
      }
    }
  }

  Future<void> _handleMacOSNetworkChange(
    MacOSNetworkRecoveryRequest request,
  ) async {
    final networkState = await macOS?.waitForStableDefaultNetwork(
      isCancelled: () => !mounted,
    );
    if (networkState == null || !mounted) return;

    if (!shouldReconcileMacOSNetworkState(
      previousFingerprint: _lastMacOSNetworkFingerprint,
      currentFingerprint: networkState.fingerprint,
      force: request.force,
    )) {
      return;
    }

    commonPrint.log(
      '开始 macOS TUN 与 DNS 恢复：service=${networkState.serviceName}, '
      'force=${request.force}',
    );
    final recovered = await globalState.appController.handleMacOSNetworkChange(
      networkState,
      isCancelled: () => !mounted,
    );
    if (!recovered || !mounted) {
      commonPrint.log('macOS 网络恢复已被用户操作或应用退出取消');
      return;
    }

    _lastMacOSNetworkFingerprint = networkState.fingerprint;
    final latestNetworkState = await macOS?.defaultNetworkState;
    if (latestNetworkState != null &&
        latestNetworkState.fingerprint != networkState.fingerprint) {
      commonPrint.log('恢复期间默认网络再次变化，已排队复核');
      _macOSNetworkRecoveryCoordinator.schedule();
    } else {
      commonPrint.log('macOS TUN 与 DNS 恢复完成');
    }

    unawaited(globalState.appController.updateLocalIp());
    globalState.appController.addCheckIpNumDebounce();
  }

  Widget _buildPlatformState(Widget child) {
    if (system.isDesktop) {
      return NetworkMonitorHost(
        child: WindowManager(
          child: TrayManager(
            child: HotKeyManager(
              child: ProxyManager(child: SmartAutoStopManager(child: child)),
            ),
          ),
        ),
      );
    }
    return AndroidManager(
      child: TileManager(child: SmartAutoStopManager(child: child)),
    );
  }

  Widget _buildState(Widget child) {
    return AppStateManager(
      child: ClashManager(
        child: ConnectivityManager(
          onConnectivityChanged: _handleConnectivityChanged,
          child: child,
        ),
      ),
    );
  }

  Widget _buildPlatformApp(Widget child) {
    if (system.isDesktop) {
      return WindowHeaderContainer(child: child);
    }
    return VpnManager(child: child);
  }

  Widget _buildApp(Widget child) {
    return MessageManager(child: ThemeManager(child: child));
  }

  @override
  Widget build(context) {
    return _buildPlatformState(
      _buildState(
        Consumer(
          builder: (_, ref, child) {
            final locale = ref.watch(
              appSettingProvider.select((state) => state.locale),
            );
            final themeProps = ref.watch(themeSettingProvider);
            final fontFamily = themeProps.useHarmonyFont
                ? 'HarmonyOS_Sans'
                : null;

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: globalState.navigatorKey,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              builder: (_, child) {
                return ValueListenableBuilder<bool>(
                  valueListenable: globalState.animationEnabled,
                  builder: (_, enabled, _) {
                    return TickerMode(
                      enabled: enabled,
                      child: AppEnvManager(
                        child: _buildApp(
                          AppSidebarContainer(child: _buildPlatformApp(child!)),
                        ),
                      ),
                    );
                  },
                );
              },
              scrollBehavior: BaseScrollBehavior(),
              title: appName,
              locale:
                  utils.getLocaleForString(locale) ?? utils.getSystemLocale(),
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              themeMode: themeProps.themeMode,
              theme: ThemeData(
                useMaterial3: true,
                pageTransitionsTheme: _pageTransitionsTheme,
                colorScheme: _getAppColorScheme(
                  brightness: Brightness.light,
                  primaryColor: themeProps.primaryColor,
                ),
                fontFamily: fontFamily,
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                pageTransitionsTheme: _pageTransitionsTheme,
                colorScheme: _getAppColorScheme(
                  brightness: Brightness.dark,
                  primaryColor: themeProps.primaryColor,
                ).toPureBlack(themeProps.pureBlack),
                fontFamily: fontFamily,
              ),
              home: child!,
            );
          },
          child: const HomePage(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (system.isMacOS) {
      app.onSystemWake = null;
    }
    globalState.backgroundMode.removeListener(_syncAutoUpdateTasks);
    WidgetsBinding.instance.removeObserver(this);
    linkManager.destroy();
    _autoUpdateGroupTaskTimer?.cancel();
    _autoUpdateProfilesTaskTimer?.cancel();
    _networkChangeDebounceTimer?.cancel();
    _macOSNetworkRecoveryCoordinator.clearPending();
    ExternalControl.stop();
    if (!system.isAndroid && !globalState.isExiting) {
      unawaited(globalState.appController.handleExit());
    }
    super.dispose();
  }
}
