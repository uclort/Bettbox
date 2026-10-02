#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>

#include <array>
#include <cstdint>
#include <filesystem>
#include <string>
#include <system_error>
#include <vector>

namespace {

constexpr std::array<char, 16> kPayloadMagic = {
    'B', 'E', 'T', 'T', 'B', 'O', 'X', '_',
    'S', 'E', 'T', 'U', 'P', '_', 'V', '1',
};

#pragma pack(push, 1)
struct PayloadFooter {
  std::array<char, 16> magic;
  std::uint64_t payload_size;
};
#pragma pack(pop)

static_assert(sizeof(PayloadFooter) == 24);

std::wstring FormatWindowsError(const DWORD error) {
  wchar_t* buffer = nullptr;
  const DWORD size = FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, error, 0, reinterpret_cast<wchar_t*>(&buffer), 0, nullptr);
  std::wstring message =
      size > 0 && buffer != nullptr ? std::wstring(buffer, size) : L"未知错误";
  if (buffer != nullptr) {
    LocalFree(buffer);
  }
  return message;
}

int ShowError(const std::wstring& message, const DWORD error = ERROR_SUCCESS) {
  std::wstring detail = message;
  if (error != ERROR_SUCCESS) {
    detail += L"\n\nWindows 错误 ";
    detail += std::to_wstring(error);
    detail += L"：";
    detail += FormatWindowsError(error);
  }
  MessageBoxW(nullptr, detail.c_str(), L"Bettbox 安装程序", MB_OK | MB_ICONERROR);
  return error == ERROR_SUCCESS ? 1 : static_cast<int>(error);
}

std::filesystem::path GetExecutablePath() {
  std::vector<wchar_t> buffer(32768);
  const DWORD length =
      GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
  if (length == 0 || length >= static_cast<DWORD>(buffer.size())) {
    return {};
  }
  return std::filesystem::path(std::wstring(buffer.data(), length));
}

std::filesystem::path GetEnvironmentPath(const wchar_t* name) {
  const DWORD length = GetEnvironmentVariableW(name, nullptr, 0);
  if (length == 0) {
    return {};
  }
  std::vector<wchar_t> buffer(length);
  if (GetEnvironmentVariableW(name, buffer.data(), length) == 0) {
    return {};
  }
  return std::filesystem::path(buffer.data());
}

std::filesystem::path GetLocalAppDataPath() {
  PWSTR raw_path = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_DEFAULT,
                                  nullptr, &raw_path))) {
    return {};
  }
  const std::filesystem::path result(raw_path);
  CoTaskMemFree(raw_path);
  return result;
}

