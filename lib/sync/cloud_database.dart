import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Connected hardware device profile participating in cloud synchronization.
class DeviceModel {
  final String deviceId;
  final String deviceName;
  final String platform; // "windows", "android", "macos", "ios", "linux"
  final DateTime lastSyncTime;
  final String appVersion;
  final bool isCurrentDevice;
  final String ipHint;

  const DeviceModel({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.lastSyncTime,
    required this.appVersion,
    this.isCurrentDevice = false,
    this.ipHint = '127.0.0.1',
  });

  DeviceModel copyWith({
    String? deviceId,
    String? deviceName,
    String? platform,
    DateTime? lastSyncTime,
    String? appVersion,
    bool? isCurrentDevice,
    String? ipHint,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      appVersion: appVersion ?? this.appVersion,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
      ipHint: ipHint ?? this.ipHint,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'lastSyncTime': lastSyncTime.toIso8601String(),
      'appVersion': appVersion,
      'ipHint': ipHint,
    };
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json, {bool isCurrentDevice = false}) {
    return DeviceModel(
      deviceId: json['deviceId'] as String? ?? 'unknown_device',
      deviceName: json['deviceName'] as String? ?? 'Cinematic Client',
      platform: json['platform'] as String? ?? 'generic',
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.tryParse(json['lastSyncTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      appVersion: json['appVersion'] as String? ?? '1.0.0',
      isCurrentDevice: isCurrentDevice,
      ipHint: json['ipHint'] as String? ?? '127.0.0.1',
    );
  }
}

/// Unified cloud snapshot payload containing all synchronized musical and UI state.
class CloudSyncPayload {
  final String userId;
  final int version;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> playlists;
  final List<Map<String, dynamic>> favorites;
  final List<Map<String, dynamic>> recentlyPlayed;
  final Map<String, dynamic> listeningHistory;
  final Map<String, dynamic> userPreferences;
  final Map<String, dynamic> visualizerSettings;
  final Map<String, dynamic> themeSettings;
  final Map<String, dynamic> lyricsPreferences;

  const CloudSyncPayload({
    required this.userId,
    this.version = 1,
    required this.updatedAt,
    required this.playlists,
    required this.favorites,
    required this.recentlyPlayed,
    required this.listeningHistory,
    required this.userPreferences,
    required this.visualizerSettings,
    required this.themeSettings,
    required this.lyricsPreferences,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'version': version,
      'updatedAt': updatedAt.toIso8601String(),
      'playlists': playlists,
      'favorites': favorites,
      'recentlyPlayed': recentlyPlayed,
      'listeningHistory': listeningHistory,
      'userPreferences': userPreferences,
      'visualizerSettings': visualizerSettings,
      'themeSettings': themeSettings,
      'lyricsPreferences': lyricsPreferences,
    };
  }

  factory CloudSyncPayload.fromJson(Map<String, dynamic> json) {
    return CloudSyncPayload(
      userId: json['userId'] as String? ?? 'guest',
      version: json['version'] as int? ?? 1,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      playlists: (json['playlists'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      favorites: (json['favorites'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      recentlyPlayed: (json['recentlyPlayed'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      listeningHistory: json['listeningHistory'] != null
          ? Map<String, dynamic>.from(json['listeningHistory'] as Map)
          : {},
      userPreferences: json['userPreferences'] != null
          ? Map<String, dynamic>.from(json['userPreferences'] as Map)
          : {},
      visualizerSettings: json['visualizerSettings'] != null
          ? Map<String, dynamic>.from(json['visualizerSettings'] as Map)
          : {},
      themeSettings: json['themeSettings'] != null
          ? Map<String, dynamic>.from(json['themeSettings'] as Map)
          : {},
      lyricsPreferences: json['lyricsPreferences'] != null
          ? Map<String, dynamic>.from(json['lyricsPreferences'] as Map)
          : {},
    );
  }

  factory CloudSyncPayload.empty(String userId) {
    return CloudSyncPayload(
      userId: userId,
      version: 1,
      updatedAt: DateTime.now(),
      playlists: [],
      favorites: [],
      recentlyPlayed: [],
      listeningHistory: {},
      userPreferences: {
        'shuffleMode': false,
        'repeatMode': 'all',
        'volume': 1.0,
      },
      visualizerSettings: {
        'preset': 'orb3d',
        'atmosphere': 'rain',
        'sensitivity': 1.0,
      },
      themeSettings: {
        'accentColor': 0xFF8B5CF6,
        'glassBlur': 24.0,
        'glassOpacity': 0.08,
      },
      lyricsPreferences: {
        'fontSize': 24.0,
        'autoScroll': true,
        'activeLineBloom': true,
        'tapToSeek': true,
      },
    );
  }
}

/// Cloud database provider and multi-device synchronizer.
/// Supports both local simulated multi-device cloud storage (for zero-setup offline/local sync testing)
/// and remote REST endpoints for real production cloud backends.
class CloudDatabase {
  CloudDatabase._internal();
  static final CloudDatabase instance = CloudDatabase._internal();

  String? remoteApiUrl; // Optional REST server URL
  String? remoteAuthBearer;

  Directory? _cloudStorageDir;

  Future<void> init() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _cloudStorageDir = Directory(p.join(docDir.path, 'CinematicMusicPlayer', 'cloud_vault'));
      if (!await _cloudStorageDir!.exists()) {
        await _cloudStorageDir!.create(recursive: true);
      }
    } catch (e) {
      debugPrint("CloudDatabase init error: $e");
    }
  }

  File _getUserPayloadFile(String userId) {
    return File(p.join(_cloudStorageDir!.path, 'users', userId, 'sync_payload.json'));
  }

  File _getUserDevicesFile(String userId) {
    return File(p.join(_cloudStorageDir!.path, 'users', userId, 'devices.json'));
  }

  /// Fetch the latest cloud snapshot for the given user.
  Future<CloudSyncPayload?> fetchSyncPayload(String userId) async {
    if (userId.isEmpty || userId == 'guest_vault_user') return null;

    // 1. If remote API configured, attempt remote pull
    if (remoteApiUrl != null && remoteApiUrl!.isNotEmpty) {
      try {
        final uri = Uri.parse('$remoteApiUrl/sync/$userId');
        final response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (remoteAuthBearer != null) 'Authorization': 'Bearer $remoteAuthBearer',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return CloudSyncPayload.fromJson(data);
        }
      } catch (e) {
        debugPrint("Remote cloud pull error, falling back to local cloud vault: $e");
      }
    }

    // 2. Read from persistent local Cloud Vault
    try {
      if (_cloudStorageDir == null) await init();
      final file = _getUserPayloadFile(userId);
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        return CloudSyncPayload.fromJson(map);
      }
    } catch (e) {
      debugPrint("Error reading user cloud snapshot: $e");
    }

    return null;
  }

  /// Upload updated user state snapshot to the cloud.
  Future<bool> uploadSyncPayload(String userId, CloudSyncPayload payload) async {
    if (userId.isEmpty || userId == 'guest_vault_user') return false;

    bool uploadedSuccessfully = false;

    // 1. If remote API configured, push to remote backend
    if (remoteApiUrl != null && remoteApiUrl!.isNotEmpty) {
      try {
        final uri = Uri.parse('$remoteApiUrl/sync/$userId');
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (remoteAuthBearer != null) 'Authorization': 'Bearer $remoteAuthBearer',
          },
          body: jsonEncode(payload.toJson()),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          uploadedSuccessfully = true;
        }
      } catch (e) {
        debugPrint("Remote cloud push error, saving to local cloud vault: $e");
      }
    }

    // 2. Write to persistent local Cloud Vault (ensures local multi-device and offline safety)
    try {
      if (_cloudStorageDir == null) await init();
      final file = _getUserPayloadFile(userId);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(payload.toJson()));
      uploadedSuccessfully = true;
    } catch (e) {
      debugPrint("Error writing cloud payload to vault: $e");
    }

    return uploadedSuccessfully;
  }

  /// Fetch all active devices connected to this user's account.
  Future<List<DeviceModel>> getConnectedDevices(String userId, {String? currentDeviceId}) async {
    if (userId.isEmpty || userId == 'guest_vault_user') return [];

    // Check remote if available
    if (remoteApiUrl != null && remoteApiUrl!.isNotEmpty) {
      try {
        final uri = Uri.parse('$remoteApiUrl/devices/$userId');
        final response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (remoteAuthBearer != null) 'Authorization': 'Bearer $remoteAuthBearer',
          },
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List<dynamic>;
          return list.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            final id = map['deviceId'] as String? ?? '';
            return DeviceModel.fromJson(map, isCurrentDevice: id == currentDeviceId);
          }).toList();
        }
      } catch (e) {
        debugPrint("Remote device fetch error, using local vault: $e");
      }
    }

    // Read from local cloud vault
    try {
      if (_cloudStorageDir == null) await init();
      final file = _getUserDevicesFile(userId);
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        return list.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          final id = map['deviceId'] as String? ?? '';
          return DeviceModel.fromJson(map, isCurrentDevice: id == currentDeviceId);
        }).toList();
      }
    } catch (e) {
      debugPrint("Error reading connected devices: $e");
    }

    return [];
  }

  /// Register or update a device heartbeat for this account.
  Future<void> registerOrUpdateDevice(String userId, DeviceModel device) async {
    if (userId.isEmpty || userId == 'guest_vault_user') return;

    try {
      if (_cloudStorageDir == null) await init();
      final file = _getUserDevicesFile(userId);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      List<Map<String, dynamic>> devices = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        devices = (jsonDecode(content) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      // Upsert device
      final index = devices.indexWhere((d) => d['deviceId'] == device.deviceId);
      if (index >= 0) {
        devices[index] = device.toJson();
      } else {
        devices.add(device.toJson());
      }

      await file.writeAsString(jsonEncode(devices));

      // Also notify remote if configured
      if (remoteApiUrl != null && remoteApiUrl!.isNotEmpty) {
        try {
          final uri = Uri.parse('$remoteApiUrl/devices/$userId');
          await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(device.toJson()),
          ).timeout(const Duration(seconds: 4));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Error registering device: $e");
    }
  }

  /// Remove/de-authorize a device from the account.
  Future<bool> removeDevice(String userId, String deviceId) async {
    if (userId.isEmpty || userId == 'guest_vault_user') return false;

    try {
      if (_cloudStorageDir == null) await init();
      final file = _getUserDevicesFile(userId);
      if (await file.exists()) {
        final content = await file.readAsString();
        final devices = (jsonDecode(content) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((d) => d['deviceId'] != deviceId)
            .toList();

        await file.writeAsString(jsonEncode(devices));
        return true;
      }
    } catch (e) {
      debugPrint("Error removing device: $e");
    }
    return false;
  }
}
