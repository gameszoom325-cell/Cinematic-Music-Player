import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/services/supabase_backend_client.dart';
import '../auth/session_manager.dart';

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
/// Bridges real Supabase cloud PostgreSQL with local persistent storage for 100% offline resilience.
class CloudDatabase {
  CloudDatabase._internal();
  static final CloudDatabase instance = CloudDatabase._internal();

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

    final token = SessionManager.instance.token;

    // 1. Attempt remote pull from real Supabase backend
    try {
      final remotePayload = await SupabaseBackendClient.instance.fetchSyncPayload(userId, token: token);
      if (remotePayload != null) {
        // Cache to local vault
        await _saveLocalPayload(userId, remotePayload);
        return remotePayload;
      }
    } catch (e) {
      debugPrint("Supabase pull note (falling back to local cache): $e");
    }

    // 2. Read from persistent local Cloud Vault (Offline Mode)
    try {
      if (_cloudStorageDir == null) await init();
      final file = _getUserPayloadFile(userId);
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        return CloudSyncPayload.fromJson(map);
      }
    } catch (e) {
      debugPrint("Error reading local user cloud snapshot: $e");
    }

    return null;
  }

  /// Upload updated user state snapshot to Supabase and cache locally.
  Future<bool> uploadSyncPayload(String userId, CloudSyncPayload payload) async {
    if (userId.isEmpty || userId == 'guest_vault_user') return false;

    // 1. Always save locally first (prevents data loss offline)
    await _saveLocalPayload(userId, payload);

    // 2. Push to Supabase Cloud
    final token = SessionManager.instance.token;
    try {
      final success = await SupabaseBackendClient.instance.uploadSyncPayload(userId, payload, token: token);
      if (success) {
        return true;
      }
    } catch (e) {
      debugPrint("Supabase upload note: $e");
    }

    return true; // Local state saved successfully
  }

  Future<void> _saveLocalPayload(String userId, CloudSyncPayload payload) async {
    try {
      if (_cloudStorageDir == null) await init();
      final file = _getUserPayloadFile(userId);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(payload.toJson()), flush: true);
      if (await temp.exists()) {
        if (await file.exists()) await file.delete();
        await temp.rename(file.path);
      }
    } catch (e) {
      debugPrint("Error saving local sync payload: $e");
    }
  }

  /// Fetch all active devices connected to this user's account.
  Future<List<DeviceModel>> getConnectedDevices(String userId, {String? currentDeviceId}) async {
    if (userId.isEmpty || userId == 'guest_vault_user') return [];

    final token = SessionManager.instance.token;

    // 1. Try remote fetch from Supabase
    try {
      final remoteDevices = await SupabaseBackendClient.instance.fetchDevices(
        userId,
        currentDeviceId: currentDeviceId,
        token: token,
      );
      if (remoteDevices.isNotEmpty) {
        // Cache locally
        await _saveLocalDevices(userId, remoteDevices);
        return remoteDevices;
      }
    } catch (e) {
      debugPrint("Supabase devices fetch note: $e");
    }

    // 2. Read from local cloud vault
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

    // 1. Save locally
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

      final index = devices.indexWhere((d) => d['deviceId'] == device.deviceId);
      if (index >= 0) {
        devices[index] = device.toJson();
      } else {
        devices.add(device.toJson());
      }

      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(devices), flush: true);
      if (await temp.exists()) {
        if (await file.exists()) await file.delete();
        await temp.rename(file.path);
      }
    } catch (e) {
      debugPrint("Error registering device locally: $e");
    }

    // 2. Push heartbeat to Supabase Cloud
    final token = SessionManager.instance.token;
    try {
      await SupabaseBackendClient.instance.registerOrUpdateDevice(userId, device, token: token);
    } catch (_) {}
  }

  Future<void> _saveLocalDevices(String userId, List<DeviceModel> devices) async {
    try {
      if (_cloudStorageDir == null) await init();
      final file = _getUserDevicesFile(userId);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      final jsonList = devices.map((d) => d.toJson()).toList();
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(jsonList), flush: true);
      if (await temp.exists()) {
        if (await file.exists()) await file.delete();
        await temp.rename(file.path);
      }
    } catch (_) {}
  }

  /// Remove/de-authorize a device from the account.
  Future<bool> removeDevice(String userId, String deviceId) async {
    if (userId.isEmpty || userId == 'guest_vault_user') return false;

    // Remove locally
    try {
      if (_cloudStorageDir == null) await init();
      final file = _getUserDevicesFile(userId);
      if (await file.exists()) {
        final content = await file.readAsString();
        final devices = (jsonDecode(content) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((d) => d['deviceId'] != deviceId)
            .toList();

        final temp = File('${file.path}.tmp');
        await temp.writeAsString(jsonEncode(devices), flush: true);
        if (await temp.exists()) {
          if (await file.exists()) await file.delete();
          await temp.rename(file.path);
        }
      }
    } catch (e) {
      debugPrint("Error removing device locally: $e");
    }

    // Remove from Supabase
    final token = SessionManager.instance.token;
    try {
      await SupabaseBackendClient.instance.removeDevice(userId, deviceId, token: token);
    } catch (_) {}

    return true;
  }
}
