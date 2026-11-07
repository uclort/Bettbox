import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/views/about.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeAppSetting extends AppSetting {
  @override
  AppSettingProps build() => const AppSettingProps();
}

class _FakeViewSize extends ViewSize {
  @override
  Size build() => const Size(800, 600);
}

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  testWidgets('更新设置默认开启自动更新、关闭预览版，切换写回设置', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appSettingProvider.overrideWith(_FakeAppSetting.new),
        viewSizeProvider.overrideWith(_FakeViewSize.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Material(child: UpdateSettingsDialog())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('自动更新'), findsOneWidget);
    expect(find.text('接收预览版'), findsOneWidget);
    SwitchListTile tile(String key) =>
        tester.widget<SwitchListTile>(find.byKey(ValueKey(key)));
    expect(tile('update-settings-auto-update').value, isTrue);
    expect(tile('update-settings-pre-release').value, isFalse);

    await tester.tap(find.byKey(const ValueKey('update-settings-pre-release')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('update-settings-auto-update')));
    await tester.pumpAndSettle();

    final setting = container.read(appSettingProvider);
    expect(setting.receivePreRelease, isTrue);
    expect(setting.autoCheckUpdate, isFalse);
    expect(tile('update-settings-pre-release').value, isTrue);
    expect(tile('update-settings-auto-update').value, isFalse);
  });
}
