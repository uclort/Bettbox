#include "include/tray_manager/tray_manager_plugin.h"

// This must be included before many other Windows headers.
#include <stdio.h>
#include <windows.h>

#include <shellapi.h>
#include <gdiplus.h>
#include <objidl.h>
#include <strsafe.h>
#include <uxtheme.h>
#include <vsstyle.h>
#include <vssym32.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <codecvt>
#include <map>
#include <memory>
#include <sstream>

#include "tray_integer.h"
#include "tray_menu_host.h"

#pragma comment(lib, "gdiplus.lib")

#define WM_MYMESSAGE (WM_USER + 1)

// Windows 11 Dark Mode APIs
using SetPreferredAppModeFunc = int (WINAPI*)(int mode);
using AllowDarkModeForWindowFunc = BOOL (WINAPI*)(HWND hwnd, BOOL allow);
using FlushMenuThemesFunc = void (WINAPI*)();

enum PreferredAppMode {
  DefaultAppMode = 0,
  AllowDarkAppMode = 1,
  ForceDarkAppMode = 2,
  ForceLightAppMode = 3,
};

static SetPreferredAppModeFunc g_setPreferredAppMode = nullptr;
static AllowDarkModeForWindowFunc g_allowDarkModeForWindow = nullptr;
static FlushMenuThemesFunc g_flushMenuThemes = nullptr;
static bool g_darkModeApisInitialized = false;

static void InitializeDarkModeApis() {
  if (g_darkModeApisInitialized) return;
  
  HMODULE hUxtheme = LoadLibrary(L"uxtheme.dll");
  if (hUxtheme) {
    g_setPreferredAppMode = (SetPreferredAppModeFunc)GetProcAddress(hUxtheme, MAKEINTRESOURCEA(135));
    g_allowDarkModeForWindow = (AllowDarkModeForWindowFunc)GetProcAddress(hUxtheme, MAKEINTRESOURCEA(133));
    g_flushMenuThemes = (FlushMenuThemesFunc)GetProcAddress(hUxtheme, MAKEINTRESOURCEA(136));
  }
  g_darkModeApisInitialized = true;
}

static bool g_darkModeLastIsDark = false;

static std::wstring NormalizeSpeedNumber(uint64_t value) {
  static const uint64_t kScales[] = {
      1,
      1024ULL,
      1024ULL * 1024ULL,
      1024ULL * 1024ULL * 1024ULL,
      1024ULL * 1024ULL * 1024ULL * 1024ULL,
  };
  static const wchar_t* kUnits[] = {L"B/s", L"K/s", L"M/s", L"G/s", L"T/s"};
  static_assert(sizeof(kScales) / sizeof(kScales[0]) ==
                sizeof(kUnits) / sizeof(kUnits[0]));

  size_t unit = 0;
  for (size_t i = 1; i < sizeof(kScales) / sizeof(kScales[0]); ++i) {
    if (value >= kScales[i]) unit = i;
  }
  if (unit == 0) {
    return std::to_wstring(value) + L" " + kUnits[0];
  }

  const double scaled = static_cast<double>(value) / kScales[unit];
  wchar_t number[16] = {};
  StringCchPrintfW(number, _countof(number), L"%.1f", scaled);
  return std::wstring(number) + L" " + kUnits[unit];
}

static void ApplyDarkModeToMenu(HWND hwnd, bool isDark) {
  InitializeDarkModeApis();

  if (isDark == g_darkModeLastIsDark && g_darkModeApisInitialized) return;
  g_darkModeLastIsDark = isDark;

  if (g_setPreferredAppMode) {
    g_setPreferredAppMode(isDark ? AllowDarkAppMode : DefaultAppMode);
  }

  if (g_allowDarkModeForWindow && hwnd) {
    g_allowDarkModeForWindow(hwnd, isDark ? TRUE : FALSE);
  }

  if (g_flushMenuThemes) {
    g_flushMenuThemes();
  }
}


