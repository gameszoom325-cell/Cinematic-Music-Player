import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../database/models/song_model.dart';

/// Metadata entry tracking a cached audio stream file on local storage.
class AudioCacheEntry {
  final String songId;
  final String fileName;
  int fileSizeBytes;
  int lastAccessedEpoch;
  final int addedEpoch;
  final String remoteUrl;

  AudioCacheEntry({
    required this.songId,
    required this.fileName,
    required this.fileSizeBytes,
    required this.lastAccessedEpoch,
    required this.addedEpoch,
    required this.remoteUrl,
  });

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'fileName': fileName,
    'fileSizeBytes': fileSizeBytes,
    'lastAccessedEpoch': lastAccessedEpoch,
    'addedEpoch': addedEpoch,
    'remoteUrl': remoteUrl,
  };

  factory AudioCacheEntry.fromJson(Map<String, dynamic> json) => AudioCacheEntry(
    songId: json['songId'] as String? ?? '',
    fileName: json['fileName'] as String? ?? '',
    fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
    lastAccessedEpoch: (json['lastAccessedEpoch'] as num?)?.toInt() ?? 0,
    addedEpoch: (json['addedEpoch'] as num?)?.toInt() ?? 0,
    remoteUrl: json['remoteUrl'] as String? ?? '',
  );
}

/// Advanced LRU Audio Stream Cache Manager inspired by Metrolist's AudioCacheManager.
/// 
/// Features:
/// 1. Zero-latency instant replay: Cached streams play immediately from disk without hitting the network.
/// 2. Bounded Storage with LRU Eviction: Enforces configurable storage threshold (default 512 MB).
/// 3. Predictive Background Priming: Pre-caches upcoming tracks in queue ahead of time.
/// 4. Atomic Temp File Commit: Protects against incomplete or aborted downloads.
class AudioStreamCacheManager {
  AudioStreamCacheManager._internal();

  static final AudioStreamCacheManager instance = AudioStreamCacheManager._internal();

  Directory? _cacheDir;
  final Map<String, AudioCacheEntry> _index = {};
  bool _initialized = false;
  final Set<String> _activeDownloads = {};

  /// Configurable maximum cache ceiling (default: 512 MB)
  int maxCacheSizeBytes = 512 * 1024 * 1024;

  bool get isInitialized => _initialized;

  int get currentCacheSizeBytes =>
      _index.values.fold(0, (sum, entry) => sum + entry.fileSizeBytes);

  int get cachedTrackCount => _index.length;

  /// Initializes directory and loads the persistent index manifest.
  Future<void> init({Directory? overrideDir}) async {
    if (_initialized && overrideDir == null) return;

    try {
      if (overrideDir != null) {
        _cacheDir = overrideDir;
      } else {
        try {
          final supportDir = await getApplicationSupportDirectory();
          _cacheDir = Directory(p.join(supportDir.path, 'stream_cache', 'audio'));
        } catch (_) {
          try {
            final tempDir = await getTemporaryDirectory();
            _cacheDir = Directory(p.join(tempDir.path, 'stream_cache', 'audio'));
          } catch (_) {
            _cacheDir = Directory(p.join(Directory.systemTemp.path, 'cinematic_stream_cache', 'audio'));
          }
        }
      }

      if (!_cacheDir!.existsSync()) {
        _cacheDir!.createSync(recursive: true);
      }

      await _loadIndex();
      _initialized = true;
      debugPrint("AudioStreamCacheManager initialized at ${_cacheDir!.path} with ${_index.length} entries (${currentCacheSizeBytes ~/ (1024 * 1024)} MB).");
    } catch (e) {
      debugPrint("AudioStreamCacheManager initialization warning: $e");
    }
  }

  File get _manifestFile => File(p.join(_cacheDir!.path, 'cache_manifest.json'));

  Future<void> _loadIndex() async {
    _index.clear();
    if (_cacheDir == null) return;
    try {
      final manifest = _manifestFile;
      if (manifest.existsSync()) {
        final content = await manifest.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        for (final entry in data.entries) {
          final entryData = entry.value as Map<String, dynamic>;
          final cacheEntry = AudioCacheEntry.fromJson(entryData);
          final diskFile = File(p.join(_cacheDir!.path, cacheEntry.fileName));
          if (diskFile.existsSync() && diskFile.lengthSync() > 1024) {
            cacheEntry.fileSizeBytes = diskFile.lengthSync();
            _index[entry.key] = cacheEntry;
          }
        }
      }
    } catch (e) {
      debugPrint("AudioStreamCacheManager._loadIndex error: $e");
    }
  }

  Future<void> _saveIndex() async {
    if (_cacheDir == null) return;
    try {
      final manifest = _manifestFile;
      final map = _index.map((key, val) => MapEntry(key, val.toJson()));
      await manifest.writeAsString(jsonEncode(map), flush: true);
    } catch (e) {
      debugPrint("AudioStreamCacheManager._saveIndex error: $e");
    }
  }

