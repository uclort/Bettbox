#include "flutter_window.h"

#include <optional>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shobjidl.h>  // For ITaskbarList3
#include <shlobj.h>    // For Shell link API

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

#ifdef BETTBOX_DEV
#define BETTBOX_REG_KEY L"Software\\BettboxDev"
#else
#define BETTBOX_REG_KEY L"Software\\Bettbox"
#endif

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  
  // Register app method channel
  SetupAppMethodChannel();
  
  // Load and apply saved icon preference
  bool use_dark_icon = LoadIconPreference();
  SetWindowIcon(use_dark_icon);
  
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {

  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SetupAppMethodChannel() {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "app",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "setLauncherIcon") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto use_dark_icon_it = arguments->find(flutter::EncodableValue("useDarkIcon"));
            if (use_dark_icon_it != arguments->end()) {
              bool use_dark_icon = std::get<bool>(use_dark_icon_it->second);
              bool success = SetWindowIcon(use_dark_icon);
              result->Success(flutter::EncodableValue(success));
              return;
            }
          }
          result->Error("INVALID_ARGUMENT", "Missing useDarkIcon argument");
        } else {
          result->NotImplemented();
        }
      });
}

bool FlutterWindow::SetWindowIcon(bool use_dark_icon) {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return false;
  }

  std::wstring icon_name = use_dark_icon ? L"icon_light.ico" : L"icon.ico";
  wchar_t exe_path_buf[MAX_PATH] = {0};
  DWORD exe_path_len = GetModuleFileNameW(NULL, exe_path_buf, MAX_PATH);
  std::wstring exe_path = exe_path_len > 0 ? std::wstring(exe_path_buf) : L"";
  std::wstring base_dir = L".";
  size_t last_slash = exe_path.find_last_of(L"\\/");
  if (!exe_path.empty() && last_slash != std::wstring::npos) {
    base_dir = exe_path.substr(0, last_slash);
  }
  std::wstring icon_path =
      base_dir + L"\\data\\flutter_assets\\assets\\images\\" + icon_name;

  // Load icon file
  HICON hIcon = (HICON)LoadImageW(
      NULL,
      icon_path.c_str(),
      IMAGE_ICON,
      0,
      0,
      LR_LOADFROMFILE | LR_DEFAULTSIZE | LR_SHARED
  );

  if (!hIcon) {
    // Fallback to app resource if load fails
    hIcon = LoadIcon(GetModuleHandle(NULL), MAKEINTRESOURCE(IDI_APP_ICON));
    if (!hIcon) {
      return false;
    }
  }

  // Set window icon (title bar)
  SendMessage(hwnd, WM_SETICON, ICON_SMALL, (LPARAM)hIcon);
  SendMessage(hwnd, WM_SETICON, ICON_BIG, (LPARAM)hIcon);
  SetClassLongPtr(hwnd, GCLP_HICON, (LONG_PTR)hIcon);
  SetClassLongPtr(hwnd, GCLP_HICONSM, (LONG_PTR)hIcon);

  // Update taskbar icon
  // Method: Refresh via ITaskbarList3 interface
  ITaskbarList3* pTaskbarList = nullptr;
  HRESULT hr = CoCreateInstance(
      CLSID_TaskbarList,
      NULL,
      CLSCTX_INPROC_SERVER,
      IID_ITaskbarList3,
      (void**)&pTaskbarList
  );

  if (SUCCEEDED(hr) && pTaskbarList) {
    pTaskbarList->HrInit();
    
    // Refresh taskbar button to update icon
    pTaskbarList->AddTab(hwnd);
    pTaskbarList->DeleteTab(hwnd);
    pTaskbarList->AddTab(hwnd);
    
    pTaskbarList->Release();
  }

  RedrawWindow(hwnd, NULL, NULL,
               RDW_INVALIDATE | RDW_FRAME | RDW_UPDATENOW | RDW_ALLCHILDREN);

  // Update desktop & start menu shortcuts
  UpdateShortcutsIcon(use_dark_icon);

  // Save preference to registry
  SaveIconPreference(use_dark_icon);

  return true;
}

