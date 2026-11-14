import 'dart:convert';

class CloudAlbumModel {
  final String id;
  final String title;
  final String artist;
  final String artwork;
  final String releaseInfo;
  final int songCount;

  const CloudAlbumModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.artwork,
    required this.releaseInfo,
    this.songCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'artwork': artwork,
      'release_info': releaseInfo,
      'song_count': songCount,
    };
  }

  factory CloudAlbumModel.fromMap(Map<String, dynamic> map) {
    return CloudAlbumModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Album',
      artist: map['artist']?.toString() ?? 'Various Artists',
      artwork: map['artwork']?.toString() ?? '',
      releaseInfo: map['release_info']?.toString() ?? (map['releaseInfo']?.toString() ?? ''),
      songCount: (map['song_count'] as num?)?.toInt() ?? ((map['songCount'] as num?)?.toInt() ?? 0),
    );
  }

  String toJson() => json.encode(toMap());

  factory CloudAlbumModel.fromJson(String source) =>
      CloudAlbumModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