  String _sanitizeSongId(String songId) {
    return songId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  /// Checks if a song is already cached on disk.
  /// If present, refreshes LRU access timestamp and returns file path.
  Future<String?> getCachedFilePath(String songId) async {
    if (!_initialized) await init();
    if (_cacheDir == null) return null;

    final entry = _index[songId];
    if (entry != null) {
      final file = File(p.join(_cacheDir!.path, entry.fileName));
      if (file.existsSync() && file.lengthSync() > 1024) {
        entry.lastAccessedEpoch = DateTime.now().millisecondsSinceEpoch;
        _saveIndex();
        return file.path;
      } else {
        _index.remove(songId);
      }
    }

    // Direct filesystem probe fallback
    final safeId = _sanitizeSongId(songId);
    for (final ext in ['.m4a', '.mp3', '.webm']) {
      final candidate = File(p.join(_cacheDir!.path, '$safeId$ext'));
      if (candidate.existsSync() && candidate.lengthSync() > 1024) {
        _index[songId] = AudioCacheEntry(
          songId: songId,
          fileName: p.basename(candidate.path),
          fileSizeBytes: candidate.lengthSync(),
          lastAccessedEpoch: DateTime.now().millisecondsSinceEpoch,
          addedEpoch: DateTime.now().millisecondsSinceEpoch,
          remoteUrl: '',
        );
        _saveIndex();
        return candidate.path;
      }
    }

    return null;
  }

  /// Downloads and caches a remote audio stream in the background.
  /// Uses atomic temporary file write to ensure data integrity.
  Future<String?> cacheStream(
    SongModel song,
    String streamUrl, {
    Duration timeout = const Duration(seconds: 40),
  }) async {
    if (!_initialized) await init();
    if (_cacheDir == null) return null;
    if (_activeDownloads.contains(song.id)) return null;

    final existing = await getCachedFilePath(song.id);
    if (existing != null) return existing;

    _activeDownloads.add(song.id);

    final safeId = _sanitizeSongId(song.id);
    final ext = streamUrl.contains('.mp3') ? '.mp3' : '.m4a';
    final tempFile = File(p.join(_cacheDir!.path, '$safeId.tmp'));
    final finalFile = File(p.join(_cacheDir!.path, '$safeId$ext'));

    http.Client? client;
    try {
      client = http.Client();
      final request = http.Request('GET', Uri.parse(streamUrl));
      request.headers['User-Agent'] = 'CinematicMusicPlayer/1.1.3';

      final response = await client.send(request).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final sink = tempFile.openWrite();
        await response.stream.pipe(sink);
        await sink.close();

        if (tempFile.existsSync() && tempFile.lengthSync() > 1024) {
          if (finalFile.existsSync()) finalFile.deleteSync();
          tempFile.renameSync(finalFile.path);

          final now = DateTime.now().millisecondsSinceEpoch;
          _index[song.id] = AudioCacheEntry(
            songId: song.id,
            fileName: p.basename(finalFile.path),
            fileSizeBytes: finalFile.lengthSync(),
            lastAccessedEpoch: now,
            addedEpoch: now,
            remoteUrl: streamUrl,
          );

          await _saveIndex();
          await pruneCacheIfNeeded();

          debugPrint("AudioStreamCacheManager: Successfully cached ${song.title} (${finalFile.lengthSync() ~/ 1024} KB)");
          return finalFile.path;
        }
      }
    } catch (e) {
      debugPrint("AudioStreamCacheManager.cacheStream error for ${song.title}: $e");
    } finally {
      _activeDownloads.remove(song.id);
      client?.close();
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    }
    return null;
  }

  /// Asynchronously prefetches a track into cache.
  void prefetch(SongModel song, String streamUrl) {
    if (_activeDownloads.contains(song.id)) return;
    unawaited(cacheStream(song, streamUrl));
  }

  /// Prunes oldest unaccessed cache items when total usage exceeds ceiling.
  Future<void> pruneCacheIfNeeded() async {
    if (currentCacheSizeBytes <= maxCacheSizeBytes) return;

    final targetCeiling = (maxCacheSizeBytes * 0.75).toInt();
    final entries = _index.values.toList()
      ..sort((a, b) => a.lastAccessedEpoch.compareTo(b.lastAccessedEpoch));

    for (final entry in entries) {
      if (currentCacheSizeBytes <= targetCeiling) break;

      final file = File(p.join(_cacheDir!.path, entry.fileName));
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
      _index.remove(entry.songId);
    }

    await _saveIndex();
    debugPrint("AudioStreamCacheManager pruned cache down to ${currentCacheSizeBytes ~/ (1024 * 1024)} MB.");
  }

  /// Clears all cached stream audio files.
  Future<void> clearCache() async {
    if (!_initialized) await init();
    if (_cacheDir == null) return;

    for (final entry in _index.values) {
      final file = File(p.join(_cacheDir!.path, entry.fileName));
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    _index.clear();
    await _saveIndex();
    debugPrint("AudioStreamCacheManager: Cache cleared.");
  }
}
