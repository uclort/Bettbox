#include "../tray_menu_host.h"

#include <cassert>
#include <cwchar>
#include <iostream>

namespace {
bool saw_menu = false;
int ticks = 0;

BOOL CALLBACK FindVisibleMenu(HWND window, LPARAM) {
  wchar_t name[32]{};
  GetClassNameW(window, name, 32);
  if (std::wcscmp(name, L"#32768") == 0 && IsWindowVisible(window)) {
    saw_menu = true;
  }
  return TRUE;
}
}  // namespace

int main() {
  tray_manager::TrayMenuHost host([](HWND window, UINT message,
                                    WPARAM, LPARAM) {
    if (message == WM_TIMER) {
      ++ticks;
      EnumThreadWindows(GetCurrentThreadId(), FindVisibleMenu, 0);
      // 真实 Win32 模态菜单，必须看见菜单窗口后才允许测试通过。
      if (saw_menu || ticks >= 20) {
        KillTimer(window, 1);
        EndMenu();
      }
    }
  });
  assert(host.window() != nullptr);
  assert(!IsWindowVisible(host.window()));
  HMENU menu = CreatePopupMenu();
  assert(menu != nullptr);
  assert(host.Show(menu, POINT{40, 40}) == 0);
  AppendMenuW(menu, MF_STRING, 1024, L"Show window");
  HMENU submenu = CreatePopupMenu();
  AppendMenuW(submenu, MF_STRING, 1025, L"System proxy");
  AppendMenuW(menu, MF_POPUP, reinterpret_cast<UINT_PTR>(submenu), L"Network");
  // 主窗口不存在/隐藏、连续多次打开、关闭后重建均需真实显示。
  for (int round = 0; round < 3; ++round) {
    saw_menu = false;
    ticks = 0;
    SetTimer(host.window(), 1, 50, nullptr);
    assert(host.Show(menu, POINT{40, 40}) == 0);
    KillTimer(host.window(), 1);
    assert(saw_menu);
    assert(!IsWindowVisible(host.window()));
    MSG message{};
    while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
      DispatchMessageW(&message);
    }
  }
  DestroyMenu(menu);
  // 鼠标点击和键盘回车均不能结束测速菜单，异步结果在同一个子菜单刷新。
  int clicks = 0;
  int stage = 0;
  bool remained_open = false;
  HMENU speed_menu = CreatePopupMenu();
  AppendMenuW(speed_menu, MF_STRING, 2048, L"Speed test");
  AppendMenuW(speed_menu, MF_STRING, 2049, L"Node\t...");
  HMENU root = CreatePopupMenu();
  AppendMenuW(root, MF_POPUP, reinterpret_cast<UINT_PTR>(speed_menu), L"Group");
  tray_manager::TrayMenuHost persistent_host(
      [&](HWND window, UINT message, WPARAM wparam, LPARAM) {
        if (message == WM_MENUSELECT) {
          std::cout << "Menu selected: " << LOWORD(wparam) << " flags: "
                    << HIWORD(wparam) << std::endl;
        }
        if (message != WM_TIMER) return;
        ++ticks;
        if (ticks > 50) {
          EndMenu();
          return;
        }
        const auto press = [window](WPARAM key) {
          PostMessageW(window, WM_KEYDOWN, key, 0);
          PostMessageW(window, WM_KEYUP, key, 0);
        };
        if (stage == 0) {
          press(VK_DOWN);
          press(VK_RIGHT);
          ++stage;
        } else if (stage == 1) {
          RECT bounds{};
          if (!GetMenuItemRect(nullptr, speed_menu, 0, &bounds)) return;
          const int x = (bounds.left + bounds.right) / 2;
          const int y = (bounds.top + bounds.bottom) / 2;
          SetCursorPos(x, y);
          PostMessageW(window, WM_MOUSEMOVE, 0, MAKELPARAM(x, y));
          PostMessageW(window, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(x, y));
          PostMessageW(window, WM_LBUTTONUP, 0, MAKELPARAM(x, y));
          ++stage;
        } else if (stage == 2 && clicks == 1) {
          press(VK_RETURN);
          ++stage;
        } else if (stage == 3 && clicks == 2) {
          saw_menu = false;
          EnumThreadWindows(GetCurrentThreadId(), FindVisibleMenu, 0);
          wchar_t label[64]{};
          GetMenuStringW(speed_menu, 2049, label, 64, MF_BYCOMMAND);
          remained_open = saw_menu && std::wcscmp(label, L"Node\t20ms") == 0;
          // 普通节点仍按原生行为关闭菜单并返回命令。
          press(VK_DOWN);
          press(VK_RETURN);
          ++stage;
        }
      });
  persistent_host.SetPersistentCommandHandler(
      [](UINT command) { return command == 2048; },
      [&](UINT command) {
        assert(command == 2048);
        ++clicks;
        MENUITEMINFOW item{};
        item.cbSize = sizeof(item);
        item.fMask = MIIM_STRING;
        wchar_t result[] = L"Node\t20ms";
        item.dwTypeData = result;
        assert(SetMenuItemInfoW(speed_menu, 2049, FALSE, &item));
        tray_manager::TrayMenuHost::RefreshVisibleMenus();
      });
  ticks = 0;
  SetTimer(persistent_host.window(), 2, 100, nullptr);
  const UINT selected = persistent_host.Show(root, POINT{400, 400});
  KillTimer(persistent_host.window(), 2);
  std::cout << "Persistent clicks: " << clicks << " stage: " << stage
            << " ticks: " << ticks << " selected: " << selected << std::endl;
  assert(clicks == 2);
  assert(remained_open);
  assert(selected == 2049);
  DestroyMenu(root);
  std::cout << "Native tray popup visible: PASS\n";
  std::cout << "Persistent speed test and live submenu results: PASS\n";
}
