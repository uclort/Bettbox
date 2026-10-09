import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bett_box/clash/interface.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/helper/helper.dart';
import 'package:bett_box/models/core.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/utils/frame_codec.dart';
import 'package:bett_box/utils/platform_check.dart';
import 'package:path/path.dart' as p;

class ClashService extends ClashHandlerInterface {
  static ClashService? _instance;

  Completer<ServerSocket> serverCompleter = Completer();

  Completer<Socket> socketCompleter = Completer();

  Socket? _activeSocket;

  bool isStarting = false;
  bool _isDestroying = false;
  bool _unexpectedExitReported = false;

  Process? process;

  Completer<void>? _restartCompleter;
  Future<void> Function(String details)? onUnexpectedExit;

  TransportType _transportType = TransportType.unixSocket;
  String? _socketPath;
  int? _tcpPort;

  factory ClashService() {
    _instance ??= ClashService._internal();
    return _instance!;
  }

  ClashService._internal() {
    _initTransport();
  }

  Future<void> _initTransport() async {
    _transportType = await PlatformChecker.getRecommendedTransport();

    if (_transportType == TransportType.unixSocket) {
      final random = Random().nextInt(10000);
      final tempDir = Directory.systemTemp.path;
      _socketPath = p.join(tempDir, 'Bettbox_$random.sock');
      commonPrint.log('Using Unix Domain Socket: $_socketPath');
    } else {
      _tcpPort = PlatformChecker.getRandomPort();
      commonPrint.log('Using TCP Socket on port: $_tcpPort');
    }

    _initServer();
    try {
      await reStart();
    } catch (e) {
      commonPrint.log('Initial BettboxCore start failed: $e');
    }
  }

  Future<void> _initServer() async {
    runZonedGuarded(
      () async {
        late final ServerSocket server;

        if (_transportType == TransportType.unixSocket) {
          final address = InternetAddress(
            _socketPath!,
            type: InternetAddressType.unix,
          );
          await _deleteSocketFile();
          server = await ServerSocket.bind(address, 0, shared: true);
        } else {
          server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
          _tcpPort = server.port;
          commonPrint.log('TCP Server bound to port: $_tcpPort');
        }

        serverCompleter.complete(server);
        await for (final socket in server) {
          await _destroySocket();
          _activeSocket = socket;
          socketCompleter.complete(socket);

          socket
              .transform(FrameDecoderTransformer())
              .listen(
                (data) {
                  handleResult(ActionResult.fromJson(json.decode(data)));
                },
                onError: (error) {
                  if (_isDestroying || globalState.isExiting) return;
                  commonPrint.log('Frame decode error: $error');
                },
                onDone: () {
                  _handleSocketClosed(socket);
                  commonPrint.log('Socket connection closed');
                },
              );
        }
      },
      (error, stack) {
        if (_isDestroying || globalState.isExiting) return;
        commonPrint.log(error.toString());
        if (error is SocketException &&
            !_isDestroying &&
            !globalState.isExiting) {
          globalState.showNotifier(error.toString());
        }
      },
    );
  }

