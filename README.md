# Cinematic Music Player

<p align="center">
  <img src="assets/icons/app_icon.png" width="130" height="130" alt="Cinematic Music Player Logo" />
</p>

<p align="center">
  <strong>A premium, 100% private cross-platform music player and audio sanctuary.</strong><br>
  Built with Impeller GLSL 460 fragment shaders, gapless audio engines, and multi-device cloud synchronization.
</p>

<p align="center">
  <a href="https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/latest"><img src="https://img.shields.io/badge/Release-v1.2.6-gold.svg?style=flat-square" alt="Latest Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Platforms-Windows%20%7C%20Android-success.svg?style=flat-square" alt="Platforms">
</p>

---

## What's New in v1.2.6 (Auto-Search Immediate Routing & Library Auto-Import)

- **Immediate Search Results Routing**:
  - Fixed `WebSearchPage` initialization in `initState` so that `autoSubmit` immediately targets `https://pagalworld.is/search?q=<query>`, eliminating intermediate home page loading.
- **Native MP3 Download Interception**:
  - Intercepts Pagalworld `.mp3` downloads natively via `onDownloadStartRequest` on `flutter_inappwebview`.
  - Downloads audio bytes, saves directly to the device Music folder, and rescans the library so the track instantly shows in the Local Files tab.

## What's New in v1.2.5 (Native Web MP3 Download & Local Library Auto-Import)

- **Native Download Interception**:
  - Replaced WebView engine with `flutter_inappwebview` to intercept Pagalworld download links natively via `onDownloadStartRequest`.
- **Automatic Storage & Local Library Sync**:
  - Downloaded MP3 bytes are saved to device Music storage (`/storage/emulated/0/Music` with fallback).
  - Automatically indexes newly downloaded songs into the SQLite database and triggers `libraryProvider.refreshLibrary()` immediately.
  - Active downloading SnackBar indicator and success notification upon import.
- **Intrusive Ad & Scheme Protection**:
  - Maintained `ContentBlockers` for intrusive ad networks and scheme filtering to block `intent://` and `market://` crash schemes.

## What's New in v1.2.4 (YouTube Results Redirect to Web MP3 Auto-Search)

- **Automated YouTube to Pagalworld Navigation**:
  - Tapping a YouTube result in the main search screen immediately navigates to `WebSearchPage` and auto-submits the search for that song title on Pagalworld.
  - Users land directly on the search results page without re-typing.
- **Preserved JioSaavn Playback**:
  - Tapping JioSaavn catalog results continues to play instantly through `just_audio`.

## What's New in v1.2.3 (Search Handoff & One-Tap Web MP3 Capture)

- **Search Handoff Flow**:
  - Seamlessly hand off queries from the main search bar to `WebSearchPage`, pre-filling the search query without auto-submitting.
  - Allows users to view and interact with web pages legitimately through the visible ad-blocking browser.
- **One-Tap "Use this MP3" Action**:
  - Added floating "Use this MP3" action in `WebSearchPage` to capture audio URLs and trigger playback immediately in the player.
  - Tagged with a gold `WEB MP3` badge in search results.

## What's New in v1.2.2 (Release Stabilization & Ad-Blocking Lock-in)

- **Locked-in Web MP3 Ad-Blocking & Navigation Security**:
  - Full production stabilization of the `adblocker_webview` integration with EasyList & AdGuard filters.
  - Strict preservation of the `intent://` scheme blocking to prevent `ERR_UNKNOWN_URL_SCHEME` errors.
  - Retained executive obsidian dark UI aesthetics and full test suite coverage.

## What's New in v1.2.1 (Complete UI Overhaul & Ad-Blocking Web MP3)

- **Executive UI Overhaul**:
  - Eliminated purple and neon gradients across the entire app; established a solid obsidian dark architecture (`#0F0F12`) with high-contrast typography and a muted gold accent (`#D4AF37`).
  - Standardized all buttons, cards, and modal sheets to 4px–8px subtle rectangular geometry (no pill buttons).
  - Stripped all emojis, em dashes, and generic AI marketing copy in favor of direct, functional headings.
- **Integrated Ad-Blocker for Web MP3 (Pagalworld)**:
  - Integrated `adblocker_webview: ^2.3.0` using EasyList and AdGuard filters to block intrusive ads on Pagalworld.
  - Implemented `SafeAdBlockerWebviewController` to enforce strict HTTP/HTTPS scheme validation, blocking `intent://` and `market://` redirects and preventing `ERR_UNKNOWN_URL_SCHEME` errors.
- **Legal Pages & Web Favicon**:
  - Added official Privacy Policy (`PrivacyPolicyPage`) and Terms and Conditions (`TermsConditionPage`).
  - Added clean web favicon in `web/` and configured Windows runner `.ico` resources.

