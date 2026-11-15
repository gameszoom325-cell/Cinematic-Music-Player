import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'base_music_source.dart';
import 'music_source_type.dart';
import 'local_music_source.dart';
import 'cloud_music_source.dart';
import 'online_music_source.dart';
import 'external_provider_source.dart';
import 'youtube_music_source.dart';
import 'jamendo_music_source.dart';
import '../catalog/catalog_music_source.dart';
import '../database/models/song_model.dart';
import '../database/database_service.dart';
import '../services/audio_stream_cache_manager.dart';

/// Unified result container for multi-category federated search (Songs, Artists, Albums)
class FederatedSearchResult {
  final String query;
  final List<SongModel> songs;
  final List<ArtistSummary> artists;
  final List<AlbumSummary> albums;

  const FederatedSearchResult({
    required this.query,
    this.songs = const [],
    this.artists = const [],
    this.albums = const [],
  });

  factory FederatedSearchResult.empty(String query) => FederatedSearchResult(query: query);

  bool get isEmpty => songs.isEmpty && artists.isEmpty && albums.isEmpty;
}

/// Central repository orchestrating all music sources in Cinematic Music Player.
/// Implements a unified abstraction layer over:
/// - Local offline acoustic vault (LocalMusicSource)
/// - Private Supabase cloud catalog (CloudMusicSource)
/// - Modern online streaming client (OnlineMusicSource - InnerTubeX pattern)
class MusicSourceRepository {
  MusicSourceRepository._internal() {
    _registerDefaultSources();
  }

  static final MusicSourceRepository instance = MusicSourceRepository._internal();

  final Map<MusicSourceType, MusicSource> _sources = {};
  MusicSourceType? _activeFilter;

  // Search results cache to eliminate redundant network requests
  final Map<String, _CachedSearch> _searchCache = {};
  static const Duration _searchCacheTtl = Duration(minutes: 5);

  void _registerDefaultSources() {
    registerSource(LocalMusicSource());
    registerSource(CloudMusicSource());
    registerSource(OnlineMusicSource());
    registerSource(CatalogMusicSource());
    registerSource(YouTubeMusicSource());
    registerSource(JamendoMusicSource());
    registerSource(ExternalProviderSource());
  }

  void registerSource(MusicSource source) {
    _sources[source.type] = source;
  }

  MusicSource? getSource(MusicSourceType type) => _sources[type];

  List<MusicSource> get allSources => _sources.values.toList();

  MusicSourceType? get activeFilter => _activeFilter;

  void setActiveFilter(MusicSourceType? filter) {
    _activeFilter = filter;
  }

  /// Initialize all available music sources
  Future<void> init() async {
    for (final src in _sources.values) {
      try {
        await src.init();
      } catch (e) {
        debugPrint("Error initializing source ${src.displayName}: $e");
      }
    }
  }

  /// Multi-category federated search across songs, artists, and albums
  Future<FederatedSearchResult> searchFederated(String query, {MusicSourceType? filter}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return FederatedSearchResult.empty(query);

    final songs = await searchSongs(cleanQuery, filter: filter);
    final artists = await searchArtists(cleanQuery, filter: filter);
    final albums = await searchAlbums(cleanQuery, filter: filter);

    return FederatedSearchResult(
      query: query,
      songs: songs,
      artists: artists,
      albums: albums,
    );
  }

  /// Search songs across registered sources
  Future<List<SongModel>> searchSongs(String query, {MusicSourceType? filter}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return getAllSongs(filter: filter);

    final targetFilter = filter ?? _activeFilter;
    if (targetFilter != null) {
      final src = _sources[targetFilter];
      if (src != null) {
        return src.searchSongs(cleanQuery);
      }
    }

    final cached = _searchCache[cleanQuery];
    if (cached != null && !cached.isExpired) {
      return cached.results;
    }

    final activeSources = _sources.values.where((s) => s.isAvailable).toList();
    final searchFutures = activeSources.map((src) async {
      try {
        return await src.searchSongs(cleanQuery);
      } catch (e) {
        debugPrint("searchSongs error in ${src.displayName}: $e");
        return <SongModel>[];
      }
    });

    final nestedResults = await Future.wait(searchFutures);
    final Set<String> seenIds = {};
    final List<SongModel> merged = [];

    for (final list in nestedResults) {
      for (final song in list) {
        if (!seenIds.contains(song.id)) {
          seenIds.add(song.id);
          merged.add(song);
        }
      }
    }

    _searchCache[cleanQuery] = _CachedSearch(
      results: merged,
      expiresAt: DateTime.now().add(_searchCacheTtl),
    );

    return merged;
  }

