#pragma once

#include <windows.h>

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

  UINT Show(HMENU menu, POINT position) {
    if (window_ == nullptr || !IsMenu(menu) || GetMenuItemCount(menu) <= 0) {
      return 0;
    }
    SetForegroundWindow(window_);
    // 返回选中 ID，避免主窗口 WM_COMMAND 与菜单关闭事件交错。
    const UINT command = TrackPopupMenuEx(
        menu, TPM_BOTTOMALIGN | TPM_LEFTALIGN | TPM_RIGHTBUTTON |
                  TPM_RETURNCMD | TPM_NONOTIFY,
        position.x, position.y, window_, nullptr);
    PostMessageW(window_, WM_NULL, 0, 0);
    return command;
  }

 private:
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
      host->handler_(window, message, wparam, lparam);
    }
    return DefWindowProcW(window, message, wparam, lparam);
  }

  MessageHandler handler_;
  HWND window_ = nullptr;
};

}  // namespace tray_manager
