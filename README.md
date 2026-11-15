# Cinematic Music Player

<p align="center">
  <img src="assets/icons/app_icon.png" width="130" height="130" alt="Cinematic Music Player Logo" />
</p>

<p align="center">
  <strong>A premium, 100% private cross-platform music player and audio sanctuary.</strong><br>
  Built with Impeller GLSL 460 fragment shaders, gapless audio engines, and multi-device cloud synchronization.
</p>

<p align="center">
  <a href="https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/latest"><img src="https://img.shields.io/badge/Release-v1.1.3-blueviolet.svg?style=flat-square" alt="Latest Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Platforms-Windows%20%7C%20Android-success.svg?style=flat-square" alt="Platforms">
</p>

---

## What's New in v1.1.3 (Backend Evolution + Smart Update System)

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
