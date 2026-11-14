import '../database/models/song_model.dart';
import '../database/database_service.dart';
import 'music_source_type.dart';

/// Abstract contract for all pluggable music sources in Cinematic Music Player.
/// Inspired by the decoupled provider pattern in Metrolist and InnerTubeX.
abstract class BaseMusicSource {
  String get id;
  String get displayName;
  MusicSourceType get type;
  bool get isAvailable;

  /// Initialize any required network sessions, local disk handles, or credentials
  Future<void> init();

  /// Fetch or browse paginated catalog of songs from this source
  Future<List<SongModel>> getSongs({int offset = 0, int limit = 50});

  /// Perform catalog search across this source
  Future<List<SongModel>> search(String query);

  /// Fetch aggregated album summaries from this source
  Future<List<AlbumSummary>> getAlbums();

  /// Fetch aggregated artist summaries from this source
  Future<List<ArtistSummary>> getArtists();

  /// Resolves the actual playable URI (file path or remote HTTP byte-range stream URL)
  /// for a song. This enables lazy-resolving stream tokens just-in-time prior to playback.
  Future<String> resolvePlaybackUri(SongModel song);
}
