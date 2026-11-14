# 🎬 Cinematic Music Player v1.0.1 Production Release

Welcome to **Cinematic Music Player v1.0.1**! This is a complete production rebuild featuring standalone Windows distribution (self-contained installer and portable package), resolved Android audio service initialization, complete removal of all demo/placeholder tracks, enhanced album cover art extraction, and a streamlined cinematic interface.

---

## 💻 Windows Desktop Installation (Standalone Production Build)

End users do **NOT** need Flutter SDK, Visual Studio, C++ tools, or any developer dependencies. Simply download and install!

### 📥 Direct Downloads
* **[Download CinematicMusicPlayerSetup.exe](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.0.1/CinematicMusicPlayerSetup.exe)** (28.1 MB)
  * **SHA-256 Checksum:** `E9775F6AD914020C0486616BB4DE7BEAF310D74950DCCCA56282B5994D777FA0`
* **[Download CinematicMusicPlayer-Windows.zip](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.0.1/CinematicMusicPlayer-Windows.zip)** (38.6 MB, Portable Standalone)
  * **SHA-256 Checksum:** `FB0E79703FA93DB67DC3542FE5D22E9238779A2F4AD48209375D29379B69970D`

### 🖥️ Windows Quick Install:
1. Download **`CinematicMusicPlayerSetup.exe`** from GitHub Releases.
2. Run installer (double click).
3. Open **Cinematic Music Player** from Desktop or Start Menu.

---

## 📱 Android Installation (Production Build)

### 📥 Direct Download
* **[Download CinematicMusicPlayer.apk](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.0.1/CinematicMusicPlayer.apk)** (61.0 MB)
* **SHA-256 Checksum:** `2919405EA89A780CA7129BDDE7B2534AA3DE31F96D3F64822F46564B4F927571`
* **Package Version:** `1.0.1` (Version Code `3`)

### 📲 Android Quick Install:
1. Download **`CinematicMusicPlayer.apk`** to your phone.
2. Tap the downloaded file in your browser or Files app.
3. If Android prompts **"For your security, your phone is not allowed to install unknown apps from this source"**:
   - Tap **Settings**
   - Toggle **Allow from this source** to **ON**
   - Tap **Back** and select **Install**
4. Open app.

---

## 🛠️ Complete Fixes & Highlights in v1.0.1

### 🖥️ 1. Windows Runner & Invisible Window Fix
* **Resolved Invisible Window in Task Manager**:
  * **Inno Setup Working Directory**: Fixed Start Menu and Desktop shortcuts in `cinematic_music_player.iss` by enforcing `WorkingDir: "{app}"`. Previously, launching from shortcuts set the working directory to `C:\Windows\System32`, causing Flutter's `DartProject(L"data")` to fail to locate `app.so` and `icudtl.dat`.
  * **Native Window Visibility Guarantee**: Added explicit native Win32 `window.Show()` and centered window coordinates (`1280x800`) directly in the C++ runner `wWinMain`, guaranteeing the window appears immediately upon process launch.
  * **Modern DPI Awareness**: Added `runner.exe.manifest` supporting PerMonitorV2 DPI awareness for modern Windows 10 & 11 displays.

### 🎵 2. Fixed Android Audio Service Initialization (Audited against Metrolist)
* **Resolved "Audio service handler is not initialized"**:
  * **MainActivity `AudioServiceActivity` Integration**: Extended `AudioServiceActivity` instead of `FlutterActivity` in `MainActivity.kt`, granting the background audio service access to Flutter's engine isolate.
  * **Eager Initialization**: Restructured `AudioEngine` and `AudioService.init()` to ensure `CinematicAudioHandler` is non-null and ready before any playback requests occur.
  * **Persistent Broadcast Streams**: Bound position, duration, and playback state streams permanently so Riverpod listeners never receive null or dead streams.
  * **Storage & Notification Permissions**: Added `READ_MEDIA_AUDIO`, `READ_MEDIA_IMAGES`, and `POST_NOTIFICATIONS` permissions.

### 🧹 3. Purged All Fake Songs & Demo Content
* **Clean Empty Library**: Removed generated placeholder track names, mock catalogues, and the 6 MB bundled `bairan_demo.mp3`.
* **Zero Ghost Songs**: Only songs with a verified local audio file (`song.isLocalFileAvailable`) appear in the playable library.
* **Unavailable Track Guard**: If an audio file is deleted from storage, the app shows:
  > *"Audio file unavailable. Please import this song again."*

### 🖼️ 4. Enhanced Album Artwork Extraction
* **Embedded ID3/APIC Magic-Byte Extraction**: Rearchitected `AudioMetadataParser` to identify embedded JPEG (`FF D8 FF`) and PNG (`89 50 4E 47`) headers directly from byte streams, avoiding encoding corruptions.
* **Folder Art Support**: Scans local directory for `cover.jpg`, `folder.jpg`, and `album.png`.
* **Graceful Fallback**: Replaced broken image icons with a clean, dark-purple cinematic gradient placeholder with a subtle music note.

### ✨ 5. Clean Interface & Removed AI-Slop
* **Focused 4-Tab Navigation**: Clean core tabs (`Home`, `Library`, `Playlists`, `Settings`) across Desktop sidebar and Mobile navigation bar.
* **Streamlined Home Screen**: Removed cluttered curated banners and category badges; restored clean onboarding with a prominent "Import Music Files" action.
* **Retained Core Features**:
  * Synced LRC lyrics with Apple Music-style auto-scrolling and tap-to-seek.
  * Real-time 60 FPS audio visualizers (Raymarched Orb, Polar Circular Spectrum Ring, Aurora Mesh).
  * Equalizer, playback speed, and pitch controls.
  * Offline-first library management.

---

## ☁️ Cloud Account & Synchronization
* **Supabase Authentication**: Secure login, registration, and persistent sessions across Android and Windows.
* **Multi-Device Synchronization**: Starred favorites, playlists, play history, theme settings, and visualizer presets automatically synchronize between devices.
* **Offline-First Resilience**: Full offline functionality when disconnected; automatically syncs when internet connection is restored.
