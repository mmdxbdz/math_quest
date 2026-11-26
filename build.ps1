# 数学闯关岛 · 一键构建 APK
# 用法: powershell -File build.ps1
# 可用环境变量覆盖路径: FLUTTER_HOME / JDK_HOME / ANDROID_SDK_ROOT
$ErrorActionPreference = 'Stop'

function First-Existing([string[]]$Paths) {
  foreach ($p in $Paths) {
    if (Test-Path $p) { return (Resolve-Path $p).Path }
  }
  return $null
}

$flutterHome = $env:FLUTTER_HOME
if (-not $flutterHome) { $flutterHome = First-Existing @('G:\dev\flutter', 'D:\dev\flutter', 'C:\dev\flutter') }

$jdkHome = $env:JDK_HOME
if (-not $jdkHome) { $jdkHome = First-Existing @('G:\dev\jdk17', 'D:\dev\jdk17', 'C:\dev\jdk17') }

$androidHome = $env:ANDROID_SDK_ROOT
if (-not $androidHome) { $androidHome = First-Existing @('G:\dev\android-sdk', 'D:\dev\android-sdk') }

if (-not $flutterHome -or -not $jdkHome -or -not $androidHome) {
  Write-Host '找不到 Flutter / JDK17 / Android SDK。'
  Write-Host '请设置环境变量 FLUTTER_HOME / JDK_HOME / ANDROID_SDK_ROOT 后重试。'
  exit 1
}

$env:JAVA_HOME = $jdkHome
$env:ANDROID_HOME = $androidHome
$env:PUB_HOSTED_URL = 'https://pub.dev'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PATH = "$jdkHome\bin;$flutterHome\bin;$env:PATH"

Set-Location $PSScriptRoot

Write-Host "Flutter : $flutterHome"
Write-Host "JDK 17  : $jdkHome"
Write-Host "Android : $androidHome"

flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host 'pub get 失败'; exit 1 }

flutter build apk --release
if ($LASTEXITCODE -eq 0) {
  Write-Host ''
  Write-Host '构建成功！APK 位置：'
  Write-Host "$PSScriptRoot\build\app\outputs\flutter-apk\app-release.apk"
} else {
  Write-Host '构建失败，请检查上方日志。'
  exit 1
}