namespace {

const flutter::EncodableValue* ValueOrNull(const flutter::EncodableMap& map,
                                           const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return &(it->second);
}
std::unique_ptr<
    flutter::MethodChannel<flutter::EncodableValue>,
    std::default_delete<flutter::MethodChannel<flutter::EncodableValue>>>
    channel = nullptr;

class TrayManagerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  TrayManagerPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~TrayManagerPlugin();

 private:
  std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> g_converter;

  flutter::PluginRegistrarWindows* registrar;
  NOTIFYICONDATA nid{};
  NOTIFYICONIDENTIFIER niif{};
  // do create pop-up menu only once.
  HMENU hMenu = CreatePopupMenu();
  bool tray_icon_setted = false;
  UINT windows_taskbar_created_message_id = 0;

  bool is_menu_open_ = false;
  std::string tray_icon_path_;
  std::wstring base_tooltip_;
  std::wstring speed_title_;
  bool tray_icon_active_ = true;
  bool tray_icon_dark_ = false;
  bool left_click_shows_menu_ = false;
  bool right_click_shows_menu_ = true;
  std::unique_ptr<tray_manager::TrayMenuHost> menu_host_;
  std::optional<flutter::EncodableMap> pending_menu_;

  // The ID of the WindowProc delegate registration.
  int window_proc_id = -1;

  void TrayManagerPlugin::_CreateMenu(HMENU menu, flutter::EncodableMap args);
  void TrayManagerPlugin::_UpdateMenuLabels(HMENU menu, flutter::EncodableMap args);
  void TrayManagerPlugin::_ApplyIcon();
  void TrayManagerPlugin::_UpdateToolTip();

