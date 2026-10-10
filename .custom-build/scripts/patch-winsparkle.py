"""在固定 WinSparkle 0.8.1 源码上回补压缩、重试与进度状态修复。"""

import argparse
from pathlib import Path


def replace(path, old, new):
    source = path.read_text(encoding='utf-8-sig')
    if new in source:
        return
    if source.count(old) != 1:
        raise RuntimeError(f'无法唯一定位 WinSparkle 补丁：{path}')
    path.write_text(source.replace(old, new), encoding='utf-8')


def apply(root):
    replace(root / 'src/ui.cpp',
            '    EnablePulsing(false);\n\n    HIDE(m_heading);\n    SHOW(m_progress);',
            '''    EnablePulsing(false);
    // BETTBOX-CUSTOM: 下载是新阶段，不能沿用检查阶段的脉冲位置与旧文案。
    m_progress->SetRange(100);
    m_progress->SetValue(0);
    m_progressLabel->SetLabel(wxEmptyString);

    HIDE(m_heading);
    SHOW(m_progress);''')
    replace(root / 'src/download.cpp',
            '    InternetSetOptionW(inet, INTERNET_OPTION_ENABLE_HTTP_PROTOCOL, &dwOption, sizeof(dwOption));',
            '''    InternetSetOptionW(inet, INTERNET_OPTION_ENABLE_HTTP_PROTOCOL, &dwOption, sizeof(dwOption));
    // BETTBOX-CUSTOM: 回补 0.8.2 的 gzip/deflate 支持；新会话重新读取系统代理。
    DWORD decode = TRUE;
    InternetSetOptionW(inet, INTERNET_OPTION_HTTP_DECODING, &decode, sizeof(decode));
    DWORD timeout = 15000;
    InternetSetOptionW(inet, INTERNET_OPTION_CONNECT_TIMEOUT, &timeout, sizeof(timeout));
    InternetSetOptionW(inet, INTERNET_OPTION_SEND_TIMEOUT, &timeout, sizeof(timeout));
    InternetSetOptionW(inet, INTERNET_OPTION_RECEIVE_TIMEOUT, &timeout, sizeof(timeout));''')
    replace(root / 'src/updatechecker.cpp',
            '        DownloadFile(url, &appcast_xml, this, Settings::GetHttpHeadersString(), Download_BypassProxies);',
            '''        // BETTBOX-CUSTOM: 仅检查源允许一次短重试，每次创建新网络会话并清空半包。
        for (int attempt = 0; ; ++attempt)
        {
            try
            {
                DownloadFile(url, &appcast_xml, this, Settings::GetHttpHeadersString(), Download_BypassProxies);
                break;
            }
            catch (const std::exception& error)
            {
                LogError(error.what());
                if (attempt != 0) throw;
                CheckShouldTerminate();
                appcast_xml.data.clear();
                InternetSetOptionW(NULL, INTERNET_OPTION_SETTINGS_CHANGED, NULL, 0);
                InternetSetOptionW(NULL, INTERNET_OPTION_REFRESH, NULL, 0);
                Sleep(300);
            }
        }''')
    replace(root / 'src/updatechecker.cpp', '#include <winsparkle.h>',
            '#include <winsparkle.h>\n#include <wininet.h>')
    replace(root / 'src/download.cpp',
            '                             headers.c_str(),\n                             (DWORD)headers.length(),',
            '''                             (headers + "Accept-Encoding: gzip, deflate\\r\\n").c_str(),
                             (DWORD)(headers.length() + sizeof("Accept-Encoding: gzip, deflate\\r\\n") - 1),''')
    replace(root / 'src/download.cpp',
            '    WaitUntilSignaledWithTerminationCheck(context.eventRequestComplete, onThread);\n\n    // Check returned status code',
            '''    WaitUntilSignaledWithTerminationCheck(context.eventRequestComplete, onThread);
    if (context.lastError != ERROR_SUCCESS)
    {
        SetLastError(context.lastError);
        throw Win32Exception("appcast/download connection");
    }

    // Check returned status code''')
    replace(root / 'src/error.cpp', '    OutputDebugStringA(err.c_str());',
            '''    OutputDebugStringA(err.c_str());
    // BETTBOX-CUSTOM: 保留真实 WinINet/解析错误，而不只有 Flutter 的 Unknown error。
    wchar_t directory[MAX_PATH] = {};
    if (GetEnvironmentVariableW(L"LOCALAPPDATA", directory, MAX_PATH))
    {
        std::wstring folder(directory);
        folder += L"\\\\Bettbox";
        CreateDirectoryW(folder.c_str(), NULL);
        HANDLE log = CreateFileW((folder + L"\\\\updater.log").c_str(), FILE_APPEND_DATA,
                                FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS, 0, NULL);
        if (log != INVALID_HANDLE_VALUE)
        {
            DWORD written = 0;
            WriteFile(log, err.c_str(), (DWORD)err.size(), &written, NULL);
            CloseHandle(log);
        }
    }''')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    apply(parser.parse_args().source)
