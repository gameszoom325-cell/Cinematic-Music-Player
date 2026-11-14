# Cinematic Music Player v1.0.2

Production release **v1.0.2** brings advanced Android `AudioSession` focus and interruption management, multi-format embedded artwork extraction (ID3v2.2-2.4, FLAC PICTURE, M4A/AAC), dynamic library genre filtering, clean zero-state screens, and verified standalone Windows installer packages.

---

## 🌟 What's New in v1.0.2

### 1. 🎧 AudioSession & System Interruption Management
- **Headphone Unplug Protection (`becomingNoisyEventStream`)**: Audio playback automatically pauses the instant Bluetooth headsets, earbuds, or 3.5mm wired headphones are disconnected.
- **System Audio Focus Management (`interruptionEventStream`)**: Configured with `AudioSessionConfiguration.music()`. The player ducks volume during GPS/notification prompts, pauses gracefully on incoming phone calls, and resumes playback once calls conclude.
- **Resilient Playback Architecture**: Eagerly queued track dispatch with zero-cost fallback, eliminating uninitialized handler exceptions even under rapid tapping or cold starts.

### 2. 🖼️ Multi-Format Album Artwork Extraction
- **Streaming Buffer Safety (`_readFully`)**: Re-engineered low-level file I/O to read entire APIC frames into contiguous memory, preventing truncated or corrupted image headers.
- **Broad Format Coverage**:
  - MP3 ID3v2.2 (`PIC`), ID3v2.3 (`APIC`), and ID3v2.4 (`APIC`, synchsafe tags) with extended header offset support.
  - FLAC metadata block type 6 PICTURE.
  - M4A / AAC ISO MP4 atom parser (`©nam`, `©ART`, `©alb`, `covr -> data`).
- **Expanded Folder Artwork Fallbacks**: Scans parent folder for `cover.jpg`, `cover.png`, `folder.jpg`, `folder.png`, `album.jpg`, `album.png`, `front.jpg`, `front.png`, and `Artwork.jpg`.
- **URI Compatibility**: Full support for Android `content://` and `file://` schemes with dark-purple cinematic gradient fallback.

### 3. 🏷️ Dynamic Library Categories & Zero-State UI
- **Dynamic Genre Chips**: Category filter chips in `LibraryScreen` are derived from actual imported tracks. The category bar hides automatically when the library is empty.
- **Polished Zero States**: Clear, minimal empty states in both `LibraryScreen` (`"Your library is empty"`) and `PlaylistScreen` (`"No playlists created yet"`).
- **Accurate Status Header**: Replaced hardcoded `"STUDIO MASTER • 24-BIT"` badge in the player header with actual track bitrate/sample rate specs or `"OFFLINE AUDIO"`.

### 4. 💻 Self-Contained Windows Distribution
- Built with Inno Setup 6, including all required runtime DLLs (`flutter_windows.dll`), AOT binary (`data\app.so`), ICU globalization data (`data\icudtl.dat`), and compiled GLSL fragment shaders.
- Instant centered window launch (`1280x800`) with working directory set to application directory.
- Requires zero developer tools, SDKs, or Visual Studio runtimes on end-user machines.

---

## 📦 Downloads & Checksums

| Package | Platform | File Size | SHA-256 Checksum |
| :--- | :--- | :--- | :--- |
| **`CinematicMusicPlayer.apk`** | Android 8.0+ | ~61.1 MB | `26B3B9ABDC1F215BB8939D7D3240A3A3D51EA6C87B89617D2A36F5C8E93C0C38` |
| **`CinematicMusicPlayerSetup.exe`** | Windows 10 / 11 (x64) | ~28.1 MB | `7AC7F1FBDF0F965C46CFBBC45A07C950BC93E1D8EBFEFCB0D83E94FF5EBE0550` |
| **`CinematicMusicPlayer-Windows.zip`** | Windows 10 / 11 (Portable) | ~38.6 MB | `FB6930EB96B7F8BC6EF1DDA62BBC582C582327EF987B648E8CCFD78E1BE3FCE2` |

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
