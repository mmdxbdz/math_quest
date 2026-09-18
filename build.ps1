# 数学闯关 · 一键构建 APK
# 用法: powershell -File build.ps1
$env:JAVA_HOME = 'D:\dev\jdk17'
$env:ANDROID_HOME = 'D:\dev\android-sdk'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PATH = "$env:JAVA_HOME\bin;D:\dev\flutter\bin;$env:PATH"

Set-Location $PSScriptRoot
flutter build apk --release
if ($LASTEXITCODE -eq 0) {
  Write-Host ""
  Write-Host "构建成功！APK 位置："
  Write-Host "$PSScriptRoot\build\app\outputs\flutter-apk\app-release.apk"
} else {
  Write-Host "构建失败，请检查上方日志。"
}
