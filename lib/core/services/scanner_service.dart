import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/models/song_model.dart';
import '../database/database_service.dart';
import '../audio_engine/waveform_analyzer.dart';
import 'audio_metadata_parser.dart';
import 'windows_file_dialog.dart';

class ScannerService {
  static const Set<String> supportedExtensions = {
    '.mp3', '.flac', '.wav', '.m4a', '.ogg', '.aac', '.opus', '.wma', '.aiff', '.alac'
  };

  static Future<bool> requestStoragePermissions() async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await Permission.audio.isGranted || await Permission.storage.isGranted) {
        return true;
      }

      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) {
        // Request photos/images for local folder album art (cover.jpg/folder.jpg)
        await Permission.photos.request();
        return true;
      }

      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;

      if (await Permission.manageExternalStorage.isGranted) return true;

      return false;
    }
    return true;
  }

  // Option 1: Pick Music Folder
  static Future<String?> pickMusicFolder() async {
    if (kIsWeb) return null;

    // Use native Win32 COM FileOpenDialog on Windows
    if (Platform.isWindows) {
      try {
        final path = WindowsFileDialog.pickFolder(dialogTitle: "Select Music Folder");
        return path;
      } catch (e) {
        debugPrint("WindowsFileDialog.pickFolder fallback: $e");
      }
    }

    final granted = await requestStoragePermissions();
    if (!granted && defaultTargetPlatform == TargetPlatform.android) {
      throw Exception("Storage permission denied. Please grant audio/storage permissions to pick folders.");
    }

    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "Select Music Folder",
      );
      return selectedPath;
    } catch (e) {
      debugPrint("Error picking folder: $e");
      throw Exception("Failed to open folder picker: $e");
    }
  }

  // Option 2: Pick Multiple Audio Files
  static Future<List<File>?> pickAudioFiles() async {
    if (kIsWeb) return null;

    // Use native Win32 COM FileOpenDialog on Windows
    if (Platform.isWindows) {
      try {
        final paths = WindowsFileDialog.pickAudioFiles(dialogTitle: "Import Audio Tracks");
        if (paths != null && paths.isNotEmpty) {
          return paths
              .map((p) => File(p))
              .where((file) => file.existsSync())
              .toList();
        }
        return null;
      } catch (e) {
        debugPrint("WindowsFileDialog.pickAudioFiles fallback: $e");
      }
    }

    final granted = await requestStoragePermissions();
    if (!granted && defaultTargetPlatform == TargetPlatform.android) {
      throw Exception("Storage permission denied. Please grant audio/storage permissions to import tracks.");
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'opus', 'wma', 'aiff', 'alac'],
        allowMultiple: true,
        dialogTitle: "Import Audio Tracks",
      );

      if (result != null && result.paths.isNotEmpty) {
        return result.paths
            .whereType<String>()
            .map((path) => File(path))
            .where((file) => file.existsSync())
            .toList();
      }
      return null;
    } catch (e) {
      debugPrint("Error picking audio files: $e");
      throw Exception("Failed to open file picker: $e");
    }
  }

  // Option 3: Standard Storage Directories
  static List<String> getStandardMusicDirectories() {
    final List<String> paths = [];
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Public';
      paths.add(p.join(userProfile, 'Music'));
      paths.add('C:\\Users\\Public\\Music');
      paths.add(p.join(userProfile, 'Downloads'));
    } else if (Platform.isAndroid) {
      paths.add('/storage/emulated/0/Music');
      paths.add('/storage/emulated/0/Download');
      paths.add('/storage/emulated/0/Downloads');
      paths.add('/storage/emulated/0/Audio');
      paths.add('/storage/emulated/0/media');
      paths.add('/sdcard/Music');
      paths.add('/sdcard/Download');
    }
    return paths;
  }

  // Import a batch of files using background Isolate to prevent UI frame drops
  static Future<List<SongModel>> importFiles(
    List<File> files, {
    void Function(int current, int total)? onProgress,
  }) async {
    final List<SongModel> importedSongs = [];
    final cacheDir = await getApplicationDocumentsDirectory();
    final artDir = Directory(p.join(cacheDir.path, 'CinematicMusicPlayer', 'art_cache'));
    final musicDir = Directory(p.join(cacheDir.path, 'CinematicMusicPlayer', 'imported_music'));
    if (!await artDir.exists()) await artDir.create(recursive: true);
    if (!await musicDir.exists()) await musicDir.create(recursive: true);

    final total = files.length;
    final List<File> targetFiles = [];

    // Pre-check files and copy temporary picker files to persistent directory
    for (int i = 0; i < total; i++) {
      final file = files[i];
      if (!file.existsSync()) continue;

      File targetFile = file;
      final lowerPath = file.path.toLowerCase();
      if (lowerPath.contains('/cache/') ||
          lowerPath.contains('\\cache\\') ||
          lowerPath.contains('file_picker') ||
          lowerPath.contains('/tmp/') ||
          lowerPath.contains('\\temp\\')) {
        try {
          final destPath = p.join(musicDir.path, p.basename(file.path));
          targetFile = await file.copy(destPath);
        } catch (e) {
          debugPrint("Note: Kept original file path: $e");
          targetFile = file;
        }
      }
      targetFiles.add(targetFile);
    }

    // Process files in isolate batches of 15 to keep memory footprint light and reporting progress smoothly
    final artDirPath = artDir.path;
    const batchSize = 15;

    for (int i = 0; i < targetFiles.length; i += batchSize) {
      final end = (i + batchSize < targetFiles.length) ? i + batchSize : targetFiles.length;
      final batchSlice = targetFiles.sublist(i, end).map((f) => f.path).toList();

      final batchSongs = await Isolate.run(() async {
        final List<SongModel> songs = [];
        final dir = Directory(artDirPath);
        for (final path in batchSlice) {
          final file = File(path);
          if (file.existsSync()) {
            final song = await _processAudioFileInternal(file, dir);
            if (song != null && song.isLocalFileAvailable) {
              songs.add(song);
            }
          }
        }
        return songs;
      });

      importedSongs.addAll(batchSongs);
      onProgress?.call(end, targetFiles.length);
    }

    if (importedSongs.isNotEmpty) {
      await DatabaseService.instance.upsertSongs(importedSongs);
      // Asynchronously compute waveforms in background without waiting
      for (final s in importedSongs) {
        WaveformAnalyzer.analyzeSong(s.id, s.path).ignore();
      }
    }

    return importedSongs;
  }

  // Scan directory recursively with background isolate batching
  static Future<List<SongModel>> scanDirectory(
    Directory rootDir, {
    void Function(int current, int total)? onProgress,
  }) async {
    final List<SongModel> detectedSongs = [];
    final List<File> audioFiles = [];

    if (!await rootDir.exists()) return detectedSongs;

    try {
      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            audioFiles.add(entity);
          }
        }
      }

      final cacheDir = await getApplicationDocumentsDirectory();
      final artDir = Directory(p.join(cacheDir.path, 'CinematicMusicPlayer', 'art_cache'));
      if (!await artDir.exists()) {
        await artDir.create(recursive: true);
      }

      final artDirPath = artDir.path;
      final total = audioFiles.length;
      const batchSize = 20;

      for (int i = 0; i < total; i += batchSize) {
        final end = (i + batchSize < total) ? i + batchSize : total;
        final batchSlice = audioFiles.sublist(i, end).map((f) => f.path).toList();

        final batchSongs = await Isolate.run(() async {
          final List<SongModel> songs = [];
          final dir = Directory(artDirPath);
          for (final path in batchSlice) {
            final file = File(path);
            if (file.existsSync()) {
              final s = await _processAudioFileInternal(file, dir);
              if (s != null && s.isLocalFileAvailable) {
                songs.add(s);
              }
            }
          }
          return songs;
        });

        detectedSongs.addAll(batchSongs);
        onProgress?.call(end, total);
      }

      if (detectedSongs.isNotEmpty) {
        await DatabaseService.instance.upsertSongs(detectedSongs);
        for (final s in detectedSongs) {
          WaveformAnalyzer.analyzeSong(s.id, s.path).ignore();
        }
      }
    } catch (e) {
      debugPrint("Library scan error: $e");
    }

    return detectedSongs;
  }

  // Internal audio processing executed inside background isolate
  static Future<SongModel?> _processAudioFileInternal(File file, Directory artDir) async {
    try {
      final stat = await file.stat();
      final parsed = await AudioMetadataParser.parseFile(file);
      final id = sha256.convert(file.path.codeUnits).toString();

      String? artworkPath;
      bool hasArtwork = false;

      // 1. Embedded cover art
      if (parsed.pictureBytes != null && parsed.pictureBytes!.isNotEmpty) {
        final artFile = File(p.join(artDir.path, '$id.jpg'));
        await artFile.writeAsBytes(parsed.pictureBytes!, flush: false);
        artworkPath = artFile.path;
        hasArtwork = true;
      }

      // 2. Fallback to folder artwork images (cover.jpg, folder.jpg, album.png, etc.)
      if (!hasArtwork) {
        final parentDir = file.parent;
        const candidateNames = [
          'cover.jpg',
          'cover.jpeg',
          'cover.png',
          'folder.jpg',
          'folder.jpeg',
          'folder.png',
          'album.jpg',
          'album.jpeg',
          'album.png',
          'front.jpg',
          'front.jpeg',
          'front.png',
          'Artwork.jpg',
          'artwork.jpg',
          'Artwork.png',
          'artwork.png',
        ];
        for (final name in candidateNames) {
          final candidate = File(p.join(parentDir.path, name));
          if (candidate.existsSync()) {
            hasArtwork = true;
            artworkPath = candidate.path;
            break;
          }
        }
      }

      // 3. Companion .lrc lyrics file (Song.mp3 -> Song.lrc)
      String? lrcPath;
      final dir = file.parent.path;
      final baseName = p.basenameWithoutExtension(file.path);
      final potentialLrc = File(p.join(dir, '$baseName.lrc'));
      if (potentialLrc.existsSync()) {
        lrcPath = potentialLrc.path;
      }

      final song = SongModel(
        id: id,
        path: file.path,
        title: parsed.title,
        artist: parsed.artist,
        album: parsed.album,
        durationMs: parsed.durationMs,
        bitrate: parsed.bitrate,
        sampleRate: parsed.sampleRate,
        format: parsed.format,
        fileSize: stat.size,
        hasArtwork: hasArtwork,
        artworkPath: artworkPath,
        genre: parsed.genre,
        year: parsed.year,
        lyrics: parsed.lyrics,
        lrcPath: lrcPath,
        dateAdded: stat.modified,
      );

      return song;
    } catch (e) {
      debugPrint("Error processing audio file ${file.path}: $e");
      return null;
    }
  }
}
