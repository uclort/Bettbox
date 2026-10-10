param(
  [string]$ProcessName = "Bettbox",
  [int]$TimeoutMilliseconds = 3000
)

$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class TrayProbe {
  public sealed class WindowInfo {
    public IntPtr Handle;
    public string ClassName = "";
    public string Title = "";
    public bool Visible;
  }

  private delegate bool EnumWindowsProc(IntPtr window, IntPtr parameter);

  [DllImport("user32.dll")]
  private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr parameter);
  [DllImport("user32.dll")]
  private static extern bool EnumThreadWindows(
      uint threadId, EnumWindowsProc callback, IntPtr parameter);
  [DllImport("user32.dll")]
  private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  private static extern int GetClassName(IntPtr window, StringBuilder value, int count);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  private static extern int GetWindowText(IntPtr window, StringBuilder value, int count);
  [DllImport("user32.dll")]
  private static extern bool IsWindowVisible(IntPtr window);
  [DllImport("user32.dll")]
  private static extern bool PostMessage(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
  [DllImport("user32.dll")]
  private static extern bool SetCursorPos(int x, int y);

  private static List<WindowInfo> Enumerate(uint processId, string className) {
    var windows = new List<WindowInfo>();
    EnumWindows((window, parameter) => {
      uint owner;
      GetWindowThreadProcessId(window, out owner);
      var classBuffer = new StringBuilder(256);
      GetClassName(window, classBuffer, classBuffer.Capacity);
      if ((processId == 0 || owner == processId) &&
          (className == null || classBuffer.ToString() == className)) {
        var titleBuffer = new StringBuilder(512);
        GetWindowText(window, titleBuffer, titleBuffer.Capacity);
        windows.Add(new WindowInfo {
          Handle = window,
          ClassName = classBuffer.ToString(),
          Title = titleBuffer.ToString(),
          Visible = IsWindowVisible(window),
        });
      }
      return true;
    }, IntPtr.Zero);
    return windows;
  }

  public static List<WindowInfo> ProcessWindows(uint processId) {
    var windows = Enumerate(processId, null);
    var handles = new HashSet<IntPtr>();
    foreach (var window in windows) handles.Add(window.Handle);
    foreach (ProcessThread thread in Process.GetProcessById((int)processId).Threads) {
      EnumThreadWindows((uint)thread.Id, (window, parameter) => {
        if (handles.Add(window)) {
          var classBuffer = new StringBuilder(256);
          var titleBuffer = new StringBuilder(512);
          GetClassName(window, classBuffer, classBuffer.Capacity);
          GetWindowText(window, titleBuffer, titleBuffer.Capacity);
          windows.Add(new WindowInfo {
            Handle = window,
            ClassName = classBuffer.ToString(),
            Title = titleBuffer.ToString(),
            Visible = IsWindowVisible(window),
          });
        }
        return true;
      }, IntPtr.Zero);
    }
    return windows;
  }

  public static bool ShowRightClickMenu(uint processId, int timeoutMilliseconds) {
    var owners = ProcessWindows(processId);
    if (owners.Count == 0) return false;
    var host = owners.Find(window => window.ClassName == "BettboxTrayMenuHost");
    if (host != null) owners = new List<WindowInfo> { host };
    SetCursorPos(400, 400);
    foreach (var owner in owners) {
      PostMessage(owner.Handle, 0x0401, IntPtr.Zero, new IntPtr(0x0205));
    }
    int waited = 0;
    while (waited < timeoutMilliseconds) {
      if (Enumerate(processId, "#32768").Exists(window => window.Visible)) return true;
      Thread.Sleep(50);
      waited += 50;
    }
    return false;
  }

  public static void CloseMenu(uint processId) {
    foreach (var owner in ProcessWindows(processId)) {
      PostMessage(owner.Handle, 0x001F, IntPtr.Zero, IntPtr.Zero);
    }
  }
}
'@

$process = Get-Process -Name $ProcessName -ErrorAction Stop |
  Sort-Object StartTime |
  Select-Object -First 1
$configuration = @()
foreach ($root in @($env:APPDATA, $env:LOCALAPPDATA)) {
  $configuration += Get-ChildItem -Path $root -Filter "config.json" -File -Recurse `
    -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "bettbox" } |
    ForEach-Object {
      $config = Get-Content $_.FullName -Raw | ConvertFrom-Json
      [pscustomobject]@{
        Path = $_.FullName
        Left = $config.vpnProps.trayLeftClickBehavior
        Right = $config.vpnProps.trayRightClickBehavior
        Speed = $config.vpnProps.enableTraySpeed
      }
    }
}
$windows = [TrayProbe]::ProcessWindows([uint32]$process.Id)
if ($windows.Count -eq 0) {
  throw "$ProcessName 没有可接收托盘消息的顶层窗口"
}

$visible = [TrayProbe]::ShowRightClickMenu(
  [uint32]$process.Id,
  $TimeoutMilliseconds
)
[TrayProbe]::CloseMenu([uint32]$process.Id)

[pscustomobject]@{
  ProcessId = $process.Id
  ProductVersion = $process.MainModule.FileVersionInfo.ProductVersion
  Configuration = $configuration
  WindowCount = $windows.Count
  Windows = @($windows | ForEach-Object {
    [pscustomobject]@{
      Handle = $_.Handle.ToInt64()
      ClassName = $_.ClassName
      Title = $_.Title
      Visible = $_.Visible
    }
  })
  MenuVisible = $visible
} | ConvertTo-Json -Depth 4

if (-not $visible) {
  throw "模拟 Windows 托盘右键后未检测到可见菜单"
}
