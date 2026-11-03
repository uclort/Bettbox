param(
  [string]$ProcessName = "Bettbox",
  [int]$TimeoutMilliseconds = 3000,
  [switch]$AltClick,
  [switch]$ExternalAlt,
  [int]$HoldAltMilliseconds = 1500
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
  [DllImport("user32.dll")]
  private static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);
  [DllImport("user32.dll")]
  private static extern short GetAsyncKeyState(int virtualKey);

  private static void SetAlt(bool down) {
    const byte VK_MENU = 0x12;
    const uint KEYEVENTF_KEYUP = 0x0002;
    keybd_event(VK_MENU, 0, down ? 0 : KEYEVENTF_KEYUP, UIntPtr.Zero);
  }

  private static bool IsMenuVisible(uint processId) {
    return Enumerate(processId, "#32768").Exists(window => window.Visible);
  }

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

  // BETTBOX-CUSTOM: hold Alt to simulate a tray click; distinguish "closes only
  // after Alt is released" from "closes while Alt is still held".
  public static string ProbeAltClickMenu(
      uint processId, int holdMilliseconds, int timeoutMilliseconds) {
    var owners = ProcessWindows(processId);
    if (owners.Count == 0) return "no-window";
    var host = owners.Find(window => window.ClassName == "BettboxTrayMenuHost");
    if (host != null) owners = new List<WindowInfo> { host };
    SetCursorPos(400, 400);
    SetAlt(true);
    Thread.Sleep(60);
    // The injected Alt must be visible to GetAsyncKeyState, otherwise the app
    // opens the cached native menu instead of the hidden-groups menu.
    bool altDown = (GetAsyncKeyState(0x12) & 0x8000) != 0;
    foreach (var owner in owners) {
      PostMessage(owner.Handle, 0x0401, IntPtr.Zero, new IntPtr(0x0205));
    }
    int waited = 0;
    while (waited < timeoutMilliseconds && !IsMenuVisible(processId)) {
      Thread.Sleep(50);
      waited += 50;
    }
    if (!IsMenuVisible(processId)) {
      SetAlt(false);
      return "menu-not-shown|altDown=" + altDown + "|appearMs=" + waited;
    }
    int held = 0;
    while (held < holdMilliseconds) {
      Thread.Sleep(50);
      held += 50;
      if (!IsMenuVisible(processId)) {
        SetAlt(false);
        return "closed-while-alt-held|altDown=" + altDown + "|appearMs=" +
            waited + "|closedAtMs=" + held;
      }
    }
    SetAlt(false);
    Thread.Sleep(300);
    return (IsMenuVisible(processId)
        ? "still-open-after-alt-release"
        : "closed-on-alt-release") + "|altDown=" + altDown + "|appearMs=" +
        waited + "|holdMs=" + held;
  }

  // BETTBOX-CUSTOM: Alt is injected by the host (press Option on the Mac while
  // the Parallels window is frontmost), so this mode only posts the tray click
  // and reports when the menu disappears.
  public static string MonitorMenuAfterClick(
      uint processId, int monitorMilliseconds) {
    var owners = ProcessWindows(processId);
    if (owners.Count == 0) return "no-window";
    var host = owners.Find(window => window.ClassName == "BettboxTrayMenuHost");
    if (host != null) owners = new List<WindowInfo> { host };
    bool altDown = (GetAsyncKeyState(0x12) & 0x8000) != 0;
    SetCursorPos(400, 400);
    foreach (var owner in owners) {
      PostMessage(owner.Handle, 0x0401, IntPtr.Zero, new IntPtr(0x0205));
    }
    int waited = 0;
    while (waited < 3000 && !IsMenuVisible(processId)) {
      Thread.Sleep(25);
      waited += 25;
    }
    if (!IsMenuVisible(processId)) {
      return "menu-not-shown|altDown=" + altDown;
    }
    int held = 0;
    while (held < monitorMilliseconds) {
      Thread.Sleep(25);
      held += 25;
      if (!IsMenuVisible(processId)) {
        return "menu-closed|altDown=" + altDown + "|appearMs=" + waited +
            "|closedAtMs=" + held;
      }
    }
    return "menu-still-open|altDown=" + altDown + "|appearMs=" + waited +
        "|monitorMs=" + held;
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

if ($ExternalAlt) {
  $altResult = [TrayProbe]::MonitorMenuAfterClick(
    [uint32]$process.Id,
    $HoldAltMilliseconds
  )
  [TrayProbe]::CloseMenu([uint32]$process.Id)
  [pscustomobject]@{
    ProcessId = $process.Id
    ProductVersion = $process.MainModule.FileVersionInfo.ProductVersion
    Configuration = $configuration
    ExternalAlt = $altResult
  } | ConvertTo-Json -Depth 4
  exit 0
}

if ($AltClick) {
  $altResult = [TrayProbe]::ProbeAltClickMenu(
    [uint32]$process.Id,
    $HoldAltMilliseconds,
    $TimeoutMilliseconds
  )
  [TrayProbe]::CloseMenu([uint32]$process.Id)
  [pscustomobject]@{
    ProcessId = $process.Id
    ProductVersion = $process.MainModule.FileVersionInfo.ProductVersion
    Configuration = $configuration
    AltClick = $altResult
  } | ConvertTo-Json -Depth 4
  if ($altResult -notlike "still-open-after-alt-release*") {
    throw "按住 Alt 打开托盘菜单后未保持打开：$altResult"
  }
  exit 0
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
