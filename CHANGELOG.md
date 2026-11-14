# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-11-14

### Added
- **Self-Contained Windows Distribution**:
  - Compiled production Windows installer `CinematicMusicPlayerSetup.exe` via Inno Setup 6.
  - Bundled standalone portable package `CinematicMusicPlayer-Windows.zip` containing all runtime DLLs, Flutter Impeller shaders, and assets.
  - Zero developer dependencies required for end users (no Flutter SDK, VS, C++, or Android Studio required).
- **GitHub Release Update Checker**:
  - Live version inspection via GitHub Releases API.
  - In-app notification prompt: `"New version available"` with `"Download Update"` and `"Later"` buttons.

### Fixed
- **Android Music Playback Engine**:
  - Resolved issue where tapping songs in the library or home screen failed to start audio playback.
  - Fixed playlist queue initialization and added content/file URI parsing (`parseAudioUri`) for Android ExoPlayer compatibility.
  - Eliminated silent playback failures with defensive error trapping and real-time floating error notifications.
- **Music Library & Ghost Track Purge**:
  - Filtered out unplayable and metadata-only tracks without real audio files (`song.isLocalFileAvailable`).
  - Added user-facing fallback alert: `"Audio file unavailable. Please import this song again."` when a target file cannot be located on disk.
  - Prevented non-existent tracks from being added to the playable library.
- **Android Storage & Import System**:
  - Fixed permission negotiation across Android 10-14 (handling both `Permission.audio` for API 33+ and legacy `Permission.storage`).
  - Added persistent copying of temporary FilePicker cache files into the app's permanent storage directory so imported tracks never disappear.
  - Updated standard Android search directories to scan `/storage/emulated/0/Music`, `/storage/emulated/0/Download`, and external SD cards.
- **Demo Track Realism**:
  - Bundled authentic high-fidelity Hindi audio track (`Bairan (Demo)`) directly into the app package.
  - Labeled all pre-seeded demo tracks explicitly with `(Demo)` in title and album tags.
  - Verified that all synthesized WAV tracks and bundled MP3s generate valid PCM/MP3 bytes and local file paths.

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
- **Cloud Account & Synchronization**:
  - Account registration and login with SHA-256 password hashing.
  - Two-way synchronization of playlists, favorites, history, and preferences across devices.
  - Connected devices overview and remote session de-authorization.
- **Automated Update Checker**:
  - Checks for latest releases via repository release API.
- **Branded Design**:
  - Glassmorphic UI with dynamic ambient palettes and customized platform icons.