  // Called for top-level WindowProc delegation.
  std::optional<LRESULT> TrayManagerPlugin::HandleWindowProc(HWND hwnd,
                                                             UINT message,
                                                             WPARAM wparam,
                                                             LPARAM lparam);
  void TrayManagerPlugin::ApplyTemplateIcon(bool active, bool isDark);
  void TrayManagerPlugin::Destroy(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::SetIcon(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::SetToolTip(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::SetActive(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::SetSpeedTitle(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::ClearSpeedTitle(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::SetContextMenu(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::SetNativeMenuClickBehavior(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::PopUpContextMenu(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  bool TrayManagerPlugin::ShowContextMenu();
  void TrayManagerPlugin::GetBounds(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

static bool plugin_already_registered = false;

// static
void TrayManagerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  if (plugin_already_registered) {
    // Skip registration in subwindow
    return;
  }
  
  plugin_already_registered = true;
  
  channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "tray_manager",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<TrayManagerPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

TrayManagerPlugin::TrayManagerPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar(registrar) {
  menu_host_ = std::make_unique<tray_manager::TrayMenuHost>(
      [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
        HandleWindowProc(hwnd, message, wparam, lparam);
      });
  window_proc_id = registrar->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleWindowProc(hwnd, message, wparam, lparam);
      });
  windows_taskbar_created_message_id = RegisterWindowMessage(L"TaskbarCreated");
}

TrayManagerPlugin::~TrayManagerPlugin() {
  if (hMenu) {
    DestroyMenu(hMenu);
    hMenu = NULL;
  }
  registrar->UnregisterTopLevelWindowProcDelegate(window_proc_id);
}

void TrayManagerPlugin::_CreateMenu(HMENU menu, flutter::EncodableMap args) {
  flutter::EncodableList items = std::get<flutter::EncodableList>(
      args.at(flutter::EncodableValue("items")));

  int count = GetMenuItemCount(menu);
  for (int i = 0; i < count; i++) {
    // always remove at 0 because they shift every time
    DeleteMenu(menu, 0, MF_BYPOSITION);
  }

  for (flutter::EncodableValue item_value : items) {
    flutter::EncodableMap item_map =
        std::get<flutter::EncodableMap>(item_value);
    int id = std::get<int>(item_map.at(flutter::EncodableValue("id")));
    std::string type =
        std::get<std::string>(item_map.at(flutter::EncodableValue("type")));
    std::string label =
        std::get<std::string>(item_map.at(flutter::EncodableValue("label")));
    auto* sublabel = std::get_if<std::string>(ValueOrNull(item_map, "sublabel"));
    if (sublabel != nullptr && !sublabel->empty()) {
      label = label + "\t" + *sublabel;
    }
    auto* checked = std::get_if<bool>(ValueOrNull(item_map, "checked"));
    bool disabled =
        std::get<bool>(item_map.at(flutter::EncodableValue("disabled")));

    UINT_PTR item_id = id;
    UINT uFlags = MF_STRING;

    if (disabled) {
      uFlags |= MF_GRAYED;
    }

    if (type.compare("separator") == 0) {
      AppendMenuW(menu, MF_SEPARATOR, item_id, NULL);
    } else {
      if (type.compare("checkbox") == 0) {
        if (checked == nullptr) {
          // skip
        } else {
          uFlags |= (*checked == true ? MF_CHECKED : MF_UNCHECKED);
        }
      } else if (type.compare("submenu") == 0) {
        uFlags |= MF_POPUP;
        HMENU sub_menu = ::CreatePopupMenu();
        _CreateMenu(sub_menu, std::get<flutter::EncodableMap>(item_map.at(
                                  flutter::EncodableValue("submenu"))));
        item_id = reinterpret_cast<UINT_PTR>(sub_menu);
      }
      AppendMenuW(menu, uFlags, item_id, g_converter.from_bytes(label).c_str());
    }
  }
}

void TrayManagerPlugin::_UpdateMenuLabels(HMENU menu, flutter::EncodableMap args) {
  flutter::EncodableList items = std::get<flutter::EncodableList>(
      args.at(flutter::EncodableValue("items")));

  int count = GetMenuItemCount(menu);
  int item_count = static_cast<int>(items.size());

  int min_count = count < item_count ? count : item_count;
  for (int i = 0; i < min_count; i++) {
    flutter::EncodableMap item_map =
        std::get<flutter::EncodableMap>(items[i]);
    std::string label =
        std::get<std::string>(item_map.at(flutter::EncodableValue("label")));
    auto* sublabel = std::get_if<std::string>(ValueOrNull(item_map, "sublabel"));
    if (sublabel != nullptr && !sublabel->empty()) {
      label = label + "\t" + *sublabel;
    }
    auto* checked = std::get_if<bool>(ValueOrNull(item_map, "checked"));
    bool disabled = std::get<bool>(item_map.at(flutter::EncodableValue("disabled")));

    MENUITEMINFO mii = { sizeof(MENUITEMINFO) };
    mii.fMask = MIIM_ID | MIIM_SUBMENU;
    if (GetMenuItemInfo(menu, i, TRUE, &mii)) {
      if (mii.hSubMenu != NULL) {
        auto submenu_it = item_map.find(flutter::EncodableValue("submenu"));
        if (submenu_it != item_map.end()) {
          _UpdateMenuLabels(mii.hSubMenu, std::get<flutter::EncodableMap>(submenu_it->second));
        }
      } else {
        std::wstring wlabel = g_converter.from_bytes(label);
        MENUITEMINFO update_mii = { sizeof(MENUITEMINFO) };
        update_mii.fMask = MIIM_STRING | MIIM_STATE;
        update_mii.dwTypeData = const_cast<LPWSTR>(wlabel.c_str());
        update_mii.cch = static_cast<UINT>(wlabel.size());

        UINT state = 0;
        if (disabled) state |= MFS_DISABLED;
        else state |= MFS_ENABLED;
        if (checked != nullptr && *checked) state |= MFS_CHECKED;
        else state |= MFS_UNCHECKED;
        update_mii.fState = state;

        SetMenuItemInfo(menu, i, TRUE, &update_mii);
      }
    }
  }
}

std::optional<LRESULT> TrayManagerPlugin::HandleWindowProc(HWND hWnd,
                                                           UINT message,
                                                           WPARAM wParam,
                                                           LPARAM lParam) {
  std::optional<LRESULT> result;
  if (message == WM_DESTROY) {
    KillTimer(hWnd, 1001);
    if (tray_icon_setted) {
      Shell_NotifyIcon(NIM_DELETE, &nid);
    }
    if (nid.hIcon != nullptr) {
      DestroyIcon(nid.hIcon);
      nid.hIcon = nullptr;
    }
    tray_icon_setted = false;
  } else if (message == WM_MYMESSAGE) {
    switch (lParam) {
      case WM_LBUTTONUP:
        if (left_click_shows_menu_) {
          ShowContextMenu();
          break;
        }
        channel->InvokeMethod("onTrayIconMouseDown",
                              std::make_unique<flutter::EncodableValue>());
        break;
      case WM_RBUTTONUP:
        if (right_click_shows_menu_) {
          ShowContextMenu();
          break;
        }
        channel->InvokeMethod("onTrayIconRightMouseDown",
                              std::make_unique<flutter::EncodableValue>());
        break;
      default:
        break;
    };
  } else if (message == WM_TIMER && wParam == 1001) {
    if (!tray_icon_setted && nid.hIcon != nullptr) {
      _ApplyIcon();
    } else {
      KillTimer(hWnd, 1001);
    }
  } else if (message == WM_POWERBROADCAST) {
    if (wParam == PBT_APMRESUMESUSPEND || wParam == PBT_APMRESUMEAUTOMATIC || wParam == PBT_APMRESUMECRITICAL) {
      if (tray_icon_setted && nid.hWnd != nullptr && IsWindow(nid.hWnd)) {
        Shell_NotifyIcon(NIM_MODIFY, &nid);
      }
    }
  } else if (message == windows_taskbar_created_message_id) {
    if (windows_taskbar_created_message_id != 0 && nid.hIcon != nullptr) {
      // restore the icon with the existing resource.
      tray_icon_setted = false;
      ApplyTemplateIcon(tray_icon_active_, tray_icon_dark_);
    }
  }
  return result;
}

void TrayManagerPlugin::Destroy(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (tray_icon_setted) {
    Shell_NotifyIcon(NIM_DELETE, &nid);
  }
  if (nid.hIcon != nullptr) {
    DestroyIcon(nid.hIcon);
    nid.hIcon = nullptr;
  }
  tray_icon_setted = false;

  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::SetIcon(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap& args =
      std::get<flutter::EncodableMap>(*method_call.arguments());

  std::string iconPath =
      std::get<std::string>(args.at(flutter::EncodableValue("iconPath")));

  tray_icon_path_ = iconPath;

  // 模板资源是 PNG，LoadImage(IMAGE_ICON) 只能读取 ICO，不能先注册空图标。
  if (iconPath.size() >= 4 && iconPath.substr(iconPath.size() - 4) == ".png") {
    ApplyTemplateIcon(tray_icon_active_, tray_icon_dark_);
    if (!tray_icon_setted) {
      result->Error("icon_unavailable", "Windows 托盘模板图标创建失败");
      return;
    }
    result->Success(flutter::EncodableValue(true));
    return;
  }

  std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;

  if (nid.hIcon != nullptr) {
    DestroyIcon(nid.hIcon);
    nid.hIcon = nullptr;
  }

  nid.hIcon = static_cast<HICON>(
      LoadImage(nullptr, (LPCWSTR)(converter.from_bytes(iconPath).c_str()),
                IMAGE_ICON, GetSystemMetrics(SM_CXSMICON),
                GetSystemMetrics(SM_CYSMICON), LR_LOADFROMFILE));

  if (nid.hIcon == nullptr) {
    result->Error("icon_unavailable", "Windows 托盘图标加载失败");
    return;
  }

  _ApplyIcon();

  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::_ApplyIcon() {
  if (tray_icon_setted) {
    Shell_NotifyIcon(NIM_MODIFY, &nid);
  } else {
    nid.cbSize = sizeof(NOTIFYICONDATA);
    nid.hWnd = menu_host_->window();
    nid.uID = 1;
    nid.uCallbackMessage = WM_MYMESSAGE;
    nid.uFlags = NIF_MESSAGE | NIF_ICON;
    if (wcslen(nid.szTip) > 0) nid.uFlags |= NIF_TIP;
    
    if (Shell_NotifyIcon(NIM_ADD, &nid)) {
      tray_icon_setted = true;
      if (nid.hWnd) KillTimer(nid.hWnd, 1001);
    } else {
      tray_icon_setted = false;
      if (nid.hWnd) SetTimer(nid.hWnd, 1001, 2000, nullptr);
    }
  }

  niif.cbSize = sizeof(NOTIFYICONIDENTIFIER);
  niif.hWnd = nid.hWnd;
  niif.uID = nid.uID;
  niif.guidItem = GUID_NULL;
}

void TrayManagerPlugin::_UpdateToolTip() {
  std::wstring tooltip = base_tooltip_;
  if (!speed_title_.empty()) {
    if (!tooltip.empty()) {
      tooltip += L"\n";
    }
    tooltip += speed_title_;
  }

  nid.uFlags |= NIF_TIP;
  StringCchCopyW(nid.szTip, _countof(nid.szTip), tooltip.c_str());
  if (tray_icon_setted) {
    Shell_NotifyIcon(NIM_MODIFY, &nid);
  }
}

void TrayManagerPlugin::ApplyTemplateIcon(bool active, bool isDark) {
  using namespace Gdiplus;

  if (tray_icon_path_.empty()) {
    return;
  }

  const int iconWidth = GetSystemMetrics(SM_CXSMICON);
  const int iconHeight = GetSystemMetrics(SM_CYSMICON);
  ULONG_PTR gdiplus_token = 0;
  GdiplusStartupInput gdiplus_input;
  if (GdiplusStartup(&gdiplus_token, &gdiplus_input, nullptr) != Ok) {
    return;
  }
  // GDI+ 没有 RAII 包装，先集中申请资源，再统一关闭并释放。
  Bitmap* source = nullptr;
  Bitmap* target = nullptr;
  Graphics* graphics = nullptr;
  HICON icon = nullptr;
  do {
    source = new Bitmap(
        std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>>()
            .from_bytes(tray_icon_path_)
            .c_str(),
        PixelFormat32bppARGB);
    if (source->GetLastStatus() != Ok) {
      break;
    }
    target = new Bitmap(iconWidth, iconHeight);
    if (target->GetLastStatus() != Ok) {
      break;
    }
    graphics = Graphics::FromImage(target);
    if (graphics->GetLastStatus() != Ok) {
      break;
    }

    // 与 macOS 模板图标一致：未接管时使用中性灰，接管后按系统明暗
    // 使用黑色或白色前景，避免深色任务栏上的黑色图标看起来仍像未启用。
    const BYTE tintValue = !active ? 153 : isDark ? 255 : 0;
    const Color tint(255, tintValue, tintValue, tintValue);
    ColorMatrix matrix = {};
    matrix.m[0][0] = static_cast<REAL>(tint.GetR()) / 255.0f;
    matrix.m[1][1] = static_cast<REAL>(tint.GetG()) / 255.0f;
    matrix.m[2][2] = static_cast<REAL>(tint.GetB()) / 255.0f;
    matrix.m[3][3] = 1.0f;
    matrix.m[4][0] = static_cast<REAL>(tint.GetR()) / 255.0f;
    matrix.m[4][1] = static_cast<REAL>(tint.GetG()) / 255.0f;
    matrix.m[4][2] = static_cast<REAL>(tint.GetB()) / 255.0f;
    ImageAttributes attributes;
    attributes.SetColorMatrix(&matrix, ColorMatrixFlagsDefault,
                              ColorAdjustTypeBitmap);

    graphics->SetPixelOffsetMode(PixelOffsetModeHalf);
    graphics->SetInterpolationMode(InterpolationModeHighQualityBicubic);
    graphics->Clear(Color(0, 0, 0, 0));
    graphics->DrawImage(source, Rect(0, 0, iconWidth, iconHeight), 0, 0,
                        source->GetWidth(), source->GetHeight(), UnitPixel,
                        &attributes);
    if (target->GetHICON(&icon) == Ok && icon != nullptr) {
      if (nid.hIcon != nullptr) {
        DestroyIcon(nid.hIcon);
      }
      nid.hIcon = icon;
      _ApplyIcon();
    }
  } while (false);

  delete graphics;
  delete target;
  delete source;
  GdiplusShutdown(gdiplus_token);
}

void TrayManagerPlugin::SetActive(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* active = std::get_if<bool>(
      &std::get<flutter::EncodableMap>(*method_call.arguments())
           .at(flutter::EncodableValue("active")));
  if (active == nullptr) {
    result->Error("bad_args", "active must be a boolean");
    return;
  }

  const auto& args = std::get<flutter::EncodableMap>(*method_call.arguments());
  const auto* brightness =
      std::get_if<std::string>(ValueOrNull(args, "brightness"));
  const bool isDark = brightness != nullptr && *brightness == "dark";

  ApplyTemplateIcon(*active, isDark);
  tray_icon_active_ = *active;
  tray_icon_dark_ = isDark;
  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::SetSpeedTitle(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& args = std::get<flutter::EncodableMap>(*method_call.arguments());
  const auto upload = tray_manager::ReadInteger(ValueOrNull(args, "upload"));
  const auto download = tray_manager::ReadInteger(ValueOrNull(args, "download"));
  const auto* active =
      std::get_if<bool>(&args.at(flutter::EncodableValue("active")));
  if (!upload || !download || active == nullptr ||
      *upload < 0 || *download < 0) {
    result->Error("bad_args", "invalid speed arguments");
    return;
  }

  speed_title_ =
      L"↑ " + NormalizeSpeedNumber(static_cast<uint64_t>(*upload)) +
      L"\n↓ " + NormalizeSpeedNumber(static_cast<uint64_t>(*download));
  _UpdateToolTip();
  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::ClearSpeedTitle(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  speed_title_.clear();
  _UpdateToolTip();
  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::SetToolTip(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap& args =
      std::get<flutter::EncodableMap>(*method_call.arguments());

  std::string toolTip =
      std::get<std::string>(args.at(flutter::EncodableValue("toolTip")));

  std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
  base_tooltip_ = converter.from_bytes(toolTip);
  _UpdateToolTip();

  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::SetContextMenu(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap& args =
      std::get<flutter::EncodableMap>(*method_call.arguments());

  auto* keep_menu_open = std::get_if<bool>(ValueOrNull(args, "keepMenuOpen"));
  bool should_keep_open = keep_menu_open != nullptr && *keep_menu_open && is_menu_open_;

  // 菜单模态循环也会处理平台消息，不能在此期间删除现有菜单项。
  if (is_menu_open_ && !should_keep_open) {
    pending_menu_ = args;
    result->Success(flutter::EncodableValue(true));
    return;
  }

  auto* brightness = std::get_if<std::string>(ValueOrNull(args, "brightness"));
  bool is_dark = brightness != nullptr && *brightness == "dark";
  ApplyDarkModeToMenu(menu_host_->window(), is_dark);

  if (should_keep_open) {
    _UpdateMenuLabels(hMenu, std::get<flutter::EncodableMap>(
                           args.at(flutter::EncodableValue("menu"))));
  } else {
    _CreateMenu(hMenu, std::get<flutter::EncodableMap>(
                           args.at(flutter::EncodableValue("menu"))));
  }

  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::SetNativeMenuClickBehavior(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap& args =
      std::get<flutter::EncodableMap>(*method_call.arguments());

  auto* left = std::get_if<bool>(ValueOrNull(args, "left"));
  auto* right = std::get_if<bool>(ValueOrNull(args, "right"));
  if (left != nullptr) {
    left_click_shows_menu_ = *left;
  }
  if (right != nullptr) {
    right_click_shows_menu_ = *right;
  }

  result->Success(flutter::EncodableValue(true));
}

bool TrayManagerPlugin::ShowContextMenu() {
  if (is_menu_open_) return true;
  if (menu_host_->window() == nullptr || GetMenuItemCount(hMenu) <= 0) {
    return false;
  }
  POINT cursorPos{};
  if (!GetCursorPos(&cursorPos)) return false;

  is_menu_open_ = true;
  channel->InvokeMethod("onMenuOpen",
                        std::make_unique<flutter::EncodableValue>());
  const UINT command = menu_host_->Show(hMenu, cursorPos);
  // 先派发旧菜单 ID，再允许 Dart 替换菜单与回调映射。
  if (command != 0) {
    flutter::EncodableMap eventData;
    eventData[flutter::EncodableValue("id")] =
        flutter::EncodableValue(static_cast<int>(command));
    channel->InvokeMethod("onTrayMenuItemClick",
                          std::make_unique<flutter::EncodableValue>(eventData));
  }
  is_menu_open_ = false;
  channel->InvokeMethod("onMenuClose",
                        std::make_unique<flutter::EncodableValue>());
  if (pending_menu_) {
    _CreateMenu(hMenu, std::get<flutter::EncodableMap>(
                          pending_menu_->at(flutter::EncodableValue("menu"))));
    pending_menu_.reset();
  }
  return true;
}

void TrayManagerPlugin::PopUpContextMenu(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!ShowContextMenu()) {
    result->Error("menu_unavailable", "Windows 托盘菜单尚未就绪");
    return;
  }
  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::GetBounds(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap& args =
      std::get<flutter::EncodableMap>(*method_call.arguments());

  if (!tray_icon_setted) {
    result->Success();
    return;
  }

  double devicePixelRatio =
      std::get<double>(args.at(flutter::EncodableValue("devicePixelRatio")));

  RECT rect;
  Shell_NotifyIconGetRect(&niif, &rect);
  flutter::EncodableMap resultMap = flutter::EncodableMap();

  double x = rect.left / devicePixelRatio * 1.0f;
  double y = rect.top / devicePixelRatio * 1.0f;
  double width = (rect.right - rect.left) / devicePixelRatio * 1.0f;
  double height = (rect.bottom - rect.top) / devicePixelRatio * 1.0f;

  resultMap[flutter::EncodableValue("x")] = flutter::EncodableValue(x);
  resultMap[flutter::EncodableValue("y")] = flutter::EncodableValue(y);
  resultMap[flutter::EncodableValue("width")] = flutter::EncodableValue(width);
  resultMap[flutter::EncodableValue("height")] =
      flutter::EncodableValue(height);

  result->Success(flutter::EncodableValue(resultMap));
}

void TrayManagerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("destroy") == 0) {
    Destroy(method_call, std::move(result));
  } else if (method_call.method_name().compare("setIcon") == 0) {
    SetIcon(method_call, std::move(result));
  } else if (method_call.method_name().compare("setActive") == 0) {
    SetActive(method_call, std::move(result));
  } else if (method_call.method_name().compare("setSpeedTitle") == 0) {
    SetSpeedTitle(method_call, std::move(result));
  } else if (method_call.method_name().compare("clearSpeedTitle") == 0) {
    ClearSpeedTitle(method_call, std::move(result));
  } else if (method_call.method_name().compare("setToolTip") == 0) {
    SetToolTip(method_call, std::move(result));
  } else if (method_call.method_name().compare("setContextMenu") == 0) {
    SetContextMenu(method_call, std::move(result));
  } else if (method_call.method_name().compare("setNativeMenuClickBehavior") ==
             0) {
    SetNativeMenuClickBehavior(method_call, std::move(result));
  } else if (method_call.method_name().compare("popUpContextMenu") == 0) {
    PopUpContextMenu(method_call, std::move(result));
  } else if (method_call.method_name().compare("getBounds") == 0) {
    GetBounds(method_call, std::move(result));
  } else {
    result->NotImplemented();
  }
}

}  // namespace

void TrayManagerPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  TrayManagerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
