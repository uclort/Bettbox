import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/clash_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS 使用 mixed 替代会导致微信图片卡住的 system TUN 栈', () {
    expect(
      const Tun(stack: TunStack.system).getRealTun(false).stack,
      system.isMacOS ? TunStack.mixed : TunStack.system,
    );
    expect(
      const Tun(stack: TunStack.gvisor).getRealTun(false).stack,
      TunStack.gvisor,
    );
  });
}
