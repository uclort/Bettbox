import 'package:bett_box/clash/core.dart';
import 'package:bett_box/clash/interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _StreamInterface implements ClashHandlerInterface {
  final calls = <String>[];

  @override
  void startTrackRequests() => calls.add('requests.start');

  @override
  void stopTrackRequests() => calls.add('requests.stop');

  @override
  void startLog() => calls.add('logs.start');

  @override
  void stopLog() => calls.add('logs.stop');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('只打开网络面板也开启请求与日志推送', () {
    final handler = _StreamInterface();
    final core = ClashCore.test(handler);
    final panel = Object();

    core.startTrackRequests(panel);
    core.startLog(panel);

    expect(handler.calls, ['requests.start', 'logs.start']);
  });

  test('请求页和日志页隐藏或销毁时不能关闭面板订阅', () {
    final handler = _StreamInterface();
    final core = ClashCore.test(handler);
    final panel = Object();
    core.startTrackRequests(panel);
    core.startLog(panel);
    core.startTrackRequests();
    core.startLog();
    handler.calls.clear();

    core.stopTrackRequests();
    core.stopLog();
    expect(handler.calls, isEmpty);

    core.stopTrackRequests(panel);
    core.stopLog(panel);
    expect(handler.calls, ['requests.stop', 'logs.stop']);
  });

  test('面板关闭不影响仍在使用的页面，同一订阅者重复开启不累计', () {
    final handler = _StreamInterface();
    final core = ClashCore.test(handler);
    final panel = Object();
    core.startTrackRequests();
    core.startLog();
    core.startTrackRequests(panel);
    core.startTrackRequests(panel);
    core.startLog(panel);
    core.startLog(panel);
    handler.calls.clear();

    core.stopTrackRequests(panel);
    core.stopLog(panel);
    expect(handler.calls, isEmpty);

    core.stopTrackRequests();
    core.stopLog();
    expect(handler.calls, ['requests.stop', 'logs.stop']);
  });
}