## What's New in v1.1.9 (WebView Intent Fix & In-App Update Link Repair)

- **Fixed WebView `intent://` Navigation Crash**:
  - Filtered non-HTTP/HTTPS navigation schemes (`intent://`, `market://`, etc.) in `WebSearchPage.NavigationDelegate` to prevent `net::ERR_UNKNOWN_URL_SCHEME` errors when browsing third-party web content.
  - Added logging diagnostics when unhandled schemes are prevented.
- **Repaired In-App Update Link Launching**:
  - Updated update popup action to reliably launch GitHub releases in external browsers via `LaunchMode.externalApplication`.
  - Added package visibility `<queries>` declaration in `AndroidManifest.xml` for browser intents on Android 11+.
  - Added automatic fallback with floating SnackBar and one-tap clipboard copy action if the browser fails to open.

## What's New in v1.1.8 (WebView MP3 Search & Download - Pagalworld)

- **Added WebView-Based MP3 Search and Download (Pagalworld)**:
  - Integrated `webview_flutter: ^4.14.1` with native Android WebView backing.
  - Dedicated `WebSearchPage` loading `https://pagalworld.is/` with search bar navigating to `https://pagalworld.is/search?q=<encoded_query>` on Enter.
  - Configured `WebViewController` with `JavaScriptMode.unrestricted`, dark theme background (`#0F0F12`), and unrestricted navigation/redirects.
  - Dedicated Home button in the AppBar returning to `https://pagalworld.is/`.
  - Handled Android back button navigation in WebView history via `PopScope`.
  - Linked `WebSearchPage` to Desktop Sidebar (index 9) and Mobile Navigation / App Drawer.

## What's New in v1.1.7 (YouTube Audio Stream Extractor Fix)

- **Fixed YouTube Playback with Native Stream Extractor**:
  - Resolved Android playback bug where raw `youtube.com/watch?v=...` HTML web page URLs caused ExoPlayer `UnrecognizedInputFormatException` errors.
  - Integrated `youtube_explode_dart: ^3.1.0` to extract direct high-bitrate Opus/AAC audio streams (`googlevideo.com`) on-the-fly.
  - Added quota-free search and stream extraction fallback, eliminating dependence on Google Cloud YouTube Data API quota.
  - Added safety guard in `PlayerNotifier` and `AudioEngine` preventing unplayable YouTube web page URLs (`youtube.com/watch`) from reaching ExoPlayer.
  - Verified and protected JioSaavn 320kbps `.mp4` stream resolution and playback.

## What's New in v1.1.6 (JioSaavn Bollywood Integration)

- **Added JioSaavn Bollywood Search & Streaming (Unofficial Wrapper)**:
  - High-fidelity 320kbps Bollywood music streaming powered by `jiosaavn_dart`.
  - Comprehensive song search with metadata extraction: song title, primary artists, album name, duration, media stream URL, and high-res album art.
  - Dedicated JioSaavn Bollywood Explorer page with quick trending search chips and instant playback into `AudioEngine`.
  - Full fallback and error handling for network hiccups or rate limits.

## What's New in v1.1.5 (Desktop Performance Overhaul & Spotify-Style Experience)

- **Complete Desktop Performance Overhaul (Windows .exe)**:
  - **Visualizer Performance Modes**: High (60 FPS unconstrained), Balanced (30 FPS capped ticker, recommended for integrated GPUs), Low (15 FPS minimal compute), and Off (completely suspends the ticker and GPU rendering).
  - **Isolated UI Rebuilding**: Seekbar scrubber and album art downsampling (96x96 cached palette generation) now run in isolated sub-trees using `RepaintBoundary`, eliminating 60fps frame drops on the main UI thread.
  - **Per-Monitor V2 High-DPI Clarity**: Added explicit `<dpiAware>true/pm</dpiAware>` and `<dpiAwareness>PerMonitorV2</dpiAwareness>` to Windows executable manifest, rendering UI at native crispness across 100%, 125%, 150%, and 200% scaling factors without fuzziness.
  - **Global Crash Logger**: Unhandled Flutter and native errors are intercepted and persisted to `%USERPROFILE%/Documents/CinematicMusicPlayer/logs/app.log` with automatic 5MB rotation.

- **100% Free & Offline Local Music Vault**:
  - Full offline capability without requiring any paid API key.
  - **Multi-Folder Library Management**: Add arbitrary music directories via directory picker; paths are persisted in `SharedPreferences` and auto-scanned on launch.
  - **Background Isolate Scanner**: Tag and duration extraction operates off the UI thread via `ScannerService`, saving metadata to `library_db.json`.
  - Manual "Add Folder" and "Rescan Library" controls in library view.
  - Fully decoupled credentials (`AppSecrets`) kept out of source tracking.

