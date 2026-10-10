import 'dart:async';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/about.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

// BETTBOX-CUSTOM: 使用 MaterialApp 已解析的语言，菜单随应用语言实时重建。
class MacOSMenuBar extends StatelessWidget {
  final Widget child;

  const MacOSMenuBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    void native(String action) => unawaited(app.performMacOSMenuAction(action));
    SingleActivator shortcut(LogicalKeyboardKey key, {bool shift = false}) =>
        SingleActivator(key, meta: true, shift: shift);

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Bettbox',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: '${strings.about} Bettbox',
                  onSelected: () async {
                    await window?.show();
                    final currentContext =
                        globalState.navigatorKey.currentContext;
                    if (currentContext == null || !currentContext.mounted) {
                      return;
                    }
                    await showExtend<void>(
                      currentContext,
                      builder: (_, type) => AdaptiveSheetScaffold(
                        type: type,
                        title: strings.about,
                        body: const AboutView(),
                      ),
                    );
                  },
                ),
                PlatformMenuItem(
                  label: '${strings.settings}…',
                  shortcut: shortcut(LogicalKeyboardKey.comma),
                  onSelected: () {
                    globalState.appController.toPage(PageLabel.tools);
                    unawaited(window?.show());
                  },
                ),
                PlatformMenuItem(
                  label: strings.checkUpdate,
                  onSelected: () => unawaited(
                    globalState.appController.checkForAppUpdate(manual: true),
                  ),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: strings.menuHideApp,
                  shortcut: shortcut(LogicalKeyboardKey.keyH),
                  onSelected: () => native('hide'),
                ),
                PlatformMenuItem(
                  label: strings.menuHideOthers,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyH,
                    meta: true,
                    alt: true,
                  ),
                  onSelected: () => native('hideOthers'),
                ),
                PlatformMenuItem(
                  label: strings.menuShowAll,
                  onSelected: () => native('showAll'),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: '${strings.exit} Bettbox',
                  shortcut: shortcut(LogicalKeyboardKey.keyQ),
                  onSelected: () =>
                      unawaited(globalState.appController.handleExit()),
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: strings.edit,
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: strings.undo,
                  shortcut: shortcut(LogicalKeyboardKey.keyZ),
                  onSelected: () => native('undo'),
                ),
                PlatformMenuItem(
                  label: strings.redo,
                  shortcut: shortcut(LogicalKeyboardKey.keyZ, shift: true),
                  onSelected: () => native('redo'),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: strings.cut,
                  shortcut: shortcut(LogicalKeyboardKey.keyX),
                  onSelected: () => native('cut'),
                ),
                PlatformMenuItem(
                  label: strings.copy,
                  shortcut: shortcut(LogicalKeyboardKey.keyC),
                  onSelected: () => native('copy'),
                ),
                PlatformMenuItem(
                  label: strings.paste,
                  shortcut: shortcut(LogicalKeyboardKey.keyV),
                  onSelected: () => native('paste'),
                ),
                PlatformMenuItem(
                  label: strings.selectAll,
                  shortcut: shortcut(LogicalKeyboardKey.keyA),
                  onSelected: () => native('selectAll'),
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: strings.menuView,
          menus: [
            PlatformMenuItem(
              label: strings.menuFullScreen,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyF,
                meta: true,
                control: true,
              ),
              onSelected: () => native('fullScreen'),
            ),
          ],
        ),
        PlatformMenu(
          label: strings.menuWindow,
          menus: [
            PlatformMenuItem(
              label: strings.show,
              onSelected: () => unawaited(window?.show()),
            ),
            PlatformMenuItem(
              label: strings.close,
              shortcut: shortcut(LogicalKeyboardKey.keyW),
              onSelected: () => unawaited(window?.hide()),
            ),
            PlatformMenuItem(
              label: strings.minimize,
              shortcut: shortcut(LogicalKeyboardKey.keyM),
              onSelected: () => unawaited(windowManager.minimize()),
            ),
            PlatformMenuItem(
              label: strings.menuZoom,
              onSelected: () => native('zoom'),
            ),
            PlatformMenuItem(
              label: strings.menuBringAllToFront,
              onSelected: () => native('bringAllToFront'),
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
