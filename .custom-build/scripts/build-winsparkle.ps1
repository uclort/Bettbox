param(
  [Parameter(Mandatory=$true)][ValidateSet('amd64','arm64')][string]$Arch,
  [string]$PluginDir = 'windows/flutter/ephemeral/.plugin_symlinks/auto_updater_windows/windows',
  [string]$WorkDir = "$env:RUNNER_TEMP/bettbox-winsparkle"
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:CL = "$env:CL /utf-8"
$archive = Join-Path $WorkDir 'WinSparkle-0.8.1-src.zip'
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
if (-not (Test-Path $archive)) {
  Invoke-WebRequest 'https://github.com/vslavik/winsparkle/releases/download/v0.8.1/WinSparkle-0.8.1-src.zip' -OutFile $archive
}
if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne '3fd7f0fb79cea9b60e31029f7bfd3c4a3f287a9b1364cec31a1292074aa75223') {
  throw 'WinSparkle 源码摘要不匹配'
}
$source = Join-Path $WorkDir 'WinSparkle-0.8.1-src'
if (-not (Test-Path $source)) { Expand-Archive $archive -DestinationPath $WorkDir }
python (Join-Path $PSScriptRoot 'patch-winsparkle.py') $source
if ($LASTEXITCODE) { throw 'WinSparkle 补丁应用失败' }
$nuget = Get-Command nuget.exe -ErrorAction SilentlyContinue
if ($nuget) { $nugetPath = $nuget.Source } else {
  $nugetPath = Join-Path $WorkDir 'nuget.exe'
  if (-not (Test-Path $nugetPath)) {
    Invoke-WebRequest 'https://dist.nuget.org/win-x86-commandline/v6.14.0/nuget.exe' -OutFile $nugetPath
  }
}
& $nugetPath restore (Join-Path $source 'WinSparkle.sln') -NonInteractive
if ($LASTEXITCODE) { throw 'WinSparkle 依赖还原失败' }
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$msbuild = & $vswhere -latest -products '*' -requires Microsoft.Component.MSBuild -find 'MSBuild/**/Bin/MSBuild.exe' | Select-Object -First 1
if (-not $msbuild) { throw '未找到 MSBuild' }
$platform = if ($Arch -eq 'arm64') { 'ARM64' } else { 'x64' }
& $msbuild (Join-Path $source 'WinSparkle.vcxproj') /m /t:Build /p:MultiProcessorCompilation=true /p:Configuration=Release "/p:Platform=$platform" /p:PlatformToolset=v143 /verbosity:minimal
if ($LASTEXITCODE) { throw 'WinSparkle 编译失败' }
& (Join-Path $PSScriptRoot 'test-winsparkle-network.ps1') -Arch $Arch -Source $source
if ($LASTEXITCODE) { throw 'WinSparkle 网络回归失败' }
$destination = Join-Path $PluginDir "WinSparkle-0.8.1/$platform/Release"
if (-not (Test-Path $destination)) { throw '未找到目标架构的 WinSparkle 插件目录' }
foreach ($name in @('WinSparkle.dll','WinSparkle.lib')) {
  Copy-Item (Join-Path $source "$platform/Release/$name") (Join-Path $destination $name) -Force
}
Write-Output "WinSparkle $platform 网络与进度补丁构建完成"
