import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration provider for Supabase Authentication and Database Cloud Backend.
/// Supports both compile-time environment injection, runtime SharedPreferences overrides,
/// and fallback defaults.
class SupabaseConfig {
  SupabaseConfig._internal();
  static final SupabaseConfig instance = SupabaseConfig._internal();

  static const String _keyUrl = 'cinematic_supabase_url';
  static const String _keyAnonKey = 'cinematic_supabase_anon_key';

  // Default cloud endpoints (can be populated or overridden by user at runtime)
  static const String _defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cinematic-music.supabase.co',
  );

  static const String _defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.dummy_cinematic_key',
  );

  String _url = _defaultUrl;
  String _anonKey = _defaultAnonKey;
  bool _isCustomized = false;

  String get url => _url;
  String get anonKey => _anonKey;
  bool get isCustomized => _isCustomized;

  /// Returns true if valid HTTP/HTTPS Supabase URL is set
  bool get isConfigured {
    final clean = _url.trim().toLowerCase();
    return clean.startsWith('http://') || clean.startsWith('https://');
  }

  /// Initialize and load saved credentials from persistent storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_keyUrl);
      final savedKey = prefs.getString(_keyAnonKey);

      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _url = savedUrl.trim();
        _isCustomized = true;
      }
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        _anonKey = savedKey.trim();
        _isCustomized = true;
      }
    } catch (e) {
      debugPrint("SupabaseConfig.init error: $e");
    }
  }

  /// Save custom project credentials entered in Settings
  Future<void> setCredentials({required String url, required String anonKey}) async {
    _url = url.trim();
    _anonKey = anonKey.trim();
    _isCustomized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUrl, _url);
      await prefs.setString(_keyAnonKey, _anonKey);
    } catch (e) {
      debugPrint("SupabaseConfig.setCredentials error: $e");
    }
  }

  /// Reset to factory default configuration
  Future<void> resetToDefaults() async {
    _url = _defaultUrl;
    _anonKey = _defaultAnonKey;
    _isCustomized = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUrl);
      await prefs.remove(_keyAnonKey);
    } catch (e) {
      debugPrint("SupabaseConfig.resetToDefaults error: $e");
    }
  }
}
