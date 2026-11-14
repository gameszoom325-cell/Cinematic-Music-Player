# Cinematic Music Player — Setup, Build & Validation Guide

> **Release**: Cinematic Music Player Alpha v0.1  
> **Target Platforms**: Windows Desktop (x64) & Android (arm64-v8a / armeabi-v7a / x86_64)

---

## 1. Prerequisites & Environment Checklist

### 1.1 Flutter & Dart SDK
- **Flutter SDK**: `3.19.0` or higher (Recommended: Flutter `3.24.x` or `3.27.x` with Impeller rendering engine).
- **Dart SDK**: `>= 3.3.0 < 4.0.0` (Included automatically with the Flutter SDK).
- **Verification Command**:
  ```powershell
  flutter --version
  dart --version
  ```

### 1.2 Windows Desktop Build Requirements
- **Visual Studio 2022**: Community, Professional, or Enterprise.
- **Required Workload**: **"Desktop development with C++"** (selected in the Visual Studio Installer).
- **Components Included**:
  - MSVC v143 - VS 2022 C++ x64/x86 build tools.
  - Windows 10 SDK (10.0.19041.0+) or Windows 11 SDK.
  - C++ CMake tools for Windows.
- **Enable Windows Desktop in Flutter**:
  ```powershell
  flutter config --enable-windows-desktop
  ```

### 1.3 Android Build Requirements
- **Android Studio / Android SDK**:
  - `compileSdkVersion`: **34** (Android 14)
  - `minSdkVersion`: **23** (Android 6.0 Marshmallow)
  - `targetSdkVersion`: **34**
  - **Android SDK Build-Tools**: `34.0.0`
  - **Java JDK**: OpenJDK 17 (`JAVA_HOME` pointing to JDK 17)
  - **NDK**: Version `25.x` or `26.x`

### 1.4 Environment Variables Checklist
Ensure the following are added to your User or System `PATH`:

| Variable | Recommended Value | Purpose |
| :--- | :--- | :--- |
| `PATH` | `C:\flutter\bin` | Flutter & Dart command line tools |
| `JAVA_HOME` | `C:\Program Files\Android\Android Studio\jbr` | Gradle Android build compiler |
| `ANDROID_HOME` | `C:\Users\<username>\AppData\Local\Android\Sdk` | Android SDK location |
| `PATH` | `%ANDROID_HOME%\platform-tools` | `adb` Android bridge tool |

Run the doctor command to confirm all checks pass:
```powershell
flutter doctor -v
```

---

## 2. Compilation & First Run Instructions

### Step 1: Install Dependencies
In the root directory `c:\MY PROJECTS`:
```powershell
flutter pub get
```
This fetches all dependencies (`just_audio`, `just_audio_windows`, `audio_service`, `file_picker`, `flutter_riverpod`, etc.) and automatically compiles the GLSL 460 shaders (`shaders/orb_visualizer.frag` and `shaders/aurora_mesh.frag`) into SPIR-V runtime effects.

### Step 2: Run on Windows Desktop
```powershell
flutter run -d windows
```

### Step 3: Run on Android (Physical Device or Emulator)
```powershell
flutter run -d android
```

---

## 3. Real Device Testing Workflows

### Test Case 1: Out-of-the-Box Demo Playback (Zero External Music Required)
1. Launch the app on Windows or Android.
2. The `SampleMusicService` automatically provisions **3 studio demo tracks**:
   - *"Neon Horizon"* (Aura Synths — 120 BPM)
   - *"Deep Space Pulse"* (Cosmic Frequency — 90 BPM)
   - *"Solar Flare"* (Hyperion — 140 BPM)
3. Each demo track has generated 16-bit 44.1kHz stereo PCM audio, waveform peaks, and procedural album art.
4. Tap any track on the **Home Screen** to start playback immediately.

### Test Case 2: Local Music Import & Scanning
1. On the **Home** or **Library** screen, click the **Folder** icon in the top right.
2. The native system folder picker opens (`FilePicker`). Select any folder containing `.mp3`, `.flac`, `.wav`, `.m4a`, or `.ogg` files.
3. The app scans files asynchronously in the background:
   - Extracts ID3v2, Vorbis, and RIFF headers (Title, Artist, Album, Duration).
   - Extracts embedded album art (`APIC` / `PICTURE` blocks) and caches them in the application document directory.
   - Pre-analyzes 128 normalized RMS waveform bins and estimates BPM.
4. The library immediately refreshes with track titles, technical format badges, and album artwork.

