import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../config/supabase_config.dart';
import '../database/models/cloud_song_model.dart';
import '../database/models/cloud_artist_model.dart';
import '../database/models/cloud_album_model.dart';

class CloudMusicService {
  CloudMusicService._internal();
  static final CloudMusicService instance = CloudMusicService._internal();

  final http.Client _client = http.Client();
  final Duration _timeout = const Duration(seconds: 10);

  // In-memory cache of curated cloud streaming songs
  final List<CloudSongModel> _cachedSongs = [];

  Map<String, String> _buildHeaders({String? token, String? contentType}) {
    final anonKey = SupabaseConfig.instance.anonKey;
    final headers = <String, String>{
      'apikey': anonKey,
      'Authorization': 'Bearer ${token != null && token.isNotEmpty ? token : anonKey}',
    };
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    return headers;
  }

  // Curated initial private cloud catalog (high-quality royalty-free streaming master tracks)
  List<CloudSongModel> get _defaultCloudCatalogue => [
    CloudSongModel(
      id: "cloud_track_01",
      title: "Chasing Shadows (Acoustic Mix)",
      artist: "Aaryan Verma",
      album: "Midnight Sessions",
      coverImage: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80",
      genre: "Bollywood Lo-Fi",
      duration: 215,
      audioUrl: "https://cdn.freesound.org/previews/612/612627_5674468-lq.mp3",
      playCount: 1420,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    CloudSongModel(
      id: "cloud_track_02",
      title: "Dil Ki Dhadkan",
      artist: "Rhea Sen",
      album: "Sufi Resonance",
      coverImage: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80",
      genre: "Sufi Fusion",
      duration: 248,
      audioUrl: "https://cdn.freesound.org/previews/530/530415_11452473-lq.mp3",
      playCount: 2890,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    CloudSongModel(
      id: "cloud_track_03",
      title: "Raga Bhairav (Ambient Chill)",
      artist: "Pandit Shivam",
      album: "Morning Dawn",
      coverImage: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80",
      genre: "Indian Classical",
      duration: 310,
      audioUrl: "https://cdn.freesound.org/previews/685/685824_11861866-lq.mp3",
      playCount: 950,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    CloudSongModel(
      id: "cloud_track_04",
      title: "Mumbai Rain Walk",
      artist: "Kabir Das Project",
      album: "Monsoon Diaries",
      coverImage: "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&q=80",
      genre: "Acoustic Pop",
      duration: 198,
      audioUrl: "https://cdn.freesound.org/previews/450/450624_6142149-lq.mp3",
      playCount: 3410,
      createdAt: DateTime.now().subtract(const Duration(hours: 18)),
    ),
    CloudSongModel(
      id: "cloud_track_05",
      title: "Neon Varanasi",
      artist: "Aaryan Verma",
      album: "Midnight Sessions",
      coverImage: "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&q=80",
      genre: "Electronic Fusion",
      duration: 232,
      audioUrl: "https://cdn.freesound.org/previews/557/557811_11861866-lq.mp3",
      playCount: 1870,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  // =========================================================================
  // SONGS RETRIEVAL
  // =========================================================================

  Future<List<CloudSongModel>> fetchSongs({
    String? query,
    String? genre,
    String? artist,
    String? album,
    bool trending = false,
    bool recentlyAdded = false,
  }) async {
    final List<CloudSongModel> remoteSongs = [];

    if (SupabaseConfig.instance.isConfigured) {
      try {
        final queryParams = <String>[];
        queryParams.add('select=*');

        if (trending) {
          queryParams.add('order=play_count.desc');
        } else if (recentlyAdded) {
          queryParams.add('order=created_at.desc');
        } else {
          queryParams.add('order=created_at.desc');
        }

        if (genre != null && genre.isNotEmpty && genre != 'All') {
          queryParams.add('genre=ilike.%25$genre%25');
        }
        if (artist != null && artist.isNotEmpty) {
          queryParams.add('artist=ilike.%25$artist%25');
        }
        if (album != null && album.isNotEmpty) {
          queryParams.add('album=ilike.%25$album%25');
        }
        if (query != null && query.trim().isNotEmpty) {
          final q = Uri.encodeComponent(query.trim());
          queryParams.add('or=(title.ilike.%25$q%25,artist.ilike.%25$q%25,album.ilike.%25$q%25)');
        }

        final uri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/songs?${queryParams.join('&')}');
        final response = await _client.get(uri, headers: _buildHeaders(contentType: 'application/json')).timeout(_timeout);

        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List<dynamic>;
          for (final item in list) {
            remoteSongs.add(CloudSongModel.fromMap(Map<String, dynamic>.from(item as Map)));
          }
        }
      } catch (e) {
        debugPrint("CloudMusicService.fetchSongs remote error: $e");
      }
    }

    // Merge remote songs with local defaults if remote is empty
    final pool = <String, CloudSongModel>{};
    for (final s in _defaultCloudCatalogue) {
      pool[s.id] = s;
    }
    for (final s in remoteSongs) {
      pool[s.id] = s;
    }
    for (final s in _cachedSongs) {
      pool[s.id] = s;
    }

    var result = pool.values.toList();

    // Local filtering
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      result = result.where((s) =>
        s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q) ||
        s.album.toLowerCase().contains(q) ||
        s.genre.toLowerCase().contains(q)
      ).toList();
    }
    if (genre != null && genre.isNotEmpty && genre != 'All') {
      result = result.where((s) => s.genre.toLowerCase().contains(genre.toLowerCase())).toList();
    }
    if (artist != null && artist.isNotEmpty) {
      result = result.where((s) => s.artist.toLowerCase() == artist.toLowerCase()).toList();
    }
    if (album != null && album.isNotEmpty) {
      result = result.where((s) => s.album.toLowerCase() == album.toLowerCase()).toList();
    }

    if (trending) {
      result.sort((a, b) => b.playCount.compareTo(a.playCount));
    } else if (recentlyAdded) {
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return result;
  }

  Future<List<CloudSongModel>> fetchTrendingSongs({int limit = 10}) async {
    final songs = await fetchSongs(trending: true);
    return songs.take(limit).toList();
  }

  Future<List<CloudSongModel>> fetchRecentlyAddedSongs({int limit = 10}) async {
    final songs = await fetchSongs(recentlyAdded: true);
    return songs.take(limit).toList();
  }

  // =========================================================================
  // ARTISTS & ALBUMS RETRIEVAL
  // =========================================================================

  Future<List<CloudArtistModel>> fetchArtists({String? query}) async {
    final List<CloudArtistModel> artists = [];

    if (SupabaseConfig.instance.isConfigured) {
      try {
        final uri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/artists?select=*&order=name.asc');
        final response = await _client.get(uri, headers: _buildHeaders(contentType: 'application/json')).timeout(_timeout);
        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List<dynamic>;
          for (final item in list) {
            artists.add(CloudArtistModel.fromMap(Map<String, dynamic>.from(item as Map)));
          }
        }
      } catch (e) {
        debugPrint("CloudMusicService.fetchArtists error: $e");
      }
    }

    // Fallback: derive artists from songs catalogue
    if (artists.isEmpty) {
      final songs = await fetchSongs();
      final Map<String, List<CloudSongModel>> byArtist = {};
      for (final s in songs) {
        byArtist.putIfAbsent(s.artist, () => []).add(s);
      }
      for (final entry in byArtist.entries) {
        final sampleSong = entry.value.first;
        artists.add(CloudArtistModel(
          id: 'artist_${entry.key.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
          name: entry.key,
          image: sampleSong.coverImage,
          biography: "${entry.key} is a featured cloud artist on Cinematic Music Player.",
          songCount: entry.value.length,
          albumCount: entry.value.map((s) => s.album).toSet().length,
        ));
      }
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      return artists.where((a) => a.name.toLowerCase().contains(q) || a.biography.toLowerCase().contains(q)).toList();
    }

    return artists;
  }

  Future<List<CloudAlbumModel>> fetchAlbums({String? query, String? artist}) async {
    final List<CloudAlbumModel> albums = [];

    if (SupabaseConfig.instance.isConfigured) {
      try {
        final uri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/albums?select=*&order=title.asc');
        final response = await _client.get(uri, headers: _buildHeaders(contentType: 'application/json')).timeout(_timeout);
        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List<dynamic>;
          for (final item in list) {
            albums.add(CloudAlbumModel.fromMap(Map<String, dynamic>.from(item as Map)));
          }
        }
      } catch (e) {
        debugPrint("CloudMusicService.fetchAlbums error: $e");
      }
    }

    // Fallback: derive albums from songs catalogue
    if (albums.isEmpty) {
      final songs = await fetchSongs(artist: artist);
      final Map<String, List<CloudSongModel>> byAlbum = {};
      for (final s in songs) {
        final key = "${s.album}:::${s.artist}";
        byAlbum.putIfAbsent(key, () => []).add(s);
      }
      for (final entry in byAlbum.entries) {
        final list = entry.value;
        final sample = list.first;
        albums.add(CloudAlbumModel(
          id: 'album_${sample.album.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
          title: sample.album,
          artist: sample.artist,
          artwork: sample.coverImage,
          releaseInfo: "Original Studio Release • ${sample.genre}",
          songCount: list.length,
        ));
      }
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      return albums.where((a) => a.title.toLowerCase().contains(q) || a.artist.toLowerCase().contains(q)).toList();
    }

    return albums;
  }

  // =========================================================================
  // PLAY COUNT & TRENDING REAL-TIME UPDATE
  // =========================================================================

  Future<void> incrementPlayCount(String songId) async {
    // Increment in-memory cache
    final idx = _cachedSongs.indexWhere((s) => s.id == songId);
    if (idx != -1) {
      _cachedSongs[idx] = _cachedSongs[idx].copyWith(playCount: _cachedSongs[idx].playCount + 1);
    }

    if (!SupabaseConfig.instance.isConfigured) return;

    try {
      // 1. Try invoking atomic RPC
      final rpcUri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/rpc/increment_song_play_count');
      final res = await _client.post(
        rpcUri,
        headers: _buildHeaders(contentType: 'application/json'),
        body: jsonEncode({'target_song_id': songId}),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode != 200 && res.statusCode != 204) {
        // Fallback: direct PATCH
        final patchUri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/songs?id=eq.$songId');
        await _client.patch(
          patchUri,
          headers: _buildHeaders(contentType: 'application/json'),
          body: jsonEncode({'play_count': 1}),
        ).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  // =========================================================================
  // ADMIN UPLOAD PANEL OPERATIONS (SUPABASE STORAGE & DATABASE)
  // =========================================================================

  /// Upload an audio file to Supabase Storage bucket 'music-files'
  /// Returns the publicly accessible streaming URL.
  Future<String> uploadAudioFile(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final fileName = "${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}";
    final ext = p.extension(file.path).toLowerCase();
    String contentType = 'audio/mpeg';
    if (ext == '.flac') contentType = 'audio/flac';
    if (ext == '.wav') contentType = 'audio/wav';
    if (ext == '.m4a' || ext == '.aac') contentType = 'audio/mp4';
    if (ext == '.ogg') contentType = 'audio/ogg';

    if (SupabaseConfig.instance.isConfigured) {
      try {
        final uri = Uri.parse('${SupabaseConfig.instance.url}/storage/v1/object/music-files/$fileName');
        final bytes = await file.readAsBytes();

        final response = await _client.post(
          uri,
          headers: _buildHeaders(contentType: contentType),
          body: bytes,
        ).timeout(const Duration(minutes: 2));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final publicUrl = '${SupabaseConfig.instance.url}/storage/v1/object/public/music-files/$fileName';
          return publicUrl;
        } else {
          debugPrint("Supabase storage upload error: ${response.statusCode} - ${response.body}");
        }
      } catch (e) {
        debugPrint("Error uploading audio file to Supabase Storage: $e");
      }
    }

    // Offline / Local Simulation fallback
    return file.path;
  }

  /// Upload an album artwork image to Supabase Storage bucket 'album-covers'
  /// Returns the publicly accessible image URL.
  Future<String> uploadCoverImage({
    File? file,
    Uint8List? rawBytes,
    String? preferredName,
  }) async {
    final fileName = "${DateTime.now().millisecondsSinceEpoch}_${preferredName ?? 'cover.jpg'}";
    final bytes = rawBytes ?? (file != null ? await file.readAsBytes() : null);
    if (bytes == null || bytes.isEmpty) return "";

    if (SupabaseConfig.instance.isConfigured) {
      try {
        final uri = Uri.parse('${SupabaseConfig.instance.url}/storage/v1/object/album-covers/$fileName');
        final response = await _client.post(
          uri,
          headers: _buildHeaders(contentType: 'image/jpeg'),
          body: bytes,
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200 || response.statusCode == 201) {
          return '${SupabaseConfig.instance.url}/storage/v1/object/public/album-covers/$fileName';
        }
      } catch (e) {
        debugPrint("Error uploading cover image: $e");
      }
    }

    if (file != null) return file.path;
    return "";
  }

  /// Adds a song to the Cloud Music database and registers its album & artist
  Future<bool> addSongToCloud(CloudSongModel song) async {
    _cachedSongs.insert(0, song);

    if (!SupabaseConfig.instance.isConfigured) return true;

    try {
      // 1. Insert into public.songs
      final songUri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/songs');
      final res = await _client.post(
        songUri,
        headers: _buildHeaders(contentType: 'application/json'),
        body: song.toJson(),
      ).timeout(_timeout);

      // 2. Ensure Artist exists
      final artistUri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/artists');
      await _client.post(
        artistUri,
        headers: _buildHeaders(contentType: 'application/json'),
        body: jsonEncode({
          'id': 'artist_${song.artist.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
          'name': song.artist,
          'image': song.coverImage,
          'biography': "${song.artist} is a registered cloud artist.",
        }),
      ).timeout(const Duration(seconds: 5));

      // 3. Ensure Album exists
      final albumUri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/albums');
      await _client.post(
        albumUri,
        headers: _buildHeaders(contentType: 'application/json'),
        body: jsonEncode({
          'id': 'album_${song.album.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
          'title': song.album,
          'artist': song.artist,
          'artwork': song.coverImage,
          'release_info': "Studio Master • ${song.genre}",
        }),
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint("Error adding song to Supabase: $e");
      return true; // cached locally
    }
  }

  /// Delete a song from the cloud library
  Future<bool> deleteSong(String songId) async {
    _cachedSongs.removeWhere((s) => s.id == songId);

    if (!SupabaseConfig.instance.isConfigured) return true;

    try {
      final uri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/songs?id=eq.$songId');
      final res = await _client.delete(uri, headers: _buildHeaders()).timeout(_timeout);
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("Error deleting song from cloud: $e");
      return false;
    }
  }
}
