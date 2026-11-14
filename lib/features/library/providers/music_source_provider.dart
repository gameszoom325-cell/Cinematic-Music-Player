import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sources/music_source_type.dart';
import '../../../core/sources/base_music_source.dart';
import '../../../core/sources/music_source_repository.dart';
import '../../../core/database/models/song_model.dart';
import '../../../core/database/database_service.dart';

final musicSourceRepositoryProvider = Provider<MusicSourceRepository>((ref) {
  return MusicSourceRepository.instance;
});

final activeSourceFilterProvider = StateProvider<MusicSourceType?>((ref) {
  return null; // null represents unified view across all sources
});

final unifiedSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  final repo = ref.watch(musicSourceRepositoryProvider);
  final activeFilter = ref.watch(activeSourceFilterProvider);
  return repo.getAllSongs(filter: activeFilter);
});

final unifiedSearchProvider = FutureProvider.family<List<SongModel>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final repo = ref.watch(musicSourceRepositoryProvider);
  final activeFilter = ref.watch(activeSourceFilterProvider);
  return repo.searchSongs(query, filter: activeFilter);
});

final federatedSearchProvider = FutureProvider.family<FederatedSearchResult, String>((ref, query) async {
  if (query.trim().isEmpty) return FederatedSearchResult.empty(query);
  final repo = ref.watch(musicSourceRepositoryProvider);
  final activeFilter = ref.watch(activeSourceFilterProvider);
  return repo.searchFederated(query, filter: activeFilter);
});

final unifiedAlbumsProvider = FutureProvider<List<AlbumSummary>>((ref) async {
  final repo = ref.watch(musicSourceRepositoryProvider);
  final activeFilter = ref.watch(activeSourceFilterProvider);
  return repo.getAllAlbums(filter: activeFilter);
});

final unifiedArtistsProvider = FutureProvider<List<ArtistSummary>>((ref) async {
  final repo = ref.watch(musicSourceRepositoryProvider);
  final activeFilter = ref.watch(activeSourceFilterProvider);
  return repo.getAllArtists(filter: activeFilter);
});
