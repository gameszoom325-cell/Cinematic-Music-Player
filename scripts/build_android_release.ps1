# Automated Release Packager for Android Mobile
$ErrorActionPreference = "Stop"
$ProjectDir = "C:\MY PROJECTS"
Set-Location $ProjectDir

Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host "    CINEMATIC MUSIC PLAYER - ANDROID APK RELEASE     " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Magenta

# 1. Fetch dependencies and compile shaders
Write-Host "`n[1/3] Running flutter pub get..." -ForegroundColor Yellow
flutter pub get

# 2. Build Release APK
Write-Host "`n[2/3] Compiling Android Release APK..." -ForegroundColor Yellow
flutter build apk --release

$BuiltApk = "$ProjectDir\build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $BuiltApk)) {
    Write-Error "Build failed: app-release.apk not found in $BuiltApk"
}

# 3. Create Distribution Folder
$DistDir = "$ProjectDir\dist\android"
if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir -Force | Out-Null }

$TargetApk = "$DistDir\CinematicMusicPlayer.apk"
Copy-Item -Path $BuiltApk -Destination $TargetApk -Force

# Calculate SHA-256 hash
$Hash = (Get-FileHash -Path $TargetApk -Algorithm SHA256).Hash

Write-Host "`n=====================================================" -ForegroundColor Magenta
Write-Host "           ANDROID APK COMPLETED SUCCESSFULLY!       " -ForegroundColor Green
Write-Host " APK Path: $TargetApk" -ForegroundColor White
Write-Host " Size:     $(([math]::Round((Get-Item $TargetApk).Length / 1MB, 2))) MB" -ForegroundColor White
Write-Host " SHA-256:  $Hash" -ForegroundColor White
Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host "`nTo install on your phone:" -ForegroundColor Cyan
Write-Host "  1. Transfer '$TargetApk' to your phone via USB or Cloud Drive."
Write-Host "  2. In Android Settings, allow installation from your file manager."
Write-Host "  3. Tap the APK file and select 'Install'."
Write-Host "  4. Launch 'Cinematic Music Player' and log in to sync your vault!"
