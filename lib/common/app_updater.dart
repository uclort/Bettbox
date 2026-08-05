import 'dart:async';

import 'package:auto_updater/auto_updater.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:ota_update/ota_update.dart';

class CustomAppUpdater with UpdaterListener {
  bool _initialized = false;
  bool _manualCheck = false;
  bool _androidUpdateRunning = false;

  bool get supportsNativeUpdater =>
      isCustomUpdateBuild &&
      customUpdateFeedUrl.isNotEmpty &&
      (system.isMacOS || system.isWindows);

  Future<void> initialize() async {
    if (_initialized || !supportsNativeUpdater) return;
    autoUpdater.addListener(this);
    await autoUpdater.setFeedURL(customUpdateFeedUrl);
    await autoUpdater.setScheduledCheckInterval(0);
    _initialized = true;
  }

  Future<void> checkDesktopUpdate({required bool manual}) async {
    if (!supportsNativeUpdater) return;
    await initialize();
    _manualCheck = manual;
    await autoUpdater.checkForUpdates(inBackground: !manual);
  }

  Future<void> installAndroidUpdate(Map<String, dynamic> release) async {
    if (!system.isAndroid || _androidUpdateRunning) return;

    const assetSuffix = String.fromEnvironment('APP_ASSET_SUFFIX');
    final assets = (release['assets'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>();
    Map<String, dynamic>? asset;
    for (final candidate in assets) {
      final name = candidate['name']?.toString() ?? '';
      if (assetSuffix.isNotEmpty && name.endsWith(assetSuffix)) {
        asset = candidate;
        break;
      }
    }

    final downloadUrl = asset?['browser_download_url']?.toString() ?? '';
    if (asset == null || downloadUrl.isEmpty) {
      final releaseUrl = release['html_url']?.toString() ?? '';
      if (releaseUrl.isNotEmpty) {
        await globalState.openUrl(releaseUrl);
      }
      return;
    }

    final fileName = asset['name']?.toString() ?? 'Bettbox-update.apk';
    final digest = asset['digest']?.toString() ?? '';
    final checksum = digest.startsWith('sha256:')
        ? digest.substring('sha256:'.length)
        : null;

    _androidUpdateRunning = true;
    var lastProgress = -10;
    try {
      final events = OtaUpdate().execute(
        downloadUrl,
        destinationFilename: fileName,
        sha256checksum: checksum,
      );
      await for (final event in events) {
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            final progress = int.tryParse(event.value ?? '') ?? 0;
            final progressBucket = (progress ~/ 10) * 10;
            if (progressBucket > lastProgress) {
              lastProgress = progressBucket;
              globalState.showNotifier(
                appLocalizations.updateDownloading(progressBucket),
              );
            }
            break;
          case OtaStatus.INSTALLING:
            globalState.showNotifier(appLocalizations.updateInstalling);
            break;
          case OtaStatus.INSTALLATION_DONE:
            return;
          case OtaStatus.ALREADY_RUNNING_ERROR:
          case OtaStatus.INSTALLATION_ERROR:
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
          case OtaStatus.INTERNAL_ERROR:
          case OtaStatus.DOWNLOAD_ERROR:
          case OtaStatus.CHECKSUM_ERROR:
          case OtaStatus.CANCELED:
            globalState.showNotifier(
              appLocalizations.updateFailed(event.value ?? event.status.name),
            );
            return;
        }
      }
    } catch (e) {
      globalState.showNotifier(appLocalizations.updateFailed(e.formatError));
    } finally {
      _androidUpdateRunning = false;
    }
  }

  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? appcastItem) {
    unawaited(globalState.appController.handleExit());
  }

  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) {}

  @override
  void onUpdaterError(UpdaterError? error) {
    if (_manualCheck) {
      globalState.showNotifier(
        appLocalizations.updateFailed(error?.message ?? 'Unknown error'),
      );
    }
    _manualCheck = false;
  }

  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) {
    _manualCheck = false;
  }

  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {}

  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) {
    _manualCheck = false;
  }
}

final customAppUpdater = CustomAppUpdater();
