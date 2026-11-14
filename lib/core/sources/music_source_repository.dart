import 'dart:async';
import 'package:flutter/foundation.dart';
import 'base_music_source.dart';
import 'music_source_type.dart';
import 'local_music_source.dart';
import 'cloud_music_source.dart';
import 'external_provider_source.dart';
import '../database/models/song_model.dart';
import '../database/database_service.dart';

/// Central repository orchestrating all music sources in Cinematic Music Player.
/// Implements a unified abstraction layer over local disk storage, private Supabase cloud,
/// and external streaming providers.
class MusicSourceRepository {
  MusicSourceRepository._internal() {
    _registerDefaultSources();
  }

  static final MusicSourceRepository instance = MusicSourceRepository._internal();

  final Map<MusicSourceType, BaseMusicSource> _sources = {};
  MusicSourceType? _activeFilter;

  // Search results cache to eliminate redundant network requests
  final Map<String, _CachedSearch> _searchCache = {};
  static const Duration _searchCacheTtl = Duration(minutes: 5);

  void _registerDefaultSources() {
    registerSource(LocalMusicSource());
    registerSource(CloudMusicSource());
    registerSource(ExternalProviderSource());
  }

  void registerSource(BaseMusicSource source) {
    _sources[source.type] = source;
  }

  BaseMusicSource? getSource(MusicSourceType type) => _sources[type];

  List<BaseMusicSource> get allSources => _sources.values.toList();

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

  /// Unified federated search:
  /// Queries all active sources concurrently and merges results with source tagging.
  Future<List<SongModel>> searchAll(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return getAllSongs();

    // Check search cache
    final cached = _searchCache[cleanQuery];
    if (cached != null && !cached.isExpired) {
      return cached.results;
    }

    final activeSources = _activeFilter != null
        ? [_sources[_activeFilter]!].whereType<BaseMusicSource>().toList()
        : _sources.values.where((s) => s.isAvailable).toList();

    final searchFutures = activeSources.map((src) async {
      try {
        return await src.search(cleanQuery);
      } catch (e) {
        debugPrint("Search error in ${src.displayName}: $e");
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

  /// Fetches songs across registered sources based on the active filter
  Future<List<SongModel>> getAllSongs({MusicSourceType? filter}) async {
    final targetFilter = filter ?? _activeFilter;
    if (targetFilter != null) {
      final src = _sources[targetFilter];
      if (src != null) {
        return src.getSongs(limit: 100);
      }
    }

    // Combine from all sources
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
  /// to its originating MusicSource.
  Future<SongModel> resolvePlayableSong(SongModel song) async {
    final sourceType = MusicSourceType.fromString(song.sourceType);
    final source = _sources[sourceType] ?? _sources[MusicSourceType.local];

    if (source != null) {
      try {
        final resolvedUri = await source.resolvePlaybackUri(song);
        return song.copyWith(path: resolvedUri);
      } catch (e) {
        debugPrint("Error resolving playback URI for ${song.title}: $e");
      }
    }
    return song;
  }
}

class _CachedSearch {
  final List<SongModel> results;
  final DateTime expiresAt;

  _CachedSearch({required this.results, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
