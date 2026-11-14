import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../../auth/user_model.dart';
import '../../sync/cloud_database.dart';

/// Real backend client communicating directly with Supabase Authentication (GoTrue)
/// and Supabase Database (PostgREST) via secure RESTful APIs.
class SupabaseBackendClient {
  SupabaseBackendClient._internal();
  static final SupabaseBackendClient instance = SupabaseBackendClient._internal();

  final http.Client _client = http.Client();
  final Duration _timeout = const Duration(seconds: 8);

  Map<String, String> _buildHeaders({String? token, bool preferMerge = false}) {
    final anonKey = SupabaseConfig.instance.anonKey;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'apikey': anonKey,
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      headers['Authorization'] = 'Bearer $anonKey';
    }
    if (preferMerge) {
      headers['Prefer'] = 'resolution=merge-duplicates';
    }
    return headers;
  }

  /// Ping the Supabase backend to verify network reachability and service status
  Future<bool> checkHealth() async {
    if (!SupabaseConfig.instance.isConfigured) return false;
    try {
      final uri = Uri.parse('${SupabaseConfig.instance.url}/auth/v1/health');
      final res = await _client.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 4));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      try {
        final restUri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/');
        final res = await _client.get(restUri, headers: _buildHeaders()).timeout(const Duration(seconds: 4));
        return res.statusCode < 500;
      } catch (_) {
        return false;
      }
    }
  }

  // =========================================================================
  // AUTHENTICATION (GoTrue API)
  // =========================================================================

  /// Register a new account via Supabase Auth
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String username,
    String? profileImage,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim();

    final uri = Uri.parse('${SupabaseConfig.instance.url}/auth/v1/signup');
    final response = await _client.post(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode({
        'email': cleanEmail,
        'password': password,
        'data': {
          'username': cleanUsername,
          'profile_image': profileImage,
        },
      }),
    ).timeout(_timeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final err = _extractErrorMessage(response.body);
      throw Exception(err.isNotEmpty ? err : "Failed to register with Supabase: HTTP ${response.statusCode}");
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final userMap = data['user'] as Map<String, dynamic>? ?? data;
    final userId = userMap['id'] as String? ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final token = data['access_token'] as String? ?? (data['session']?['access_token'] as String?);
    final now = DateTime.now();

    final user = UserModel(
      userId: userId,
      username: cleanUsername,
      email: cleanEmail,
      profileImage: profileImage,
      createdDate: now,
      token: token,
      isGuest: false,
      devices: const [],
    );

    // Also persist into public profiles table if possible
    if (token != null) {
      try {
        await _upsertProfile(user, token);
      } catch (e) {
        debugPrint("Warning: could not upsert profile table: $e");
      }
    }

    return user;
  }

  /// Sign in with an existing account via Supabase Auth
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final uri = Uri.parse('${SupabaseConfig.instance.url}/auth/v1/token?grant_type=password');

    final response = await _client.post(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode({
        'email': cleanEmail,
        'password': password,
      }),
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      final err = _extractErrorMessage(response.body);
      throw Exception(err.isNotEmpty ? err : "Invalid email or password");
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    final userMap = data['user'] as Map<String, dynamic>? ?? {};
    final userId = userMap['id'] as String? ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';

    final metadata = (userMap['user_metadata'] as Map<String, dynamic>?) ?? {};
    String username = metadata['username'] as String? ?? '';
    String? profileImage = metadata['profile_image'] as String?;

    // Try fetching profile from profiles table for richer metadata
    if (token != null) {
      try {
        final profile = await _fetchProfile(userId, token);
        if (profile != null) {
          if (profile['username'] != null && (profile['username'] as String).isNotEmpty) {
            username = profile['username'] as String;
          }
          if (profile['profileImage'] != null) {
            profileImage = profile['profileImage'] as String;
          }
        }
      } catch (_) {}
    }

    if (username.isEmpty) {
      username = cleanEmail.split('@').first;
    }

    return UserModel(
      userId: userId,
      username: username,
      email: cleanEmail,
      profileImage: profileImage,
      createdDate: DateTime.tryParse(userMap['created_at'] as String? ?? '') ?? DateTime.now(),
      token: token,
      isGuest: false,
      devices: const [],
    );
  }

  /// Sign out current session
  Future<void> signOut(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      final uri = Uri.parse('${SupabaseConfig.instance.url}/auth/v1/logout');
      await _client.post(uri, headers: _buildHeaders(token: token)).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Refresh an expired session token
  Future<String?> refreshToken(String refreshToken) async {
    try {
      final uri = Uri.parse('${SupabaseConfig.instance.url}/auth/v1/token?grant_type=refresh_token');
      final res = await _client.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['access_token'] as String?;
      }
    } catch (e) {
      debugPrint("Error refreshing token: $e");
    }
    return null;
  }

  // =========================================================================
  // PROFILES TABLE (PostgREST API)
  // =========================================================================

  Future<void> _upsertProfile(UserModel user, String token) async {
    final uri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/profiles');
    await _client.post(
      uri,
      headers: _buildHeaders(token: token, preferMerge: true),
      body: jsonEncode({
        'user_id': user.userId,
        'username': user.username,
        'email': user.email,
        'profile_image': user.profileImage,
        'created_date': user.createdDate.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>?> _fetchProfile(String userId, String token) async {
    final uri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/profiles?user_id=eq.$userId&select=*');
    final res = await _client.get(uri, headers: _buildHeaders(token: token)).timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isNotEmpty) {
        final raw = list.first as Map<String, dynamic>;
        return {
          'userId': raw['user_id'],
          'username': raw['username'],
          'email': raw['email'],
          'profileImage': raw['profile_image'],
          'createdDate': raw['created_date'],
        };
      }
    }
    return null;
  }

  // =========================================================================
  // SYNC PAYLOADS TABLE (PostgREST API)
  // =========================================================================

  /// Pull full synchronized musical and preference state from Supabase
  Future<CloudSyncPayload?> fetchSyncPayload(String userId, {String? token}) async {
    final uri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/sync_payloads?user_id=eq.$userId&select=*');
    final response = await _client.get(uri, headers: _buildHeaders(token: token)).timeout(_timeout);

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      if (list.isNotEmpty) {
        final row = list.first as Map<String, dynamic>;
        return CloudSyncPayload(
          userId: row['user_id'] as String? ?? userId,
          version: (row['version'] as num?)?.toInt() ?? 1,
          updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ?? DateTime.now(),
          playlists: (row['playlists'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
          favorites: (row['favorites'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
          recentlyPlayed: (row['recently_played'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
          listeningHistory: row['listening_history'] != null ? Map<String, dynamic>.from(row['listening_history'] as Map) : {},
          userPreferences: row['user_preferences'] != null ? Map<String, dynamic>.from(row['user_preferences'] as Map) : {},
          visualizerSettings: row['visualizer_settings'] != null ? Map<String, dynamic>.from(row['visualizer_settings'] as Map) : {},
          themeSettings: row['theme_settings'] != null ? Map<String, dynamic>.from(row['theme_settings'] as Map) : {},
          lyricsPreferences: row['lyrics_preferences'] != null ? Map<String, dynamic>.from(row['lyrics_preferences'] as Map) : {},
        );
      }
    }
    return null;
  }

  /// Push full synchronized musical and preference state to Supabase
  Future<bool> uploadSyncPayload(String userId, CloudSyncPayload payload, {String? token}) async {
    final uri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/sync_payloads');
    final body = jsonEncode({
      'user_id': userId,
      'version': payload.version,
      'updated_at': payload.updatedAt.toIso8601String(),
      'playlists': payload.playlists,
      'favorites': payload.favorites,
      'recently_played': payload.recentlyPlayed,
      'listening_history': payload.listeningHistory,
      'user_preferences': payload.userPreferences,
      'visualizer_settings': payload.visualizerSettings,
      'theme_settings': payload.themeSettings,
      'lyrics_preferences': payload.lyricsPreferences,
    });

    final response = await _client.post(
      uri,
      headers: _buildHeaders(token: token, preferMerge: true),
      body: body,
    ).timeout(_timeout);

    return response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204;
  }

  // =========================================================================
  // DEVICES TABLE (PostgREST API)
  // =========================================================================

  /// Fetch all active hardware devices for this account
  Future<List<DeviceModel>> fetchDevices(String userId, {String? currentDeviceId, String? token}) async {
    final uri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/devices?user_id=eq.$userId&select=*');
    final response = await _client.get(uri, headers: _buildHeaders(token: token)).timeout(_timeout);

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((e) {
        final row = Map<String, dynamic>.from(e as Map);
        final id = row['device_id'] as String? ?? '';
        return DeviceModel(
          deviceId: id,
          deviceName: row['device_name'] as String? ?? 'Cinematic Client',
          platform: row['platform'] as String? ?? 'generic',
          lastSyncTime: DateTime.tryParse(row['last_sync_time'] as String? ?? '') ?? DateTime.now(),
          appVersion: row['app_version'] as String? ?? '1.0.0',
          isCurrentDevice: id == currentDeviceId,
          ipHint: row['ip_hint'] as String? ?? '127.0.0.1',
        );
      }).toList();
    }
    return [];
  }

  /// Register or heartbeat a hardware device in Supabase
  Future<bool> registerOrUpdateDevice(String userId, DeviceModel device, {String? token}) async {
    final uri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/devices');
    final body = jsonEncode({
      'user_id': userId,
      'device_id': device.deviceId,
      'device_name': device.deviceName,
      'platform': device.platform,
      'last_sync_time': device.lastSyncTime.toIso8601String(),
      'app_version': device.appVersion,
      'ip_hint': device.ipHint,
    });

    final response = await _client.post(
      uri,
      headers: _buildHeaders(token: token, preferMerge: true),
      body: body,
    ).timeout(const Duration(seconds: 5));

    return response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204;
  }

  /// Remove or de-authorize a device from the account
  Future<bool> removeDevice(String userId, String deviceId, {String? token}) async {
    final uri = Uri.parse('${SupabaseConfig.instance.url}/rest/v1/devices?user_id=eq.$userId&device_id=eq.$deviceId');
    final response = await _client.delete(uri, headers: _buildHeaders(token: token)).timeout(const Duration(seconds: 5));
    return response.statusCode == 200 || response.statusCode == 204;
  }

  String _extractErrorMessage(String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      if (map.containsKey('msg')) return map['msg'] as String;
      if (map.containsKey('message')) return map['message'] as String;
      if (map.containsKey('error_description')) return map['error_description'] as String;
      if (map.containsKey('error')) {
        final err = map['error'];
        if (err is String) return err;
        if (err is Map && err.containsKey('message')) return err['message'] as String;
      }
    } catch (_) {}
    return '';
  }
}
