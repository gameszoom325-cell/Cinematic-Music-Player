# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.6] - 2026-11-15

### Fixed
- v1.2.6: Fixed auto-search routing to load results immediately and added MP3 download interception to save files directly to Local Library.
- Corrected `WebSearchPage` initialization in `initState` to immediately route to `https://pagalworld.is/search?q=<encodedQuery>` when `autoSubmit` is true, eliminating the initial home page redirect.
- Verified permission handling and local storage paths so downloads seamlessly appear in the user's Local Files tab.

## [1.2.5] - 2026-11-15

### Added
- v1.2.5: Swapped WebSearchPage engine to `flutter_inappwebview` with native download interception.
- Implemented `onDownloadStartRequest` to intercept Pagalworld MP3 download links on tap.
- Added automatic background download and storage to device Music folder (`/storage/emulated/0/Music` with fallback).
- Integrated immediate local indexing via `ScannerService.importFiles` and `libraryProvider.refreshLibrary()` so newly downloaded MP3s appear in Local Library right away.
- Preserved ad-blocking filters and `intent://` scheme blocking to prevent navigation crashes.

## [1.2.4] - 2026-11-15

### Added
- v1.2.4: Tapping YouTube search results now automatically opens the Web MP3 (Pagalworld) search for that specific song.
- Preserved instant just_audio playback for JioSaavn catalog results.

## [1.2.3] - 2026-11-15

### Added
- Integrated user-assisted search handoff from main search screen to `WebSearchPage` with pre-filled query and manual search initiation.
- Added floating "Use this MP3" button in `WebSearchPage` to capture audio URLs and start playback automatically in the player.
- Tagged captured web audio with `WEB MP3` source badge.

## [1.2.2] - 2026-11-15

### Changed
- Locked in v1.2.1 ad-blocking and WebView stability fixes. Version bump for release tracking.

## [1.2.1] - 2026-11-15

### Added
- v1.2.1: Added ad-blocking to the Web MP3 feature.
- v1.2.1: Complete UI Revamp, Ad-blocking WebView, Favicon, Privacy Policy, Terms & Conditions.
- Integrated `adblocker_webview: ^2.3.0` into `WebSearchPage` to block Pagalworld ads using EasyList and AdGuard filters without breaking intent:// or navigation protection.
- Created `PrivacyPolicyPage` and `TermsConditionPage` under `lib/features/legal/`, linked in Mobile Drawer, Desktop Sidebar, and Settings.
- Added clean web favicon to `web/favicon.png` with `web/index.html` and configured Windows runner icon in `windows/runner/Runner.rc`.
- Completely revamped UI across all screens: eliminated all purple/neon gradients, normalized buttons to 4px-8px subtle rectangular geometry, removed all emojis, and replaced vague marketing hero copy with direct, functional headers.
- Bumped version to `1.2.1+17`.

## [1.1.9] - 2026-11-15

### Fixed
- Fixed WebView intent:// crash and repaired in-app update link:
  - Blocked non-HTTP URL schemes (`intent://`, `market://`, etc.) in `WebSearchPage.NavigationDelegate.onNavigationRequest` to prevent `net::ERR_UNKNOWN_URL_SCHEME` crashes.
  - Added debug logging when non-HTTP navigation schemes are blocked.
  - Repaired in-app update dialog action to launch external GitHub release link with `LaunchMode.externalApplication`.
  - Added robust fallback with floating SnackBar and one-tap clipboard copy if browser launching fails.
  - Declared `<queries>` package visibility intent filters in `AndroidManifest.xml` for browser URL launching on Android 11+.
- Bumped version to `1.1.9+15`.

## [1.1.8] - 2026-11-15

### Added
- Added WebView-based MP3 search and download feature (Pagalworld):
  - Integrated `webview_flutter: ^4.14.1` with native Android WebView backing.
  - Implemented `WebSearchPage` loading `https://pagalworld.is/` with search bar navigating to `https://pagalworld.is/search?q=<encoded_query>` on Enter.
  - Configured `WebViewController` with `JavaScriptMode.unrestricted`, dark theme background (`#0F0F12`), and unrestricted navigation/redirects.
  - Added dedicated Home button in the AppBar returning to `https://pagalworld.is/`.
  - Handled Android back button navigation in WebView history via `PopScope`.
  - Linked `WebSearchPage` to Desktop Sidebar (index 9) and Mobile Navigation / App Drawer.
- Bumped version to `1.1.8+14`.

## [1.1.7] - 2026-11-15

