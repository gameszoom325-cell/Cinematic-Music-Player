import 'dart:convert';
import 'package:http/http.dart' as http;

class JamendoTrack {
  final String id, name, artist, album, audioUrl, imageUrl;
  final int duration; // seconds

  JamendoTrack({
    required this.id,
    required this.name,
    required this.artist,
    required this.album,
    required this.audioUrl,
    required this.imageUrl,
    required this.duration,
  });

  factory JamendoTrack.fromJson(Map<String, dynamic> j) => JamendoTrack(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        artist: (j['artist_name'] ?? '').toString(),
        album: (j['album_name'] ?? '').toString(),
        audioUrl: (j['audio'] ?? '').toString(),
        imageUrl: (j['image'] ?? '').toString(),
        duration: int.tryParse(j['duration'].toString()) ?? 0,
      );
}

class JamendoService {
  JamendoService(this.clientId);
  final String clientId;
  static const _base = 'https://api.jamendo.com/v3.0/tracks/';

  Future<List<JamendoTrack>> _fetch(Map<String, String> extra) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'client_id': clientId,
      'format': 'json',
      'limit': '30',
      'audioformat': 'mp32',
      'imagesize': '300',
      ...extra,
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Jamendo error ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final status = body['headers']?['status'];
    if (status != null && status != 'success') {
      throw Exception(body['headers']?['error_message'] ?? 'Jamendo request failed');
    }
    final results = (body['results'] as List?) ?? [];
    return results
        .map((e) => JamendoTrack.fromJson(e as Map<String, dynamic>))
        .where((t) => t.audioUrl.isNotEmpty)
        .toList();
  }

  Future<List<JamendoTrack>> popular() async {
    final list = await _fetch({'order': 'popularity_week'});
    if (list.isNotEmpty) return list;
    return _fetch({'order': 'popularity_total'});
  }
  Future<List<JamendoTrack>> search(String q) => _fetch({'search': q});
}
