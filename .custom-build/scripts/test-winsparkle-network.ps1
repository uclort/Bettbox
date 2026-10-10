param([Parameter(Mandatory=$true)][ValidateSet('amd64','arm64')][string]$Arch, [Parameter(Mandatory=$true)][string]$Source)
$ErrorActionPreference = 'Stop'
$platform = if ($Arch -eq 'arm64') { 'ARM64' } else { 'x64' }
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$vcvars = Join-Path $installation 'VC/Auxiliary/Build/vcvarsall.bat'
$hostArch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
$toolArch = if ($hostArch -eq 'arm64' -and $Arch -eq 'amd64') { 'arm64_x64' } elseif ($hostArch -eq 'x64' -and $Arch -eq 'arm64') { 'x64_arm64' } else { $hostArch }
$probeSource = Join-Path $PSScriptRoot 'updater-probe.cpp'
$serverSource = Join-Path $PSScriptRoot 'updater-feed-server.py'
$probe = Join-Path $Source "updater-probe-$platform.exe"
Push-Location $Source
try {
  cmd.exe /c "`"$vcvars`" $toolArch && cl /nologo /EHsc /utf-8 `"$probeSource`" /Fe:`"$probe`" /Fo:`"$Source/probe-$platform.obj`""
  if ($LASTEXITCODE) { throw 'WinSparkle 网络探针编译失败' }
} finally { Pop-Location }
$portFile = Join-Path $Source "probe-port-$platform.txt"
Remove-Item $portFile -Force -ErrorAction SilentlyContinue
$server = Start-Process python -ArgumentList @("`"$serverSource`"","`"$portFile`"") -PassThru -WindowStyle Hidden
try {
  for ($attempt = 0; $attempt -lt 100 -and -not (Test-Path $portFile); $attempt++) { if ($server.HasExited) { throw 'WinSparkle 测试 HTTP 服务提前退出' }; Start-Sleep -Milliseconds 100 }
  if (-not (Test-Path $portFile)) { throw 'WinSparkle 测试 HTTP 服务启动失败' }
  $port = (Get-Content $portFile -Raw).Trim()
  foreach ($mode in @('gzip','deflate','flaky')) {
    Write-Output "WinSparkle $platform 网络回归：$mode"
    & $probe (Join-Path $Source "$platform/Release/WinSparkle.dll") "http://127.0.0.1:$port/$mode"
    if ($LASTEXITCODE) { throw "WinSparkle $mode 连续检查失败" }
  }
} finally {
  Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
  Remove-Item $portFile -Force -ErrorAction SilentlyContinue
}
