# 🎵 Cinematic Music Player — Private Cloud Streaming Architecture

Cinematic Music Player has been upgraded from a local-only audio player into a **Private Cloud Music Streaming Platform** (Spotify-style private platform).

---

## 🏗️ 1. Architecture Overview

```
                      +-----------------------------------+
                      |       GitHub Repository           |
                      |  (Source Code & Releases Only)    |
                      +-----------------------------------+
                                        |
                 +----------------------+----------------------+
                 |                                             |
     +-----------------------+                     +-----------------------+
     |   Windows Desktop     |                     |    Android Mobile     |
     |  (Direct DAC Engine)  |                     |  (Background Service) |
     +-----------------------+                     +-----------------------+
                 \                                             /
                  \                                           /
                   +-----------------------------------------+
                   |       Supabase Cloud Infrastructure     |
                   |-----------------------------------------|
                   | 1. Storage Buckets:                     |
                   |    • music-files (Audio Master Streams) |
                   |    • album-covers (High-Res Artwork)    |
                   | 2. PostgREST Database:                  |
                   |    • songs, artists, albums, profiles   |
                   |    • sync_payloads (Cross-Device Sync)  |
                   | 3. GoTrue Authentication:               |
                   |    • Secure JWT Sessions & Offline Auth |
                   +-----------------------------------------+
```

---

## 📊 2. Database Schema & Tables

All database tables and storage policies are defined in [`supabase_schema.sql`](file:///C:/MY%20PROJECTS/supabase_schema.sql):

### `public.songs`
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `TEXT PRIMARY KEY` | Unique song ID (e.g. `song_179468...`) |
| `title` | `TEXT` | Song Title |
| `artist` | `TEXT` | Artist Name |
| `album` | `TEXT` | Album or Film name |
| `cover_image` | `TEXT` | Public HTTP URL from `album-covers` bucket |
| `genre` | `TEXT` | Music genre (Bollywood, Sufi, Lo-Fi, etc.) |
| `duration` | `INTEGER` | Duration in seconds |
| `audio_url` | `TEXT` | Direct streaming HTTP URL from `music-files` bucket |
| `play_count` | `INTEGER` | Play counter for real-time trending calculation |
| `created_at` | `TIMESTAMPTZ` | Timestamp of upload |

### `public.artists`
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `TEXT PRIMARY KEY` | Unique artist ID |
| `name` | `TEXT UNIQUE` | Artist Name |
| `image` | `TEXT` | Artist avatar image URL |
| `biography` | `TEXT` | Artist description & bio |

### `public.albums`
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `TEXT PRIMARY KEY` | Unique album ID |
| `title` | `TEXT` | Album Title |
| `artist` | `TEXT` | Artist Name |
| `artwork` | `TEXT` | Album artwork URL |
| `release_info` | `TEXT` | Release metadata |

---

## 🛡️ 3. Admin Music Library (Upload Portal)

The app includes an **Admin Music Library** (`AdminUploadScreen`) accessible directly from:
- **Cloud Library Screen** → Top right **"Admin Upload"** pill button.
- **Settings Screen** → Under **Cloud Synchronization** → **"Admin Music Library"**.

### Admin Features:
1. **Audio Master File Upload**:
   - Supports `.mp3`, `.flac`, `.wav`, `.m4a`, `.aac`, `.ogg`.
   - Uploads to the Supabase Storage bucket `music-files`.
2. **Automated Metadata Extraction**:
   - Analyzes ID3v2, ID3v1, and Vorbis tags using `AudioMetadataParser`.
   - Automatically populates **Title**, **Artist**, **Album**, **Genre**, **Year**, **Duration**, and **Embedded Artwork**.
3. **High-Res Cover Artwork Upload**:
   - Keeps embedded ID3 picture or allows selecting custom cover image.
   - Uploads to the Supabase Storage bucket `album-covers`.
4. **Auto-Organization**:
   - Automatically registers artist and album entries in Supabase.
5. **Catalog Management**:
   - View, preview stream, or delete cloud tracks anytime.

---

## 📱 4. App Navigation & Dedicated Tabs

Navigation across Windows (Top capsule header & left sidebar) and Android (Bottom navigation bar) is organized into four core tabs:

1. **Local Music (`LibraryScreen`)**:
   - Offline music vault with native Win32 drag-and-drop import, folder picker, and 60 FPS virtualized scrolling for offline audio files.
2. **Cloud Library (`CloudLibraryScreen`)**:
   - **Real-Time Search**: Search songs, artists, albums, or genres with instant debounced filtering.
   - **Trending Now**: Horizontal carousel sorted by real-time play counts.
   - **Featured Artists**: Browse artist avatars with biography previews and artist-filtered tracklists.
   - **Featured Albums**: Browse album artwork cards with track count and album playback.
   - **Recently Added**: Fresh cloud additions with one-tap streaming.
   - **Admin Upload**: Quick access to publish new tracks.
3. **Playlists (`PlaylistScreen`)**:
   - Create and organize custom playlists synchronized across all your devices.
4. **Favorites (`FavoritesScreen`)**:
   - Star any local or cloud track to add it to your synchronized favorites list. Supports "Play All" and "Shuffle".
5. **Studio Settings (`SettingsScreen`)**:
   - Account login, profile, multi-device management, custom Supabase credentials configuration, and audio engine diagnostics.

---

## ⚡ 5. Performance & Streaming Engine

- **On-Demand HTTP Range Streaming**:
  - Songs are never pre-downloaded in bulk; `just_audio` streams remote audio chunks on-demand via HTTP byte-range requests.
- **GPU Visualizer Integration**:
  - Real audio PCM/FFT spectrum sampling (`FFTEngine`) smoothly drives the 3D raymarched liquid orb and aurora mesh during streaming.
- **Downsampled Image Caching**:
  - Cloud cover artwork decoders are restricted to `cacheWidth: 120, cacheHeight: 120` in list items and `160` in cards, preventing memory spikes on mobile devices.
- **Virtualized Lists**:
  - `RepaintBoundary` and fixed extents ensure a smooth 60 FPS scroll over thousands of tracks.
