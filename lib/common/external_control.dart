import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/utils/platform_check.dart';
import 'package:restart_app/restart_app.dart';

class ExternalControl {
  static ServerSocket? _server;
  static TransportType? _transportType;
  static Future<Object?> Function(String method, Object? arguments)?
  _networkMonitorHandler;
  static final Set<Socket> _networkMonitorSubscribers = {};

  static Future<void> start() async {
    if (!system.isDesktop || _server != null) return;

    _transportType = await PlatformChecker.getRecommendedTransport();

    if (_transportType == TransportType.unixSocket) {
      try {
        await _startUnixSocket();
        return;
      } catch (e) {
        commonPrint.log(
          'ExternalControl UDS bind failed, falling back to TCP: $e',
        );
      }
    }
    await _startTcpSocket();
  }

  static Future<void> _startUnixSocket() async {
    final socketPath = await appPath.controlSocketPath;
    final type = FileSystemEntity.typeSync(socketPath);
    if (type != FileSystemEntityType.notFound) {
      try {
        await File(socketPath).delete();
      } catch (_) {}
    }
    final address = InternetAddress(socketPath, type: InternetAddressType.unix);
    _server = await ServerSocket.bind(address, 0);
    _listen();
  }

  static Future<void> _startTcpSocket() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final portFilePath = await appPath.controlPortFilePath;
    try {
      await File(portFilePath).writeAsString('${_server!.port}');
    } catch (_) {}
    _listen();
  }

  static void _listen() {
    _server!.listen(
      _handleSocket,
      onError: (e) => commonPrint.log('ExternalControl server error: $e'),
    );
  }

  static void _handleSocket(Socket socket) {
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => unawaited(_handleLine(socket, line)),
          onDone: () => _closeSocket(socket),
          onError: (_) => _closeSocket(socket),
        );
  }

  static Future<void> _handleLine(Socket socket, String line) async {
    try {
      if (!line.trimLeft().startsWith('{')) {
        _handleCommand(line);
        return;
      }
      final message = jsonDecode(line) as Map<String, dynamic>;
      final method = message['method'] as String;
      if (method == 'networkMonitor.subscribe') {
        _networkMonitorSubscribers.add(socket);
        socket.writeln(jsonEncode({'event': 'ready'}));
        await socket.flush();
        return;
      }
      final handler = _networkMonitorHandler;
      if (handler == null) throw StateError('网络面板服务尚未就绪');
      final result = await handler(method, message['arguments']);
      socket.writeln(jsonEncode({'ok': true, 'result': result}));
    } catch (error) {
      socket.writeln(jsonEncode({'ok': false, 'error': error.toString()}));
    } finally {
      if (!_networkMonitorSubscribers.contains(socket)) {
        try {
          await socket.flush();
        } finally {
          _closeSocket(socket);
        }
      }
    }
  }

  static void _closeSocket(Socket socket) {
    _networkMonitorSubscribers.remove(socket);
    socket.destroy();
  }

  static Future<void> stop() async {
    for (final socket in _networkMonitorSubscribers) {
      socket.destroy();
    }
    _networkMonitorSubscribers.clear();
    await _server?.close();
    _server = null;
    _transportType = null;

    final socketPath = await appPath.controlSocketPath;
    final type = FileSystemEntity.typeSync(socketPath);
    if (type != FileSystemEntityType.notFound) {
      try {
        await File(socketPath).delete();
      } catch (_) {}
    }

    final portFilePath = await appPath.controlPortFilePath;
    if (await File(portFilePath).exists()) {
      try {
        await File(portFilePath).delete();
      } catch (_) {}
    }
  }

  static Future<void> sendCommand(String command) async {
    if (!system.isDesktop) return;
    final socket = await _connect();
    try {
      socket.write('$command\n');
      await socket.flush();
    } on SocketException catch (e) {
      if (!_isConnectionReset(e)) rethrow;
    } finally {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  static Future<Object?> request(
    String method, [
    Object? arguments,
    Duration timeout = const Duration(seconds: 5),
  ]) async {
    final socket = await _connect();
    try {
      socket.writeln(jsonEncode({'method': method, 'arguments': arguments}));
      await socket.flush();
      final line = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(timeout);
      final response = jsonDecode(line) as Map<String, dynamic>;
      if (response['ok'] != true) {
        throw StateError(response['error']?.toString() ?? '网络面板请求失败');
      }
      return response['result'];
    } finally {
      socket.destroy();
    }
  }

  static Stream<void> get networkMonitorChanges async* {
    while (true) {
      Socket? socket;
      try {
        socket = await _connect();
        socket.writeln(jsonEncode({'method': 'networkMonitor.subscribe'}));
        await socket.flush();
        await for (final line
            in socket
                .cast<List<int>>()
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          final event = jsonDecode(line) as Map<String, dynamic>;
          if (event['event'] == 'dataChanged') yield null;
        }
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      } finally {
        socket?.destroy();
      }
    }
  }

  static void setNetworkMonitorHandler(
    Future<Object?> Function(String method, Object? arguments)? handler,
  ) {
    _networkMonitorHandler = handler;
  }

  static Future<void> notifyNetworkMonitorChanged() async {
    final message = jsonEncode({'event': 'dataChanged'});
    for (final socket in _networkMonitorSubscribers.toList()) {
      try {
        socket.writeln(message);
        await socket.flush();
      } catch (_) {
        _closeSocket(socket);
      }
    }
  }

  static Future<Socket> _connect() async {
    final socketPath = await appPath.controlSocketPath;
    if (FileSystemEntity.typeSync(socketPath) !=
        FileSystemEntityType.notFound) {
      try {
        return await Socket.connect(
          InternetAddress(socketPath, type: InternetAddressType.unix),
          0,
        ).timeout(const Duration(seconds: 1));
      } catch (_) {}
    }

    final portFilePath = await appPath.controlPortFilePath;
    if (await File(portFilePath).exists()) {
      final port = int.tryParse(
        (await File(portFilePath).readAsString()).trim(),
      );
      if (port != null) {
        return Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
        ).timeout(const Duration(seconds: 1));
      }
    }
    throw StateError('Bettbox is not running');
  }

  static bool _isConnectionReset(SocketException e) {
    final osError = e.osError;
    if (osError == null) return false;
    const resetMessages = [
      'Connection reset by peer',
      'Connection refused',
      '远程主机强迫关闭了一个现有的连接',
      'An existing connection was forcibly closed',
    ];
    return osError.errorCode == 10054 ||
        resetMessages.any((m) => osError.message.contains(m));
  }

  static void _handleCommand(String command) {
    switch (command.trim()) {
      case 'exit':
        globalState.appController.handleExit();
      case 'restart':
        Restart.restartApp();
      case 'show':
        window?.show();
      default:
        commonPrint.log('ExternalControl unknown command: $command');
    }
  }
}