### Test Case 3: Player Controls & Background Audio
1. **Play / Pause**: Tap the hero pulsing button or press `Space` on Windows.
2. **Seeking**: Drag along the glowing waveform scrubber. Audio seeks with sub-10ms latency.
3. **Skip Next / Previous**: Press next/prev or use `MediaTrackNext`/`MediaTrackPrevious` keys.
4. **Android Background Test**: Press Home to background the app or lock the screen. Verify the ongoing notification appears with play/pause/skip buttons, title, artist, and album art.
5. **Windows SMTC Test**: Adjust volume using Windows volume keys; verify the media flyout reflects the current track and controls.

### Test Case 4: Audio-Reactive Visualizer Pipeline
Tap the **Cinema View** capsule or the mini player to open the full cinematic stage:
1. **Preset 1 (3D Liquid Raymarched Orb)**:
   - Observe the base sphere pulsating in sync with sub-bass kick drums.
   - Observe harmonic surface waves vibrating in the mid-frequency range.
   - Observe shimmering sparkles and dust motes reacting to hi-hat treble bursts.
2. **Preset 2 (Polar Circular Spectrum Ring)**:
   - Tap the preset selector icon (top right) $\rightarrow$ choose **Polar Spectrum Ring**.
   - 64 radial bars encircle the 3D tilt album artwork, dancing synchronously with the audio spectrum at 60 FPS.
3. **Preset 3 (Aurora Dynamic Mesh Gradient)**:
   - Select **Aurora Dynamic Mesh**.
   - Background fluid mesh morphs smoothly in a lava-lamp effect tinted with the extracted album art palette.

---

## 4. Multi-Device Account & Cloud Synchronization Validation

### 4.1 First Launch Welcome Gateway
1. On fresh app launch, the `AuthGateway` displays `WelcomeScreen`:
   - **Option 1**: **Create Account** — Enter username, email, password (minimum 6 chars), and select a holographic avatar.
   - **Option 2**: **Log In** — Enter existing credentials with optional "Remember session on this device".
   - **Option 3**: **Continue without account** — Explores the player in 100% offline guest vault mode.

### 4.2 Multi-Device Cross-Sync Workflow
```
[Windows Laptop]                                        [Android Phone]
1. Log in with you@example.com                         1. Log in with you@example.com
2. Create playlist "Cyberpunk Nights"                  2. Automatically pulls "Cyberpunk Nights"
3. Star / favorite 3 tracks                            3. Those 3 tracks automatically appear starred
4. Set Visualizer to "3D Liquid Orb + Rain Mode"       4. Visualizer preset instantly mirrors
5. Settings shows:                                     5. Settings shows:
   • This Device (Windows Laptop)                         • This Device (Android Mobile)
   • Android Phone                                        • Windows Laptop
```

### 4.3 Device Management & De-authorization
- Navigate to **Settings** (`SettingsScreen`):
  - View **Account Profile** card (Username, Email, Sync Active badge, Member since date).
  - View **Cloud Synchronization** card: Shows last sync time ("Just now", "5m ago") with a manual **Sync Now** button.
  - View **Connected Devices** list: Lists all authorized hardware endpoints.
  - Tapping **Remove Device** on another device remotely de-authorizes it.
  - Tapping **Log Out** clears local session and returns to the Welcome Gateway.

---

## 5. Alpha v0.1 Release Summary

```
======================================================
  CINEMATIC MUSIC PLAYER — ALPHA v0.1
======================================================
  [✓] Functional Local Audio Playback (just_audio + audio_service)
  [✓] High-Throughput Directory Scanner (MP3, FLAC, WAV, M4A, OGG)
  [✓] Binary Tag & Embedded Artwork Extractor
  [✓] Hybrid Audio Reactive FFT Engine & Beat Detection
  [✓] 3D Liquid Raymarched Orb (GLSL 460 SPIR-V Shader)
  [✓] Polar Circular Spectrum Ring (60 FPS CustomPainter)
  [✓] Aurora Dynamic Mesh Gradient Shader
  [✓] 4 Atmospheric Particle Modes (Rain, Snow, Dust, Fireflies)
  [✓] Glassmorphic UI with 3D Tilt Album Artwork
  [✓] Waveform Scrubber with Pre-Analyzed RMS Peaks
  [✓] Windows Desktop + Android Single Codebase
  [✓] Apple Music-Style Synchronized LRC Lyrics Engine
  [✓] Cross-Platform Multi-Device Account & Cloud Sync (Windows + Android)
  [✓] Remote Device Management & Heartbeat Tracking
======================================================
```

---

## 6. Phase 2 Roadmap & Next Milestones

1. **Vinyl Mode**:
   - Photorealistic rotating 3D vinyl disc simulation with anisotropic grooves and tonearm needle tracking.
2. **Enhanced Atmosphere Physics**:
   - Dynamic wind vectors and glass surface raindrops with refractive distortion.
3. **AI Playlist Assistant & Smart Flow**:
   - Clustering songs based on BPM, frequency balance, and energy profiles for seamless mood transitions.
