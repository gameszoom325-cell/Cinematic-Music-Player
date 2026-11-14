# Cinematic Music Player v1.0.3

Production release **v1.0.3** introduces the new **Acoustic Minimal** design language across the application, reliable direct Win32 COM File Explorer integration, real audio PCM/FFT-driven GPU visualizers that decay into a tranquil calm state during silence, native Windows drag-and-drop, global desktop keyboard shortcuts, background isolate scanning on Android, virtualized 60 FPS library scrolling, and hardened cross-platform cloud sync sessions.

---

## 🌟 What's New in v1.0.3

### 1. 🎨 Acoustic Minimal Design System Integration
- **Warm Studio Charcoal Palette**: Redesigned color scheme featuring `#131315`, `#201f21`, and `#2a2a2c` backgrounds with amber acoustic accents (`#ffb77d`, `#d97707`) and Inter-based editorial typography.
- **Acoustic Soundwave Ring (`AcousticArtRing`)**: Album artwork surrounded by an audio-reactive perimeter ring with active playback progress arc and 8 radial acoustic tick spikes pulsing to real frequencies.
- **52-Bar Tactile Waveform Scrubber (`WaveformScrubber`)**: Precision 52-bar tactile scrubber displaying elapsed, remaining, and total duration with glowing active cutoff and drag-to-seek.
- **Centerpiece Audio Control Island (`TactileControlIsland`)**: Analog-feel transport dock housing the ambient rain volume slider, shuffle, previous, 56px amber play/pause spring button, next, repeat mode, and master volume gain slider with Direct DAC status.
- **Dual Editorial Tab Capsule**:
  - **Synced Lyrics View**: Synced timestamps `[mm:ss]`, past lines dimmed/blurred, active line highlighted in an elevated warm amber container (`[mm:ss • ACTIVE NOW]`), tap any line to seek.
  - **Dynamic Up Next Queue**: Real-time playlist queue with animated equalizer badge on the active track, format indicators, duration badges, and tap-to-play.

### 2. 🗂️ Windows File Explorer Dialog Overhaul
- **Direct Win32 COM `FileOpenDialog` (`IFileOpenDialog`)**: Direct Windows Shell COM implementation avoiding Dart FFI/isolate issues or plugin registration deadlocks.
- Guarantees Windows File Explorer dialogs open synchronously and reliably every time.
- Supports multi-file selection, folder selection, custom audio extensions (`.mp3`, `.flac`, `.wav`, `.m4a`, `.ogg`, `.aac`, `.opus`, `.wma`, `.aiff`, `.alac`), parent HWND binding, and graceful cancellation.

### 3. 🌊 Real Audio GPU Visualizer (PCM/FFT Driven)
- **Real Audio Spectrum Sampling**: Removed synthetic procedural beat oscillations; visualizers are now strictly driven by real audio PCM/FFT spectrum sampling at the active playback timestamp.
- **Frequency Band Separation**: Bass drives large displacement/expansion, Mids control motion/contours, and Treble controls detail/shimmer.
- **Tranquil Calm State in Silence**: During pause or silence (RMS < 0.02), energy decays smoothly to 0.0 with $e^{-10t}$ damping. Visualizers rest completely flat with zero artificial idle animation and minimal CPU usage.
- **Hardware-Accelerated 60 FPS**: Raymarched 3D liquid orb (`orb_visualizer.frag`) and dynamic aurora mesh (`aurora_mesh.frag`) locked at 60 FPS.

### 4. 🚀 Mobile Performance & Virtualization (Android)
- **Background Isolate Scanning**: Directory scans and ID3/FLAC/M4A metadata extraction run in background isolates (`Isolate.run`) in batches of 15-20 files, keeping the UI completely free of jank.
- **Virtualized Library List**: Fixed `itemExtent: 68.0` with `RepaintBoundary` for 60 FPS scrolling over 10,000+ tracks.
- **Downsampled Artwork Caching**: Artwork decoders restricted to `cacheWidth: 120, cacheHeight: 120` to prevent memory blowups and GC pauses during fast scroll on mobile.

### 5. 💻 Windows Desktop Polish
- **Native Win32 Drag & Drop (`WM_DROPFILES`)**: Drag and drop audio files or folders directly into the app window to import immediately.
- **Global Desktop Keyboard Shortcuts**:
  - `Space` / `MediaPlayPause`: Play / Pause
  - `Left` / `Right` Arrow: Seek $\pm 5$ seconds
  - `Up` / `Down` Arrow: Volume $\pm 5\%$
  - `N` / `P` / Media Track Next / Previous: Next / Previous track
  - `M`: Mute / Unmute
  - `F`: Full Cinema view toggle

### 6. ☁️ Cloud Sync & Persistent Sessions
- **Session Refresh Token Support**: Integrated GoTrue token refresh (`/auth/v1/token?grant_type=refresh_token`) in `SupabaseBackendClient`.
- Seamless cross-platform synchronization of playlists, favorites, recently played history, visualizer presets, and equalizer preferences between Android and Windows.
- Resilient offline fallback ensuring users are never locked out of their local vault during network disconnects.

---

## 📦 Downloads & Checksums

| Package | Platform | File Size | SHA-256 Checksum |
| :--- | :--- | :--- | :--- |
| **`CinematicMusicPlayer.apk`** | Android 8.0+ | ~61.2 MB | `B241C06C2D280C20CE63333EA1534D6BA9FFE4FCAED5C09B436FDA48E99E1216` |
| **`CinematicMusicPlayerSetup.exe`** | Windows 10 / 11 (x64) | ~28.2 MB | `F296F212077746A7743453A67BB844704026AA93EFB12B1BE49EAE0E66B2C7A4` |
| **`CinematicMusicPlayer-Windows.zip`** | Windows 10 / 11 (Portable) | ~38.7 MB | `B51AC663356F4D04016C555D003D4BE86B31A48AA9D70497284EC8F10DFBBCD1` |

---

## 🚀 Installation Instructions

### Windows
1. Download **`CinematicMusicPlayerSetup.exe`**.
2. Double-click the installer and follow the setup wizard.
3. Launch **Cinematic Music Player** from your Start Menu or Desktop.

### Android
1. Download **`CinematicMusicPlayer.apk`** to your device.
2. Tap the APK in your downloads folder and confirm installation.
3. Grant audio/storage permissions when prompted to let the player scan your offline music library.
