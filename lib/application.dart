import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/common/external_control.dart';
import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/manager/hotkey_manager.dart';
import 'package:bett_box/manager/manager.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/macos_menu_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
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

  SwitchThemeData _switchTheme(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    return SwitchThemeData(
      thumbIcon: const WidgetStatePropertyAll(Icon(null)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) return colorScheme.onPrimary;
        return isLight ? Colors.white : colorScheme.onSurfaceVariant;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return isLight
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHighest.lighten(6);
      }),
    );
  }

  InputDecorationTheme _inputDecorationTheme(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    final border = _FieldInputBorder(
      borderSide: BorderSide(
        color: isLight
            ? colorScheme.outlineVariant
            : colorScheme.outline.withValues(alpha: 0.45),
      ),
    );
    final focusedBorder = _FieldInputBorder(
      borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
    );
    final errorBorder = _FieldInputBorder(
      borderSide: BorderSide(color: colorScheme.error),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.brightness == Brightness.light
          ? Color.lerp(
              colorScheme.surface,
              colorScheme.surfaceContainerLowest,
              0.5,
            )
          : colorScheme.surfaceContainerHighest,
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      disabledBorder: _FieldInputBorder(
        borderSide: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error, width: 1.6),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (system.isAndroid) {
      unawaited(SystemNavigator.setFrameworkHandlesBack(true));
    }
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
    if (!appPath.isPortable) {
      try {
        await ExternalControl.start();
      } catch (e) {
        commonPrint.warn('ExternalControl start failed: $e');
      }
    }
    await globalState.appController.init();
    if (system.isMacOS) {
      final networkState = await macOS?.defaultNetworkState;
      if (!mounted) return;
      _lastMacOSNetworkFingerprint = networkState?.fingerprint;
      _macOSNetworkRecoveryReady = true;
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
  Future<bool> didPopRoute() async {
    if (!system.isAndroid) return false;
    final navigator = globalState.navigatorKey.currentState;
    if (navigator == null) return false;
    try {
      if (!await navigator.maybePop()) {
        await globalState.appController.handleBackOrExit();
      }
    } catch (e) {
      commonPrint.warn('Back dispatch failed: $e');
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncAutoUpdateTasks();
  }

  void _syncAutoUpdateTasks() {
    final shouldRun = _isForeground && !globalState.backgroundMode.value;
    if (!shouldRun) {
      _autoUpdateGroupTaskTimer?.cancel();
      _autoUpdateGroupTaskTimer = null;
      if (!system.isDesktop) {
        _autoUpdateProfilesTaskTimer?.cancel();
        _autoUpdateProfilesTaskTimer = null;
      }
      return;
    }
    if (_autoUpdateGroupTaskTimer == null) {
      _autoUpdateGroupTask();
    }
    if (_autoUpdateProfilesTaskTimer == null) {
      _autoUpdateProfilesTask();
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
        unawaited(
          clashCore.closeConnections().then<void>(
            (_) {},
            onError: (Object error) =>
                commonPrint.log('closeConnections ignored: $error'),
          ),
        );
      }
      if (system.isLinux) {
        unawaited(_syncLinuxSystemDns());
      }
      globalState.appController.updateLocalNetwork();
      globalState.appController.addCheckIpNumDebounce();
      return;
    }

    unawaited(globalState.appController.updateLocalNetwork());
    if (!_macOSNetworkRecoveryReady) return;
    _scheduleMacOSNetworkRecovery();
  }


  Future<void> _syncLinuxSystemDns() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final isStart = ref.read(runTimeProvider) != null;
    final tunEnabled = ref.read(realTunEnableProvider);
    final autoSet = ref.read(networkSettingProvider).autoSetSystemDns;
    await system.updateDns(!(isStart && tunEnabled && autoSet));
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

    unawaited(globalState.appController.updateLocalNetwork());
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
              navigatorObservers: [routeIdleObserver],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              builder: (_, child) {
                final content = Directionality(
                  textDirection: TextDirection.ltr,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: globalState.animationEnabled,
                    builder: (_, enabled, _) {
                      return TickerMode(
                        enabled: enabled,
                        child: _buildApp(
                          AppSidebarContainer(child: _buildPlatformApp(child!)),
                        ),
                      );
                    },
                  ),
                );
                // BETTBOX-CUSTOM: 菜单必须在响应式布局外保持同一生命周期。
                // 否则旧 PlatformMenuBar 的 dispose 会清空新实例刚注册的菜单。
                return system.isMacOS ? MacOSMenuBar(child: content) : content;
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
                scaffoldBackgroundColor: _getAppColorScheme(
                  brightness: Brightness.light,
                  primaryColor: themeProps.primaryColor,
                ).surfaceContainer,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  surfaceTintColor: Colors.transparent,
                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                    statusBarBrightness: Brightness.light,
                    systemStatusBarContrastEnforced: false,
                  ),
                ),
                colorScheme: _getAppColorScheme(
                  brightness: Brightness.light,
                  primaryColor: themeProps.primaryColor,
                ),
                fontFamily: fontFamily,
                floatingActionButtonTheme: const FloatingActionButtonThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  elevation: 3,
                  hoverElevation: 5,
                ),
                dialogTheme: DialogThemeData(
                  backgroundColor: _getAppColorScheme(
                    brightness: Brightness.light,
                    primaryColor: themeProps.primaryColor,
                  ).surfaceContainerLowest,
                  surfaceTintColor: Colors.transparent,
                  elevation: 10,
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _getAppColorScheme(
                        brightness: Brightness.light,
                        primaryColor: themeProps.primaryColor,
                      ).outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                bottomSheetTheme: const BottomSheetThemeData(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                ),
                popupMenuTheme: const PopupMenuThemeData(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                dividerTheme: DividerThemeData(
                  color: _getAppColorScheme(
                    brightness: Brightness.light,
                    primaryColor: themeProps.primaryColor,
                  ).outlineVariant.withValues(alpha: 0.45),
                  thickness: 1,
                  space: 1,
                ),
                inputDecorationTheme: _inputDecorationTheme(
                  _getAppColorScheme(
                    brightness: Brightness.light,
                    primaryColor: themeProps.primaryColor,
                  ),
                ),
                switchTheme: _switchTheme(
                  _getAppColorScheme(
                    brightness: Brightness.light,
                    primaryColor: themeProps.primaryColor,
                  ),
                ),
                chipTheme: ChipThemeData(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  side: BorderSide(
                    color: _getAppColorScheme(
                      brightness: Brightness.light,
                      primaryColor: themeProps.primaryColor,
                    ).outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                tooltipTheme: TooltipThemeData(
                  decoration: BoxDecoration(
                    color: _getAppColorScheme(
                      brightness: Brightness.light,
                      primaryColor: themeProps.primaryColor,
                    ).inverseSurface,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  textStyle: TextStyle(
                    color: _getAppColorScheme(
                      brightness: Brightness.light,
                      primaryColor: themeProps.primaryColor,
                    ).onInverseSurface,
                    fontSize: 13,
                  ),
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                pageTransitionsTheme: _pageTransitionsTheme,
                scaffoldBackgroundColor: _getAppColorScheme(
                  brightness: Brightness.dark,
                  primaryColor: themeProps.primaryColor,
                ).toPureBlack(themeProps.pureBlack).surfaceContainer,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  surfaceTintColor: Colors.transparent,
                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                    statusBarBrightness: Brightness.dark,
                    systemStatusBarContrastEnforced: false,
                  ),
                ),
                colorScheme: _getAppColorScheme(
                  brightness: Brightness.dark,
                  primaryColor: themeProps.primaryColor,
                ).toPureBlack(themeProps.pureBlack),
                fontFamily: fontFamily,
                floatingActionButtonTheme: const FloatingActionButtonThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  elevation: 3,
                  hoverElevation: 5,
                ),
                dialogTheme: DialogThemeData(
                  backgroundColor: _getAppColorScheme(
                    brightness: Brightness.dark,
                    primaryColor: themeProps.primaryColor,
                  ).toPureBlack(themeProps.pureBlack).surfaceContainerHigh,
                  surfaceTintColor: Colors.transparent,
                  elevation: 10,
                  shadowColor: Colors.black.withValues(alpha: 0.6),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color:
                          _getAppColorScheme(
                                brightness: Brightness.dark,
                                primaryColor: themeProps.primaryColor,
                              )
                              .toPureBlack(themeProps.pureBlack)
                              .outlineVariant
                              .withValues(alpha: 0.5),
                    ),
                  ),
                ),
                bottomSheetTheme: const BottomSheetThemeData(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                ),
                popupMenuTheme: const PopupMenuThemeData(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                dividerTheme: DividerThemeData(
                  color:
                      _getAppColorScheme(
                            brightness: Brightness.dark,
                            primaryColor: themeProps.primaryColor,
                          )
                          .toPureBlack(themeProps.pureBlack)
                          .outlineVariant
                          .withValues(alpha: 0.25),
                  thickness: 1,
                  space: 1,
                ),
                inputDecorationTheme: _inputDecorationTheme(
                  _getAppColorScheme(
                    brightness: Brightness.dark,
                    primaryColor: themeProps.primaryColor,
                  ).toPureBlack(themeProps.pureBlack),
                ),
                switchTheme: _switchTheme(
                  _getAppColorScheme(
                    brightness: Brightness.dark,
                    primaryColor: themeProps.primaryColor,
                  ).toPureBlack(themeProps.pureBlack),
                ),
                chipTheme: ChipThemeData(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  side: BorderSide(
                    color:
                        _getAppColorScheme(
                              brightness: Brightness.dark,
                              primaryColor: themeProps.primaryColor,
                            )
                            .toPureBlack(themeProps.pureBlack)
                            .outlineVariant
                            .withValues(alpha: 0.5),
                  ),
                ),
                tooltipTheme: TooltipThemeData(
                  decoration: BoxDecoration(
                    color: _getAppColorScheme(
                      brightness: Brightness.dark,
                      primaryColor: themeProps.primaryColor,
                    ).toPureBlack(themeProps.pureBlack).inverseSurface,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  textStyle: TextStyle(
                    color: _getAppColorScheme(
                      brightness: Brightness.dark,
                      primaryColor: themeProps.primaryColor,
                    ).toPureBlack(themeProps.pureBlack).onInverseSurface,
                    fontSize: 13,
                  ),
                ),
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

class _FieldInputBorder extends InputBorder {
  const _FieldInputBorder({super.borderSide = BorderSide.none});

  static const _borderRadius = BorderRadius.all(Radius.circular(16));

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  _FieldInputBorder copyWith({BorderSide? borderSide}) {
    return _FieldInputBorder(borderSide: borderSide ?? this.borderSide);
  }

  @override
  ShapeBorder scale(double t) {
    return _FieldInputBorder(borderSide: borderSide.scale(t));
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is _FieldInputBorder) {
      return _FieldInputBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is _FieldInputBorder) {
      return _FieldInputBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(_borderRadius.toRRect(rect).deflate(borderSide.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(_borderRadius.toRRect(rect));
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style == BorderStyle.none || borderSide.width == 0) {
      return;
    }
    canvas.drawRRect(
      _borderRadius.toRRect(rect).deflate(borderSide.width / 2),
      borderSide.toPaint(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _FieldInputBorder && other.borderSide == borderSide;
  }

  @override
  int get hashCode => borderSide.hashCode;
}
