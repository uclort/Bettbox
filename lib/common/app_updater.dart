import 'dart:async';

import 'package:auto_updater/auto_updater.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/dialog.dart';
import 'package:flutter/material.dart';

class AndroidAppUpdateState {
  final String status;
  final String releaseTag;
  final String fileName;
  final int downloadedBytes;
  final int totalBytes;
  final int speedBytes;
  final String error;

  const AndroidAppUpdateState({
    this.status = 'idle',
    this.releaseTag = '',
    this.fileName = '',
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speedBytes = 0,
    this.error = '',
  });

  factory AndroidAppUpdateState.fromMap(Map<String, dynamic> map) {
    int number(String key) => (map[key] as num?)?.toInt() ?? 0;
    return AndroidAppUpdateState(
      status: map['status']?.toString() ?? 'idle',
      releaseTag: map['releaseTag']?.toString() ?? '',
      fileName: map['fileName']?.toString() ?? '',
      downloadedBytes: number('downloadedBytes'),
      totalBytes: number('totalBytes'),
      speedBytes: number('speedBytes'),
      error: map['error']?.toString() ?? '',
    );
  }

  bool get isDownloading => status == 'downloading';
  bool get isDownloaded => status == 'downloaded';
  bool get isFailed => status == 'failed';
  double? get progress => totalBytes > 0
      ? (downloadedBytes / totalBytes).clamp(0.0, 1.0).toDouble()
      : null;
}

class CustomAppUpdater with UpdaterListener {
  bool _initialized = false;
  bool _manualCheck = false;
  bool _androidUpdateRunning = false;
  bool _androidDialogVisible = false;

  bool get supportsNativeUpdater =>
      isCustomUpdateBuild &&
      customUpdateFeedUrl.isNotEmpty &&
      (system.isMacOS || system.isWindows);

  Future<void> initialize() async {
    if (_initialized) return;
    if (system.isAndroid && isCustomUpdateBuild) {
      app.onAppUpdateNotificationOpened = () =>
          unawaited(showAndroidUpdateProgress());
      _initialized = true;
      if (await app.consumeAppUpdateOpenRequest()) {
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 500),
            showAndroidUpdateProgress,
          ),
        );
      }
      return;
    }
    if (supportsNativeUpdater) {
      autoUpdater.addListener(this);
      await autoUpdater.setFeedURL(customUpdateFeedUrl);
      await autoUpdater.setScheduledCheckInterval(0);
    }
    _initialized = true;
  }

  Future<void> checkDesktopUpdate({required bool manual}) async {
    if (!supportsNativeUpdater) return;
    await initialize();
    _manualCheck = manual;
    await autoUpdater.checkForUpdates(inBackground: !manual);
  }

  Future<void> installAndroidUpdate(Map<String, dynamic> release) async {
    if (!system.isAndroid) return;

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
      if (releaseUrl.isNotEmpty) await globalState.openUrl(releaseUrl);
      return;
    }

    final fileName = asset['name']?.toString() ?? 'Bettbox-update.apk';
    final digest = asset['digest']?.toString() ?? '';
    final checksum = digest.startsWith('sha256:')
        ? digest.substring('sha256:'.length)
        : null;
    final releaseTag = release['tag_name']?.toString() ?? '';
    final currentState = AndroidAppUpdateState.fromMap(
      await app.getAppUpdateState(),
    );

    if (currentState.isDownloaded && currentState.releaseTag == releaseTag) {
      final installed = await app.installDownloadedAppUpdate(releaseTag);
      if (!installed) {
        globalState.showNotifier(appLocalizations.updateFailed('无法打开已下载的安装包'));
      }
      return;
    }
    if (currentState.isDownloading && currentState.releaseTag == releaseTag) {
      await showAndroidUpdateProgress();
      return;
    }

    if (_androidUpdateRunning) return;
    _androidUpdateRunning = true;
    try {
      await app.requestNotificationPermission();
      final started = await app.startAppUpdateDownload(
        url: downloadUrl,
        fileName: fileName,
        releaseTag: releaseTag,
        checksum: checksum,
      );
      if (!started) {
        globalState.showNotifier(appLocalizations.updateFailed('无法启动下载任务'));
        return;
      }
      await showAndroidUpdateProgress();
    } catch (e) {
      globalState.showNotifier(appLocalizations.updateFailed(e.formatError));
    } finally {
      _androidUpdateRunning = false;
    }
  }

  Future<void> showAndroidUpdateProgress() async {
    if (!system.isAndroid || _androidDialogVisible) return;
    final state = AndroidAppUpdateState.fromMap(await app.getAppUpdateState());
    if (!state.isDownloading && !state.isDownloaded && !state.isFailed) return;

    _androidDialogVisible = true;
    try {
      await globalState.showCommonDialog<void>(
        dismissible: false,
        child: AndroidUpdateProgressDialog(initialState: state),
      );
    } finally {
      _androidDialogVisible = false;
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

class AndroidUpdateProgressDialog extends StatefulWidget {
  final AndroidAppUpdateState initialState;

  const AndroidUpdateProgressDialog({super.key, required this.initialState});

  @override
  State<AndroidUpdateProgressDialog> createState() =>
      _AndroidUpdateProgressDialogState();
}

class _AndroidUpdateProgressDialogState
    extends State<AndroidUpdateProgressDialog> {
  late AndroidAppUpdateState _state = widget.initialState;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = AndroidAppUpdateState.fromMap(await app.getAppUpdateState());
    if (mounted) setState(() => _state = next);
  }

  Future<void> _background() async {
    await app.showAppUpdateNotification();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _install() async {
    if (_busy) return;
    setState(() => _busy = true);
    final installed = await app.installDownloadedAppUpdate(_state.releaseTag);
    if (mounted) {
      setState(() => _busy = false);
      if (installed) Navigator.of(context).pop();
    }
  }

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await app.retryAppUpdateDownload();
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: _state.isDownloaded ? '更新已下载' : '下载应用更新',
      actions: [
        if (_state.isDownloading)
          TextButton(onPressed: _background, child: const Text('后台下载')),
        if (_state.isDownloaded) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后安装'),
          ),
          FilledButton(
            onPressed: _busy ? null : _install,
            child: const Text('立即安装'),
          ),
        ],
        if (_state.isFailed) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: _busy ? null : _retry,
            child: const Text('重新下载'),
          ),
        ],
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_state.fileName.isNotEmpty) ...[
            Text(
              _state.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
          ],
          if (_state.isDownloading) ...[
            LinearProgressIndicator(value: _state.progress),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_progressText(_state)),
                Text('${_formatBytes(_state.speedBytes)}/s'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatBytes(_state.downloadedBytes)} / '
              '${_state.totalBytes > 0 ? _formatBytes(_state.totalBytes) : '未知大小'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_state.isDownloaded) const Text('安装包已保存在本机，可立即安装或稍后再次检查更新后安装。'),
          if (_state.isFailed)
            Text(_state.error.isEmpty ? '下载失败，请重试。' : _state.error),
        ],
      ),
    );
  }

  String _progressText(AndroidAppUpdateState state) {
    final progress = state.progress;
    return progress == null ? '正在连接…' : '${(progress * 100).round()}%';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var index = -1;
    do {
      value /= 1024;
      index++;
    } while (value >= 1024 && index < units.length - 1);
    final digits = value >= 100 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[index]}';
  }
}
