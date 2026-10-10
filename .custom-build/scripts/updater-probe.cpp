#include <windows.h>
#include <atomic>
#include <cstdio>

namespace {
HANDLE finished = nullptr;
std::atomic<int> outcome{0};

void signal(int result) {
  outcome.store(result);
  SetEvent(finished);
}

void __cdecl failed() { signal(-1); }
void __cdecl found() { signal(1); }
void __cdecl missing() { signal(2); }
}

int main(int argc, char** argv) {
  if (argc != 3) return 5;
  HMODULE dll = LoadLibraryA(argv[1]);
  if (!dll) {
    printf("load error %lu\n", GetLastError());
    return 6;
  }
  auto api = [&](const char* name) {
    auto function = GetProcAddress(dll, name);
    if (!function) {
      printf("missing export: %s\n", name);
      ExitProcess(7);
    }
    return function;
  };
  using Action = void(__cdecl*)();
  using CallbackSetter = void(__cdecl*)(Action);
  reinterpret_cast<void(__cdecl*)(const wchar_t*, const wchar_t*, const wchar_t*)>(
      api("win_sparkle_set_app_details"))(L"BettboxTest", L"GzipProbe", L"1.0+1");
  reinterpret_cast<void(__cdecl*)(const wchar_t*)>(
      api("win_sparkle_set_app_build_version"))(L"1");
  reinterpret_cast<void(__cdecl*)(int)>(
      api("win_sparkle_set_automatic_check_for_updates"))(0);
  reinterpret_cast<void(__cdecl*)(const char*)>(
      api("win_sparkle_set_appcast_url"))(argv[2]);
  reinterpret_cast<CallbackSetter>(api("win_sparkle_set_error_callback"))(failed);
  reinterpret_cast<CallbackSetter>(api("win_sparkle_set_did_find_update_callback"))(found);
  reinterpret_cast<CallbackSetter>(api("win_sparkle_set_did_not_find_update_callback"))(missing);
  finished = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  if (!finished) return 8;
  reinterpret_cast<Action>(api("win_sparkle_init"))();
  for (int i = 0; i < 3; ++i) {
    outcome.store(0);
    reinterpret_cast<Action>(api("win_sparkle_check_update_without_ui"))();
    if (WaitForSingleObject(finished, 40000) != WAIT_OBJECT_0) {
      printf("check timeout\n");
      // 避免异常清理路径把 CI 挂住；此探针不接触应用实际配置。
      ExitProcess(9);
    }
    printf("Check %d result: %d\n", i + 1, outcome.load());
    if (outcome.load() != 1) break;
    Sleep(300);
  }
  reinterpret_cast<Action>(api("win_sparkle_cleanup"))();
  CloseHandle(finished);
  FreeLibrary(dll);
  return outcome.load() == 1 ? 0 : 1;
}
