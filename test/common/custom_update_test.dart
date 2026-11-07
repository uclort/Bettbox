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

  test('默认开启自动更新、关闭预览版，旧配置缺字段时同样如此', () {
    const props = AppSettingProps();
    expect(props.autoCheckUpdate, isTrue);
    expect(props.receivePreRelease, isFalse);
    final legacy = AppSettingProps.fromJson(const {});
    expect(legacy.autoCheckUpdate, isTrue);
    expect(legacy.receivePreRelease, isFalse);
  });

  group('更新通道', () {
    const base =
        'https://raw.githubusercontent.com/uclort/Bettbox/custom-update-feed';

    test('未开启预览版时保持正式版更新源', () {
      expect(
        customUpdateFeedUrlFor(
          '$base/appcast-macos-arm64.xml',
          receivePreRelease: false,
        ),
        '$base/appcast-macos-arm64.xml',
      );
      expect(customUpdateFeedUrlFor('', receivePreRelease: true), '');
    });

    test('开启预览版时在扩展名前追加 -pre', () {
      expect(
        customUpdateFeedUrlFor(
          '$base/appcast-windows-amd64.xml',
          receivePreRelease: true,
        ),
        '$base/appcast-windows-amd64-pre.xml',
      );
      expect(
        customUpdateFeedUrlFor(
          '$base/android-update-arm64.json?t=1',
          receivePreRelease: true,
        ),
        '$base/android-update-arm64-pre.json?t=1',
      );
      expect(
        customUpdateFeedUrlFor('https://a.b/feed', receivePreRelease: true),
        'https://a.b/feed-pre',
      );
    });

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

    test('GitHub 回退默认跳过预览版与草稿', () {
      expect(
        latestCustomRelease(releases, receivePreRelease: false)?['tag_name'],
        'custom-v1.19.7+2090000290',
      );
    });

    test('开启预览版后取最新的非草稿 Release', () {
      expect(
        latestCustomRelease(releases, receivePreRelease: true)?['tag_name'],
        'custom-v1.19.8+2090000300',
      );
      expect(latestCustomRelease(const [], receivePreRelease: true), isNull);
    });
  });
}
