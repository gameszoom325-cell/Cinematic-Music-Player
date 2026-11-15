// This uses an unofficial JioSaavn wrapper. It may break without notice and may violate JioSaavn's terms of service. Use for personal/testing only.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jiosaavn_dart/jiosaavn_dart.dart';

/// Data model representing a parsed JioSaavn Bollywood song track.
class JioSaavnTrack {
  final String id;
  final String title;
  final String primaryArtists;
  final String album;
  final int durationSeconds;
  final String mediaUrl;
  final String imageUrl;
  final bool hasLyrics;
  final String? lyrics;
  final String year;

  const JioSaavnTrack({
    required this.id,
    required this.title,
    required this.primaryArtists,
    required this.album,
    required this.durationSeconds,
    required this.mediaUrl,
    required this.imageUrl,
    required this.hasLyrics,
    this.lyrics,
    required this.year,
  });

  /// Human-friendly duration string (e.g. "4:28")
  String get formattedDuration {
    if (durationSeconds <= 0) return '--:--';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'primaryArtists': primaryArtists,
      'album': album,
      'durationSeconds': durationSeconds,
      'formattedDuration': formattedDuration,
      'mediaUrl': mediaUrl,
      'imageUrl': imageUrl,
      'hasLyrics': hasLyrics,
      'lyrics': lyrics,
      'year': year,
    };
  }

  @override
  String toString() {
    return 'JioSaavnTrack(id: $id, title: "$title", artist: "$primaryArtists", album: "$album", duration: $formattedDuration, stream: $mediaUrl)';
  }
}

/// Service wrapping the unofficial JioSaavn API via `jiosaavn_dart`.
///
/// NOTE:
/// - This uses an unofficial JioSaavn wrapper. It may break without notice and may violate JioSaavn's terms of service. Use for personal/testing only.
/// - Media URLs are never cached or hardcoded — they are generated fresh on demand because tokens expire.
class JioSaavnService {
  final JioSaavnApi _api = JioSaavnApi();

  /// 1. SEARCH + PLAY FUNCTION:
  /// Accepts a query string (e.g. "Kesariya Arijit Singh"), calls the unofficial
  /// JioSaavn search API, extracts title, primary artists, album, duration, and
  /// the media_url, prints the media_url, and returns the track list.
  Future<List<JioSaavnTrack>> searchSongs(String query, {bool fetchLyrics = false}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      debugPrint('[JioSaavnService] Searching: "$cleanQuery"');

      // [UNOFFICIAL JIOSAAVN API CALL] Calls JioSaavn search autocomplete & song details endpoint
      final List<Song> songs = await _api.searchSong(cleanQuery, lyrics: fetchLyrics);

      if (songs.isEmpty) {
        debugPrint('[JioSaavnService] No songs found for query: "$cleanQuery"');
        return [];
      }

      final List<JioSaavnTrack> results = [];

      for (final s in songs) {
        // [UNOFFICIAL JIOSAAVN API CALL] Fetch fresh duration metadata from song details endpoint
        final duration = await _fetchSongDurationSeconds(s.id);

        final track = JioSaavnTrack(
          id: s.id,
          title: s.song,
          primaryArtists: s.primaryArtists.isNotEmpty ? s.primaryArtists : s.singers,
          album: s.album,
          durationSeconds: duration,
          mediaUrl: s.mediaUrl, // Decrypted fresh direct AAC/MP4 stream URL
          imageUrl: s.image,
          hasLyrics: s.hasLyrics,
          lyrics: s.lyrics,
          year: s.year,
        );

        // Print/log extracted track info and media_url as required
        debugPrint('----------------------------------------');
        debugPrint('Title:       ${track.title}');
        debugPrint('Artist(s):   ${track.primaryArtists}');
        debugPrint('Album:       ${track.album}');
        debugPrint('Duration:    ${track.formattedDuration} (${track.durationSeconds}s)');
        debugPrint('Media URL:   ${track.mediaUrl}');
        debugPrint('----------------------------------------');

        results.add(track);
      }

      return results;
    } catch (e, stack) {
      debugPrint('[JioSaavnService] Error during search for "$cleanQuery": $e\n$stack');
      return [];
    }
  }

  /// 2. GET SONG BY ID FUNCTION:
  /// Accepts a song ID (e.g. "rjkrTnma").
  /// Fetches detailed info including a fresh media_url, lyrics (if available),
  /// and 500x500 album art URL. Never caches media_url.
  Future<JioSaavnTrack?> getSongById(String songId, {bool fetchLyrics = true}) async {
    final cleanId = songId.trim();
    if (cleanId.isEmpty) return null;

    try {
      debugPrint('[JioSaavnService] Fetching fresh details for song ID: $cleanId');

      // [UNOFFICIAL JIOSAAVN API CALL] Fetches song details by PID with on-demand URL decryption
      final Song? song = await _api.getSongFromId(cleanId, fetchLyrics: fetchLyrics);
      if (song == null) {
        debugPrint('[JioSaavnService] Song ID not found: $cleanId');
        return null;
      }

      // [UNOFFICIAL JIOSAAVN API CALL] Fetch lyrics if available and not already loaded
      String? lyrics = song.lyrics;
      if (fetchLyrics && lyrics == null && song.hasLyrics) {
        // [UNOFFICIAL JIOSAAVN API CALL]
        lyrics = await _api.getLyrics(cleanId);
      }

      // [UNOFFICIAL JIOSAAVN API CALL] Fetch fresh duration
      final duration = await _fetchSongDurationSeconds(cleanId);

      final track = JioSaavnTrack(
        id: song.id,
        title: song.song,
        primaryArtists: song.primaryArtists.isNotEmpty ? song.primaryArtists : song.singers,
        album: song.album,
        durationSeconds: duration,
        mediaUrl: song.mediaUrl, // Always fresh on-demand decrypted URL
        imageUrl: song.image,
        hasLyrics: song.hasLyrics,
        lyrics: lyrics,
        year: song.year,
      );

      debugPrint('[JioSaavnService] Resolved fresh song: ${track.title} -> ${track.mediaUrl}');
      return track;
    } catch (e, stack) {
      debugPrint('[JioSaavnService] Error fetching song by ID "$cleanId": $e\n$stack');
      return null;
    }
  }

  /// Helper to get a fresh, un-cached media_url directly by song ID.
  Future<String?> getFreshMediaUrl(String songId) async {
    final track = await getSongById(songId, fetchLyrics: false);
    return track?.mediaUrl;
  }

  /// [UNOFFICIAL JIOSAAVN API CALL]
  /// Queries raw song details endpoint to extract exact duration in seconds.
  Future<int> _fetchSongDurationSeconds(String id) async {
    try {
      final uri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=song.getDetails&cc=in&_marker=0%3F_marker%3D0&_format=json&pids=$id',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
        final songObj = data[id];
        if (songObj is Map<String, dynamic> && songObj['duration'] != null) {
          return int.tryParse(songObj['duration'].toString()) ?? 0;
        }
      }
    } catch (_) {
      // Fallback silently if duration request fails or times out
    }
    return 0;
  }
}
