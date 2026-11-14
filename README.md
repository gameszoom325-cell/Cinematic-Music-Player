# Cinematic Music Player

<p align="center">
  <img src="assets/icons/app_icon.png" width="130" height="130" alt="Cinematic Music Player Logo" />
</p>

<p align="center">
  <strong>A premium, 100% private cross-platform music player and audio sanctuary.</strong><br>
  Built with Impeller GLSL 460 fragment shaders, gapless audio engines, and multi-device cloud synchronization.
</p>

<p align="center">
  <a href="https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/latest"><img src="https://img.shields.io/badge/Release-v1.0.2-blueviolet.svg?style=flat-square" alt="Latest Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License: MIT"></a>
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
  - Shows update notifications when a new version is available with direct download links.

---

## Download & Install

Get the latest verified production release from [GitHub Releases](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/latest).

### Windows

1. Download **`CinematicMusicPlayerSetup.exe`** from GitHub Releases.
2. Run installer.
3. Open app.

*(A portable standalone archive `CinematicMusicPlayer-Windows.zip` is also available if you prefer running without installation).*

---

### Android

1. Download **`CinematicMusicPlayer.apk`** from GitHub Releases.
2. Tap the downloaded file and allow installation (*"Allow from this source"* if prompted).
3. Open app.

---

## Release Downloads Matrix

| Target Platform | Asset Filename | Package Type | Size | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Windows Desktop** | [CinematicMusicPlayerSetup.exe](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.0.1/CinematicMusicPlayerSetup.exe) | Self-Contained Installer | ~35.5 MB | Complete Windows installer wizard with Start Menu and Desktop shortcuts. |
| **Windows Desktop** | [CinematicMusicPlayer-Windows.zip](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.0.1/CinematicMusicPlayer-Windows.zip) | Portable Archive | ~46.5 MB | Standalone portable folder with executable, DLLs, and shaders. |
| **Android Mobile** | [CinematicMusicPlayer.apk](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.0.1/CinematicMusicPlayer.apk) | Signed Release APK | ~66.9 MB | Direct installable APK targeting Android 6.0 through Android 14+. |

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
