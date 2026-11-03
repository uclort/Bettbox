import 'package:bett_box/common/request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('自定义 Release 版本号解析出构建号', () {
    expect(customBuildNumberFrom('1.19.7+2090000225'), 2090000225);
    expect(customBuildNumberFrom('custom-v1.19.7+2090000225'), 2090000225);
  });

  test('兼容带构建时间与源码后缀的旧 tag', () {
    expect(
      customBuildNumberFrom(
        'custom-v1.19.7+2090000225-r20261103030645-003230dbf86b-641aedd217de',
      ),
      2090000225,
    );
  });

  test('没有构建号时返回 null', () {
    expect(customBuildNumberFrom(null), isNull);
    expect(customBuildNumberFrom(''), isNull);
    expect(customBuildNumberFrom('v1.19.7'), isNull);
  });
}