  /// Search artists across registered sources
  Future<List<ArtistSummary>> searchArtists(String query, {MusicSourceType? filter}) async {
    final cleanQuery = query.trim().toLowerCase();
    final targetFilter = filter ?? _activeFilter;
    if (targetFilter != null) {
      final src = _sources[targetFilter];
      if (src != null) return src.searchArtists(cleanQuery);
    }

    final activeSources = _sources.values.where((s) => s.isAvailable).toList();
    final futures = activeSources.map((src) async {
      try {
        return await src.searchArtists(cleanQuery);
      } catch (e) {
        debugPrint("searchArtists error in ${src.displayName}: $e");
        return <ArtistSummary>[];
      }
    });

    final nested = await Future.wait(futures);
    final Set<String> seenNames = {};
    final List<ArtistSummary> merged = [];

    for (final list in nested) {
      for (final a in list) {
        if (!seenNames.contains(a.name.toLowerCase())) {
          seenNames.add(a.name.toLowerCase());
          merged.add(a);
        }
      }
    }
    return merged;
  }

  /// Search albums across registered sources
  Future<List<AlbumSummary>> searchAlbums(String query, {MusicSourceType? filter}) async {
    final cleanQuery = query.trim().toLowerCase();
    final targetFilter = filter ?? _activeFilter;
    if (targetFilter != null) {
      final src = _sources[targetFilter];
      if (src != null) return src.searchAlbums(cleanQuery);
    }

    final activeSources = _sources.values.where((s) => s.isAvailable).toList();
    final futures = activeSources.map((src) async {
      try {
        return await src.searchAlbums(cleanQuery);
      } catch (e) {
        debugPrint("searchAlbums error in ${src.displayName}: $e");
        return <AlbumSummary>[];
      }
    });

    final nested = await Future.wait(futures);
    final Set<String> seenAlbums = {};
    final List<AlbumSummary> merged = [];

    for (final list in nested) {
      for (final a in list) {
        final key = "${a.name.toLowerCase()}:::${a.artist.toLowerCase()}";
        if (!seenAlbums.contains(key)) {
          seenAlbums.add(key);
          merged.add(a);
        }
      }
    }
    return merged;
  }

  /// Convenience wrapper for backward compatibility
  Future<List<SongModel>> searchAll(String query) => searchSongs(query);

  /// Fetches songs across registered sources based on active filter
  Future<List<SongModel>> getAllSongs({MusicSourceType? filter}) async {
    final targetFilter = filter ?? _activeFilter;
    if (targetFilter != null) {
      final src = _sources[targetFilter];
      if (src != null) {
        return src.getSongs(limit: 100);
      }
    }

    final List<SongModel> combined = [];
    final Set<String> seenIds = {};

    for (final src in _sources.values) {
      if (!src.isAvailable) continue;
      try {
        final songs = await src.getSongs(limit: 50);
        for (final song in songs) {
          if (!seenIds.contains(song.id)) {
            seenIds.add(song.id);
            combined.add(song);
          }
        }
      } catch (e) {
        debugPrint("Error fetching songs from ${src.displayName}: $e");
      }
    }

    return combined;
  }

  /// Unified artist aggregation
  Future<List<ArtistSummary>> getAllArtists({MusicSourceType? filter}) async {
    final targetFilter = filter ?? _activeFilter;
    if (targetFilter != null) {
      final src = _sources[targetFilter];
      if (src != null) return src.getArtists();
    }

    final List<ArtistSummary> combined = [];
    for (final src in _sources.values) {
      if (!src.isAvailable) continue;
      try {
        final artists = await src.getArtists();
        combined.addAll(artists);
      } catch (_) {}
    }
    return combined;
  }

