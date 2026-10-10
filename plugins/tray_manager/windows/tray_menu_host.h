#pragma once

#include <windows.h>

#include <cwchar>
#include <functional>
#include <utility>

namespace tray_manager {

// BETTBOX-CUSTOM: 独立托盘窗口不受 Flutter 主窗口隐藏、焦点转移影响。
class TrayMenuHost {
 public:
  using MessageHandler = std::function<void(HWND, UINT, WPARAM, LPARAM)>;

  explicit TrayMenuHost(MessageHandler handler) : handler_(std::move(handler)) {
    WNDCLASSW window_class{};
    window_class.lpfnWndProc = WindowProc;
    window_class.hInstance = GetModuleHandleW(nullptr);
    window_class.lpszClassName = L"BettboxTrayMenuHost";
    RegisterClassW(&window_class);
    window_ = CreateWindowExW(
        WS_EX_TOOLWINDOW, window_class.lpszClassName, L"", WS_POPUP,
        0, 0, 0, 0, nullptr, nullptr, window_class.hInstance, this);
  }

  ~TrayMenuHost() {
    handler_ = nullptr;
    if (window_ != nullptr) DestroyWindow(window_);
  }

  TrayMenuHost(const TrayMenuHost&) = delete;
  TrayMenuHost& operator=(const TrayMenuHost&) = delete;

  HWND window() const { return window_; }

  void SetPersistentCommandHandler(std::function<bool(UINT)> is_persistent,
                                   std::function<void(UINT)> on_click) {
    is_persistent_ = std::move(is_persistent);
    on_persistent_click_ = std::move(on_click);
  }

  static void RefreshVisibleMenus() {
    EnumThreadWindows(GetCurrentThreadId(), [](HWND window, LPARAM) -> BOOL {
      wchar_t name[32]{};
      GetClassNameW(window, name, 32);
      if (std::wcscmp(name, L"#32768") == 0 && IsWindowVisible(window)) {
        RedrawWindow(window, nullptr, nullptr,
                     RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN);
      }
      return TRUE;
    }, 0);
  }

  UINT Show(HMENU menu, POINT position) {
    if (window_ == nullptr || !IsMenu(menu) || GetMenuItemCount(menu) <= 0) {
      return 0;
    }
    SetForegroundWindow(window_);
    selected_menu_ = nullptr;
    selected_command_ = 0;
    active_host_ = this;
    const HHOOK filter = SetWindowsHookExW(
        WH_MSGFILTER, MenuMessageFilter, nullptr, GetCurrentThreadId());
    // 返回选中 ID，避免主窗口 WM_COMMAND 与菜单关闭事件交错。
    const UINT command = TrackPopupMenuEx(
        menu, TPM_BOTTOMALIGN | TPM_LEFTALIGN | TPM_RIGHTBUTTON |
                  TPM_RETURNCMD | TPM_NONOTIFY,
        position.x, position.y, window_, nullptr);
    if (filter != nullptr) UnhookWindowsHookEx(filter);
    active_host_ = nullptr;
    PostMessageW(window_, WM_NULL, 0, 0);
    return command;
  }

 private:
  // BETTBOX-CUSTOM: 只截获测速项，不结束系统菜单跟踪，不关闭后重弹。
  static LRESULT CALLBACK MenuMessageFilter(int code, WPARAM wparam,
                                            LPARAM lparam) {
    auto* host = active_host_;
    if (code == MSGF_MENU && host != nullptr && host->selected_command_ != 0 &&
        host->is_persistent_ &&
        host->is_persistent_(host->selected_command_)) {
      const auto* message = reinterpret_cast<MSG*>(lparam);
      const UINT state = GetMenuState(host->selected_menu_,
                                      host->selected_command_, MF_BYCOMMAND);
      if (state != UINT(-1) && !(state & (MF_DISABLED | MF_GRAYED))) {
        const bool key = message->message == WM_KEYDOWN &&
                         (message->wParam == VK_RETURN ||
                          message->wParam == VK_SPACE);
        RECT bounds{};
        const bool inside = GetMenuItemRect(nullptr, host->selected_menu_,
                                            host->selected_position_, &bounds) &&
                            PtInRect(&bounds, message->pt);
        const bool mouse = inside &&
            (message->message == WM_LBUTTONDOWN ||
             message->message == WM_LBUTTONUP ||
             message->message == WM_LBUTTONDBLCLK);
        if (key || mouse) {
          if ((key && !(message->lParam & (1LL << 30))) ||
              message->message == WM_LBUTTONUP) {
            if (host->on_persistent_click_) {
              host->on_persistent_click_(host->selected_command_);
            }
          }
          return 1;
        }
      }
    }
    return CallNextHookEx(nullptr, code, wparam, lparam);
  }

  static LRESULT CALLBACK WindowProc(HWND window, UINT message,
                                     WPARAM wparam, LPARAM lparam) {
    auto* host = reinterpret_cast<TrayMenuHost*>(
        GetWindowLongPtrW(window, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
      host = static_cast<TrayMenuHost*>(
          reinterpret_cast<CREATESTRUCTW*>(lparam)->lpCreateParams);
      SetWindowLongPtrW(window, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(host));
    }
    if (host != nullptr && host->handler_) {
      if (message == WM_MENUSELECT) {
        host->selected_menu_ = reinterpret_cast<HMENU>(lparam);
        host->selected_command_ = 0;
        if (host->selected_menu_ != nullptr && !(HIWORD(wparam) & MF_POPUP)) {
          host->selected_command_ = LOWORD(wparam);
          for (int i = 0; i < GetMenuItemCount(host->selected_menu_); ++i) {
            if (GetMenuItemID(host->selected_menu_, i) == host->selected_command_) {
              host->selected_position_ = static_cast<UINT>(i);
              break;
            }
          }
        }
      }
      host->handler_(window, message, wparam, lparam);
    }
    return DefWindowProcW(window, message, wparam, lparam);
  }

  MessageHandler handler_;
  HWND window_ = nullptr;
  HMENU selected_menu_ = nullptr;
  UINT selected_command_ = 0;
  UINT selected_position_ = 0;
  std::function<bool(UINT)> is_persistent_;
  std::function<void(UINT)> on_persistent_click_;
  inline static thread_local TrayMenuHost* active_host_ = nullptr;
};

}  // namespace tray_manager
