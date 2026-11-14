# Cinematic Music Player

<p align="center">
  <img src="assets/icons/app_icon.png" width="130" height="130" alt="Cinematic Music Player Logo" />
</p>

<p align="center">
  <strong>A premium, 100% private cross-platform music player and audio sanctuary.</strong><br>
  Built with Flutter, Impeller GLSL 460 fragment shaders, gapless audio engines, and multi-device cloud synchronization.
</p>

<p align="center">
  <a href="https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/latest"><img src="https://img.shields.io/badge/Release-v1.0.1-blueviolet.svg?style=flat-square" alt="Latest Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License: MIT"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%3E%3D3.19.0-02569B.svg?style=flat-square&logo=flutter" alt="Flutter"></a>
  <img src="https://img.shields.io/badge/Platforms-Windows%20%7C%20Android-success.svg?style=flat-square" alt="Platforms">
</p>

---

## Key Features

- **100% Private Offline Audio Vault**:
  - Recursively scans local folders for `MP3`, `FLAC`, `WAV`, `M4A`, and `OGG` files.
  - Zero scraping, zero third-party telemetry, zero external dependencies to play your collection.
  - High-performance binary metadata reader extracts ID3v2 APIC and FLAC PICTURE embedded covers.

- **GPU Audio-Reactive Visualizers (GLSL 460)**:
  - **Preset 1 (3D Liquid Raymarched Orb)**: Real-time SDF sphere with 3D simplex noise surface displacement reactive to bass, mid-range waves, and treble highlights.
  - **Preset 2 (Polar Circular Spectrum Ring)**: 64-bar frequency ring with beat synchronization running at a fluid 60-120 FPS.
  - **Preset 3 (Aurora Dynamic Mesh Gradient)**: Multi-octave domain-warped mesh gradient derived from the active album art palette.
  - **Atmospheric Simulations**: Interactive Rain, Snow, Floating Dust, and Fireflies particle physics.

- **Synchronized Lyrics Engine**:
  - Reads companion `.lrc` files automatically.
  - Smooth viewport centering with active line bloom highlight and dimmed upcoming lines.
  - Interactive **Tap-to-Seek** to jump playback directly to any lyric timestamp.

- **Multi-Device Account & Cloud Synchronization**:
  - Single account across **Windows Desktop** and **Android Mobile**.
  - Two-way synchronization of playlists, starred favorites, playback counts, history, visualizer settings, and theme preferences.
  - Hardware device management with active heartbeat tracking and remote session revocation.

- **In-App Auto Update Checker**:
  - Automatically queries GitHub Releases on startup.
  - Informs users with a release dialog and direct download links for installers and APKs.

---

# Download & Install

Download the verified production release from [GitHub Releases](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/latest).

### Windows Desktop

**Downloads Available**:
- Installer Setup: `CinematicMusicPlayerSetup.exe`
- Portable Archive: `CinematicMusicPlayer-Windows.zip`

**Steps**:
1. Open [GitHub Releases](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/latest).
2. Download `CinematicMusicPlayerSetup.exe` (or the portable `.zip` version).
3. Run the installer (or extract the `.zip` folder).
4. Open **Cinematic Music Player** from your Start Menu or Desktop shortcut!

---

### Android Mobile

**Download Available**:
- Production APK: `CinematicMusicPlayer.apk`

**Steps**:
1. Open [GitHub Releases](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/latest) on your phone and download `CinematicMusicPlayer.apk`.
2. Allow installation permission in Android settings when prompted (*"Allow from this source"*).
3. Install `CinematicMusicPlayer.apk`.
4. Open **Cinematic Music Player** and enjoy your private audio vault!

---

## Release Assets Matrix

| Target Platform | Asset Filename | Package Type | Description |
| :--- | :--- | :--- | :--- |
| **Windows Desktop** | `CinematicMusicPlayerSetup.exe` | Setup Wizard | Inno Setup installation wizard with Start Menu, Desktop shortcuts, and uninstaller. |
| **Windows Desktop** | `CinematicMusicPlayer-Windows.zip` | Portable Archive | Standalone portable folder with executable, DLLs, and shaders. |
| **Android Mobile** | `CinematicMusicPlayer.apk` | Signed Release APK | Direct sideloadable APK targeting Android 6.0 (API 23) through Android 14 (API 34). |

---

## Build from Source

### Prerequisites
- **Flutter SDK**: `>= 3.19.0` (Recommended `3.24.x` / `3.27.x`)
- **Dart SDK**: `>= 3.3.0 < 4.0.0`
- **Windows**: Visual Studio 2022 with **"Desktop development with C++"**
- **Android**: Android Studio with Android SDK 34 and JDK 17

### 1. Windows Desktop Build
```powershell
# Clone the repository
git clone https://github.com/gameszoom325-cell/Cinematic-Music-Player.git
cd Cinematic-Music-Player

# Build release using automated packager
powershell .\scripts\build_windows_release.ps1

# Or standard Flutter build
flutter pub get
flutter build windows --release
```
The output binary will be located at:
`build/windows/x64/runner/Release/cinematic_music_player.exe`

### 2. Android APK Build
```powershell
# Build release APK using automated packager
powershell .\scripts\build_android_release.ps1

# Or standard Flutter build
flutter pub get
flutter build apk --release
```
The output APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## How to Release a New Version

1. **Update Version**:
   - Update `version: X.Y.Z+B` in `pubspec.yaml`.
   - Update `static const String current = "X.Y.Z"` in `lib/core/services/update_service.dart`.
2. **Commit and Tag**:
   ```bash
   git add .
   git commit -m "chore: release vX.Y.Z"
   git tag vX.Y.Z
   git push origin main --tags
   ```
3. **Automated CI/CD**:
   - The GitHub Actions workflow (`.github/workflows/release.yml`) triggers automatically.
   - Compiles Windows `.exe`, Windows installer, and Android `.apk`.
   - Publishes the GitHub Release with attached assets and release notes.
4. **User In-App Notifications**:
   - Running clients check GitHub Releases and present the update dialog automatically.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