  /// Unified album aggregation
  Future<List<AlbumSummary>> getAllAlbums({MusicSourceType? filter}) async {
    final targetFilter = filter ?? _activeFilter;
    if (targetFilter != null) {
      final src = _sources[targetFilter];
      if (src != null) return src.getAlbums();
    }

    final List<AlbumSummary> combined = [];
    for (final src in _sources.values) {
      if (!src.isAvailable) continue;
      try {
        final albums = await src.getAlbums();
        combined.addAll(albums);
      } catch (_) {}
    }
    return combined;
  }

  /// Resolves the final playable audio URI for any song by delegating
  /// to its originating MusicSource (lazy stream resolution).
  /// Integrates LRU disk cache lookup and Faraday/InnerTubeX stream validation.
  Future<SongModel> resolvePlayableSong(SongModel song) async {
    // 1. If it's already a local file that exists, return directly
    if (!song.isRemoteStream && song.isLocalFileAvailable) {
      return song;
    }

    // 2. Check LRU Audio Stream Cache for instantaneous offline playback
    try {
      final cachedPath = await AudioStreamCacheManager.instance.getCachedFilePath(song.id);
      if (cachedPath != null) {
        debugPrint("MusicSourceRepository: Stream cache hit for '${song.title}' -> $cachedPath");
        return song.copyWith(path: cachedPath);
      }
    } catch (e) {
      debugPrint("MusicSourceRepository cache lookup warning: $e");
    }

    // 3. Delegate resolution to originating source
    final sourceType = MusicSourceType.fromString(song.sourceType);
    final source = _sources[sourceType] ?? _sources[MusicSourceType.online] ?? _sources[MusicSourceType.local];

    if (source != null) {
      try {
        final resolvedUri = await source.resolvePlaybackUri(song);

        // 4. Validate stream health using HTTP 206 range probe if remote
        if (resolvedUri.startsWith('http://') || resolvedUri.startsWith('https://')) {
          final isHealthy = await verifyStreamHealth(resolvedUri);
          // Never fall back to an unplayable YouTube webpage URL if range probe fails or times out
          final finalUri = (isHealthy || resolvedUri.contains('googlevideo.com') || resolvedUri.contains('saavncdn.com'))
              ? resolvedUri
              : (song.path.contains('youtube.com') ? resolvedUri : song.path);

          // 5. Trigger asynchronous background caching into LRU audio cache
          if (isHealthy && !finalUri.contains('youtube.com')) {
            unawaited(AudioStreamCacheManager.instance.cacheStream(song, finalUri));
          }
          return song.copyWith(path: finalUri);
        }

        return song.copyWith(path: resolvedUri);
      } catch (e) {
        debugPrint("Error resolving playback URI for ${song.title}: $e");
      }
    }
    return song;
  }

  /// Verifies stream health using a lightweight HTTP 206 byte-range probe.
  /// Inspired by Faraday and InnerTubeX stream validators.
  static Future<bool> verifyStreamHealth(String url, {Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final uri = Uri.parse(url);
      final request = http.Request('GET', uri);
      request.headers['Range'] = 'bytes=0-1024';
      request.headers['User-Agent'] = 'CinematicMusicPlayer/1.1.3';

      final client = http.Client();
      try {
        final streamedResponse = await client.send(request).timeout(timeout);
        // Valid status for range request is 206 Partial Content or 200 OK
        if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 206) {
          return true;
        }
        // 403 Forbidden or 404 indicates expired signature or dead stream
        if (streamedResponse.statusCode == 403 || streamedResponse.statusCode == 404) {
          debugPrint("verifyStreamHealth: Stream rejected with HTTP ${streamedResponse.statusCode} for $url");
          return false;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint("verifyStreamHealth check notice: $e");
    }
    // Fail-open for transient network disconnects
    return true;
  }
}

class _CachedSearch {
  final List<SongModel> results;
  final DateTime expiresAt;

  _CachedSearch({required this.results, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
