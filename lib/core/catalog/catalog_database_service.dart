import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/catalog_song.dart';
import 'models/catalog_artist.dart';
import 'models/catalog_album.dart';
import 'catalog_dataset_seed.dart';
import 'catalog_recommendation_engine.dart';
import '../database/database_service.dart';

/// Central database service managing the searchable music catalog
/// ingested from open-source Bollywood and global datasets.
class CatalogDatabaseService {
  CatalogDatabaseService._internal() {
    _initCatalog();
  }

  static final CatalogDatabaseService instance = CatalogDatabaseService._internal();

  final Map<String, CatalogSong> _songs = {};
  final Map<String, CatalogArtist> _artists = {};
  final Map<String, CatalogAlbum> _albums = {};

  bool _isInitialized = false;

  void _initCatalog() {
    if (_isInitialized) return;

    // Ingest seed datasets
    for (final song in CatalogDatasetSeed.getInitialSongs()) {
      _songs[song.id] = song;
    }
    for (final artist in CatalogDatasetSeed.getInitialArtists()) {
      _artists[artist.name.toLowerCase()] = artist;
    }
    for (final album in CatalogDatasetSeed.getInitialAlbums()) {
      _albums[album.title.toLowerCase()] = album;
    }

    _isInitialized = true;
  }

  Future<void> init() async {
    _initCatalog();
  }

  // ==========================================
  // SONG DATABASE
  // ==========================================
  List<CatalogSong> getAllSongs() => _songs.values.toList();

  CatalogSong? getSongById(String id) => _songs[id];

  void addSong(CatalogSong song) {
    _songs[song.id] = song;
  }

  void importSongs(List<CatalogSong> songs) {
    for (final song in songs) {
      _songs[song.id] = song;
    }
  }

  // ==========================================
  // ARTIST DATABASE
  // ==========================================
  List<CatalogArtist> getAllArtists() => _artists.values.toList();

  CatalogArtist? getArtistByName(String name) => _artists[name.toLowerCase()];

  void addArtist(CatalogArtist artist) {
    _artists[artist.name.toLowerCase()] = artist;
  }

  // ==========================================
  // ALBUM DATABASE
  // ==========================================
  List<CatalogAlbum> getAllAlbums() => _albums.values.toList();

  CatalogAlbum? getAlbumByTitle(String title) => _albums[title.toLowerCase()];

  void addAlbum(CatalogAlbum album) {
    _albums[album.title.toLowerCase()] = album;
  }

  // ==========================================
  // SEARCH
  // ==========================================
  List<CatalogSong> searchSongs(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getAllSongs();

    return _songs.values.where((song) {
      return song.title.toLowerCase().contains(q) ||
          song.artist.toLowerCase().contains(q) ||
          song.album.toLowerCase().contains(q) ||
          song.genre.toLowerCase().contains(q) ||
          song.year.contains(q);
    }).toList();
  }

  List<CatalogArtist> searchArtists(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getAllArtists();

    return _artists.values.where((artist) {
      return artist.name.toLowerCase().contains(q) ||
          artist.genres.any((g) => g.toLowerCase().contains(q));
    }).toList();
  }

  List<CatalogAlbum> searchAlbums(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getAllAlbums();

    return _albums.values.where((album) {
      return album.title.toLowerCase().contains(q) ||
          album.artist.toLowerCase().contains(q) ||
          album.year.contains(q);
    }).toList();
  }

  // ==========================================
  // TRENDING SECTION
  // ==========================================
  List<CatalogSong> getTrendingSongs({int limit = 20}) {
    return CatalogRecommendationEngine.getTrendingRankings(getAllSongs(), limit: limit);
  }

  List<CatalogArtist> getTrendingArtists({int limit = 10}) {
    final list = List<CatalogArtist>.from(getAllArtists());
    list.sort((a, b) => b.songCount.compareTo(a.songCount));
    return list.take(limit).toList();
  }

  List<CatalogAlbum> getTrendingAlbums({int limit = 10}) {
    final list = List<CatalogAlbum>.from(getAllAlbums());
    list.sort((a, b) => b.songCount.compareTo(a.songCount));
    return list.take(limit).toList();
  }

  // ==========================================
  // RECENTLY ADDED SECTION
  // ==========================================
  List<CatalogSong> getRecentlyAddedSongs({int limit = 20}) {
    return CatalogRecommendationEngine.getRecentlyAdded(getAllSongs(), limit: limit);
  }

  List<CatalogAlbum> getRecentlyAddedAlbums({int limit = 10}) {
    final list = List<CatalogAlbum>.from(getAllAlbums());
    list.sort((a, b) {
      final yA = int.tryParse(a.year) ?? 0;
      final yB = int.tryParse(b.year) ?? 0;
      return yB.compareTo(yA);
    });
    return list.take(limit).toList();
  }

  // ==========================================
  // RECOMMENDATIONS FOUNDATION
  // ==========================================
  List<CatalogSong> getRelatedSongs(String songId, {int limit = 10}) {
    final target = _songs[songId];
    if (target == null) return getTrendingSongs(limit: limit);

    return CatalogRecommendationEngine.getRelatedSongs(
      target,
      getAllSongs(),
      limit: limit,
    );
  }

  List<CatalogSong> getPersonalizedRecommendations({int limit = 15}) {
    final List<String> favIds = DatabaseService.instance.getFavoriteSongIds();
    final List<String> history = DatabaseService.instance.getHistorySongIds();
    final Set<String> combinedSet = <String>{...favIds, ...history};
    final List<String> combinedIds = combinedSet.toList();

    return CatalogRecommendationEngine.getPersonalizedRecommendations(
      favoriteOrHistorySongIds: combinedIds,
      allCatalogSongs: getAllSongs(),
      limit: limit,
    );
  }
}
