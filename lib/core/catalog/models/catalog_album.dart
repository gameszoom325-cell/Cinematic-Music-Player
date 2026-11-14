import '../../database/database_service.dart';

/// App-friendly Album model converted from Bollywood & MusicMoveArr datasets.
class CatalogAlbum {
  final String title;
  final String cover;
  final String year;
  final String artist;
  final int songCount;
  final List<String> songIds;

  const CatalogAlbum({
    required this.title,
    required this.cover,
    required this.year,
    this.artist = "Various Artists",
    this.songCount = 0,
    this.songIds = const [],
  });

  AlbumSummary toAlbumSummary() {
    return AlbumSummary(
      name: title,
      artist: artist,
      artworkPath: cover,
      songCount: songCount,
      songIds: songIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'cover': cover,
      'year': year,
      'artist': artist,
      'songCount': songCount,
      'songIds': songIds,
    };
  }

  factory CatalogAlbum.fromMap(Map<String, dynamic> map) {
    return CatalogAlbum(
      title: map['title'] as String,
      cover: (map['cover'] as String?) ?? "",
      year: (map['year'] as Object?)?.toString() ?? "",
      artist: (map['artist'] as String?) ?? "Various Artists",
      songCount: (map['songCount'] as num?)?.toInt() ?? 0,
      songIds: (map['songIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
