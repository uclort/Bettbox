import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/cupertino.dart';

class Request {
  late final Dio _dio;
  late final Dio _clashDio;
  String? userAgent;

  Request() {
    _dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.autoUncompress = false;
        return client;
      },
    );
    _clashDio = Dio();
    _clashDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.autoUncompress = false;
        client.findProxy = (Uri uri) {
          client.userAgent = globalState.ua;
          return BettboxHttpOverrides.handleFindProxy(uri);
        };
        return client;
      },
    );
  }

  Uint8List _decompressIfNeeded(Uint8List bytes, Headers headers) {
    final encodings =
        headers['content-encoding']?.map((e) => e.toLowerCase()).toList() ?? [];
    final encodingStr = encodings.join(', ');
    final wantGzip = encodingStr.contains('gzip');
    final wantDeflate = encodingStr.contains('deflate');

    var current = bytes;
    for (var i = 0; i < 4; i++) {
      final isGzipMagic =
          current.length >= 2 && current[0] == 0x1f && current[1] == 0x8b;
      if (wantGzip || isGzipMagic) {
        try {
          current = Uint8List.fromList(gzip.decode(current));
          continue;
        } catch (_) {
          break;
        }
      }
      if (wantDeflate) {
        try {
          current = Uint8List.fromList(zlib.decode(current));
          continue;
        } catch (_) {
          break;
        }
      }
      break;
    }
    return current;
  }

  Uint8List _bytesFromResponse(Response response) {
    final data = response.data;
    if (data is Uint8List) return data;
    return Uint8List.fromList((data as List).cast<int>());
  }

  Future<Response> _getResponseForUrl(
    String url,
    ResponseType responseType,
  ) async {
    String? userInfo;
    String requestUrl = url;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      final schemeEnd = url.indexOf('://') + 3;
      final slashIndex = url.indexOf('/', schemeEnd);
      final questionIndex = url.indexOf('?', schemeEnd);
      final hashIndex = url.indexOf('#', schemeEnd);
      var authorityEnd = url.length;
      if (slashIndex != -1) authorityEnd = slashIndex;
      if (questionIndex != -1 && questionIndex < authorityEnd) {
        authorityEnd = questionIndex;
      }
      if (hashIndex != -1 && hashIndex < authorityEnd) {
        authorityEnd = hashIndex;
      }
      final atIndex = url.lastIndexOf('@', authorityEnd - 1);
      if (atIndex >= schemeEnd) {
        userInfo = url.substring(schemeEnd, atIndex);
        requestUrl = url.substring(0, schemeEnd) + url.substring(atIndex + 1);
      }
    }

    final headers = <String, dynamic>{'Connection': 'close'};
    if (userInfo != null && userInfo.isNotEmpty) {
      final auth = base64Encode(utf8.encode(userInfo));
      headers['Authorization'] = 'Basic $auth';
    }

    final response = await _clashDio.get(
      requestUrl,
      options: Options(responseType: ResponseType.bytes, headers: headers),
    );

    final rawBytes = _bytesFromResponse(response);
    final decompressedBytes = _decompressIfNeeded(rawBytes, response.headers);

    if (responseType == ResponseType.plain) {
      final text = utf8.decode(decompressedBytes, allowMalformed: true);
      return Response(
        requestOptions: response.requestOptions,
        data: text,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        isRedirect: response.isRedirect,
        redirects: response.redirects,
        extra: response.extra,
        headers: response.headers,
      );
    } else {
      return Response(
        requestOptions: response.requestOptions,
        data: decompressedBytes,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        isRedirect: response.isRedirect,
        redirects: response.redirects,
        extra: response.extra,
        headers: response.headers,
      );
    }
  }

  Future<Response> getFileResponseForUrl(String url) async {
    return _getResponseForUrl(url, ResponseType.bytes);
  }

  Future<Response> getTextResponseForUrl(String url) async {
    return _getResponseForUrl(url, ResponseType.plain);
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await _dio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) return null;
    final bytes = _decompressIfNeeded(data, response.headers);
    return MemoryImage(bytes);
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    if (isCustomUpdateBuild) {
      return _checkForCustomUpdate();
    }

    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final response = await _dio.get(
        'https://github.com/$repository/releases/latest?t=$t',
        options: Options(
          followRedirects: false,
          validateStatus: (status) =>
              status != null && status >= 300 && status < 400,
        ),
      );
      final location = response.headers['location']?.firstOrNull;
      if (location != null && location.contains('/releases/tag/')) {
        final remoteVersion = location.split('/').last.trim();
        if (remoteVersion.isNotEmpty) {
          final version = globalState.packageInfo.version;
          final hasUpdate =
              utils.compareVersions(
                remoteVersion.replaceAll('v', ''),
                version,
              ) >
              0;
          if (!hasUpdate) return null;
          return {
            'tag_name': remoteVersion,
            'html_url': 'https://github.com/$repository/releases/latest',
            'body': 'New version available. Please visit GitHub to download.',
          };
        }
      }
    } catch (e) {
      commonPrint.log('Check update failed: ${e.formatError}');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _checkForCustomUpdate() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        'https://api.github.com/repos/$customUpdateRepository/releases',
        queryParameters: {
          'per_page': 30,
          't': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        ),
      );
      final releases =
          (response.data ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .where((release) => release['draft'] != true)
              .toList()
            ..sort((a, b) {
              final aPublished =
                  DateTime.tryParse(a['published_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final bPublished =
                  DateTime.tryParse(b['published_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return bPublished.compareTo(aPublished);
            });

      if (releases.isEmpty) return null;
      final latest = releases.first;
      final latestTag = latest['tag_name']?.toString().trim() ?? '';
      if (latestTag.isEmpty || latestTag == currentCustomReleaseTag) {
        return null;
      }
      final buildIdPattern = RegExp(r'-r(\d{14})-');
      final latestBuildId = int.tryParse(
        buildIdPattern.firstMatch(latestTag)?.group(1) ?? '',
      );
      final currentBuildId = int.tryParse(
        buildIdPattern.firstMatch(currentCustomReleaseTag)?.group(1) ?? '',
      );
      if (latestBuildId != null &&
          currentBuildId != null &&
          latestBuildId <= currentBuildId) {
        return null;
      }
      return latest;
    } catch (e) {
      commonPrint.log('Check custom update failed: ${e.formatError}');
      return null;
    }
  }

  final List<String> _ipInfoSources = [
    'https://ip.sb/cdn-cgi/trace',
    'https://api.ip.sb/cdn-cgi/trace',
  ];

  final List<String> _domesticIpSources = [
    'https://www.qualcomm.cn/cdn-cgi/trace',
    'https://www.teamviewer.cn/cdn-cgi/trace',
  ];

  Future<Result<IpInfo?>> _checkIpFromSources(
    List<String> sources,
    CancelToken? cancelToken,
    Duration? timeout,
  ) async {
    final effectiveTimeout = timeout ?? const Duration(seconds: 5);

    final dio = Dio(
      BaseOptions(
        receiveTimeout: effectiveTimeout,
        connectTimeout: effectiveTimeout,
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.autoUncompress = false;
        return client;
      },
    );

    final Completer<Result<IpInfo?>> resultCompleter = Completer();
    int failureCount = 0;

    void handleFailure() {
      if (resultCompleter.isCompleted) return;
      failureCount++;
      if (failureCount == sources.length) {
        resultCompleter.complete(Result.success(null));
      }
    }

    for (final url in sources) {
      dio
          .get<Uint8List>(
            url,
            cancelToken: cancelToken,
            options: Options(responseType: ResponseType.bytes),
          )
          .then((res) {
            if (resultCompleter.isCompleted) return;
            if (res.statusCode == HttpStatus.ok && res.data != null) {
              try {
                final text = utf8.decode(
                  _decompressIfNeeded(_bytesFromResponse(res), res.headers),
                  allowMalformed: true,
                );
                resultCompleter.complete(
                  Result.success(IpInfo.fromCloudflareTrace(text)),
                );
              } catch (_) {
                handleFailure();
              }
            } else {
              handleFailure();
            }
          })
          .catchError((e) {
            if (resultCompleter.isCompleted) return;
            if (e is DioException && e.type == DioExceptionType.cancel) {
              resultCompleter.complete(Result.error('cancelled'));
              return;
            }
            handleFailure();
          });
    }

    try {
      return await resultCompleter.future.timeout(
        effectiveTimeout,
        onTimeout: () => Result.success(null),
      );
    } finally {
      dio.close(force: true);
    }
  }

  Future<Result<IpInfo?>> checkIp({
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    return _checkIpFromSources(_ipInfoSources, cancelToken, timeout);
  }

  Future<Result<IpInfo?>> checkIpDomestic({
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    return _checkIpFromSources(_domesticIpSources, cancelToken, timeout);
  }
}

final request = Request();
