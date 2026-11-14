import 'dart:convert';

class PlaylistModel {
  final String id;
  final String name;
  final String description;
  final List<String> songIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? coverArtworkPath;
  final bool isSmartPlaylist;

  const PlaylistModel({
    required this.id,
    required this.name,
    this.description = "",
    required this.songIds,
    required this.createdAt,
    required this.updatedAt,
    this.coverArtworkPath,
    this.isSmartPlaylist = false,
  });

  PlaylistModel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? songIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? coverArtworkPath,
    bool? isSmartPlaylist,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverArtworkPath: coverArtworkPath ?? this.coverArtworkPath,
      isSmartPlaylist: isSmartPlaylist ?? this.isSmartPlaylist,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'songIds': songIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'coverArtworkPath': coverArtworkPath,
      'isSmartPlaylist': isSmartPlaylist,
    };
  }

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? "",
      songIds: List<String>.from(map['songIds'] as List),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      coverArtworkPath: map['coverArtworkPath'] as String?,
      isSmartPlaylist: (map['isSmartPlaylist'] as bool?) ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory PlaylistModel.fromJson(String source) =>
      PlaylistModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
