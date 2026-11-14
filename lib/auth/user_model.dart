import 'dart:convert';

/// Representation of an authenticated user profile in the Cinematic Music system.
/// Synchronized across Windows Desktop and Android Mobile.
class UserModel {
  final String userId;
  final String username;
  final String email;
  final String? profileImage;
  final DateTime createdDate;
  final String? token;
  final bool isGuest;
  final List<dynamic>? devices;

  const UserModel({
    required this.userId,
    required this.username,
    required this.email,
    this.profileImage,
    required this.createdDate,
    this.token,
    this.isGuest = false,
    this.devices,
  });

  /// Factory for an anonymous local guest profile
  factory UserModel.guest() {
    return UserModel(
      userId: 'guest_vault_user',
      username: 'Vault Explorer',
      email: 'guest@cinematic.local',
      profileImage: null,
      createdDate: DateTime.now(),
      token: null,
      isGuest: true,
      devices: const [],
    );
  }

  UserModel copyWith({
    String? userId,
    String? username,
    String? email,
    String? profileImage,
    DateTime? createdDate,
    String? token,
    bool? isGuest,
    List<dynamic>? devices,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      createdDate: createdDate ?? this.createdDate,
      token: token ?? this.token,
      isGuest: isGuest ?? this.isGuest,
      devices: devices ?? this.devices,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
      'profileImage': profileImage,
      'createdDate': createdDate.toIso8601String(),
      'token': token,
      'isGuest': isGuest,
      'devices': devices,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] as String? ?? 'unknown_user',
      username: json['username'] as String? ?? 'Music Enthusiast',
      email: json['email'] as String? ?? '',
      profileImage: json['profileImage'] as String?,
      createdDate: json['createdDate'] != null
          ? DateTime.tryParse(json['createdDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      token: json['token'] as String?,
      isGuest: json['isGuest'] as bool? ?? false,
      devices: json['devices'] as List<dynamic>?,
    );
  }

  String serialize() => jsonEncode(toJson());

  static UserModel? deserialize(String rawJson) {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'UserModel(userId: $userId, username: $username, email: $email, isGuest: $isGuest)';
}
