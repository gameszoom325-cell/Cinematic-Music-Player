import 'base_music_source.dart';
import 'music_source_type.dart';
import '../database/database_service.dart';
import '../database/models/song_model.dart';
import '../services/scanner_service.dart';

class LocalMusicSource implements BaseMusicSource {
  @override
  String get id => 'local';

  @override
  String get displayName => 'Offline Acoustic Vault';

  @override
  MusicSourceType get type => MusicSourceType.local;

  @override
  bool get isAvailable => true;

  @override
  Future<void> init() async {
    await DatabaseService.instance.init();
  }

  @override
  Future<List<SongModel>> getSongs({int offset = 0, int limit = 50}) async {
    final all = DatabaseService.instance.getAllSongs()
        .where((s) => s.sourceType == 'local' || (!s.path.startsWith('http://') && !s.path.startsWith('https://')))
        .toList();

    if (offset >= all.length) return [];
    final end = (offset + limit < all.length) ? offset + limit : all.length;
    return all.sublist(offset, end);
  }

  @override
  Future<List<SongModel>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getSongs(limit: 30);

    final all = DatabaseService.instance.getAllSongs()
        .where((s) => s.sourceType == 'local' || (!s.path.startsWith('http://') && !s.path.startsWith('https://')));

    return all.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q) ||
          s.genre.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<List<AlbumSummary>> getAlbums() async {
    return DatabaseService.instance.getAllAlbums();
  }

  @override
  Future<List<ArtistSummary>> getArtists() async {
    return DatabaseService.instance.getAllArtists();
  }

  @override
  Future<String> resolvePlaybackUri(SongModel song) async {
    return song.path;
  }
}
