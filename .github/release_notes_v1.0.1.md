# 🎬 Cinematic Music Player v1.0.1 Release

Welcome to **Cinematic Music Player v1.0.1**! This is a stability and bug-fix release addressing Android music library scanning, file attachment, audio playback initialization, and robust player error handling.

---

## 📱 Android Installation (Production Build)

### 📥 Direct Download
* **[Download CinematicMusicPlayer.apk](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.0.1/CinematicMusicPlayer.apk)** (66.9 MB)
* **SHA-256 Checksum:** `4394A786CE4766279F2D71CFC70E1C3DC085035E7E3255362DD73AC6056DAA18`
* **Package Version:** `1.0.1` (Build `2`)

### 📲 Quick Install Guide for Android:
1. Tap the download link above to download **`CinematicMusicPlayer.apk`** to your phone.
2. Tap the downloaded file in your browser or Files app.
3. If Android prompts **"For your security, your phone is not allowed to install unknown apps from this source"**:
   - Tap **Settings**
   - Toggle **Allow from this source** to **ON**
   - Tap **Back** and select **Install**
4. Open **Cinematic Music Player**.
5. Grant audio and storage permissions to scan your music folders or import your personal MP3 collection!

---

## 🛠️ What's Fixed & Improved in v1.0.1

### 🎵 1. Fixed Android Music Playback Engine
* **Tapping Songs Starts Playback Immediately**: Fixed playlist queue setup and URI resolution in `CinematicAudioHandler` so tapping any song in Library, Home, Hindi Collection, or Playlists instantly begins audio playback.
* **Content and File URI Support (`parseAudioUri`)**: Handles both native `file://` filesystem paths and Android SAF `content://` URIs seamlessly, preventing ExoPlayer source failures.
* **Active Controls & Progress**: Play, pause, seek, next track, previous track, shuffle, and repeat modes are wired and synchronized with the background audio service.

### 📁 2. Fixed Songs Appearing Without Audio Files (Ghost Track Purge)
* **Playable Library Verification**: Only songs with a verified, accessible local audio file (`song.isLocalFileAvailable`) are added to the playable library.
* **Friendly Unavailable Song Guard**: If an audio file was moved or deleted from the device, the app alerts the user:
  > *"Audio file unavailable. Please import this song again."*
  instead of freezing or crashing.
* **Zero Fake Songs**: Removed mock entries from database initialization; pre-seeded catalogue entries serve strictly as lyrics templates ready to link with real local MP3 files.

### 📥 3. Improved Music Import Reliability
* **Modern & Legacy Android Permissions**: Robust handling for both Android 13+ (`Permission.audio`) and Android 10-12 (`Permission.storage` + `requestLegacyExternalStorage="true"`).
* **Native Audio File Picker**: Configured `FileType.audio` in `FilePicker` so the Android document picker displays all audio files (`audio/*`) without graying them out.
* **Persistent Import Storage**: When importing via file picker, temporary cache paths are permanently copied into the app's private documents directory so tracks remain available across device restarts and cache clearing.
* **Expanded Scan Directories**: Auto-detects tracks across `/storage/emulated/0/Music`, `/storage/emulated/0/Download`, `/storage/emulated/0/Downloads`, and external SD cards.

### 🛡️ 4. Improved Player Error Handling & Android Stability
* **No More Silent Failures**: Added `errorMessage` tracking in Riverpod `playerProvider` and automatic floating error SnackBars in `AppShell` with full stack logging for troubleshooting.
* **ExoPlayer Error Listeners**: Intercepts playback errors in `playbackEventStream` and safely recovers playback state.
* **Bundled High-Fidelity Demo Track**: Bundles a real, authentic studio track (`Bairan (Demo)`) and three synthesized 44.1 kHz 16-bit PCM WAV tracks with valid waveforms and synchronized LRC lyrics.

---

## ☁️ Cloud Account & Synchronization
* **Supabase Authentication**: Secure login, registration, and persistent sessions across Android and Windows.
* **Multi-Device Synchronization**: Starred favorites, playlists, play history, theme settings, and visualizer presets automatically synchronize between devices.
* **Offline-First Resilience**: Full offline functionality when disconnected; automatically syncs when internet connection is restored.
