import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'base_music_source.dart';
import 'music_source_type.dart';
import '../config/youtube_config.dart';
import '../database/database_service.dart';
import '../database/models/song_model.dart';
import '../services/youtube_api_service.dart';

/// YouTube Data API v3 & YoutubeExplode Music Source for Cinematic Music Player.
/// 
/// Powers live discovery across songs, artists, and playlists/albums,
/// decoupling search metadata from just-in-time audio playback stream resolution.
/// Direct audio streams are extracted on demand using [YoutubeExplode] into
/// high-fidelity direct media URLs (e.g. googlevideo.com AAC/Opus) playable by just_audio.
class YouTubeMusicSource implements MusicSource {
  @override
  String get id => 'youtube';

  @override
  String get displayName => 'YouTube Music';

  @override
  MusicSourceType get type => MusicSourceType.youtube;

  @override
  bool get isAvailable => true;

  // Stream URL cache with 45-minute TTL to minimize repeated network lookups
  final Map<String, _CachedStreamUrl> _streamUrlCache = {};
  static const Duration _cacheTtl = Duration(minutes: 45);

  @override
  Future<void> init() async {
    await YouTubeConfig.instance.init();
    debugPrint("YouTubeMusicSource initialized (Key configured: ${YouTubeConfig.instance.hasApiKey})");
  }

  @override
  Future<List<SongModel>> getSongs({int offset = 0, int limit = 50}) async {
    try {
      if (YouTubeConfig.instance.hasApiKey) {
        final trending = await YouTubeApiService.instance.getTrendingMusic(maxResults: limit);
        if (trending.isNotEmpty) {
          if (offset >= trending.length) return [];
          final end = (offset + limit < trending.length) ? offset + limit : trending.length;
          return trending.sublist(offset, end);
        }
      }
      return await _searchViaYoutubeExplode("Trending Bollywood Music 2026", maxResults: limit);
    } catch (e) {
      debugPrint("YouTubeMusicSource.getSongs error: $e");
      return [];
    }
  }

  @override
  Future<List<SongModel>> search(String query) async => searchSongs(query);

  @override
  Future<List<SongModel>> searchSongs(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return getSongs(limit: 25);

    // 1. Try YouTube Data API v3 if key is configured
    if (YouTubeConfig.instance.hasApiKey) {
      try {
        final apiResults = await YouTubeApiService.instance.searchVideos(cleanQuery, maxResults: 25);
        if (apiResults.isNotEmpty) return apiResults;
      } catch (e) {
        debugPrint("YouTubeMusicSource: Data API v3 search failed ($e), falling back to youtube_explode.");
      }
    }

    // 2. Direct Dart-native search fallback via youtube_explode_dart
    return _searchViaYoutubeExplode(cleanQuery, maxResults: 25);
  }

  /// Fallback search using youtube_explode_dart without requiring any API key
  Future<List<SongModel>> _searchViaYoutubeExplode(String query, {int maxResults = 25}) async {
    final yt = YoutubeExplode();
    try {
      final searchList = await yt.search.search(query);
      final List<SongModel> songs = [];
      for (final video in searchList.take(maxResults)) {
        songs.add(SongModel(
          id: 'yt_${video.id.value}',
          path: 'https://www.youtube.com/watch?v=${video.id.value}',
          title: video.title,
          artist: video.author,
          album: 'YouTube Music',
          language: 'Hindi',
          durationMs: video.duration?.inMilliseconds ?? 180000,
          bitrate: 256,
          sampleRate: 44100,
          format: 'YouTube Stream',
          hasArtwork: video.thumbnails.highResUrl.isNotEmpty,
          artworkPath: video.thumbnails.highResUrl,
          dateAdded: video.uploadDate ?? DateTime.now(),
          genre: 'YouTube Music',
          year: (video.uploadDate ?? DateTime.now()).year.toString(),
          sourceType: 'youtube',
          sourceId: video.id.value,
          externalUrl: 'https://www.youtube.com/watch?v=${video.id.value}',
        ));
      }
      return songs;
    } catch (e) {
      debugPrint("YouTubeMusicSource._searchViaYoutubeExplode error: $e");
      return [];
    } finally {
      yt.close();
    }
  }

  @override
  Future<List<ArtistSummary>> searchArtists(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return getArtists();
    return YouTubeApiService.instance.searchArtists(cleanQuery, maxResults: 15);
  }

  @override
  Future<List<AlbumSummary>> searchAlbums(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return getAlbums();
    return YouTubeApiService.instance.searchAlbums(cleanQuery, maxResults: 15);
  }

