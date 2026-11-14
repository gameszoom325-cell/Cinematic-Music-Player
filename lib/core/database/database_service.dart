import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'models/song_model.dart';
import 'models/playlist_model.dart';
import 'models/waveform_cache_model.dart';

class AlbumSummary {
  final String name;
  final String artist;
  final String? artworkPath;
  final int songCount;
  final List<String> songIds;

  const AlbumSummary({
    required this.name,
    required this.artist,
    this.artworkPath,
    required this.songCount,
    required this.songIds,
  });
}

class ArtistSummary {
  final String name;
  final int songCount;
  final int albumCount;
  final String? sampleArtworkPath;

  const ArtistSummary({
    required this.name,
    required this.songCount,
    required this.albumCount,
    this.sampleArtworkPath,
  });
}

class DatabaseService {
  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();
  DatabaseService._();

  final Map<String, SongModel> _songs = {};
  final Map<String, PlaylistModel> _playlists = {};
  final Map<String, WaveformCacheModel> _waveformCache = {};
  final List<String> _historySongIds = [];

  bool _initialized = false;
  File? _dbFile;
  File? _waveformFile;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final appDir = Directory('${dir.path}/CinematicMusicPlayer');
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }

      _dbFile = File('${appDir.path}/library_db.json');
      _waveformFile = File('${appDir.path}/waveform_cache.json');

      if (await _dbFile!.exists()) {
        final content = await _dbFile!.readAsString();
        if (content.isNotEmpty) {
          final data = json.decode(content) as Map<String, dynamic>;

          if (data['songs'] != null) {
            final songList = data['songs'] as List;
            for (final item in songList) {
              final song = SongModel.fromMap(item as Map<String, dynamic>);
              _songs[song.id] = song;
            }
          }

          if (data['playlists'] != null) {
            final plList = data['playlists'] as List;
            for (final item in plList) {
              final pl = PlaylistModel.fromMap(item as Map<String, dynamic>);
              _playlists[pl.id] = pl;
            }
          }

          if (data['history'] != null) {
            _historySongIds.addAll(List<String>.from(data['history'] as List));
          }
        }
      }

      if (await _waveformFile!.exists()) {
        final content = await _waveformFile!.readAsString();
        if (content.isNotEmpty) {
          final data = json.decode(content) as Map<String, dynamic>;
          for (final entry in data.entries) {
            _waveformCache[entry.key] =
                WaveformCacheModel.fromMap(entry.value as Map<String, dynamic>);
          }
        }
      }

      _ensureDefaultPlaylists();
      _initialized = true;
    } catch (e) {
      debugPrint("Database initialization fallback: $e");
      _initialized = true;
    }
  }

  void _ensureDefaultPlaylists() {
    if (!_playlists.containsKey('favorites')) {
      _playlists['favorites'] = PlaylistModel(
        id: 'favorites',
        name: 'Favorites',
        description: 'Your starred and favorite tracks',
        songIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSmartPlaylist: true,
      );
    }
    if (!_playlists.containsKey('recently_played')) {
      _playlists['recently_played'] = PlaylistModel(
        id: 'recently_played',
        name: 'Recently Played',
        description: 'Auto-updating history of recently played tracks',
        songIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSmartPlaylist: true,
      );
    }
  }

  Future<void> _persistDb() async {
    if (_dbFile == null) return;
    try {
      final data = {
        'songs': _songs.values.map((s) => s.toMap()).toList(),
        'playlists': _playlists.values.map((p) => p.toMap()).toList(),
        'history': _historySongIds,
      };
      final tempFile = File('${_dbFile!.path}.tmp');
      await tempFile.writeAsString(json.encode(data), flush: true);
      if (await tempFile.exists()) {
        if (await _dbFile!.exists()) await _dbFile!.delete();
        await tempFile.rename(_dbFile!.path);
      }
    } catch (e) {
      debugPrint("Error persisting DB: $e");
    }
  }

  Future<void> _persistWaveforms() async {
    if (_waveformFile == null) return;
    try {
      final data = _waveformCache.map((k, v) => MapEntry(k, v.toMap()));
      final tempFile = File('${_waveformFile!.path}.tmp');
      await tempFile.writeAsString(json.encode(data), flush: true);
      if (await tempFile.exists()) {
        if (await _waveformFile!.exists()) await _waveformFile!.delete();
        await tempFile.rename(_waveformFile!.path);
      }
    } catch (e) {
      debugPrint("Error persisting waveforms: $e");
    }
  }

  // --- Song Operations ---
  List<SongModel> getAllSongs() => _songs.values.toList();

  SongModel? getSongById(String id) => _songs[id];

  List<SongModel> getRecentlyPlayedSongs() {
    final List<SongModel> recents = [];
    for (final id in _historySongIds) {
      final song = _songs[id];
      if (song != null) recents.add(song);
    }
    return recents;
  }

  List<SongModel> getFavorites() {
    return _songs.values.where((s) => s.isFavorite).toList();
  }

  List<AlbumSummary> getAllAlbums() {
    final Map<String, List<SongModel>> albumMap = {};
    for (final s in _songs.values) {
      final key = "${s.album}:::${s.artist}";
      albumMap.putIfAbsent(key, () => []).add(s);
    }

    return albumMap.entries.map((e) {
      final songs = e.value;
      final firstWithArt = songs.firstWhere(
        (s) => s.artworkPath != null,
        orElse: () => songs.first,
      );
      return AlbumSummary(
        name: songs.first.album,
        artist: songs.first.artist,
        artworkPath: firstWithArt.artworkPath,
        songCount: songs.length,
        songIds: songs.map((s) => s.id).toList(),
      );
    }).toList();
  }

  List<ArtistSummary> getAllArtists() {
    final Map<String, List<SongModel>> artistMap = {};
    for (final s in _songs.values) {
      artistMap.putIfAbsent(s.artist, () => []).add(s);
    }

    return artistMap.entries.map((e) {
      final songs = e.value;
      final albums = songs.map((s) => s.album).toSet();
      final firstWithArt = songs.firstWhere(
        (s) => s.artworkPath != null,
        orElse: () => songs.first,
      );
      return ArtistSummary(
        name: e.key,
        songCount: songs.length,
        albumCount: albums.length,
        sampleArtworkPath: firstWithArt.artworkPath,
      );
    }).toList();
  }

  Future<void> upsertSongs(List<SongModel> newSongs) async {
    for (final song in newSongs) {
      _songs[song.id] = song;
    }
    await _persistDb();
  }

  Future<void> toggleFavorite(String songId) async {
    final song = _songs[songId];
    if (song != null) {
      final updated = song.copyWith(isFavorite: !song.isFavorite);
      _songs[songId] = updated;

      final favPlaylist = _playlists['favorites'];
      if (favPlaylist != null) {
        final List<String> updatedSongIds = List.from(favPlaylist.songIds);
        if (updated.isFavorite) {
          if (!updatedSongIds.contains(songId)) updatedSongIds.add(songId);
        } else {
          updatedSongIds.remove(songId);
        }
        _playlists['favorites'] = favPlaylist.copyWith(
          songIds: updatedSongIds,
          updatedAt: DateTime.now(),
        );
      }
      await _persistDb();
    }
  }

  Future<void> recordPlay(String songId) async {
    final song = _songs[songId];
    if (song != null) {
      _songs[songId] = song.copyWith(
        playCount: song.playCount + 1,
        lastPlayedAt: DateTime.now(),
      );

      _historySongIds.remove(songId);
      _historySongIds.insert(0, songId);
      if (_historySongIds.length > 200) {
        _historySongIds.removeLast();
      }

      final recentPl = _playlists['recently_played'];
      if (recentPl != null) {
        _playlists['recently_played'] = recentPl.copyWith(
          songIds: List.from(_historySongIds),
          updatedAt: DateTime.now(),
        );
      }
      await _persistDb();
    }
  }

  // --- Playlist Operations ---
  List<PlaylistModel> getAllPlaylists() => _playlists.values.toList();

  PlaylistModel? getPlaylistById(String id) => _playlists[id];

  Future<void> createPlaylist(String name, {String description = ""}) async {
    final id = 'pl_${DateTime.now().millisecondsSinceEpoch}';
    final pl = PlaylistModel(
      id: id,
      name: name,
      description: description,
      songIds: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _playlists[id] = pl;
    await _persistDb();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final pl = _playlists[playlistId];
    if (pl != null && !pl.songIds.contains(songId)) {
      final updatedIds = List<String>.from(pl.songIds)..add(songId);
      _playlists[playlistId] = pl.copyWith(
        songIds: updatedIds,
        updatedAt: DateTime.now(),
      );
      await _persistDb();
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final pl = _playlists[playlistId];
    if (pl != null) {
      final updatedIds = List<String>.from(pl.songIds)..remove(songId);
      _playlists[playlistId] = pl.copyWith(
        songIds: updatedIds,
        updatedAt: DateTime.now(),
      );
      await _persistDb();
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    if (_playlists[playlistId]?.isSmartPlaylist ?? false) return;
    _playlists.remove(playlistId);
    await _persistDb();
  }

  // --- Waveform & Audio Pre-Analysis Cache ---
  WaveformCacheModel? getWaveform(String songId) => _waveformCache[songId];

  Future<void> saveWaveform(WaveformCacheModel waveform) async {
    _waveformCache[waveform.songId] = waveform;
    if (_songs.containsKey(waveform.songId)) {
      _songs[waveform.songId] = _songs[waveform.songId]!.copyWith(bpm: waveform.bpm);
    }
    await _persistWaveforms();
    await _persistDb();
  }

  // --- Search ---
  List<SongModel> searchSongs(String query) {
    if (query.trim().isEmpty) return getAllSongs();
    final lower = query.toLowerCase();
    return _songs.values.where((s) {
      return s.title.toLowerCase().contains(lower) ||
          s.artist.toLowerCase().contains(lower) ||
          s.album.toLowerCase().contains(lower) ||
          s.genre.toLowerCase().contains(lower);
    }).toList();
  }

  // --- Cloud Sync Integration Helpers ---
  List<String> getRawHistoryIds() => List.unmodifiable(_historySongIds);

  Future<void> applyCloudPlaylists(List<PlaylistModel> cloudPlaylists) async {
    for (final cp in cloudPlaylists) {
      // Find matching playlist by id or name
      final existing = _playlists[cp.id] ??
          _playlists.values.firstWhere((p) => p.name.toLowerCase() == cp.name.toLowerCase(),
              orElse: () => cp);

      if (existing.id == cp.id && _playlists.containsKey(cp.id)) {
        // Conflict resolution: latest updatedAt wins
        if (cp.updatedAt.isAfter(existing.updatedAt)) {
          _playlists[cp.id] = cp;
        }
      } else {
        // Add newly discovered cloud playlist
        _playlists[cp.id] = cp;
      }
    }
    await _persistDb();
  }

  Future<void> applyCloudFavorites(Set<String> favSignatures) async {
    bool changed = false;
    final List<String> favSongIds = [];

    for (final entry in _songs.entries) {
      final song = entry.value;
      final signature = "${song.title.trim().toLowerCase()}:::${song.artist.trim().toLowerCase()}";
      final isFavInCloud = favSignatures.contains(signature) || favSignatures.contains(song.id);

      if (isFavInCloud && !song.isFavorite) {
        _songs[entry.key] = song.copyWith(isFavorite: true);
        changed = true;
      }

      if (_songs[entry.key]!.isFavorite) {
        favSongIds.add(entry.key);
      }
    }

    final favPlaylist = _playlists['favorites'];
    if (favPlaylist != null) {
      _playlists['favorites'] = favPlaylist.copyWith(
        songIds: favSongIds,
        updatedAt: DateTime.now(),
      );
      changed = true;
    }

    if (changed) {
      await _persistDb();
    }
  }

  Future<void> applyCloudHistory(Map<String, int> playCounts, List<String> recentSignatures) async {
    bool changed = false;

    // 1. Merge play counts
    for (final entry in _songs.entries) {
      final song = entry.value;
      final signature = "${song.title.trim().toLowerCase()}:::${song.artist.trim().toLowerCase()}";
      final cloudCount = playCounts[signature] ?? playCounts[song.id] ?? 0;
      if (cloudCount > song.playCount) {
        _songs[entry.key] = song.copyWith(playCount: cloudCount);
        changed = true;
      }
    }

    // 2. Merge recently played
    for (final sig in recentSignatures.reversed) {
      final song = _songs.values.firstWhere(
        (s) => "${s.title.trim().toLowerCase()}:::${s.artist.trim().toLowerCase()}" == sig || s.id == sig,
        orElse: () => SongModel(
          id: '',
          path: '',
          title: '',
          artist: '',
          album: '',
          durationMs: 0,
        ),
      );
      if (song.id.isNotEmpty && !_historySongIds.contains(song.id)) {
        _historySongIds.insert(0, song.id);
        changed = true;
      }
    }

    while (_historySongIds.length > 200) {
      _historySongIds.removeLast();
    }

    final recentPl = _playlists['recently_played'];
    if (recentPl != null) {
      _playlists['recently_played'] = recentPl.copyWith(
        songIds: List.from(_historySongIds),
        updatedAt: DateTime.now(),
      );
      changed = true;
    }

    if (changed) {
      await _persistDb();
    }
  }
}