  @override
  Future<void> reStart() async {
    final completer = Completer<void>();
    final previous = _restartCompleter;
    _restartCompleter = completer;

    if (previous != null) {
      await previous.future;
    }

    try {
      // Perform a real restart so every caller is guaranteed to see a fresh
      // core after this call returns. Queued calls will run sequentially.
      await _doRestart();
    } finally {
      if (_restartCompleter == completer) {
        _restartCompleter = null;
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> _doRestart() async {
    isStarting = true;
    _isDestroying = false;
    _unexpectedExitReported = false;

    try {
      await _destroySocket();

      if (system.isWindows) {
        await helperClient.stopCore().catchError((_) => false);
      }

      final previousProcess = process;
      process = null;
      previousProcess?.kill();
      if (previousProcess != null) {
        await previousProcess.exitCode.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            previousProcess.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      }

      final serverSocket = await serverCompleter.future;

      final String arg;
      if (_transportType == TransportType.unixSocket) {
        arg = _socketPath!;
      } else {
        arg = '${serverSocket.port}';
      }

      final homeDirPath = await appPath.homeDirPath;
      final environment = Map<String, String>.from(Platform.environment);
      environment['SAFE_PATHS'] = homeDirPath;

      if (system.isWindows) {
        final isHealthy = await windows?.isHelperHealthy() ?? false;
        if (isHealthy) {
          final started = await helperClient.startCore(
            corePath: appPath.corePath,
            arg: arg,
            homeDir: homeDirPath,
          );
          if (started) {
            if (await _waitForCoreReady()) {
              _setWindowsCorePriority();
              return;
            }
            commonPrint.log(
              'Helper start core timed out waiting for socket, falling back to normal mode',
            );
            await helperClient.stopCore().catchError((_) => false);
          } else {
            commonPrint.log(
              'Helper start core failed, falling back to normal mode',
            );
          }
        }
      }

      final coreProcess = await Process.start(appPath.corePath, [
        arg,
      ], environment: environment);
      process = coreProcess;
      coreProcess.stdout.listen((_) {});
      var lastCoreError = '';
      coreProcess.stderr.listen((e) {
        final error = utf8.decode(e);
        if (error.isNotEmpty) {
          lastCoreError = error.trim();
          commonPrint.log(error);
        }
      });
      unawaited(
        coreProcess.exitCode.then((exitCode) {
          if (!identical(process, coreProcess) ||
              _isDestroying ||
              globalState.isExiting) {
            return;
          }
          process = null;
          final details =
              'BettboxCore 异常退出（代码 $exitCode）'
              '${lastCoreError.isEmpty ? '' : ': $lastCoreError'}';
          final socket = _activeSocket;
          if (socket != null) {
            _handleSocketClosed(socket, details: details);
          } else {
            _notifyUnexpectedExit(details);
          }
          commonPrint.log(details);
        }),
      );
      if (!await _waitForCoreReady()) {
        if (identical(process, coreProcess)) {
          process = null;
        }
        coreProcess.kill();
        throw StateError('BettboxCore 启动超时，未建立控制连接');
      }
      _setWindowsCorePriority();
    } finally {
      isStarting = false;
    }
  }

  void _setWindowsCorePriority() {
    if (!system.isWindows ||
        !globalState.config.appSetting.enableHighPriority) {
      return;
    }
    unawaited(
      helperClient
          .setProcessPriority('${AppIdentity.coreExecutableName}.exe', true)
          .catchError((e) {
            commonPrint.log('Failed to set core process priority: $e');
            return false;
          }),
    );
  }

  Future<bool> _waitForCoreReady() async {
    try {
      await socketCompleter.future.timeout(const Duration(seconds: 5));
      _unexpectedExitReported = false;
      return true;
    } catch (_) {
      commonPrint.log('Core ready timeout after 5s');
      return false;
    }
  }

  @override
  destroy() async {
    _isDestroying = true;
    final server = await serverCompleter.future;
    await server.close();
    await _deleteSocketFile();
    return true;
  }

  @override
  sendMessage(String message) async {
    if (_isDestroying || globalState.isExiting) {
      return;
    }
    if (_restartCompleter != null) {
      await _restartCompleter!.future;
    }
    final socket = await socketCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException('Core socket connection timed out');
      },
    );
    try {
      final frame = FrameCodec.encode(message);
      socket.add(frame);
    } on SocketException catch (e) {
      _handleSocketClosed(socket);
      if (_isDestroying || globalState.isExiting || isStarting) {
        commonPrint.log(
          'Ignored message send on closed socket during transition: $e',
        );
        return;
      }
      rethrow;
    } on StateError catch (e) {
      _handleSocketClosed(socket);
      if (_isDestroying || globalState.isExiting || isStarting) {
        commonPrint.log(
          'Ignored message send on closed socket during transition: $e',
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> _deleteSocketFile() async {
    if (_transportType == TransportType.unixSocket && _socketPath != null) {
      final file = File(_socketPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _destroySocket() async {
    final socket = _activeSocket;
    _activeSocket = null;
    if (socketCompleter.isCompleted) socketCompleter = Completer();
    await socket?.close();
  }

  void _handleSocketClosed(Socket socket, {String? details}) {
    if (!identical(_activeSocket, socket)) return;
    _activeSocket = null;
    if (socketCompleter.isCompleted) socketCompleter = Completer();
    if (!_isDestroying && !globalState.isExiting && !isStarting) {
      _notifyUnexpectedExit(details ?? 'BettboxCore 控制连接意外断开');
    }
  }

  void _notifyUnexpectedExit(String details) {
    if (_unexpectedExitReported ||
        _isDestroying ||
        globalState.isExiting ||
        isStarting) {
      return;
    }
    _unexpectedExitReported = true;
    final callback = onUnexpectedExit;
    if (callback == null) {
      globalState.showNotifier('BettboxCore 异常退出，请查看日志');
      return;
    }
    unawaited(
      callback(details).catchError((Object error, StackTrace stackTrace) {
        commonPrint.log('处理 BettboxCore 异常退出失败：$error\n$stackTrace');
      }),
    );
  }

  @override
  shutdown() async {
    _isDestroying = true;
    if (system.isWindows) {
      await helperClient.stopCore();
    }
    await _destroySocket();
    process?.kill();
    process = null;
    return true;
  }

  Future<bool> checkCoreHealth({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_isDestroying || globalState.isExiting || isStarting) return false;
    if (!socketCompleter.isCompleted) return false;
    try {
      final result = await invoke<bool>(
        method: ActionMethod.getIsInit,
        timeout: timeout,
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> preload() async {
    await serverCompleter.future;
    return true;
  }
}

final clashService = system.isDesktop ? ClashService() : null;
