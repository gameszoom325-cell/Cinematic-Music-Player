import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/jamendo_config.dart';
import '../database/database_service.dart';
import '../database/models/song_model.dart';

/// Service interfacing directly with the Jamendo Music API v3.0.
/// 
/// Provides discovery for royalty-free and Creative Commons music, artist exploration,
/// album browsing, and direct MP3 audio streaming capabilities.
class JamendoApiService {
  JamendoApiService._internal();
  static final JamendoApiService instance = JamendoApiService._internal();

  static const String _baseUrl = 'https://api.jamendo.com/v3.0';

  // Cache to reduce repeated API lookups and protect quota
  final Map<String, _CachedJamendoResult> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 10);

  http.Client? _client;
  http.Client get _httpClient => _client ??= http.Client();

  /// Search Jamendo catalog for tracks by keyword (title, artist, tags, mood)
  Future<List<SongModel>> searchTracks(
    String query, {
    int limit = 25,
    int offset = 0,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return getTrendingTracks(limit: limit, offset: offset);
    }

    final cacheKey = 'tracks_${cleanQuery}_${limit}_$offset';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.songs;
    }

    final clientId = JamendoConfig.instance.clientId;
    if (clientId.isEmpty) {
      debugPrint("JamendoApiService: Missing Client ID. Please configure JAMENDO_CLIENT_ID in JamendoConfig.");
      return [];
    }

    try {
      final uri = Uri.parse('$_baseUrl/tracks/').replace(queryParameters: {
        'client_id': clientId,
        'format': 'json',
        'limit': limit.clamp(1, 100).toString(),
        'offset': offset.toString(),
        'search': cleanQuery,
        'audioformat': 'mp31',
        'include': 'musicinfo',
      });

      final response = await _httpClient.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'CinematicMusicPlayer/1.1.3',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint("JamendoApiService HTTP error (${response.statusCode}) for query '$cleanQuery':\n${response.body}");
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final headers = data['headers'] as Map<String, dynamic>? ?? {};
      final status = headers['status'] as String? ?? 'failed';

      if (status != 'success') {
        final code = headers['code'];
        final errorMsg = headers['error_message'] ?? 'Unknown Jamendo API error';
        debugPrint("JamendoApiService returned error [Code $code]: $errorMsg (Client ID: ${JamendoConfig.instance.maskedClientId})");
        return [];
      }

      final results = data['results'] as List? ?? [];
      final songs = results
          .map((item) => _parseJamendoTrack(item as Map<String, dynamic>))
          .whereType<SongModel>()
          .toList();

      _cache[cacheKey] = _CachedJamendoResult(
        songs: songs,
        expiresAt: DateTime.now().add(_cacheTtl),
      );

      return songs;
    } catch (e, stack) {
      debugPrint("JamendoApiService.searchTracks exception for '$cleanQuery': $e\n$stack");
      return [];
    }
  }

  /// Fetch trending and popular tracks on Jamendo (weekly popularity)
  Future<List<SongModel>> getTrendingTracks({
    int limit = 25,
    int offset = 0,
  }) async {
    final cacheKey = 'trending_${limit}_$offset';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.songs;
    }

    final clientId = JamendoConfig.instance.clientId;
    if (clientId.isEmpty) {
      debugPrint("JamendoApiService: Missing Client ID.");
      return [];
    }

    try {
      final uri = Uri.parse('$_baseUrl/tracks/').replace(queryParameters: {
        'client_id': clientId,
        'format': 'json',
        'limit': limit.clamp(1, 100).toString(),
        'offset': offset.toString(),
        'order': 'popularity_week',
        'audioformat': 'mp31',
        'include': 'musicinfo',
      });

      final response = await _httpClient.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'CinematicMusicPlayer/1.1.3',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint("JamendoApiService.getTrendingTracks error (${response.statusCode}):\n${response.body}");
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? [];
      final songs = results
          .map((item) => _parseJamendoTrack(item as Map<String, dynamic>))
          .whereType<SongModel>()
          .toList();

      _cache[cacheKey] = _CachedJamendoResult(
        songs: songs,
        expiresAt: DateTime.now().add(_cacheTtl),
      );

      return songs;
    } catch (e, stack) {
      debugPrint("JamendoApiService.getTrendingTracks exception: $e\n$stack");
      return [];
    }
  }

  /// Search artists across Jamendo by keyword
  Future<List<ArtistSummary>> searchArtists(String query, {int limit = 15}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final clientId = JamendoConfig.instance.clientId;
    if (clientId.isEmpty) return [];

    try {
      // Use track search with artist query to ensure robust cross-endpoint compatibility
      final uri = Uri.parse('$_baseUrl/tracks/').replace(queryParameters: {
        'client_id': clientId,
        'format': 'json',
        'limit': (limit * 2).clamp(1, 50).toString(),
        'search': cleanQuery,
      });

      final response = await _httpClient.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'CinematicMusicPlayer/1.1.3',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];
      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? [];

      final Map<String, _ArtistAggregation> artistMap = {};
      for (final item in results) {
        final artistName = item['artist_name'] as String? ?? '';
        if (artistName.isEmpty) continue;
        final key = artistName.toLowerCase();
        final artwork = (item['album_image'] as String?) ?? (item['image'] as String?);

        final entry = artistMap.putIfAbsent(key, () => _ArtistAggregation(name: artistName, sampleArt: artwork));
        entry.trackCount++;
        if (entry.sampleArt == null && artwork != null) {
          entry.sampleArt = artwork;
        }
      }

      return artistMap.values.take(limit).map((a) => ArtistSummary(
        name: a.name,
        songCount: a.trackCount,
        albumCount: 1,
        sampleArtworkPath: a.sampleArt,
      )).toList();
    } catch (e) {
      debugPrint("JamendoApiService.searchArtists error: $e");
      return [];
    }
  }

  /// Search albums across Jamendo by keyword
  Future<List<AlbumSummary>> searchAlbums(String query, {int limit = 15}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final clientId = JamendoConfig.instance.clientId;
    if (clientId.isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/tracks/').replace(queryParameters: {
        'client_id': clientId,
        'format': 'json',
        'limit': (limit * 2).clamp(1, 50).toString(),
        'search': cleanQuery,
      });

      final response = await _httpClient.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'CinematicMusicPlayer/1.1.3',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];
      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? [];

      final Map<String, _AlbumAggregation> albumMap = {};
      for (final item in results) {
        final albumName = (item['album_name'] as String?) ?? '';
        final artistName = (item['artist_name'] as String?) ?? '';
        if (albumName.isEmpty) continue;

        final key = "${albumName.toLowerCase()}:::${artistName.toLowerCase()}";
        final artwork = (item['album_image'] as String?) ?? (item['image'] as String?);
        final trackId = "jamendo_${item['id']}";

        final entry = albumMap.putIfAbsent(key, () => _AlbumAggregation(
          name: albumName,
          artist: artistName,
          artwork: artwork,
        ));
        entry.songIds.add(trackId);
        if (entry.artwork == null && artwork != null) {
          entry.artwork = artwork;
        }
      }

      return albumMap.values.take(limit).map((a) => AlbumSummary(
        name: a.name,
        artist: a.artist,
        artworkPath: a.artwork,
        songCount: a.songIds.length,
        songIds: a.songIds,
      )).toList();
    } catch (e) {
      debugPrint("JamendoApiService.searchAlbums error: $e");
      return [];
    }
  }

  /// Fetch single track by ID to obtain fresh stream audio URL
  Future<SongModel?> getTrackById(String trackId) async {
    final cleanId = trackId.replaceFirst('jamendo_', '').trim();
    if (cleanId.isEmpty) return null;

    final clientId = JamendoConfig.instance.clientId;
    if (clientId.isEmpty) return null;

    try {
      final uri = Uri.parse('$_baseUrl/tracks/').replace(queryParameters: {
        'client_id': clientId,
        'format': 'json',
        'id': cleanId,
        'audioformat': 'mp31',
        'include': 'musicinfo',
      });

      final response = await _httpClient.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'CinematicMusicPlayer/1.1.3',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? [];
      if (results.isEmpty) return null;

      return _parseJamendoTrack(results.first as Map<String, dynamic>);
    } catch (e) {
      debugPrint("JamendoApiService.getTrackById error for $trackId: $e");
      return null;
    }
  }

  /// Maps Jamendo raw track JSON item into a unified SongModel
  SongModel? _parseJamendoTrack(Map<String, dynamic> item) {
    try {
      final rawId = item['id']?.toString() ?? '';
      if (rawId.isEmpty) return null;

      final title = (item['name'] as String?)?.trim() ?? 'Unknown Track';
      final artist = (item['artist_name'] as String?)?.trim() ?? 'Jamendo Artist';
      final album = (item['album_name'] as String?)?.trim() ?? 'Jamendo Creative Commons';
      final durationSec = (item['duration'] as num?)?.toInt() ?? 0;
      final artworkUrl = (item['album_image'] as String?) ?? (item['image'] as String?);
      final audioUrl = (item['audio'] as String?)?.trim() ?? '';
      final shareUrl = (item['shareurl'] as String?)?.trim() ?? 'https://www.jamendo.com/track/$rawId';
      final releaseDate = (item['releasedate'] as String?) ?? '';

      // Extract genre tags if present
      String genre = 'Creative Commons';
      if (item['musicinfo'] is Map<String, dynamic>) {
        final tags = item['musicinfo']['tags'] as Map<String, dynamic>?;
        if (tags != null && tags['genres'] is List && (tags['genres'] as List).isNotEmpty) {
          genre = (tags['genres'][0] as String).capitalizeFirst();
        }
      }

      return SongModel(
        id: 'jamendo_$rawId',
        path: audioUrl,
        title: title,
        artist: artist,
        album: album,
        albumArtist: artist,
        language: 'Instrumental / Global',
        durationMs: durationSec * 1000,
        bitrate: 128,
        sampleRate: 44100,
        format: 'MP3',
        fileSize: 0,
        hasArtwork: artworkUrl != null && artworkUrl.isNotEmpty,
        artworkPath: artworkUrl,
        isFavorite: false,
        playCount: 0,
        dateAdded: DateTime.now(),
        bpm: 0.0,
        genre: genre,
        year: releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '',
        sourceType: 'jamendo',
        sourceId: rawId,
        externalUrl: shareUrl,
      );
    } catch (e) {
      debugPrint("Error parsing Jamendo track: $e");
      return null;
    }
  }
}

class _CachedJamendoResult {
  final List<SongModel> songs;
  final DateTime expiresAt;

  _CachedJamendoResult({required this.songs, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class _ArtistAggregation {
  final String name;
  String? sampleArt;
  int trackCount = 0;

  _ArtistAggregation({required this.name, this.sampleArt});
}

class _AlbumAggregation {
  final String name;
  final String artist;
  String? artwork;
  final List<String> songIds = [];

  _AlbumAggregation({required this.name, required this.artist, this.artwork});
}

extension _StringCap on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
