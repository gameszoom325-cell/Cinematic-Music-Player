import '../../database/models/song_model.dart';

/// App-friendly Song model converted from Bollywood & MusicMoveArr datasets.
class CatalogSong {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String year;
  final String artwork;
  final String source; // e.g. 'bollywood_dataset', 'bollywood_metadata', 'musicmovearr'
  final int durationMs;
  final String genre;
  final String language;
  final int playCount;
  final DateTime dateAdded;
  final String? audioUrl;
  final String? lyrics;

  const CatalogSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.year,
    required this.artwork,
    required this.source,
    this.durationMs = 210000,
    this.genre = "Bollywood",
    this.language = "Hindi",
    this.playCount = 0,
    required this.dateAdded,
    this.audioUrl,
    this.lyrics,
  });

  /// Seamless conversion into the application's unified [SongModel]
  /// for immediate compatibility with AudioEngine, Visualizers, and Player UI.
  SongModel toSongModel() {
    return SongModel(
      id: id,
      path: audioUrl ?? "https://ia800504.us.archive.org/33/items/Bensound_AcousticBreeze/bensound-acousticbreeze.mp3",
      title: title,
      artist: artist,
      album: album,
      year: year,
      durationMs: durationMs,
      hasArtwork: artwork.isNotEmpty,
      artworkPath: artwork.isNotEmpty ? artwork : null,
      sourceType: "catalog",
      sourceId: source,
      genre: genre,
      language: language,
      playCount: playCount,
      dateAdded: dateAdded,
      lyrics: lyrics,
      format: "MP3",
      bitrate: 320,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'year': year,
      'artwork': artwork,
      'source': source,
      'durationMs': durationMs,
      'genre': genre,
      'language': language,
      'playCount': playCount,
      'dateAdded': dateAdded.toIso8601String(),
      'audioUrl': audioUrl,
      'lyrics': lyrics,
    };
  }

  factory CatalogSong.fromMap(Map<String, dynamic> map) {
    return CatalogSong(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      year: (map['year'] as Object?)?.toString() ?? "",
      artwork: (map['artwork'] as String?) ?? "",
      source: (map['source'] as String?) ?? "bollywood_dataset",
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 210000,
      genre: (map['genre'] as String?) ?? "Bollywood",
      language: (map['language'] as String?) ?? "Hindi",
      playCount: (map['playCount'] as num?)?.toInt() ?? 0,
      dateAdded: map['dateAdded'] != null
          ? DateTime.tryParse(map['dateAdded'] as String) ?? DateTime.now()
          : DateTime.now(),
      audioUrl: map['audioUrl'] as String?,
      lyrics: map['lyrics'] as String?,
    );
  }

  CatalogSong copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? year,
    String? artwork,
    String? source,
    int? durationMs,
    String? genre,
    String? language,
    int? playCount,
    DateTime? dateAdded,
    String? audioUrl,
    String? lyrics,
  }) {
    return CatalogSong(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      year: year ?? this.year,
      artwork: artwork ?? this.artwork,
      source: source ?? this.source,
      durationMs: durationMs ?? this.durationMs,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      playCount: playCount ?? this.playCount,
      dateAdded: dateAdded ?? this.dateAdded,
      audioUrl: audioUrl ?? this.audioUrl,
      lyrics: lyrics ?? this.lyrics,
    );
  }
}
