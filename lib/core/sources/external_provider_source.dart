import 'dart:async';
import 'base_music_source.dart';
import 'music_source_type.dart';
import '../database/database_service.dart';
import '../database/models/song_model.dart';

/// Architecture reference implementation inspired by Metrolist & InnerTubeX.
/// Decouples remote stream discovery and lazy URL resolution from the playback UI.
class ExternalProviderSource implements BaseMusicSource {
  @override
  String get id => 'external_provider';

  @override
  String get displayName => 'External Stream Network';

  @override
  MusicSourceType get type => MusicSourceType.externalProvider;

  @override
  bool get isAvailable => true;

  // Stream URL cache with TTL (Time-To-Live) to prevent redundant resolving
  final Map<String, _CachedStreamUrl> _streamUrlCache = {};
  static const Duration _cacheTtl = Duration(minutes: 45);

  // Curated open-source external streaming catalog (Internet Archive / CC Public Domain streams)
  final List<SongModel> _externalCatalog = [
    SongModel(
      id: "ext_track_01",
      path: "https://ia800504.us.archive.org/33/items/Bensound_AcousticBreeze/bensound-acousticbreeze.mp3",
      title: "Acoustic Breeze",
      artist: "Benjamin Tissot",
      album: "Cinematic Acoustic Sessions",
      genre: "Acoustic Folk",
      durationMs: 168000,
      hasArtwork: true,
      artworkPath: "https://images.unsplash.com/photo-1510915361894-db8b60106cb1?w=500&q=80",
      format: "MP3",
      bitrate: 320,
      dateAdded: DateTime.now(),
      sourceType: "external",
      sourceId: "external_provider",
    ),
    SongModel(
      id: "ext_track_02",
      path: "https://ia800504.us.archive.org/33/items/Bensound_Sunny/bensound-sunny.mp3",
      title: "Sunny Rays (Lofi Chill)",
      artist: "Benjamin Tissot",
      album: "Morning Meditations",
      genre: "Lo-Fi Pop",
      durationMs: 140000,
      hasArtwork: true,
      artworkPath: "https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80",
      format: "MP3",
      bitrate: 320,
      dateAdded: DateTime.now(),
      sourceType: "external",
      sourceId: "external_provider",
    ),
    SongModel(
      id: "ext_track_03",
      path: "https://ia800504.us.archive.org/33/items/Bensound_Tenderness/bensound-tenderness.mp3",
      title: "Tenderness Strings",
      artist: "Cinematic Strings Ensemble",
      album: "Symphonic Nocturnes",
      genre: "Neoclassical",
      durationMs: 203000,
      hasArtwork: true,
      artworkPath: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80",
      format: "MP3",
      bitrate: 320,
      dateAdded: DateTime.now(),
      sourceType: "external",
      sourceId: "external_provider",
    ),
    SongModel(
      id: "ext_track_04",
      path: "https://ia800504.us.archive.org/33/items/Bensound_Memories/bensound-memories.mp3",
      title: "Monsoon Memories",
      artist: "Rahul Sharma & Trio",
      album: "Monsoon Diaries",
      genre: "Indian Fusion",
      durationMs: 230000,
      hasArtwork: true,
      artworkPath: "https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=500&q=80",
      format: "MP3",
      bitrate: 320,
      dateAdded: DateTime.now(),
      sourceType: "external",
      sourceId: "external_provider",
    ),
  ];

  @override
  Future<void> init() async {
    // Ready immediately
  }

  @override
  Future<List<SongModel>> getSongs({int offset = 0, int limit = 50}) async {
    if (offset >= _externalCatalog.length) return [];
    final end = (offset + limit < _externalCatalog.length) ? offset + limit : _externalCatalog.length;
    return _externalCatalog.sublist(offset, end);
  }

  @override
  Future<List<SongModel>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _externalCatalog;

    return _externalCatalog.where((s) =>
      s.title.toLowerCase().contains(q) ||
      s.artist.toLowerCase().contains(q) ||
      s.album.toLowerCase().contains(q) ||
      s.genre.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Future<List<AlbumSummary>> getAlbums() async {
    final Map<String, List<SongModel>> byAlbum = {};
    for (final s in _externalCatalog) {
      final key = "${s.album}:::${s.artist}";
      byAlbum.putIfAbsent(key, () => []).add(s);
    }

    return byAlbum.entries.map((e) {
      final list = e.value;
      final sample = list.first;
      return AlbumSummary(
        name: sample.album,
        artist: sample.artist,
        artworkPath: sample.artworkPath,
        songCount: list.length,
        songIds: list.map((s) => s.id).toList(),
      );
    }).toList();
  }

  @override
  Future<List<ArtistSummary>> getArtists() async {
    final Map<String, List<SongModel>> byArtist = {};
    for (final s in _externalCatalog) {
      byArtist.putIfAbsent(s.artist, () => []).add(s);
    }

    return byArtist.entries.map((e) {
      final list = e.value;
      final sample = list.first;
      return ArtistSummary(
        name: e.key,
        songCount: list.length,
        albumCount: list.map((s) => s.album).toSet().length,
        sampleArtworkPath: sample.artworkPath,
      );
    }).toList();
  }

  /// Lazy Resolving Strategy:
  /// Resolves the streaming URI just-in-time when user initiates playback.
  /// Checks cache first; if expired or not present, resolves fresh stream URL.
  @override
  Future<String> resolvePlaybackUri(SongModel song) async {
    final cached = _streamUrlCache[song.id];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // In a full production external backend (e.g. InnerTubeX / Subsonic),
    // this executes an asynchronous RPC to obtain a signed streaming media URL.
    final resolvedUrl = song.path;

    _streamUrlCache[song.id] = _CachedStreamUrl(
      url: resolvedUrl,
      expiresAt: DateTime.now().add(_cacheTtl),
    );

    return resolvedUrl;
  }
}

class _CachedStreamUrl {
  final String url;
  final DateTime expiresAt;

  _CachedStreamUrl({required this.url, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
