import 'base_music_source.dart';
import 'music_source_type.dart';
import '../config/supabase_config.dart';
import '../database/database_service.dart';
import '../database/models/song_model.dart';
import '../services/cloud_music_service.dart';

class CloudMusicSource implements BaseMusicSource {
  @override
  String get id => 'cloud';

  @override
  String get displayName => 'Private Cloud Vault';

  @override
  MusicSourceType get type => MusicSourceType.cloud;

  @override
  bool get isAvailable => SupabaseConfig.instance.isConfigured;

  @override
  Future<void> init() async {
    await SupabaseConfig.instance.init();
  }

  @override
  Future<List<SongModel>> getSongs({int offset = 0, int limit = 50}) async {
    final cloudSongs = await CloudMusicService.instance.fetchSongs();
    final models = cloudSongs.map((c) => c.toSongModel().copyWith(
      sourceType: 'cloud',
      sourceId: id,
    )).toList();

    if (offset >= models.length) return [];
    final end = (offset + limit < models.length) ? offset + limit : models.length;
    return models.sublist(offset, end);
  }

  @override
  Future<List<SongModel>> search(String query) async => searchSongs(query);

  @override
  Future<List<SongModel>> searchSongs(String query) async {
    final cloudSongs = await CloudMusicService.instance.fetchSongs(query: query);
    return cloudSongs.map((c) => c.toSongModel().copyWith(
      sourceType: 'cloud',
      sourceId: id,
    )).toList();
  }

  @override
  Future<List<AlbumSummary>> searchAlbums(String query) async {
    final q = query.trim().toLowerCase();
    final albums = await getAlbums();
    if (q.isEmpty) return albums;
    return albums.where((a) =>
      a.name.toLowerCase().contains(q) ||
      a.artist.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Future<List<ArtistSummary>> searchArtists(String query) async {
    final q = query.trim().toLowerCase();
    final artists = await getArtists();
    if (q.isEmpty) return artists;
    return artists.where((a) => a.name.toLowerCase().contains(q)).toList();
  }

  @override
  Future<List<AlbumSummary>> getAlbums() async {
    final albums = await CloudMusicService.instance.fetchAlbums();
    return albums.map((a) => AlbumSummary(
      name: a.title,
      artist: a.artist,
      artworkPath: a.artwork,
      songCount: a.songCount,
      songIds: const [],
    )).toList();
  }

  @override
  Future<List<ArtistSummary>> getArtists() async {
    final artists = await CloudMusicService.instance.fetchArtists();
    return artists.map((a) => ArtistSummary(
      name: a.name,
      songCount: a.songCount,
      albumCount: a.albumCount,
      sampleArtworkPath: a.image,
    )).toList();
  }

  @override
  Future<String> resolvePlaybackUri(SongModel song) async {
    // If audioUrl is already resolved and valid, return it
    if (song.path.startsWith('http://') || song.path.startsWith('https://')) {
      return song.path;
    }
    return song.path;
  }
}
