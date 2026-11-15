import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_secrets.dart';

/// Secure configuration manager for Jamendo Music API integration.
/// 
/// Stores Jamendo API credentials separately from UI, audio engine, and repository code.
/// Supports compile-time environment flags, local persistent overrides,
/// and safe masking for diagnostics and logging.
class JamendoConfig {
  JamendoConfig._internal();
  static final JamendoConfig instance = JamendoConfig._internal();

  static const String _prefKey = 'cinematic_jamendo_client_id';

  // Client ID loaded from git-ignored AppSecrets or environment variable
  static const String _defaultClientId = String.fromEnvironment(
    'JAMENDO_CLIENT_ID',
    defaultValue: AppSecrets.jamendoClientId,
  );

  String _clientId = _defaultClientId;
  bool _isCustomized = false;

  String get clientId => _clientId.trim();
  bool get isCustomized => _isCustomized;
  bool get hasClientId => _clientId.trim().isNotEmpty;

  /// Returns a safely masked Client ID for logging and diagnostics (e.g. "fd91...4c0b")
  String get maskedClientId {
    final id = _clientId.trim();
    if (id.isEmpty) return '(not configured)';
    if (id.length <= 4) return '****';
    final prefix = id.substring(0, 2);
    final suffix = id.substring(id.length - 2);
    return '$prefix...$suffix';
  }

  /// Initialize and load persisted custom client ID if available
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _clientId = saved.trim();
        _isCustomized = true;
      }
    } catch (e) {
      debugPrint("JamendoConfig.init error: $e");
    }
  }

  /// Update Client ID at runtime and persist locally
  Future<void> setClientId(String clientId) async {
    _clientId = clientId.trim();
    _isCustomized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _clientId);
    } catch (e) {
      debugPrint("JamendoConfig.setClientId error: $e");
    }
  }

  /// Reset to default compile-time Client ID
  Future<void> resetToDefault() async {
    _clientId = _defaultClientId;
    _isCustomized = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (e) {
      debugPrint("JamendoConfig.resetToDefault error: $e");
    }
  }

  /// Diagnostic validation of Client ID format
  JamendoConfigValidation validate() {
    final id = clientId;
    if (id.isEmpty) {
      return JamendoConfigValidation(
        isValid: false,
        errorMessage: 'Jamendo Client ID is missing. Configure JAMENDO_CLIENT_ID or set via JamendoConfig.',
      );
    }
    if (id.length < 6) {
      return JamendoConfigValidation(
        isValid: false,
        errorMessage: 'Jamendo Client ID "$maskedClientId" appears too short to be valid.',
      );
    }
    return JamendoConfigValidation(isValid: true);
  }
}

class JamendoConfigValidation {
  final bool isValid;
  final String? errorMessage;

  const JamendoConfigValidation({required this.isValid, this.errorMessage});
}
