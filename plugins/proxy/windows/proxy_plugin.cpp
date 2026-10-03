#include "proxy_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <WinInet.h>
#include <Ras.h>
#include <RasError.h>
#include <iostream>
#include <vector>

#pragma comment(lib, "wininet")
#pragma comment(lib, "Rasapi32")

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <memory>
#include <sstream>

namespace {

bool ApplyProxyOptionsToConnections(INTERNET_PER_CONN_OPTION_LIST* list) {
  const DWORD list_size = sizeof(*list);
  list->pszConnection = nullptr;
  if (!InternetSetOptionW(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION, list,
                          list_size)) {
    return false;
  }

  RASENTRYNAME entry = {};
  entry.dwSize = sizeof(entry);
  DWORD size = sizeof(entry);
  DWORD count = 0;
  LPRASENTRYNAME entry_address = &entry;
  std::vector<RASENTRYNAME> entries;
  auto result =
      RasEnumEntriesW(nullptr, nullptr, entry_address, &size, &count);
  if (result == ERROR_BUFFER_TOO_SMALL) {
    const size_t entry_count =
        std::max<size_t>(count, size / sizeof(RASENTRYNAME));
    entries.resize(entry_count);
    for (auto& item : entries) {
      item.dwSize = sizeof(RASENTRYNAME);
    }
    entry_address = entries.data();
    result =
        RasEnumEntriesW(nullptr, nullptr, entry_address, &size, &count);
  }
  if (result != ERROR_SUCCESS) {
    return true;
  }

  for (DWORD i = 0; i < count; i++) {
    list->pszConnection = entry_address[i].szEntryName;
    InternetSetOptionW(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION, list,
                       list_size);
  }
  return true;
}

void NotifyProxyChanged() {
  InternetSetOptionW(nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0);
  InternetSetOptionW(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0);
}

}  // namespace

bool stopProxy();

bool startProxy(const int port,
                const flutter::EncodableList& bypassDomain) {
  const std::string address = "127.0.0.1:" + std::to_string(port);
  std::wstring proxy_address(address.begin(), address.end());
  std::wstring bypass_list = L"<local>";
  for (const auto& domain : bypassDomain) {
    const auto& value = std::get<std::string>(domain);
    bypass_list += L";";
    bypass_list.append(value.begin(), value.end());
  }

  INTERNET_PER_CONN_OPTION options[3] = {};
  options[0].dwOption = INTERNET_PER_CONN_FLAGS;
  options[0].Value.dwValue = PROXY_TYPE_DIRECT | PROXY_TYPE_PROXY;
  options[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
  options[1].Value.pszValue = proxy_address.data();
  options[2].dwOption = INTERNET_PER_CONN_PROXY_BYPASS;
  options[2].Value.pszValue = bypass_list.data();

  INTERNET_PER_CONN_OPTION_LIST list = {};
  list.dwSize = sizeof(list);
  list.dwOptionCount = 3;
  list.pOptions = options;

  if (!ApplyProxyOptionsToConnections(&list)) {
    stopProxy();
    return false;
  }
  NotifyProxyChanged();
  return true;
}

bool stopProxy() {
  INTERNET_PER_CONN_OPTION option = {};
  option.dwOption = INTERNET_PER_CONN_FLAGS;
  option.Value.dwValue = PROXY_TYPE_DIRECT;

  INTERNET_PER_CONN_OPTION_LIST list = {};
  list.dwSize = sizeof(list);
  list.dwOptionCount = 1;
  list.pOptions = &option;
  const bool updated = ApplyProxyOptionsToConnections(&list);
  NotifyProxyChanged();
  return updated;
}

namespace proxy
{

  // static
  void ProxyPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "proxy",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<ProxyPlugin>(registrar);

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result)
        {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  ProxyPlugin::ProxyPlugin(flutter::PluginRegistrarWindows *registrar)
      : registrar(registrar) {
    window_proc_id = registrar->RegisterTopLevelWindowProcDelegate(
        [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
          return HandleWindowProc(hwnd, message, wparam, lparam);
        });
  }

  ProxyPlugin::~ProxyPlugin() {
    if (registrar && window_proc_id != -1) {
      registrar->UnregisterTopLevelWindowProcDelegate(window_proc_id);
    }
  }

  std::optional<LRESULT> ProxyPlugin::HandleWindowProc(
      HWND hwnd,
      UINT message,
      WPARAM wparam,
      LPARAM lparam) {
    if (message == WM_ENDSESSION) {
      if (wparam == TRUE) {
        stopProxy();
      }
    }
    return std::nullopt;
  }

  void ProxyPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (method_call.method_name().compare("StopProxy") == 0)
    {
      result->Success(stopProxy());
    }
    else if (method_call.method_name().compare("StartProxy") == 0)
    {
      auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      auto port = std::get<int>(arguments->at(flutter::EncodableValue("port")));
      auto bypassDomain = std::get<flutter::EncodableList>(arguments->at(flutter::EncodableValue("bypassDomain")));
      result->Success(startProxy(port, bypassDomain));
    }
    else
    {
      result->NotImplemented();
    }
  }
} // namespace proxy
