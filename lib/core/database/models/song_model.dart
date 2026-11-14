import 'dart:convert';
import 'dart:io';

class SongModel {
  final String id;
  final String path;            // localFilePath
  final String title;
  final String artist;
  final String album;           // album / movie
  final String albumArtist;
  final String language;        // e.g. "Hindi", "English", "Tamil", "Japanese"
  final int durationMs;         // duration in milliseconds
  final int bitrate;
  final int sampleRate;
  final String format;
  final int fileSize;
  final bool hasArtwork;
  final String? artworkPath;    // artwork local file path
  final bool isFavorite;        // favorite
  final int playCount;          // playCount
  final DateTime? lastPlayedAt;
  final DateTime dateAdded;
  final double bpm;
  final String genre;
  final String year;
  final String? lyrics;
  final String? lrcPath;        // lyricsPath
  final String sourceType;      // 'local', 'cloud', 'external'
  final String? sourceId;       // identifier of the originating source

  const SongModel({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtist = "",
    this.language = "Hindi",
    required this.durationMs,
    this.bitrate = 320,
    this.sampleRate = 44100,
    this.format = "mp3",
    this.fileSize = 0,
    this.hasArtwork = false,
    this.artworkPath,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayedAt,
    required this.dateAdded,
    this.bpm = 0.0,
    this.genre = "Bollywood",
    this.year = "",
    this.lyrics,
    this.lrcPath,
    this.sourceType = "local",
    this.sourceId,
  });

  factory SongModel.empty() {
    return SongModel(
      id: '',
      path: '',
      title: '',
      artist: '',
      album: '',
      durationMs: 0,
      bitrate: 0,
      sampleRate: 44100,
      format: '',
      fileSize: 0,
      hasArtwork: false,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Duration get duration => Duration(milliseconds: durationMs);

  /// Unified accessors requested for multi-source system
  String? get artwork => artworkPath;
  String? get thumbnail => artworkPath;
  String get source => sourceType;

  bool get isCloudSong =>
      sourceType == 'cloud' ||
      path.startsWith('http://') ||
      path.startsWith('https://');
  bool get isOnline => sourceType == 'online';
  bool get isCatalog => sourceType == 'catalog';
  bool get isExternal => sourceType == 'external';
  bool get isRemoteStream =>
      isCloudSong ||
      isOnline ||
      isCatalog ||
      isExternal ||
      path.startsWith('http://') ||
      path.startsWith('https://');

  bool get isLocalFileAvailable {
    if (isRemoteStream) return true;
    if (path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  String get technicalSpecs =>
      "$format • ${bitrate > 0 ? '$bitrate kbps' : ''} ${sampleRate > 0 ? '• ${(sampleRate / 1000).toStringAsFixed(1)} kHz' : ''}";

  SongModel copyWith({
    String? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? language,
    int? durationMs,
    int? bitrate,
    int? sampleRate,
    String? format,
    int? fileSize,
    bool? hasArtwork,
    String? artworkPath,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayedAt,
    DateTime? dateAdded,
    double? bpm,
    String? genre,
    String? year,
    String? lyrics,
    String? lrcPath,
    String? sourceType,
    String? sourceId,
  }) {
    return SongModel(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      language: language ?? this.language,
      durationMs: durationMs ?? this.durationMs,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      format: format ?? this.format,
      fileSize: fileSize ?? this.fileSize,
      hasArtwork: hasArtwork ?? this.hasArtwork,
      artworkPath: artworkPath ?? this.artworkPath,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      dateAdded: dateAdded ?? this.dateAdded,
      bpm: bpm ?? this.bpm,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      lyrics: lyrics ?? this.lyrics,
      lrcPath: lrcPath ?? this.lrcPath,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtist': albumArtist,
      'language': language,
      'durationMs': durationMs,
      'bitrate': bitrate,
      'sampleRate': sampleRate,
      'format': format,
      'fileSize': fileSize,
      'hasArtwork': hasArtwork,
      'artworkPath': artworkPath,
      'isFavorite': isFavorite,
      'playCount': playCount,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'dateAdded': dateAdded.toIso8601String(),
      'bpm': bpm,
      'genre': genre,
      'year': year,
      'lyrics': lyrics,
      'lrcPath': lrcPath,
      'sourceType': sourceType,
      'sourceId': sourceId,
    };
  }

  factory SongModel.fromMap(Map<String, dynamic> map) {
    final rawPath = map['path'] as String? ?? '';
    final defaultSourceType = (rawPath.startsWith('http://') || rawPath.startsWith('https://')) ? 'cloud' : 'local';

    return SongModel(
      id: map['id'] as String,
      path: rawPath,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      albumArtist: (map['albumArtist'] as String?) ?? "",
      language: (map['language'] as String?) ?? "Hindi",
      durationMs: map['durationMs'] as int? ?? 0,
      bitrate: map['bitrate'] as int? ?? 320,
      sampleRate: map['sampleRate'] as int? ?? 44100,
      format: (map['format'] as String?) ?? "MP3",
      fileSize: map['fileSize'] as int? ?? 0,
      hasArtwork: map['hasArtwork'] as bool? ?? false,
      artworkPath: map['artworkPath'] as String?,
      isFavorite: map['isFavorite'] as bool? ?? false,
      playCount: map['playCount'] as int? ?? 0,
      lastPlayedAt: map['lastPlayedAt'] != null
          ? DateTime.parse(map['lastPlayedAt'] as String)
          : null,
      dateAdded: DateTime.parse(map['dateAdded'] as String),
      bpm: (map['bpm'] as num?)?.toDouble() ?? 0.0,
      genre: (map['genre'] as String?) ?? "Bollywood",
      year: (map['year'] as String?) ?? "",
      lyrics: map['lyrics'] as String?,
      lrcPath: map['lrcPath'] as String?,
      sourceType: (map['sourceType'] as String?) ?? defaultSourceType,
      sourceId: map['sourceId'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory SongModel.fromJson(String source) =>
      SongModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
