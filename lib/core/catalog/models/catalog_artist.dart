import '../../database/database_service.dart';

/// App-friendly Artist model converted from Bollywood & MusicMoveArr datasets.
class CatalogArtist {
  final String name;
  final String image;
  final int songCount;
  final int albumCount;
  final List<String> genres;

  const CatalogArtist({
    required this.name,
    required this.image,
    this.songCount = 0,
    this.albumCount = 0,
    this.genres = const ["Bollywood"],
  });

  ArtistSummary toArtistSummary() {
    return ArtistSummary(
      name: name,
      songCount: songCount,
      albumCount: albumCount,
      sampleArtworkPath: image,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'image': image,
      'songCount': songCount,
      'albumCount': albumCount,
      'genres': genres,
    };
  }

  factory CatalogArtist.fromMap(Map<String, dynamic> map) {
    return CatalogArtist(
      name: map['name'] as String,
      image: (map['image'] as String?) ?? "",
      songCount: (map['songCount'] as num?)?.toInt() ?? 0,
      albumCount: (map['albumCount'] as num?)?.toInt() ?? 0,
      genres: (map['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ["Bollywood"],
    );
  }
}