- **Spotify-Style Desktop Layout & Workflow**:
  - **Collapsible Desktop Sidebar**: Instant navigation to Home, Search, Your Library, Liked Songs, and custom Playlists with quick playlist creation dialog.
  - **Persistent Bottom Player Bar**: Left album artwork & title, center transport controls with dedicated independent seekbar, right volume slider, queue toggle, and full-screen view.
  - **Rich Library Views**: Tabbed browsing for Songs (with tabular track row format: #, artwork, title, album, duration, action menu), Albums, Artists, and Folders.
  - **Desktop Queue Drawer**: Sliding side drawer with live equalizer, track deletion, drag-to-reorder (`ReorderableListView`), and clear queue button.
  - **Global Keyboard Shortcuts**: Space (Play/Pause), Ctrl+Right (Next), Ctrl+Left (Previous), Up/Down (Volume $\pm 5\%$), M (Mute), `/` or Ctrl+K (Quick Search focus).

- **Complete Metrolist Ecosystem Architecture Integration**:
  - Researched and synthesized patterns from all 10 MetrolistGroup projects (`Metrolist`, `innertubex`, `quackjs`, `faraday`, `metroserver`, `metroproto`, `metrolist-coverart-lib`, `MetrolistManager`, `metrosite`, `metrobot`).
  - **Bounded LRU Audio Stream Cache (`AudioStreamCacheManager`)**: Streams are saved to disk with a 512 MB LRU ceiling, enabling instant zero-latency playback on repeated listens without touching the network.
  - **Predictive Lookahead Preloading (`NextTrackPreloadService`)**: Continuously monitors playback progress; when remaining duration is $\le 30$ seconds or playback reaches 80%, the next queue track is resolved and primed into cache.
  - **HTTP 206 Byte-Range Stream Health Probing**: Stream URLs are probed with byte-range headers (`bytes=0-1024`) to eliminate expired tokens and 403 playback failures before dispatch to the audio engine.

- **Smart Application Update System (`UpdateService` & `CinematicUpdateDialog`)**:
  - Semantic version comparisons (`AppVersion.compare`) supporting `1.0.x`, `1.1.0`, `1.1.1`, `1.1.2`, `1.1.3`, `1.1.4`, `1.2.0`, `2.0.0`, etc.
  - Automatic prompt on older versions (e.g. 1.0.x, 1.1.0, 1.1.1, 1.1.2) to upgrade to 1.1.3+.
  - Silenced on current/newer versions (v1.1.3 does not prompt for 1.1.3).
  - Sleek glassmorphic update dialog with:
    - **Update Now**: One-click download of the Windows installer or Android APK.
    - **Remind Me Later**: 24-hour suppression cooldown saved in `SharedPreferences`.
    - **Skip This Version**: Permanent dismissal for that specific release tag.
  - Non-blocking background execution with zero interruption to active music streaming.

---

## Key Features

- **YouTube Data API v3 Music Discovery & Search Integration (v1.1.2)**:
  - Secure, decoupled API key configuration layer (`YouTubeConfig`) stored separately from UI and repository code.
  - Live federated discovery for songs, artist channels, and playlists/albums with exact ISO 8601 duration extraction.
  - Native playback routing via `YouTubeMusicSource`, with automatic metadata mapping (`SongModel`) and library persistence.
  - Multi-tier resilient stream resolution with 45-minute TTL memory caching.

- **Searchable Bollywood & Global Music Catalog System (Open-Source Datasets)**:
  - Integrated music catalog synthesized from open-source datasets:
    - [devensinghbhagtani/Bollywood-Songs-Dataset](https://github.com/devensinghbhagtani/Bollywood-Songs-Dataset)
    - [MrAsacker/bollywood-songs-metadata](https://github.com/MrAsacker/bollywood-songs-metadata)
    - [MusicMoveArr/Datasets](https://github.com/MusicMoveArr/Datasets)
  - Dedicated **Song Database**, **Artist Database**, and **Album Database** converted into unified app-friendly models.
  - **Trending Section**: Popularity-ranked tracks calculated with weighted playcount metrics.
  - **Recently Added**: Chronologically indexed releases showcasing modern hits and classic remasters.
  - **Recommendations Foundation**: Content-based similarity engine matching artists, albums, genres, and release eras ($\pm 3$ years) with personalized user taste profiling.

- **Decoupled Multi-Source Music Architecture (Metrolist/InnerTubeX Inspired)**:
  - Unified abstract `MusicSource` provider layer cleanly decoupling audio playback from data provenance.
  - Seamless support for `LocalMusicSource` (offline encrypted vault), `CloudMusicSource` (Supabase storage & catalog), and `ExternalProviderSource` (custom streaming gateways).
  - Central `MusicSourceRepository` registry with federated multi-source search and smart lazy stream URI resolution with TTL-based caching.
  - Decoupled `SongModel` data flow: `MusicSource` $\rightarrow$ `SongModel` $\rightarrow$ `AudioEngine` $\rightarrow$ `audio_service` (Background Playback) $\rightarrow$ Cinematic UI.

- **Private Cloud Music Streaming Platform (Spotify-Style)**:
  - Stream master tracks on-demand with HTTP byte-range requests directly from Supabase Storage.
  - Dedicated **Cloud Library** with real-time Search, **Trending Now** rankings, **Recently Added** showcase, and **Browse by Artists & Albums**.
  - **Admin Music Library**: Built-in admin panel to upload audio files (`MP3`, `FLAC`, `WAV`, `M4A`) and album artwork, automatically extract ID3 tags, and publish tracks to your private cloud catalog.

- **100% Private Offline Audio Vault (Local Music)**:
  - Recursively scans local folders for `MP3`, `FLAC`, `WAV`, `M4A`, and `OGG` files.
  - Native Windows Win32 drag-and-drop import and synchronous File Explorer dialogs.
  - High-performance binary metadata reader extracts ID3v2 APIC and FLAC PICTURE embedded covers.

- **Dedicated Navigation Tabs**:
  - **Local Music**: Offline local music vault and drag-and-drop importer.
  - **Cloud Library**: Private streaming catalog with Trending, Artists, and Albums.
  - **Playlists**: User-created and cloud-synchronized playlists.
  - **Favorites**: Starred local and cloud songs with one-tap instant playback and shuffle.
  - **Studio Settings**: Account sync, multi-device management, and private Supabase credentials.

- **GPU Audio-Reactive Visualizers (GLSL 460)**:
  - **Preset 1 (3D Liquid Raymarched Orb)**: Real-time SDF sphere with 3D simplex noise surface displacement reactive to bass, mid-range waves, and treble highlights.
  - **Preset 2 (Polar Circular Spectrum Ring)**: 64-bar frequency ring with beat synchronization running at a fluid 60-120 FPS.
  - **Preset 3 (Aurora Dynamic Mesh Gradient)**: Multi-octave domain-warped mesh gradient derived from the active album art palette.
  - **Atmospheric Simulations**: Interactive Rain, Snow, Floating Dust, and Fireflies particle physics.

- **Synchronized Lyrics Engine**:
  - Reads companion `.lrc` files automatically.
  - Smooth viewport centering with active line bloom highlight and dimmed upcoming lines.
  - Interactive **Tap-to-Seek** to jump playback directly to any lyric timestamp.

- **Multi-Device Account & Cloud Synchronization**:
  - Single account across **Windows Desktop** and **Android Mobile**.
  - Two-way synchronization of playlists, starred favorites, playback counts, history, visualizer settings, and theme preferences.
  - Hardware device management with active heartbeat tracking and remote session revocation.

- **In-App Auto Update Checker**:
  - Automatically queries GitHub Releases on startup.
  - Shows update notifications when a new version is available with direct download links.

---

## Download & Install

Get the latest verified production release from [GitHub Releases](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/latest).

### Windows

1. Download **`CinematicMusicPlayerSetup.exe`** from GitHub Releases.
2. Run installer.
3. Open app.

*(A portable standalone archive `CinematicMusicPlayer-Windows.zip` is also available if you prefer running without installation).*

---

### Android

1. Download **`CinematicMusicPlayer.apk`** from GitHub Releases.
2. Tap the downloaded file and allow installation (*"Allow from this source"* if prompted).
3. Open app.

---

## Release Downloads Matrix (v1.1.1)

| Target Platform | Asset Filename | Package Type | Description |
| :--- | :--- | :--- | :--- |
| **Windows Desktop** | [CinematicMusicPlayerSetup.exe](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.1.1/CinematicMusicPlayerSetup.exe) | Self-Contained Installer | Complete Windows installer wizard with Start Menu and Desktop shortcuts. |
| **Windows Desktop** | [CinematicMusicPlayer-Windows.zip](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.1.1/CinematicMusicPlayer-Windows.zip) | Portable Archive | Standalone portable folder with executable, DLLs, and shaders. |
| **Android Mobile** | [CinematicMusicPlayer.apk](https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/download/v1.1.1/CinematicMusicPlayer.apk) | Signed Release APK | Direct installable APK targeting Android 6.0 through Android 14+. |

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
