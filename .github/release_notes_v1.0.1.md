# 🎬 Cinematic Music Player v1.0.1 Release

Welcome to **Cinematic Music Player v1.0.1**! This release brings full standalone Windows distribution (self-contained installer and portable package with zero developer dependencies), resolved Android music playback, library integrity guards, and in-app GitHub update checker integration.

---

## 💻 Windows Desktop Installation (Standalone Production Build)

End users do **NOT** need Flutter SDK, Visual Studio, C++ tools, or any developer dependencies. Simply download and install!

### 📥 Direct Downloads
* **[Download CinematicMusicPlayerSetup.exe](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.0.1/CinematicMusicPlayerSetup.exe)** (35.5 MB)
  * **SHA-256 Checksum:** `5A25561C756B1C754023936498430971AC0DED821A4D216B6965F2AE658F3DBF`
* **[Download CinematicMusicPlayer-Windows.zip](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.0.1/CinematicMusicPlayer-Windows.zip)** (46.5 MB, Portable Standalone)
  * **SHA-256 Checksum:** `523E4C448456DCC74C9A9F079E3963702F696D7ABEF789211055339DEFB330A5`

### 🖥️ Windows Quick Install:
1. Download **`CinematicMusicPlayerSetup.exe`** from GitHub Releases.
2. Run installer.
3. Open app.

---

## 📱 Android Installation (Production Build)

### 📥 Direct Download
* **[Download CinematicMusicPlayer.apk](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.0.1/CinematicMusicPlayer.apk)** (66.9 MB)
* **SHA-256 Checksum:** `D14B04BD8D1F691E890EEC64D9600B34730DD1694869EB19A1FBBD34FA2DE052`
* **Package Version:** `1.0.1` (Build `2`)

### 📲 Android Quick Install:
1. Download **`CinematicMusicPlayer.apk`** to your phone.
2. Tap the downloaded file in your browser or Files app.
3. If Android prompts **"For your security, your phone is not allowed to install unknown apps from this source"**:
   - Tap **Settings**
   - Toggle **Allow from this source** to **ON**
   - Tap **Back** and select **Install**
4. Open app.

---

## 🛠️ What's New & Fixed in v1.0.1

### 🚀 1. Windows Standalone Distribution & In-App Update Checker
* **Self-Contained Installer (`CinematicMusicPlayerSetup.exe`)**: Built with Inno Setup 6. Includes all compiled native AOT libraries (`app.so`), Flutter Windows engine DLLs, shaders, ICU locale definitions, and assets. End users double-click and play.
* **In-App GitHub Update Checker**: Connects to the GitHub Releases API. When a newer version is detected, users are prompted with:
  * Title: `"New version available"`
  * Actions: `[Download Update]` (launches direct download) and `[Later]` (dismisses dialog).

### 🎵 2. Fixed Android Music Playback Engine & Background Service
* **Resolved "Audio service handler is not initialized"**:
  * **MainActivity `AudioServiceActivity` Integration**: Changed `MainActivity.kt` to extend `AudioServiceActivity` instead of `FlutterActivity`, granting the Android foreground service access to the cached FlutterEngine isolate.
  * **Android 13+ Notification Permissions**: Added `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />` to `AndroidManifest.xml` to prevent foreground media notification crashes.
  * **Resilient AudioEngine Initialization**: Rearchitected `AudioEngine` to instantiate `CinematicAudioHandler` eagerly and provide a non-null handler, eliminating race conditions between UI state bindings and background service registration.
  * **Persistent Broadcast Reactive Streams**: Bound audio position, duration, playing, buffered position, and processing state streams as permanent broadcast streams so Riverpod UI listeners never receive dead empty streams.
  * **Visual Loading State**: Introduced `isLoading` in `CinematicPlayerState` with spinner feedback in both the full player and mini-player bar while ExoPlayer buffers track streams.
* **Tapping Songs Starts Playback Immediately**: Fixed playlist queue setup and URI resolution in `CinematicAudioHandler` so tapping any song in Library, Home, Hindi Collection, or Playlists instantly begins audio playback.
* **Content and File URI Support (`parseAudioUri`)**: Handles both native `file://` filesystem paths and Android SAF `content://` URIs seamlessly, preventing ExoPlayer source failures.
* **Active Controls & Progress**: Play, pause, seek, next track, previous track, shuffle, and repeat modes are wired and synchronized with the background audio service.

### 📁 3. Removed Fake Songs & Ghost Track Purge
* **Playable Library Verification**: Only songs with a verified, accessible local audio file (`song.isLocalFileAvailable`) are added to the playable library.
* **Friendly Unavailable Song Guard**: If an audio file was moved or deleted from the device, the app alerts the user:
  > *"Audio file unavailable. Please import this song again."*
  instead of freezing or crashing.
* **Zero Fake Songs**: Removed mock entries from database initialization; pre-seeded catalogue entries serve strictly as lyrics templates ready to link with real local MP3 files.

### 📥 4. Improved Music Import Reliability
* **Modern & Legacy Android Permissions**: Robust handling for both Android 13+ (`Permission.audio`) and Android 10-12 (`Permission.storage` + `requestLegacyExternalStorage="true"`).
* **Native Audio File Picker**: Configured `FileType.audio` in `FilePicker` so the Android document picker displays all audio files (`audio/*`) without graying them out.
* **Persistent Import Storage**: When importing via file picker, temporary cache paths are permanently copied into the app's private documents directory so tracks remain available across device restarts and cache clearing.
* **Expanded Scan Directories**: Auto-detects tracks across `/storage/emulated/0/Music`, `/storage/emulated/0/Download`, `/storage/emulated/0/Downloads`, and external SD cards.

### 🛡️ 5. Bundled High-Fidelity Demo Audio & Player Error Handling
* **Bundled High-Fidelity Demo Track**: Bundles a real, authentic studio track (`Bairan (Demo)`) and three synthesized 44.1 kHz 16-bit PCM WAV tracks with valid waveforms and synchronized LRC lyrics.
* **No More Silent Failures**: Added `errorMessage` tracking in Riverpod `playerProvider` and automatic floating error SnackBars in `AppShell` with full stack logging for troubleshooting.
* **ExoPlayer Error Listeners**: Intercepts playback errors in `playbackEventStream` and safely recovers playback state.

---

## ☁️ Cloud Account & Synchronization
* **Supabase Authentication**: Secure login, registration, and persistent sessions across Android and Windows.
* **Multi-Device Synchronization**: Starred favorites, playlists, play history, theme settings, and visualizer presets automatically synchronize between devices.
* **Offline-First Resilience**: Full offline functionality when disconnected; automatically syncs when internet connection is restored.
