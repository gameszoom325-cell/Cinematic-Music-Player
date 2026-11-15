import 'dart:async';
import 'package:flutter/foundation.dart';
import 'base_music_source.dart';
import 'music_source_type.dart';
import '../config/jamendo_config.dart';
import '../database/database_service.dart';
import '../database/models/song_model.dart';
import '../services/jamendo_api_service.dart';

/// Jamendo Music Source for Cinematic Music Player.
/// 
/// Integrates the royalty-free Jamendo catalog into the unified MusicSource architecture,
/// allowing track discovery, search, and direct MP3 streaming alongside local and YouTube music.
class JamendoMusicSource implements MusicSource {
  @override
  String get id => 'jamendo';

  @override
  String get displayName => 'Jamendo Music (Creative Commons)';

  @override
  MusicSourceType get type => MusicSourceType.jamendo;

  @override
  bool get isAvailable => JamendoConfig.instance.hasClientId;

  // Stream URL cache with 45-minute TTL to avoid repeated API calls
  final Map<String, _CachedStreamUrl> _streamUrlCache = {};
  static const Duration _cacheTtl = Duration(minutes: 45);

  @override
  Future<void> init() async {
    await JamendoConfig.instance.init();
    debugPrint("JamendoMusicSource initialized (Client ID configured: ${JamendoConfig.instance.hasClientId})");
  }

  @override
  Future<List<SongModel>> getSongs({int offset = 0, int limit = 50}) async {
    try {
      return await JamendoApiService.instance.getTrendingTracks(limit: limit, offset: offset);
    } catch (e) {
      debugPrint("JamendoMusicSource.getSongs error: $e");
      return [];
    }
  }

  @override
  Future<List<SongModel>> search(String query) async => searchSongs(query);

  @override
  Future<List<SongModel>> searchSongs(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return getSongs(limit: 25);
    return JamendoApiService.instance.searchTracks(clean, limit: 25);
  }

  @override
  Future<List<ArtistSummary>> searchArtists(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return getArtists();
    return JamendoApiService.instance.searchArtists(clean, limit: 15);
  }

  @override
  Future<List<AlbumSummary>> searchAlbums(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return getAlbums();
    return JamendoApiService.instance.searchAlbums(clean, limit: 15);
  }

  @override
  Future<List<AlbumSummary>> getAlbums() async {
    return [
      const AlbumSummary(
        name: "Cinematic Ambient Soundscapes",
        artist: "Jamendo Curated",
        artworkPath: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80",
        songCount: 20,
        songIds: [],
      ),
      const AlbumSummary(
        name: "Lofi Beats & Chillout",
        artist: "Jamendo Chill",
        artworkPath: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80",
        songCount: 25,
        songIds: [],
      ),
      const AlbumSummary(
        name: "Epic Orchestral Scores",
        artist: "Jamendo Classical",
        artworkPath: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80",
        songCount: 18,
        songIds: [],
      ),
    ];
  }

  @override
  Future<List<ArtistSummary>> getArtists() async {
    return [
      const ArtistSummary(
        name: "Alexander Morozov",
        songCount: 15,
        albumCount: 2,
        sampleArtworkPath: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80",
      ),
      const ArtistSummary(
        name: "StimiBeats",
        songCount: 12,
        albumCount: 1,
        sampleArtworkPath: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80",
      ),
      const ArtistSummary(
        name: "Joystock",
        songCount: 22,
        albumCount: 3,
        sampleArtworkPath: "https://images.unsplash.com/photo-1510915361894-db8b60106cb1?w=500&q=80",
      ),
    ];
  }

  @override
  Future<String> resolvePlaybackUri(SongModel song) async {
    // 1. Check in-memory stream URL cache
    final cached = _streamUrlCache[song.id];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // 2. If song path is already a valid remote HTTP stream URL, cache and return
    if (song.path.startsWith('http://') || song.path.startsWith('https://')) {
      _streamUrlCache[song.id] = _CachedStreamUrl(
        url: song.path,
        expiresAt: DateTime.now().add(_cacheTtl),
      );
      return song.path;
    }

    // 3. Otherwise fetch fresh track details from Jamendo API
    try {
      final fresh = await JamendoApiService.instance.getTrackById(song.sourceId ?? song.id);
      if (fresh != null && (fresh.path.startsWith('http://') || fresh.path.startsWith('https://'))) {
        _streamUrlCache[song.id] = _CachedStreamUrl(
          url: fresh.path,
          expiresAt: DateTime.now().add(_cacheTtl),
        );
        return fresh.path;
      }
    } catch (e) {
      debugPrint("JamendoMusicSource.resolvePlaybackUri exception: $e");
    }

    // Fallback: return original song path
    return song.path;
  }
}

class _CachedStreamUrl {
  final String url;
  final DateTime expiresAt;

  _CachedStreamUrl({required this.url, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
