import 'package:bett_box/common/app_localizations.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class App {
  static App? _instance;
  late MethodChannel methodChannel;
  Function()? onExit;
  Function()? onAppUpdateNotificationOpened;

  App._internal() {
    methodChannel = const MethodChannel('app');
    methodChannel.setMethodCallHandler(handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'exit':
        await onExit?.call();
      case 'appUpdateNotificationOpened':
        await onAppUpdateNotificationOpened?.call();
      case 'getText':
        try {
          return Intl.message(call.arguments as String);
        } catch (_) {
          return '';
        }
      default:
        throw MissingPluginException();
    }
  }

  factory App() {
    _instance ??= App._internal();
    return _instance!;
  }

  Future<bool?> moveTaskToBack() async {
    return await methodChannel.invokeMethod<bool>('moveTaskToBack');
  }

  Future<List<Package>> getPackages({bool forceRefresh = false}) async {
    final packagesRaw =
        await methodChannel.invokeListMethod<Map<dynamic, dynamic>>(
          'getPackages',
          {'forceRefresh': forceRefresh},
        ) ??
        const [];
    return packagesRaw
        .map((e) => Package.fromJson(Map<String, Object?>.from(e)))
        .toList();
  }

  Future<bool> hasPackageListPermission() async {
    final result = await methodChannel.invokeMethod<bool>(
      'hasPackageListPermission',
    );
    return result ?? true;
  }

  Future<bool> hasCameraPermission() async {
    final result = await methodChannel.invokeMethod<bool>(
      'hasCameraPermission',
    );
    return result ?? true;
  }

  Future<void> requestPackageListPermission() async {
    await methodChannel.invokeMethod<void>('requestPackageListPermission');
  }

  Future<void> openAppSettings() async {
    await methodChannel.invokeMethod<void>('openAppSettings');
  }

  Future<List<String>> getChinaPackageNames() async {
    final packageNamesRaw =
        await methodChannel.invokeListMethod<String>('getChinaPackageNames') ??
        const [];
    return packageNamesRaw.map((e) => e.toString()).toList();
  }

  Future<bool> openFile(String path) async {
    return await methodChannel.invokeMethod<bool>('openFile', {'path': path}) ??
        false;
  }

  Future<Uint8List?> getPackageIcon(
    String packageName, {
    bool forceRefresh = false,
  }) async {
    return await methodChannel.invokeMethod<Uint8List>('getPackageIcon', {
      'packageName': packageName,
      'forceRefresh': forceRefresh,
    });
  }

  Future<bool?> tip(String? message) async {
    if (message == null || message.isEmpty) return false;
    return await methodChannel.invokeMethod<bool>('tip', {'message': message});
  }

  Future<bool?> initShortcuts() async {
    return await methodChannel.invokeMethod<bool>('initShortcuts', {
      'toggle': appLocalizations.toggle,
      'start': appLocalizations.start,
      'stop': appLocalizations.stop,
    });
  }

  Future<bool?> updateExcludeFromRecents(bool value) async {
    return await methodChannel.invokeMethod<bool>('updateExcludeFromRecents', {
      'value': value,
    });
  }

  Future<int> getSelfLastUpdateTime() async {
    final result = await methodChannel.invokeMethod<int>(
      'getSelfLastUpdateTime',
    );
    return result ?? 0;
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    final result = await methodChannel.invokeMethod<bool>(
      'isIgnoringBatteryOptimizations',
    );
    return result ?? false;
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    await methodChannel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
  }

  Future<bool> setLauncherIcon(bool useLightIcon) async {
    final result = await methodChannel.invokeMethod<bool>('setLauncherIcon', {
      'useLightIcon': useLightIcon,
    });
    return result ?? false;
  }

  Future<bool> isAndroidTV() async {
    final result = await methodChannel.invokeMethod<bool>('isAndroidTV');
    return result ?? false;
  }

  Future<void> requestNotificationPermission() async {
    await methodChannel.invokeMethod<void>('requestNotificationPermission');
  }

  Future<bool> startAppUpdateDownload({
    required String url,
    required String fileName,
    required String releaseTag,
    String? checksum,
  }) async {
    return await methodChannel.invokeMethod<bool>('startAppUpdateDownload', {
          'url': url,
          'fileName': fileName,
          'releaseTag': releaseTag,
          'checksum': checksum,
        }) ??
        false;
  }

  Future<Map<String, dynamic>> getAppUpdateState() async {
    final state = await methodChannel.invokeMapMethod<String, dynamic>(
      'getAppUpdateState',
    );
    return state ?? const <String, dynamic>{};
  }

  Future<bool> retryAppUpdateDownload() async {
    return await methodChannel.invokeMethod<bool>('retryAppUpdateDownload') ??
        false;
  }

  Future<bool> installDownloadedAppUpdate(String releaseTag) async {
    return await methodChannel.invokeMethod<bool>(
          'installDownloadedAppUpdate',
          {'releaseTag': releaseTag},
        ) ??
        false;
  }

  Future<void> showAppUpdateNotification() async {
    await methodChannel.invokeMethod<void>('showAppUpdateNotification');
  }

  Future<bool> consumeAppUpdateOpenRequest() async {
    return await methodChannel.invokeMethod<bool>(
          'consumeAppUpdateOpenRequest',
        ) ??
        false;
  }
}

final app = App();
