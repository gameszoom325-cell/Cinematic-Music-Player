import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure configuration manager for YouTube Data API v3 integration.
/// 
/// Stores credentials in a dedicated layer outside UI and repository code.
/// Supports compile-time environment flags, local persistent storage,
/// and safe masking for diagnostics.
class YouTubeConfig {
  YouTubeConfig._internal();
  static final YouTubeConfig instance = YouTubeConfig._internal();

  static const String _prefKey = 'cinematic_youtube_api_key';

  // Default API key supplied for this private project
  static const String _defaultApiKey = String.fromEnvironment(
    'YOUTUBE_API_KEY',
    defaultValue: 'AIzaSyAoqbmfwc618y2JLqwuJ1XNESNXzseVV4k',
  );

  String _apiKey = _defaultApiKey;
  bool _isCustomized = false;

  String get apiKey => _apiKey.trim();
  bool get isCustomized => _isCustomized;
  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  /// Returns a safely masked API key for logging or UI display (e.g. "AIza...VV4k")
  String get maskedApiKey {
    final key = _apiKey.trim();
    if (key.length <= 8) return '****';
    final prefix = key.substring(0, 4);
    final suffix = key.substring(key.length - 4);
    return '$prefix...$suffix';
  }

  /// Load persisted custom key from SharedPreferences if set
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _apiKey = saved.trim();
        _isCustomized = true;
      }
    } catch (e) {
      debugPrint("YouTubeConfig.init error: $e");
    }
  }

  /// Update key at runtime and persist locally
  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    _isCustomized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _apiKey);
    } catch (e) {
      debugPrint("YouTubeConfig.setApiKey error: $e");
    }
  }

  /// Reset to project default configuration
  Future<void> resetToDefault() async {
    _apiKey = _defaultApiKey;
    _isCustomized = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (e) {
      debugPrint("YouTubeConfig.resetToDefault error: $e");
    }
  }
}
