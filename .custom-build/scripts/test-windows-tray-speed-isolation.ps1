param(
  [string]$AppPath = "C:\Program Files\Bettbox\Bettbox.exe"
)

$ErrorActionPreference = "Stop"
$configPath = Join-Path $env:APPDATA "com.appshub\Bettbox\config.json"
$probePath = Join-Path $PSScriptRoot "test-windows-tray-menu.ps1"
$backupPath = "$configPath.tray-test-backup"

if (-not (Test-Path $configPath)) {
  throw "未找到 Bettbox 配置：$configPath"
}
if (-not (Test-Path $AppPath)) {
  throw "未找到 Bettbox：$AppPath"
}
if (Test-Path $backupPath) {
  throw "已存在配置备份，请先恢复或检查：$backupPath"
}

function Stop-TestApp {
  $processes = @(Get-Process -Name "Bettbox" -ErrorAction SilentlyContinue)
  if ($processes.Count -eq 0) { return }
  $processes | Stop-Process -Force -ErrorAction Stop
  $processes | Wait-Process -Timeout 10 -ErrorAction Stop
  if (Get-Process -Name "Bettbox" -ErrorAction SilentlyContinue) {
    throw "Bettbox 未完全退出，不能修改配置或进行有效的 A/B 测试"
  }
}

Copy-Item $configPath $backupPath -Force
try {
  Stop-TestApp
  $raw = [IO.File]::ReadAllText($configPath)
  $updated = [regex]::Replace(
    $raw,
    '("enableTraySpeed"\s*:\s*)true',
    '${1}false',
    [Text.RegularExpressions.RegexOptions]::IgnoreCase
  )
  if ($updated -eq $raw) {
    throw "配置中未找到已开启的 enableTraySpeed"
  }
  [IO.File]::WriteAllText(
    $configPath,
    $updated,
    [Text.UTF8Encoding]::new($false)
  )
  Start-Process $AppPath
  Start-Sleep -Seconds 8
  & $probePath
} finally {
  try {
    Stop-TestApp
  } finally {
    Move-Item $backupPath $configPath -Force
  }
  Start-Process $AppPath
}
