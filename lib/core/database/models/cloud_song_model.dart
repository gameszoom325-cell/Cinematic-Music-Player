import 'dart:convert';
import 'song_model.dart';

class CloudSongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverImage;
  final String genre;
  final int duration; // In seconds or ms
  final String audioUrl;
  final int playCount;
  final DateTime createdAt;

  const CloudSongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverImage,
    required this.genre,
    required this.duration,
    required this.audioUrl,
    this.playCount = 0,
    required this.createdAt,
  });

  /// Converts this cloud song into a playback-ready SongModel for AudioEngine
  SongModel toSongModel() {
    // Normalise duration to ms if stored in seconds
    final int durationMs = duration < 10000 ? duration * 1000 : duration;

    return SongModel(
      id: id,
      path: audioUrl,
      title: title,
      artist: artist,
      album: album,
      genre: genre.isNotEmpty ? genre : 'Cloud',
      durationMs: durationMs,
      hasArtwork: coverImage.isNotEmpty,
      artworkPath: coverImage.isNotEmpty ? coverImage : null,
      format: audioUrl.contains('.flac')
          ? 'FLAC'
          : (audioUrl.contains('.wav') ? 'WAV' : 'MP3'),
      bitrate: 320,
      sampleRate: 44100,
      dateAdded: createdAt,
      playCount: playCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'cover_image': coverImage,
      'genre': genre,
      'duration': duration,
      'audio_url': audioUrl,
      'play_count': playCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CloudSongModel.fromMap(Map<String, dynamic> map) {
    return CloudSongModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Track',
      artist: map['artist']?.toString() ?? 'Unknown Artist',
      album: map['album']?.toString() ?? 'Single',
      coverImage: map['cover_image']?.toString() ?? (map['coverImage']?.toString() ?? ''),
      genre: map['genre']?.toString() ?? 'Bollywood',
      duration: (map['duration'] as num?)?.toInt() ?? 210,
      audioUrl: map['audio_url']?.toString() ?? (map['audioUrl']?.toString() ?? ''),
      playCount: (map['play_count'] as num?)?.toInt() ?? ((map['playCount'] as num?)?.toInt() ?? 0),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  String toJson() => json.encode(toMap());

  factory CloudSongModel.fromJson(String source) =>
      CloudSongModel.fromMap(json.decode(source) as Map<String, dynamic>);

  CloudSongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? coverImage,
    String? genre,
    int? duration,
    String? audioUrl,
    int? playCount,
    DateTime? createdAt,
  }) {
    return CloudSongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverImage: coverImage ?? this.coverImage,
      genre: genre ?? this.genre,
      duration: duration ?? this.duration,
      audioUrl: audioUrl ?? this.audioUrl,
      playCount: playCount ?? this.playCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