  @override
  Future<List<AlbumSummary>> getAlbums() async {
    return [
      const AlbumSummary(
        name: "Trending Bollywood Hits",
        artist: "YouTube Music",
        artworkPath: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80",
        songCount: 25,
        songIds: [],
      ),
      const AlbumSummary(
        name: "Top Indian Pop 2026",
        artist: "YouTube Chartbusters",
        artworkPath: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80",
        songCount: 30,
        songIds: [],
      ),
      const AlbumSummary(
        name: "Soulful Acoustic & Sufi",
        artist: "YouTube Music",
        artworkPath: "https://images.unsplash.com/photo-1510915361894-db8b60106cb1?w=500&q=80",
        songCount: 20,
        songIds: [],
      ),
    ];
  }

  @override
  Future<List<ArtistSummary>> getArtists() async {
    return [
      const ArtistSummary(
        name: "Arijit Singh",
        songCount: 50,
        albumCount: 12,
        sampleArtworkPath: "https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=500&q=80",
      ),
      const ArtistSummary(
        name: "Pritam",
        songCount: 45,
        albumCount: 10,
        sampleArtworkPath: "https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80",
      ),
      const ArtistSummary(
        name: "Shreya Ghoshal",
        songCount: 40,
        albumCount: 8,
        sampleArtworkPath: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80",
      ),
    ];
  }

  /// Extracts the canonical YouTube Video ID from various song representations.
  static String? extractVideoId(SongModel song) {
    if (song.sourceId != null &&
        song.sourceId!.isNotEmpty &&
        song.sourceId != 'youtube' &&
        !song.sourceId!.startsWith('http')) {
      return song.sourceId;
    }
    if (song.id.startsWith('yt_')) {
      final candidate = song.id.substring(3);
      if (candidate.isNotEmpty && !candidate.contains('/')) {
        return candidate;
      }
    }
    for (final url in [song.externalUrl, song.path]) {
      if (url == null || url.isEmpty) continue;
      final uri = Uri.tryParse(url);
      if (uri != null) {
        if (uri.queryParameters.containsKey('v')) {
          return uri.queryParameters['v'];
        }
        if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
          return uri.pathSegments.first;
        }
      }
    }
    return null;
  }

  /// Resolves the direct, playable audio stream URL for a YouTube song.
  /// 
  /// 1. Checks memory cache for non-expired direct stream URL.
  /// 2. Uses [YoutubeExplode] to extract the highest bitrate audioOnly stream URL (googlevideo.com).
  /// 3. Caches the resolved direct stream URL with a 45-minute TTL.
  /// 4. If resolution fails, returns empty string so caller can cleanly report unavailable.
  @override
  Future<String> resolvePlaybackUri(SongModel song) async {
    // 1. Check memory cache for non-expired signed URL
    final cached = _streamUrlCache[song.id];
    if (cached != null && !cached.isExpired) {
      debugPrint("YouTubeMusicSource: Stream cache hit for '${song.title}' -> ${cached.url.substring(0, 50)}...");
      return cached.url;
    }

    // 2. Extract video ID and resolve direct googlevideo.com audio stream via youtube_explode_dart
    final videoId = extractVideoId(song);
    if (videoId != null && videoId.isNotEmpty) {
      debugPrint("YouTubeMusicSource: Resolving audio stream via YoutubeExplode for videoId: $videoId ('${song.title}')");
      final yt = YoutubeExplode();
      try {
        final manifest = await yt.videos.streamsClient.getManifest(videoId);
        final audioStreams = manifest.audioOnly;
        StreamInfo? bestStream;
        if (audioStreams.isNotEmpty) {
          bestStream = audioStreams.withHighestBitrate();
        } else if (manifest.muxed.isNotEmpty) {
          bestStream = manifest.muxed.withHighestBitrate();
        }

        if (bestStream != null) {
          final directStreamUrl = bestStream.url.toString();
          debugPrint("YouTubeMusicSource: Extracted direct audio stream (${bestStream.container.name}, ${bestStream.bitrate}): ${directStreamUrl.substring(0, 60)}...");
          _streamUrlCache[song.id] = _CachedStreamUrl(
            url: directStreamUrl,
            expiresAt: DateTime.now().add(_cacheTtl),
          );
          return directStreamUrl;
        }
      } catch (e) {
        debugPrint("YouTubeMusicSource: YoutubeExplode extraction failed for videoId $videoId: $e");
      } finally {
        yt.close();
      }
    }

    // 3. Fallback: If song.path is already a direct playable audio file/stream (and NOT a youtube webpage)
    if (song.path.isNotEmpty && !song.path.contains('youtube.com') && !song.path.contains('youtu.be')) {
      return song.path;
    }

    return '';
  }
}

class _CachedStreamUrl {
  final String url;
  final DateTime expiresAt;

  _CachedStreamUrl({required this.url, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
