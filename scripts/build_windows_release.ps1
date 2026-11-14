# Automated Release Packager for Windows Desktop
Param (
    [switch]$CreateInstaller = $false
)

$ErrorActionPreference = "Stop"
$ProjectDir = "C:\MY PROJECTS"
Set-Location $ProjectDir

Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host "   CINEMATIC MUSIC PLAYER - WINDOWS RELEASE BUILD    " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Magenta

# 1. Fetch dependencies and compile shaders
Write-Host "`n[1/4] Running flutter pub get..." -ForegroundColor Yellow
flutter pub get

# 2. Build Release Windows Executable
Write-Host "`n[2/4] Compiling Windows x64 Release Binary..." -ForegroundColor Yellow
flutter build windows --release

$ReleaseDir = "$ProjectDir\build\windows\x64\runner\Release"
if (-not (Test-Path "$ReleaseDir\cinematic_music_player.exe")) {
    Write-Error "Build failed: cinematic_music_player.exe not found in $ReleaseDir"
}

# 3. Create Distribution Folder
$DistDir = "$ProjectDir\dist\windows"
$PortableDir = "$DistDir\CinematicMusicPlayer-v1.0.0-Windows-x64"
if (Test-Path $PortableDir) { Remove-Item -Recurse -Force $PortableDir }
New-Item -ItemType Directory -Path $PortableDir -Force | Out-Null

Write-Host "`n[3/4] Packaging portable distribution to $PortableDir..." -ForegroundColor Yellow
Copy-Item -Path "$ReleaseDir\*" -Destination $PortableDir -Recurse -Force

# Create ZIP archive
$ZipFile = "$DistDir\CinematicMusicPlayer-v1.0.0-Windows-x64.zip"
if (Test-Path $ZipFile) { Remove-Item -Force $ZipFile }
Compress-Archive -Path "$PortableDir\*" -DestinationPath $ZipFile -Force
Write-Host "Created portable archive: $ZipFile" -ForegroundColor Green

# 4. Optional Inno Setup compilation
if ($CreateInstaller) {
    Write-Host "`n[4/4] Attempting Inno Setup Installer Compilation..." -ForegroundColor Yellow
    $InnoPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (Test-Path $InnoPath) {
        & $InnoPath "$ProjectDir\windows\installer\cinematic_music_player.iss"
        Write-Host "Installer created in $DistDir\CinematicMusicPlayer-Setup-v1.0.0.exe" -ForegroundColor Green
    } else {
        Write-Host "Inno Setup compiler (ISCC.exe) not found at standard path. Use the generated portable zip or install Inno Setup 6 to compile the setup wizard." -ForegroundColor Yellow
    }
}

Write-Host "`n=====================================================" -ForegroundColor Magenta
Write-Host "             BUILD COMPLETED SUCCESSFULLY!           " -ForegroundColor Green
Write-Host " Executable: $PortableDir\cinematic_music_player.exe" -ForegroundColor White
Write-Host " Archive:    $ZipFile" -ForegroundColor White
Write-Host "=====================================================" -ForegroundColor Magenta
