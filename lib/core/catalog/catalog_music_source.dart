import 'dart:async';
import '../sources/base_music_source.dart';
import '../sources/music_source_type.dart';
import '../database/database_service.dart';
import '../database/models/song_model.dart';
import 'catalog_database_service.dart';

/// MusicSource provider connecting the Bollywood and Global Music Datasets
/// into the unified playback and search pipeline of Cinematic Music Player.
class CatalogMusicSource implements MusicSource {
  @override
  String get id => 'catalog';

  @override
  String get displayName => 'Bollywood & Global Catalog';

  @override
  MusicSourceType get type => MusicSourceType.catalog;

  @override
  bool get isAvailable => true;

  @override
  Future<void> init() async {
    await CatalogDatabaseService.instance.init();
  }

  @override
  Future<List<SongModel>> getSongs({int offset = 0, int limit = 50}) async {
    final all = CatalogDatabaseService.instance.getAllSongs().map((s) => s.toSongModel()).toList();
    if (offset >= all.length) return [];
    final end = (offset + limit < all.length) ? offset + limit : all.length;
    return all.sublist(offset, end);
  }

  @override
  Future<List<SongModel>> search(String query) async => searchSongs(query);

  @override
  Future<List<SongModel>> searchSongs(String query) async {
    return CatalogDatabaseService.instance.searchSongs(query).map((s) => s.toSongModel()).toList();
  }

  @override
  Future<List<ArtistSummary>> searchArtists(String query) async {
    return CatalogDatabaseService.instance.searchArtists(query).map((a) => a.toArtistSummary()).toList();
  }

  @override
  Future<List<AlbumSummary>> searchAlbums(String query) async {
    return CatalogDatabaseService.instance.searchAlbums(query).map((a) => a.toAlbumSummary()).toList();
  }

  @override
  Future<List<AlbumSummary>> getAlbums() async {
    return CatalogDatabaseService.instance.getAllAlbums().map((a) => a.toAlbumSummary()).toList();
  }

  @override
  Future<List<ArtistSummary>> getArtists() async {
    return CatalogDatabaseService.instance.getAllArtists().map((a) => a.toArtistSummary()).toList();
  }

  @override
  Future<String> resolvePlaybackUri(SongModel song) async {
    if (song.path.isNotEmpty) {
      return song.path;
    }
    // High-fidelity fallback streaming track
    return "https://ia800504.us.archive.org/33/items/Bensound_AcousticBreeze/bensound-acousticbreeze.mp3";
  }
}