### Fixed
- Fixed YouTube playback by integrating `youtube_explode_dart` for direct audio stream extraction and added safety fallbacks:
  - Integrated `youtube_explode_dart: ^3.1.0` to resolve canonical YouTube video IDs into direct high-bitrate audio streams (`googlevideo.com` Opus/AAC) on-the-fly.
  - Added quota-free search and stream extraction fallback, eliminating dependence on Google Cloud YouTube Data API quota.
  - Added safety guard in `PlayerNotifier` and `AudioEngine` preventing unplayable YouTube web page URLs (`youtube.com/watch`) from reaching ExoPlayer.
  - Verified and protected JioSaavn 320kbps `.mp4` stream resolution and playback.
- Bumped version to `1.1.7+13`.

## [1.1.6] - 2026-11-15

### Added
- Added JioSaavn Bollywood search & streaming (unofficial wrapper):
  - Integrated `jiosaavn_dart` package for high-fidelity 320kbps Bollywood music streaming.
  - Implemented `JioSaavnService` with `searchSongs` and `getSongById` (retrieving media stream URL, high-resolution album artwork, and synced/plain lyrics).
  - Built dedicated `JioSaavnPage` with trending quick-chips (Arijit Singh, Shreya Ghoshal, Diljit Dosanjh, Sidhu Moose Wala, Pritam, Rahman, Bollywood Hits 2024), real-time search debouncing, and direct integration with `AudioEngine`.
  - Added unit test suite covering `JioSaavnTrack` instantiation, formatted duration conversion, service instantiation, and page widget rendering.
- Bumped version to `1.1.6+12`.

## [1.1.5] - 2026-11-15

### Added
- **Visualizer Performance Settings**:
  - Added Studio Performance quality selector (`High` 60 FPS, `Balanced` 30 FPS, `Low` 15 FPS, `Off` completely sleeps ticker and GPU draws).
  - Persisted user preference in `SharedPreferences` (`cinematic_visualizer_quality`).
  - Implemented dynamic timer intervals in `AudioReactiveAnalyzer` to eliminate CPU/GPU load on integrated graphics.
- **Spotify-Style Desktop Layout & Workflow**:
  - Collapsible desktop sidebar with direct navigation to Home, Search, Your Library, Liked Songs, and custom Playlists.
  - Quick "+ Create Playlist" dialog from sidebar.
  - Persistent bottom Now Playing bar with track metadata, playback controls, dedicated independent seekbar widget (preventing root frame rebuilds), and master volume slider.
  - Sliding Desktop Queue Drawer with drag-to-reorder tracks (`ReorderableListView`), track removal, live equalizer badge, and clear queue button.
  - Rich Library views with tabbed navigation for Songs, Albums, Artists, and Folders.
  - Full desktop keyboard shortcuts: Space (Play/Pause), Ctrl+Right/Left (Next/Previous), Up/Down (Volume $\pm 5\%$), M (Mute), `/` or Ctrl+K (Quick Search focus).
- **Persistent Offline Music Library (Free, Zero API Keys Required)**:
  - Multi-folder library monitoring: users can add any local music directory via native Windows folder picker.
  - Persisted folder paths across app restarts in `SharedPreferences` and `library_db.json`.
  - Automatic startup folder rescanning and manual "Rescan Library" button.
  - Full offline local playback supporting MP3, FLAC, WAV, M4A, OGG, AAC, OPUS, WMA.
- **High-DPI Per-Monitor V2 Crispness**:
  - Updated `windows/runner/runner.exe.manifest` with `<dpiAware>true/pm</dpiAware>` and `<dpiAwareness>PerMonitorV2</dpiAwareness>`, fixing fuzzy/soft UI rendering on Windows desktop.
- **Global Error & Crash Logging**:
  - Global `CrashLogger` capturing Flutter framework errors, platform dispatcher unhandled exceptions, and background isolate errors.
  - Writes to `%USERPROFILE%/Documents/CinematicMusicPlayer/logs/app.log` with automatic 5MB log rotation.
- **Decoupled API Secrets**:
  - Moved all API keys (YouTube, Jamendo, Supabase) into git-ignored `app_secrets.dart` with fallback template in `app_secrets.example.dart`.

### Changed
- Downsampled palette extraction artwork to 96x96 via `ResizeImage`, resolving frame drops and stutter on song change.
- Isolated seekbar into `_IndependentSeekBar` widget, decoupling position ticks from parent view rebuilds.
- Bumped version to `1.1.5+11`.

## [1.0.3] - 2026-11-14

### Added
- **Acoustic Minimal Design System Integration**:
  - Implemented the warm studio charcoal aesthetic (`#131315`, `#201f21`, `#2a2a2c`) with amber accents (`#ffb77d`, `#d97707`) and Inter-based editorial typography.
  - Album Art Showcase featuring the `AcousticArtRing` (breathing soundwave perimeter ring, progress arc, and 8 radial acoustic tick spikes pulsing to real audio frequencies).
  - 52-bar Tactile `WaveformScrubber` with elapsed, remaining, and duration counters, glowing active cutoff, and drag-to-seek.
  - Centerpiece `TactileControlIsland` with ambient rain sound slider, analog transport controls (shuffle, previous, 56px amber play/pause spring button, next, repeat), and master volume gain slider with Direct DAC status.
  - Dual Editorial Tab Capsule in `CinematicPlayerScreen`:
    - **Synced Lyrics View**: Vertical timeline indicator, timestamp badges `[mm:ss]`, past lines dimmed, active line elevated in an amber card with active marker, upcoming lines muted.
    - **Dynamic Up Next Queue**: Real-time track list, live animated equalizer on currently playing track, tap-to-play, duration badges.
