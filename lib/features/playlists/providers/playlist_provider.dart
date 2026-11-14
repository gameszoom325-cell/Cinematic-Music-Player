import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/models/playlist_model.dart';
import '../../../core/database/models/song_model.dart';
import '../../../sync/sync_manager.dart';

class PlaylistNotifier extends StateNotifier<List<PlaylistModel>> {
  PlaylistNotifier() : super([]) {
    refreshPlaylists();
  }

  void refreshPlaylists() {
    state = DatabaseService.instance.getAllPlaylists();
  }

  Future<void> createPlaylist(String name, {String description = ""}) async {
    await DatabaseService.instance.createPlaylist(name, description: description);
    refreshPlaylists();
    SyncManager.instance.syncAll();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await DatabaseService.instance.addSongToPlaylist(playlistId, songId);
    refreshPlaylists();
    SyncManager.instance.syncAll();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await DatabaseService.instance.removeSongFromPlaylist(playlistId, songId);
    refreshPlaylists();
    SyncManager.instance.syncAll();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await DatabaseService.instance.deletePlaylist(playlistId);
    refreshPlaylists();
    SyncManager.instance.syncAll();
  }

  List<SongModel> getSongsForPlaylist(PlaylistModel playlist) {
    final List<SongModel> songs = [];
    for (final songId in playlist.songIds) {
      final song = DatabaseService.instance.getSongById(songId);
      if (song != null) songs.add(song);
    }
    return songs;
  }
}

final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, List<PlaylistModel>>((ref) {
  return PlaylistNotifier();
});
