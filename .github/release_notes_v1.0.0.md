# 🎬 Cinematic Music Player v1.0.0 Release

Welcome to the **Cinematic Music Player v1.0.0**! A private, local-first, high-fidelity offline music player featuring real-time GPU visualizers, synchronized LRC lyrics, and automatic multi-device cloud synchronization.

---

## 📱 Android Installation (Ready for Friends)

### 📥 Direct Download
* **[Download CinematicMusicPlayer.apk](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.0.0/CinematicMusicPlayer.apk)** (61.1 MB)
* **SHA-256 Checksum:** `07790A515B8123ACD86458AC321FFE0DD8AD960909240CD8DF7EE208FB2E761B`

### 📲 Quick Install Guide for Android:
1. Tap the download link above to download **`CinematicMusicPlayer.apk`** to your phone.
2. Tap the downloaded file in your browser or Files app.
3. If Android prompts **"For your security, your phone is not allowed to install unknown apps from this source"**:
   - Tap **Settings**
   - Toggle **Allow from this source** to **ON**
   - Tap **Back** and select **Install**
4. Open **Cinematic Music Player**.
5. Grant audio and storage permissions to scan your music folders.

---

## 🛠️ Post-Login Runtime & Black Screen Fixes (v1.0.0 Hotfix)
* **Glassmorphic Invariant Resolution**: Fixed Flutter `BoxDecoration` assertion error (`color == null || gradient == null`) in `CinematicGlassCard` which caused `HomeScreen` and `AppShell` to crash into Flutter's default release black screen.
* **Resilient AudioEngine Lifecycle**: Made `AudioEngine` stream listeners and playback controls completely null-safe (`_handler?.player... ?? const Stream.empty()`), preventing unhandled `StateError` crashes when `AudioService` is still initializing on Android.
* **AudioServiceHandler Null Map Lookup**: Replaced unsafe map lookups with safe default `AudioProcessingState.idle` fallback.
* **Riverpod State Flow Synchronized**: Wired `LoginScreen`, `RegisterScreen`, and `WelcomeScreen` directly to `authProvider.notifier`, guaranteeing authenticated user state is immediately available when `AppShell` mounts.
* **Shader Capability Auto-Fallback**: Integrated `ShaderCapabilityService` with proactive GPU fragment shader validation; if GLSL runtime shaders are unsupported on the Android GPU or throw during painting, rendering automatically and gracefully falls back to high-performance Canvas 3D visualizers.
* **Global Error Boundary**: Replaced Flutter's blank black screen release error builder with a styled, informative recovery screen with an "Enter Player" reset button.

---

## 💻 Windows Desktop Setup Instructions

To build the native Windows `.exe` and setup installer locally:

1. **Enable Developer Mode**:
   - Press `Win + R`, type `ms-settings:developers`, and toggle **Developer Mode** to **ON**.
2. **Install Visual Studio C++ Compiler**:
   - Run the Visual Studio Installer and check **"Desktop development with C++"**.
3. **Build the Windows Executable & Inno Setup Installer**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\build_windows_release.ps1 -CreateInstaller
   ```
   This automatically produces:
   - Portable Zip: `dist\release\Windows\CinematicMusicPlayer.zip`
   - Setup Installer: `dist\release\Windows\CinematicMusicPlayerSetup.exe`

---

## ☁️ Real Cloud Backend & Database Synchronization
* **Authentication Engine**: Real Supabase GoTrue Auth API supporting secure registration, JWT bearer tokens, session renewal, and password salting.
* **Database Synchronization**: Multi-device sync for Playlists, Starred Favorites, Recently Played, Listening History, and Audio/Theme/Visualizer preferences via PostgreSQL with Row Level Security (RLS).
* **Offline + Online Hybrid**: When offline, the app operates from a local cache with zero interruption; when internet returns, changes are automatically reconciled and synchronized.
* **Full Database Schema**: Included in the repository root as `supabase_schema.sql` for instant deployment.

---

## ✨ Key Features in v1.0.0
* 🔮 **3D GPU Visualizers:** Real-time Raymarched Liquid Orb (GLSL 460), Aurora Mesh Gradient, and Polar Spectrum Ring with audio FFT reactivity.
* 📜 **Synced LRC Lyrics:** Auto-scrolling, active line bloom highlight, and tap-to-seek timestamp navigation.
* 📁 **Smart Local Library:** Pure Dart audio metadata parser for MP3 (ID3v2 APIC artwork), FLAC, WAV, M4A, and OGG.
* 🎧 **Background Audio Service:** Lock screen controls, notification media controls, and Android MediaSession integration.
* 🎨 **OLED Obsidian Glassmorphic UI:** Smooth 60 FPS fluid animations with dynamic album palette extraction.
* 🔄 **In-App Auto Update Checker:** Seamlessly alerts users when a new GitHub release is published.
