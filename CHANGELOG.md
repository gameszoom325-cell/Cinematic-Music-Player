# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-11-14

### Fixed
- **Windows Runner & Window Visibility**:
  - Fixed application running invisibly in Task Manager by adding native Win32 `window.Show()` and centered coordinates (`1280x800`) directly to the C++ runner `wWinMain`.
  - Fixed Inno Setup shortcuts by specifying `WorkingDir: "{app}"`, preventing Windows from launching with working directory `C:\Windows\System32` (which caused Dart to fail to find `data\app.so` and `data\icudtl.dat`).
  - Added `runner.exe.manifest` for modern Windows 10 & 11 PerMonitorV2 DPI awareness.
- **Android Audio Service Initialization (Audited against Metrolist)**:
  - Fixed "Playback failed: Bad state: Audio service handler is not initialized".
  - Extended `AudioServiceActivity` instead of `FlutterActivity` in `MainActivity.kt`, granting the Android foreground media service immediate access to the Flutter engine isolate.
  - Eagerly initialized `CinematicAudioHandler` in `AudioEngine` before any player operations.
  - Configured permanent broadcast streams for audio position, duration, and playback state so UI listeners never encounter dead streams.
  - Added `READ_MEDIA_AUDIO`, `READ_MEDIA_IMAGES`, and `POST_NOTIFICATIONS` permissions.
- **Album Artwork & Metadata Extraction**:
  - Re-engineered embedded cover art parser using magic-byte scanning (JPEG `FF D8 FF`, PNG `89 50 4E 47`, WebP, and FLAC PICTURE) to eliminate string-encoding corruptions.
  - Added folder art lookup for `cover.jpg`, `folder.jpg`, and `album.png`.
  - Added clean dark-purple cinematic gradient placeholder fallback for tracks without embedded artwork.
- **Purged All Fake Songs & Demo Content**:
  - Removed all generated placeholder tracks, sample catalogues, and the bundled `bairan_demo.mp3`.
  - App starts with a clean, empty library on first launch; only user-imported audio files appear.
  - Filtered out unplayable or metadata-only tracks without real audio files (`song.isLocalFileAvailable`).
  - Added user alert: *"Audio file unavailable. Please import this song again."* for missing files.
- **Streamlined UI & Removed Clutter**:
  - Simplified navigation to 4 core tabs: `Home`, `Library`, `Playlists`, `Settings`.
  - Replaced curated banners and category badges with a clean "Import Music Files" onboarding experience.

### Added
- **Self-Contained Windows Distribution**:
  - Windows installer `CinematicMusicPlayerSetup.exe` built with Inno Setup 6 (28.1 MB).
  - Standalone portable package `CinematicMusicPlayer-Windows.zip` (38.6 MB).
  - Zero developer dependencies required for end users (no Flutter SDK, VS, C++, or build tools required).
- **In-App GitHub Update Checker**:
  - Automatic version check against the GitHub Releases API.
  - In-app prompt: *"New version available"* with *"Download Update"* and *"Later"* actions.

## [1.0.0] - 2026-11-14

### Added
- **Cross-Platform Audio Engine**: High-fidelity gapless playback with system media controls on Windows and Android.
- **GPU Visualizer Presets**:
  - 3D Liquid Raymarched Orb with audio reactive vertex displacement.
  - Polar Spectrum Circular Ring running at 60 FPS.
  - Aurora Dynamic Mesh Gradient responsive to audio energy.
  - Atmospheric particle modes: Rain, Snow, Floating Dust, and Fireflies.
- **Local Audio Library**:
  - Recursive folder scanner supporting MP3, FLAC, WAV, M4A, and OGG.
  - Pure Dart binary metadata parser for embedded cover art, titles, and tags.
- **Synchronized Lyrics**:
  - Precision LRC parser with active line highlight, smooth scrolling, and tap-to-seek.
- **Cloud Synchronization**:
  - Supabase authentication and cloud database sync for playlists, favorites, and settings.
