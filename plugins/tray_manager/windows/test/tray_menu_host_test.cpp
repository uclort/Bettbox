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
  std::cout << "Native tray popup visible: PASS\n";
}