- **Windows File Explorer Dialog Overhaul**:
  - Direct Win32 COM `FileOpenDialog` (`IFileOpenDialog`) implementation for Windows.
  - Guarantees File Explorer dialogs reliably open synchronously on Windows desktop without isolate or plugin registration failures.
  - Supports multi-file selection, folder selection, custom audio extensions (`.mp3`, `.flac`, `.wav`, `.m4a`, `.ogg`, `.aac`, `.opus`, `.wma`, `.aiff`, `.alac`), parent HWND binding, and graceful cancellation.
- **Real Audio GPU Visualizer (PCM/FFT Driven)**:
  - Replaced procedural synthetic sine animations with real audio spectrum sampling tied to actual playback timestamp and waveform peaks.
  - Bass controls large displacement/expansion, Mids control motion/contours, Treble controls detail/shimmer.
  - In silence or paused state, energy decays smoothly to 0.0 with $e^{-10t}$ damping—calming to a tranquil rest state with zero artificial motion and minimal CPU usage.
- **Native Windows Drag and Drop & Keyboard Shortcuts**:
  - Native Win32 `WM_DROPFILES` integration in the Windows runner: drag and drop audio files or folders directly into the app window to import immediately.
  - Global desktop keyboard shortcuts:
    - `Space` / `MediaPlayPause`: Play / Pause
    - `Left` / `Right` Arrow: Seek $\pm 5$ seconds
    - `Up` / `Down` Arrow: Volume $\pm 5\%$
    - `N` / `P` / Media Next / Previous: Next / Previous track
    - `M`: Mute / Unmute
    - `F`: Full Cinema view toggle
- **Mobile Performance & Virtualization (Android)**:
  - Background isolate scanning via `Isolate.run` in batches of 15-20 files to eliminate UI thread blocking during library scans.
  - Virtualized song list using `itemExtent: 68.0` and `RepaintBoundary` for buttery 60 FPS scrolling over 10,000+ tracks.
  - Downsampled image decoding (`cacheWidth: 120, cacheHeight: 120`) to prevent out-of-memory crashes and GC pauses.
- **Authentication & Cloud Sync Hardening**:
  - Automatic token refresh via GoTrue REST endpoint (`/auth/v1/token?grant_type=refresh_token`).
  - Offline session persistence ensuring users stay logged in across device restarts and network reconnections.

## [1.0.2] - 2026-11-14

### Added
- **AudioSession & System Interruption Management**:
  - Configured Android `AudioSession.configure(AudioSessionConfiguration.music())` for system audio focus.
  - Headphone unplug event (`becomingNoisyEventStream`): auto-pauses music instantly when Bluetooth or wired headphones are disconnected.
  - Call & notification focus transitions (`interruptionEventStream`): ducks music on system notifications, pauses on incoming calls, and automatically resumes on call completion.
- **Multi-Format Album Artwork Extraction**:
  - Re-engineered streaming buffer reader (`_readFully`) to eliminate truncated ID3 `APIC` / FLAC pictures.
  - Native parser for ID3v2.2 (`PIC`), ID3v2.3 (`APIC`), ID3v2.4 (`APIC`, synchsafe), and ID3 extended headers.
  - M4A / AAC ISO MP4 atom parser for embedded `covr -> data` album artwork.
  - FLAC metadata block type 6 PICTURE parser.
  - Expanded folder artwork fallbacks: `cover.jpg`, `cover.png`, `folder.jpg`, `folder.png`, `album.jpg`, `album.png`, `front.jpg`, `front.png`, `Artwork.jpg`.
- **Dynamic Genre Categories**:
  - Category filter chips in `LibraryScreen` are derived dynamically from imported music files.
  - Filter chips bar is hidden when the library is empty, maintaining a clean cinematic look.

### Fixed
- **Player Status Header**:
  - Replaced hardcoded `"STUDIO MASTER • 24-BIT"` fallback with actual audio file specs (`SongModel.technicalSpecs`) or `"OFFLINE AUDIO"`.
- **Zero-State Screens**:
  - Added dedicated empty states for both `LibraryScreen` and `PlaylistScreen` guiding users to import music files or create playlists.
- **Playback Reliability**:
  - Queued track requests and added automatic fallback in `AudioEngine.playTrack`, ensuring zero uninitialized handler exceptions even under rapid taps or cold start.

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