void FlutterWindow::UpdateShortcutsIcon(bool use_dark_icon) {
  wchar_t exe_path_buf[MAX_PATH] = {0};
  DWORD exe_path_len = GetModuleFileNameW(NULL, exe_path_buf, MAX_PATH);
  std::wstring exe_path = exe_path_len > 0 ? std::wstring(exe_path_buf) : L"";
  if (exe_path.empty()) return;

  std::wstring base_dir = L".";
  size_t last_slash = exe_path.find_last_of(L"\\/");
  if (last_slash != std::wstring::npos) {
    base_dir = exe_path.substr(0, last_slash);
  }

  std::wstring icon_name = use_dark_icon ? L"icon_light.ico" : L"icon.ico";
  std::wstring icon_path = base_dir + L"\\data\\flutter_assets\\assets\\images\\" + icon_name;

  int csidl_locations[] = {
      CSIDL_DESKTOPDIRECTORY,
      CSIDL_COMMON_DESKTOPDIRECTORY,
      CSIDL_PROGRAMS,
      CSIDL_COMMON_PROGRAMS
  };

  // COM is already initialized in main.cpp via CoInitializeEx; no need to re-init here.
  IShellLinkW* pShellLink = NULL;
  HRESULT hr = CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (void**)&pShellLink);
  if (FAILED(hr) || !pShellLink) {
    return;
  }

  IPersistFile* pPersistFile = NULL;
  hr = pShellLink->QueryInterface(IID_IPersistFile, (void**)&pPersistFile);
  if (FAILED(hr) || !pPersistFile) {
    pShellLink->Release();
    return;
  }

  bool updated_any = false;
  for (int csidl : csidl_locations) {
    wchar_t dir_path[MAX_PATH] = {0};
    if (SUCCEEDED(SHGetFolderPathW(NULL, csidl, NULL, 0, dir_path))) {
      WIN32_FIND_DATAW find_data;
      std::wstring search_pattern = std::wstring(dir_path) + L"\\*.lnk";
      HANDLE hFind = FindFirstFileW(search_pattern.c_str(), &find_data);
      if (hFind != INVALID_HANDLE_VALUE) {
        do {
          std::wstring lnk_path = std::wstring(dir_path) + L"\\" + find_data.cFileName;
          if (SUCCEEDED(pPersistFile->Load(lnk_path.c_str(), STGM_READWRITE))) {
            wchar_t target_path[MAX_PATH] = {0};
            if (SUCCEEDED(pShellLink->GetPath(target_path, MAX_PATH, NULL, 0))) {
              if (_wcsicmp(target_path, exe_path.c_str()) == 0) {
                pShellLink->SetIconLocation(icon_path.c_str(), 0);
                if (SUCCEEDED(pPersistFile->Save(lnk_path.c_str(), TRUE))) {
                  updated_any = true;
                }
              }
            }
          }
        } while (FindNextFileW(hFind, &find_data));
        FindClose(hFind);
      }
    }
  }

  pPersistFile->Release();
  pShellLink->Release();

  if (updated_any) {
    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, NULL, NULL);
  }
}

void FlutterWindow::SaveIconPreference(bool use_dark_icon) {
  HKEY hKey;
  LONG result = RegCreateKeyExW(
      HKEY_CURRENT_USER,
      BETTBOX_REG_KEY,
      0,
      NULL,
      REG_OPTION_NON_VOLATILE,
      KEY_WRITE,
      NULL,
      &hKey,
      NULL
  );

  if (result == ERROR_SUCCESS) {
    DWORD value = use_dark_icon ? 1 : 0;
    RegSetValueExW(hKey, L"UseDarkIcon", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
    RegCloseKey(hKey);
  }
}

bool FlutterWindow::LoadIconPreference() {
  HKEY hKey;
  LONG result = RegOpenKeyExW(
      HKEY_CURRENT_USER,
      BETTBOX_REG_KEY,
      0,
      KEY_READ,
      &hKey
  );

  if (result == ERROR_SUCCESS) {
    DWORD value = 0;
    DWORD size = sizeof(DWORD);
    result = RegQueryValueExW(hKey, L"UseDarkIcon", NULL, NULL, (BYTE*)&value, &size);
    RegCloseKey(hKey);
    
    if (result == ERROR_SUCCESS) {
      return value != 0;
    }
  }

  return false;
}
