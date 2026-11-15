# CINEMATIC MUSIC PLAYER - PRODUCTION BUILD REPORT

**Project Location:** `C:\MY PROJECTS`  
**Application Version:** `1.1.7+13`  
**Release Date:** 2026-11-15  
**Target Platforms:** Windows Desktop (x64), Android Mobile (API 21 - 36, ARM64/v7/x86_64)  

---

## 1. Executive Build Summary

| Artifact Name | Platform | File Size | Location | Build Status |
| :--- | :--- | :--- | :--- | :--- |
| **`CinematicMusicPlayerSetup.exe`** | Windows Desktop (x64) | **28.0 MB** (29,376,768 bytes) | [CinematicMusicPlayerSetup.exe](file:///C:/MY%20PROJECTS/dist/windows/CinematicMusicPlayerSetup.exe) | **SUCCESS (Compiled & Packaged with Inno Setup 6)** |
| **`CinematicMusicPlayer-Windows.zip`** | Windows Desktop (x64) | **38.5 MB** (40,417,821 bytes) | [CinematicMusicPlayer-Windows.zip](file:///C:/MY%20PROJECTS/dist/windows/CinematicMusicPlayer-Windows.zip) | **SUCCESS (Portable Distribution Archive)** |
| **`CinematicMusicPlayer-v1.1.7.apk`** | Android (API 21 - 36) | **66.7 MB** | [CinematicMusicPlayer-v1.1.7.apk](file:///C:/MY%20PROJECTS/dist/android/CinematicMusicPlayer-v1.1.7.apk) | **SUCCESS (Universal Multi-ABI Release)** |

---

## 2. Release v1.1.7 Architectural Enhancements

### YouTube Playback Fix & Native Stream Resolution
- Resolved Android playback bug where raw `youtube.com/watch?v=...` HTML web page URLs caused ExoPlayer `UnrecognizedInputFormatException` errors.
- Integrated `youtube_explode_dart: ^3.1.0` to extract direct high-bitrate Opus/AAC audio streams (`googlevideo.com`) on-the-fly.
- Added quota-free search and stream extraction fallback, eliminating dependence on Google Cloud YouTube Data API quota.
- Added safety guard in `PlayerNotifier` and `AudioEngine` preventing unplayable YouTube web page URLs (`youtube.com/watch`) from reaching ExoPlayer.
- Verified and protected JioSaavn 320kbps `.mp4` stream resolution and playback.

## 3. Release v1.1.6 Architectural Enhancements

### JioSaavn Bollywood Search & High-Bitrate Audio Streaming
- Integrated unofficial JioSaavn API wrapper via `jiosaavn_dart: ^1.0.0` with `just_audio` / `just_audio_windows`.
- Stream URL extraction: 320kbps AAC media stream decryption with real-time stream caching and playback.
- Synchronized / Plain Lyrics resolution and high-resolution album cover artwork.
- Dedicated `JioSaavnPage` with quick-filter chips for trending artists and songs.
- Pre-build verification: `lyrics:` and `fetchLyrics:` parameters verified against pub cache source.

## 3. Release v1.1.5 Architectural Enhancements

### Task 1: Fix Lag and Frame Drops
- **Studio Performance Modes**: Added Performance setting under Studio Settings with 4 selectable levels:
  - `High`: Unconstrained 60 FPS real-time audio wave analysis and glow.
  - `Balanced` (Default): 30 FPS capped analysis loop (`33ms` tick interval). Recommended for integrated Intel/AMD GPUs.
  - `Low`: 15 FPS analysis loop (`66ms` interval).
  - `Off`: Shuts down the periodic ticker completely and sets amplitude to zero, resulting in zero background CPU/GPU load.
- **Isolated Frame Rebuilding**:
  - Encapsulated seekbar slider into isolated `_IndependentSeekBar` widget, decoupling position ticks (200ms) from parent player screens and eliminating whole-tree rebuilding.
  - Downscaled extracted album artwork to $96\times 96$ via `ResizeImage` in `PaletteService`, eliminating UI frame stutter during track transitions.
- **Global Crash Logger**:
  - Initialized `CrashLogger` in `lib/main.dart` catching `FlutterError.onError` and `PlatformDispatcher.instance.onError`.
  - Writes diagnostics to `%USERPROFILE%/Documents/CinematicMusicPlayer/logs/app.log` with automatic 5MB log rotation (`app.old.log`).

### Task 2: High-DPI Display Sharpness Fix
- Updated `windows/runner/runner.exe.manifest` with both:
  - `<dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2</dpiAwareness>`
  - `<dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">true/pm</dpiAware>`
- Eliminates Windows GDI bitmap stretching on 125%, 150%, and 200% scaling, rendering all typography, custom painters, and icons at native sharpness.

### Task 3: 100% Free & Offline Local Music Vault
- Completely operational without any external or paid API key.
- Multi-folder library indexing via native `ScannerService.pickMusicFolder()`:
  - Folders are persisted in `SharedPreferences` (`cinematic_library_folders`) and `library_db.json`.
  - Background recursive isolate scan for MP3, FLAC, WAV, M4A, OGG, AAC, OPUS, and WMA.
  - Automatic startup folder rescanning and manual "Rescan Library" button in the library header.
  - All credentials (YouTube, Jamendo, Supabase) decoupled into git-ignored `lib/core/config/app_secrets.dart`.

### Task 5: Spotify-Style Desktop Player Interface
- **Collapsible Desktop Sidebar**:
  - Direct navigation to Home, Search, Your Library, Liked Songs, and custom Playlists.
  - Quick "+ Create Playlist" dialog.
- **Persistent Bottom Player Bar**:
  - Left: Thumbnail, title, artist, and favorite heart button.
  - Center: Shuffle, previous, play/pause, next, repeat, with dedicated independent seekbar and elapsed/duration counters.
  - Right: Studio visualizer mode indicator, volume slider with mute toggle, queue drawer toggle, and full-screen view button.
- **Sliding Queue Panel**:
  - Accessible via bottom right button or keyboard shortcut.
  - Live equalizer animation on playing track, track removal, drag-to-reorder via `ReorderableListView`, and "Clear Queue" button.
- **Tabbed Library Views**:
  - Songs: Tabular track list with `#`, title, album, duration, and contextual action menu.
  - Albums & Artists: Grid layouts with sample artwork and song counts.
  - Folders: Monitored folders list with "Add Folder", "Rescan All", and "Remove" actions.
- **Global Desktop Keyboard Shortcuts**:
  - `Space`: Play / Pause
  - `Ctrl + Right`: Skip to Next
  - `Ctrl + Left`: Skip to Previous
  - `Up` / `Down`: Volume $\pm 5\%$
  - `M`: Toggle Mute
  - `/` or `Ctrl + K`: Focus Search

---

## 3. Test Suite Verification

- **Total Test Cases**: 72
- **Pass Rate**: 100% (72/72 passing)
- **Execution Command**: `flutter test`
- **Coverage**: UserModel, Cloud Database Sync, Supabase Config, LRC Lyrics Engine, AppVersion Semantic Comparator, SongModel, ShaderCapabilityService, AudioMetadataParser, Playable Song Availability, AudioEngine, Cloud Streaming, MusicSource Architecture, InnerTubeX-inspired OnlineMusicSource, Bollywood Catalog System, YouTube Data API v3, Metrolist Backend Evolution & Stream Cache, Real Audio-Reactive Minimal Line Visualizer, Jamendo API, Android Background Playback & Media3, and Desktop Performance & Offline Library (v1.1.5).

---

## 2. Android Release Compilation Details

The Android application was compiled using **Flutter 3.50.0**, **Gradle 9.5.0**, **Android Gradle Plugin 9.3.1**, and **Microsoft OpenJDK 17.0.21 LTS**.

### Build Artifact Verification
* **File Path:** [CinematicMusicPlayer.apk](file:///C:/MY%20PROJECTS/dist/release/Android/CinematicMusicPlayer.apk)
* **Byte Size:** `63,881,067` bytes (60.9 MB)
* **Application ID / Package:** `com.cinematic.music.player`
* **Target SDK:** 34 | **Compile SDK:** 36 | **Min SDK:** 21
* **ABIs Included:**
  * `lib/arm64-v8a/libflutter.so` (Universal 64-bit ARM mobile CPUs)
  * `lib/armeabi-v7a/libflutter.so` (32-bit legacy mobile CPUs)
  * `lib/x86_64/libflutter.so` (Android Studio emulators & ChromeOS)

### Embedded Assets & Compilations
* **GPU Shaders:** Compiled and verified in `assets/flutter_assets/shaders/`
  * `orb_visualizer.frag` (3D Raymarched Liquid Orb)
  * `aurora_mesh.frag` (Dynamic Color Gradient Mesh)
* **Launcher Icon:** Master logo integrated into all mipmap buckets (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`).
* **Fonts:** MaterialIcons & CupertinoIcons tree-shaken and embedded.
* **Audio Engine:** `just_audio` + `audio_service` with foreground notification service.

---

## 3. Windows Desktop Build Status & Requirements

### Current Status: **BLOCKED BY OPERATING SYSTEM PERMISSIONS**
The Windows desktop compilation was attempted with `flutter build windows --release`. It halted with the following system requirement:

```text
Building with plugins requires symlink support.
Please enable Developer Mode in your system settings. Run:
  start ms-settings:developers
```

### Required Actions to Compile Windows Binary:
1. **Enable Windows Developer Mode:**
   * Open Windows Settings -> **Privacy & Security** -> **For Developers**.
   * Toggle **Developer Mode** to **ON**. (Allows Flutter to create symlinks for plugins).
2. **Install Visual Studio 2022 C++ Tools:**
   * The installer is staged at:
     ```text
     C:\Users\games\AppData\Local\Temp\WinGet\Microsoft.VisualStudio.2022.Community.17.14.45\vs_Community.exe
     ```
   * Run it, approve the UAC elevation prompt, and select **Desktop development with C++**.
3. **Execute One-Click Windows Packager:**
   * Once the above 2 steps are complete, run:
     ```powershell
     powershell -ExecutionPolicy Bypass -File "C:\MY PROJECTS\scripts\build_windows_release.ps1" -CreateInstaller
     ```
   * This will automatically build `cinematic_music_player.exe`, package `CinematicMusicPlayer.zip`, and invoke Inno Setup 6 (`ISCC.exe`) to generate `CinematicMusicPlayerSetup.exe` in `C:\MY PROJECTS\dist\release\Windows\`.

---

## 4. Verification & Known Issues Audit

| System / Feature | Reality Status | Notes / Limitations |
| :--- | :---: | :--- |
| **Audio Playback Engine** | **VERIFIED** | Gapless audio playback with audio focus, lock screen controls, and Android MediaSession foreground service. |
| **Local Music Import** | **VERIFIED** | Pure Dart ID3v2/FLAC/WAV/M4A/OGG metadata parser. No external native C libraries required for tag extraction. |
| **LRC Lyrics Synchronizer** | **VERIFIED** | Synchronized timestamp parser with dynamic active line bloom highlight and tap-to-seek. |
| **GPU Visualizers** | **VERIFIED** | GLSL 460 raymarched 3D liquid orb, polar ring, aurora gradient, and particles compiled into APK bundle. |
| **User Authentication** | **LOCAL MOCK** | User accounts are stored locally on-device in `cloud_vault/auth/accounts.json` with SHA-256 salted hashes. |
| **Cloud Synchronization** | **INCOMPLETE** | **No live remote backend exists.** Sync operates as a simulated vault on local disk. Two physically separate devices cannot sync across the internet without deploying a live REST server. |

---

## 5. Installation Instructions

### Android Mobile Installation:
1. Transfer `C:\MY PROJECTS\dist\release\Android\CinematicMusicPlayer.apk` to your phone via USB cable, Google Drive, or local file sharing.
2. Open the file on your Android device.
3. If prompted, allow **"Install unknown apps"** for your file browser.
4. Tap **Install** -> Open **Cinematic Music Player**.
5. Grant audio and file permissions to scan your music folders.

### Windows Desktop Installation (After Step 3 compilation):
1. Navigate to `C:\MY PROJECTS\dist\release\Windows\`.
2. Double-click `CinematicMusicPlayerSetup.exe`.
3. Follow the installation wizard (installs to `%LocalAppData%\Programs\Cinematic Music Player`).
4. Launch from the Desktop shortcut or Start Menu.
