import 'dart:io';
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
import 'smart_matching_service.dart';

class ScannerService {
  static const Set<String> supportedExtensions = {
    '.mp3', '.flac', '.wav', '.m4a', '.ogg', '.aac'
  };

  static Future<bool> requestStoragePermissions() async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await Permission.audio.isGranted || await Permission.storage.isGranted) {
        return true;
      }

      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) return true;

      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }

  // Option 1: Pick Music Folder
  static Future<String?> pickMusicFolder() async {
    final granted = await requestStoragePermissions();
    if (!granted && defaultTargetPlatform == TargetPlatform.android) {
      debugPrint("Storage permission denied on Android.");
      return null;
    }

    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "Select Music Folder",
      );
      return selectedPath;
    } catch (e) {
      debugPrint("Error picking folder: $e");
      return null;
    }
  }

  // Option 2: Pick Multiple Audio Files
  static Future<List<File>?> pickAudioFiles() async {
    final granted = await requestStoragePermissions();
    if (!granted && defaultTargetPlatform == TargetPlatform.android) return null;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
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
    } catch (e) {
      debugPrint("Error picking audio files: $e");
    }
    return null;
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

  // Import a custom batch of files with persistent caching for temporary picker paths
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
    for (int i = 0; i < total; i++) {
      final file = files[i];
      if (!file.existsSync()) continue;

      File targetFile = file;
      final lowerPath = file.path.toLowerCase();
      // If file was picked from a temporary cache directory, make a permanent copy
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

      final song = await _processAudioFile(targetFile, artDir);
      if (song != null && song.isLocalFileAvailable) {
        importedSongs.add(song);
        WaveformAnalyzer.analyzeSong(song.id, song.path).ignore();
      }
      onProgress?.call(i + 1, total);
    }

    if (importedSongs.isNotEmpty) {
      await DatabaseService.instance.upsertSongs(importedSongs);
    }
    return importedSongs;
  }

  // Scan directory recursively
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

      final total = audioFiles.length;
      for (int i = 0; i < total; i++) {
        final file = audioFiles[i];
        final song = await _processAudioFile(file, artDir);
        if (song != null) {
          detectedSongs.add(song);
          WaveformAnalyzer.analyzeSong(song.id, song.path).ignore();
        }
        onProgress?.call(i + 1, total);
      }

      await DatabaseService.instance.upsertSongs(detectedSongs);
    } catch (e) {
      debugPrint("Library scan error: $e");
    }

    return detectedSongs;
  }

  static Future<SongModel?> _processAudioFile(File file, Directory artDir) async {
    try {
      final stat = await file.stat();
      final parsed = await AudioMetadataParser.parseFile(file);
      final id = sha256.convert(file.path.codeUnits).toString();

      String? artworkPath;
      bool hasArtwork = false;

      // 1. Check embedded cover art bytes
      if (parsed.pictureBytes != null && parsed.pictureBytes!.isNotEmpty) {
        final artFile = File(p.join(artDir.path, '$id.jpg'));
        await artFile.writeAsBytes(parsed.pictureBytes!);
        artworkPath = artFile.path;
        hasArtwork = true;
      }

      // 2. Fallback to folder cover.jpg / folder.jpg
      if (!hasArtwork) {
        final parentDir = file.parent;
        final localCover = File(p.join(parentDir.path, 'cover.jpg'));
        final localFolder = File(p.join(parentDir.path, 'folder.jpg'));
        if (await localCover.exists()) {
          hasArtwork = true;
          artworkPath = localCover.path;
        } else if (await localFolder.exists()) {
          hasArtwork = true;
          artworkPath = localFolder.path;
        }
      }

      // 3. Check for companion .lrc lyrics file (Song.mp3 -> Song.lrc)
      String? lrcPath;
      final dir = file.parent.path;
      final baseName = p.basenameWithoutExtension(file.path);
      final potentialLrc = File(p.join(dir, '$baseName.lrc'));
      if (await potentialLrc.exists()) {
        lrcPath = potentialLrc.path;
      }

      SongModel song = SongModel(
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

      // 4. Smart Matching against curated Hindi catalogue
      final catalogueMatch = SmartMatchingService.findCatalogueMatch(
        filePath: file.path,
        tagTitle: parsed.title,
        tagArtist: parsed.artist,
      );

      if (catalogueMatch != null) {
        song = await SmartMatchingService.enrichSongWithCatalogue(
          song: song,
          match: catalogueMatch,
        );
      }

      return song;
    } catch (e) {
      debugPrint("Error processing audio file ${file.path}: $e");
      return null;
    }
  }
}