bool IsDirectoryWritable(const std::filesystem::path& directory) {
  const auto probe = directory / L".write-test";
  const HANDLE file = CreateFileW(
      probe.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
      FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_DELETE_ON_CLOSE, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  CloseHandle(file);
  return true;
}

std::filesystem::path CreateInstallerTempDirectory(
    const std::filesystem::path& executable_path) {
  const auto local_app_data = GetLocalAppDataPath();
  const auto user_profile = GetEnvironmentPath(L"USERPROFILE");
  const std::array<std::filesystem::path, 3> roots = {
      local_app_data.empty()
          ? std::filesystem::path()
          : local_app_data / L"Bettbox" / L"InstallerTemp",
      executable_path.parent_path() / L".bettbox-installer-temp",
      user_profile.empty() ? std::filesystem::path()
                           : user_profile / L"BettboxInstallerTemp",
  };

  for (const auto& root : roots) {
    if (root.empty()) {
      continue;
    }
    std::error_code error;
    std::filesystem::create_directories(root, error);
    if (error || !IsDirectoryWritable(root)) {
      continue;
    }

    const auto run_name =
        L"run-" + std::to_wstring(GetCurrentProcessId()) + L"-" +
        std::to_wstring(GetTickCount64());
    const auto run_directory = root / run_name;
    if (std::filesystem::create_directory(run_directory, error) && !error) {
      return run_directory;
    }
  }
  return {};
}

bool ReadExact(const HANDLE file, void* buffer, const DWORD size) {
  DWORD bytes_read = 0;
  return ReadFile(file, buffer, size, &bytes_read, nullptr) != FALSE &&
         bytes_read == size;
}

bool WriteExact(const HANDLE file, const void* buffer, const DWORD size) {
  DWORD bytes_written = 0;
  return WriteFile(file, buffer, size, &bytes_written, nullptr) != FALSE &&
         bytes_written == size;
}

bool ExtractPayload(const std::filesystem::path& executable_path,
                    const std::filesystem::path& payload_path,
                    DWORD* error) {
  const HANDLE source =
      CreateFileW(executable_path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                  OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (source == INVALID_HANDLE_VALUE) {
    *error = GetLastError();
    return false;
  }

  LARGE_INTEGER file_size{};
  if (GetFileSizeEx(source, &file_size) == FALSE) {
    *error = GetLastError();
    CloseHandle(source);
    return false;
  }
  if (file_size.QuadPart < static_cast<LONGLONG>(sizeof(PayloadFooter))) {
    *error = ERROR_INVALID_DATA;
    CloseHandle(source);
    return false;
  }

  LARGE_INTEGER footer_offset{};
  footer_offset.QuadPart =
      file_size.QuadPart - static_cast<LONGLONG>(sizeof(PayloadFooter));
  if (SetFilePointerEx(source, footer_offset, nullptr, FILE_BEGIN) == FALSE) {
    *error = GetLastError();
    CloseHandle(source);
    return false;
  }

  PayloadFooter footer{};
  if (!ReadExact(source, &footer, static_cast<DWORD>(sizeof(footer))) ||
      footer.magic != kPayloadMagic ||
      footer.payload_size >
          static_cast<std::uint64_t>(footer_offset.QuadPart)) {
    *error = ERROR_INVALID_DATA;
    CloseHandle(source);
    return false;
  }

  LARGE_INTEGER payload_offset{};
  payload_offset.QuadPart =
      footer_offset.QuadPart - static_cast<LONGLONG>(footer.payload_size);
  if (SetFilePointerEx(source, payload_offset, nullptr, FILE_BEGIN) == FALSE) {
    *error = GetLastError();
    CloseHandle(source);
    return false;
  }

  const HANDLE destination =
      CreateFileW(payload_path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW,
                  FILE_ATTRIBUTE_NORMAL, nullptr);
  if (destination == INVALID_HANDLE_VALUE) {
    *error = GetLastError();
    CloseHandle(source);
    return false;
  }

  std::array<std::uint8_t, 1024 * 1024> buffer{};
  std::uint64_t remaining = footer.payload_size;
  bool succeeded = true;
  while (remaining > 0) {
    const DWORD chunk_size = static_cast<DWORD>(
        remaining < buffer.size() ? remaining : buffer.size());
    if (!ReadExact(source, buffer.data(), chunk_size) ||
        !WriteExact(destination, buffer.data(), chunk_size)) {
      *error = GetLastError();
      succeeded = false;
      break;
    }
    remaining -= chunk_size;
  }

  CloseHandle(destination);
  CloseHandle(source);
  if (!succeeded) {
    DeleteFileW(payload_path.c_str());
  }
  return succeeded;
}

std::wstring QuoteArgument(const std::wstring& argument) {
  std::wstring quoted = L"\"";
  std::size_t backslashes = 0;
  for (const wchar_t character : argument) {
    if (character == L'\\') {
      ++backslashes;
      continue;
    }
    if (character == L'"') {
      quoted.append(backslashes * 2 + 1, L'\\');
      quoted.push_back(L'"');
    } else {
      quoted.append(backslashes, L'\\');
      quoted.push_back(character);
    }
    backslashes = 0;
  }
  quoted.append(backslashes * 2, L'\\');
  quoted.push_back(L'"');
  return quoted;
}

std::wstring BuildInstallerCommandLine(
    const std::filesystem::path& installer_path) {
  std::wstring command_line = QuoteArgument(installer_path.wstring());
  int argument_count = 0;
  LPWSTR* arguments = CommandLineToArgvW(GetCommandLineW(), &argument_count);
  if (arguments == nullptr) {
    return command_line;
  }
  for (int index = 1; index < argument_count; ++index) {
    command_line.push_back(L' ');
    command_line += QuoteArgument(arguments[index]);
  }
  LocalFree(arguments);
  return command_line;
}

void CleanupTempDirectory(const std::filesystem::path& directory) {
  std::error_code error;
  std::filesystem::remove_all(directory, error);
}

}  // 命名空间

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  const auto executable_path = GetExecutablePath();
  if (executable_path.empty()) {
    return ShowError(L"无法读取安装程序路径。", GetLastError());
  }

  const auto temp_directory = CreateInstallerTempDirectory(executable_path);
  if (temp_directory.empty()) {
    return ShowError(
        L"无法创建 Bettbox 专用安装临时目录，请检查当前用户目录权限。");
  }

  const auto payload_path = temp_directory / L"Bettbox-Setup-Inner.exe";
  DWORD error = ERROR_SUCCESS;
  if (!ExtractPayload(executable_path, payload_path, &error)) {
    CleanupTempDirectory(temp_directory);
    return ShowError(L"无法释放 Bettbox 安装程序。", error);
  }

  if (SetEnvironmentVariableW(L"TEMP", temp_directory.c_str()) == FALSE ||
      SetEnvironmentVariableW(L"TMP", temp_directory.c_str()) == FALSE) {
    error = GetLastError();
    CleanupTempDirectory(temp_directory);
    return ShowError(L"无法设置 Bettbox 安装临时目录。", error);
  }

  auto command_line = BuildInstallerCommandLine(payload_path);
  std::vector<wchar_t> mutable_command_line(command_line.begin(),
                                             command_line.end());
  mutable_command_line.push_back(L'\0');

  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  PROCESS_INFORMATION process_info{};
  const BOOL created = CreateProcessW(
      payload_path.c_str(), mutable_command_line.data(), nullptr, nullptr, FALSE,
      0, nullptr, executable_path.parent_path().c_str(), &startup_info,
      &process_info);
  if (created == FALSE) {
    error = GetLastError();
    CleanupTempDirectory(temp_directory);
    return ShowError(L"无法启动 Bettbox 安装程序。", error);
  }

  CloseHandle(process_info.hThread);
  WaitForSingleObject(process_info.hProcess, INFINITE);
  DWORD exit_code = 1;
  GetExitCodeProcess(process_info.hProcess, &exit_code);
  CloseHandle(process_info.hProcess);

  CleanupTempDirectory(temp_directory);
  return static_cast<int>(exit_code);
}
