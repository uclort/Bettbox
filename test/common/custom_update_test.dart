import 'package:bett_box/common/request.dart';
import 'package:bett_box/models/models.dart';
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

  test('默认开启自动更新，旧配置缺字段时同样如此；旧版的预览版设置被忽略', () {
    const props = AppSettingProps();
    expect(props.autoCheckUpdate, isTrue);
    final legacy = AppSettingProps.fromJson(const {'receivePreRelease': true});
    expect(legacy.autoCheckUpdate, isTrue);
    expect(legacy.toJson().containsKey('receivePreRelease'), isFalse);
  });

  group('GitHub 回退', () {
    final releases = [
      {
        'tag_name': 'custom-v1.19.8+2090000300',
        'prerelease': true,
        'published_at': '2026-11-07T00:00:00Z',
      },
      {
        'tag_name': 'custom-v1.19.8+2090000301',
        'draft': true,
        'published_at': '2026-11-08T00:00:00Z',
      },
      {
        'tag_name': 'custom-v1.19.7+2090000290',
        'prerelease': false,
        'published_at': '2026-11-01T00:00:00Z',
      },
    ];

    test('取最新的正式 Release，跳过历史预览版与草稿', () {
      expect(
        latestCustomRelease(releases)?['tag_name'],
        'custom-v1.19.7+2090000290',
      );
      expect(latestCustomRelease(const []), isNull);
    });
  });
}
