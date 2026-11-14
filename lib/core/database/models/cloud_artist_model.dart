import 'dart:convert';

class CloudArtistModel {
  final String id;
  final String name;
  final String image;
  final String biography;
  final int songCount;
  final int albumCount;

  const CloudArtistModel({
    required this.id,
    required this.name,
    required this.image,
    required this.biography,
    this.songCount = 0,
    this.albumCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'biography': biography,
      'song_count': songCount,
      'album_count': albumCount,
    };
  }

  factory CloudArtistModel.fromMap(Map<String, dynamic> map) {
    return CloudArtistModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown Artist',
      image: map['image']?.toString() ?? '',
      biography: map['biography']?.toString() ?? '',
      songCount: (map['song_count'] as num?)?.toInt() ?? ((map['songCount'] as num?)?.toInt() ?? 0),
      albumCount: (map['album_count'] as num?)?.toInt() ?? ((map['albumCount'] as num?)?.toInt() ?? 0),
    );
  }

  String toJson() => json.encode(toMap());

  factory CloudArtistModel.fromJson(String source) =>
      CloudArtistModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
