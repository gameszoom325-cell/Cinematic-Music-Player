import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_model.dart';

/// Manages authentication tokens, local device identification,
/// and cross-session persistence across Windows Desktop and Android.
class SessionManager {
  SessionManager._internal();
  static final SessionManager instance = SessionManager._internal();

  static const String _keyUser = 'cinematic_session_user';
  static const String _keyToken = 'cinematic_session_token';
  static const String _keyRememberMe = 'cinematic_session_remember_me';
  static const String _keyGuest = 'cinematic_session_is_guest';
  static const String _keyDeviceId = 'cinematic_device_id';
  static const String _keyDeviceName = 'cinematic_device_name';
  static const String _keyLastSync = 'cinematic_last_sync_timestamp';

  SharedPreferences? _prefs;
  UserModel? _currentUser;
  String? _token;
  bool _isGuest = false;
  String? _deviceId;
  String? _deviceName;
  DateTime? _lastSyncTime;

  bool get isLoggedIn => _currentUser != null && !_isGuest && (_currentUser?.token != null || _token != null);
  bool get isGuest => _isGuest;
  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  String get deviceId => _deviceId ?? 'unknown_device_id';
  String get deviceName => _deviceName ?? 'Cinematic Device';
  DateTime? get lastSyncTime => _lastSyncTime;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // 1. Resolve or generate persistent device identifier
      _deviceId = _prefs!.getString(_keyDeviceId);
      if (_deviceId == null) {
        _deviceId = _generateUniqueDeviceId();
        await _prefs!.setString(_keyDeviceId, _deviceId!);
      }

      // 2. Resolve default device name
      _deviceName = _prefs!.getString(_keyDeviceName) ?? _detectDefaultDeviceName();

      // 3. Restore session
      _isGuest = _prefs!.getBool(_keyGuest) ?? false;
      final rememberMe = _prefs!.getBool(_keyRememberMe) ?? true;
      final rawUser = _prefs!.getString(_keyUser);
      _token = _prefs!.getString(_keyToken);

      final rawLastSync = _prefs!.getString(_keyLastSync);
      if (rawLastSync != null) {
        _lastSyncTime = DateTime.tryParse(rawLastSync);
      }

      if (rememberMe && rawUser != null) {
        _currentUser = UserModel.deserialize(rawUser);
      } else if (_isGuest) {
        _currentUser = UserModel.guest();
      }
    } catch (e) {
      debugPrint("SessionManager init error: $e");
    }
  }

  /// Store authenticated user session
  Future<void> saveSession(UserModel user, {String? token, bool rememberMe = true}) async {
    _currentUser = user;
    _token = token ?? user.token;
    _isGuest = false;

    if (_prefs != null) {
      await _prefs!.setString(_keyUser, user.serialize());
      if (_token != null) await _prefs!.setString(_keyToken, _token!);
      await _prefs!.setBool(_keyRememberMe, rememberMe);
      await _prefs!.setBool(_keyGuest, false);
    }
  }

  /// Set the user to continue in offline guest vault mode
  Future<void> setGuestMode(bool value) async {
    _isGuest = value;
    if (value) {
      _currentUser = UserModel.guest();
      _token = null;
    }
    if (_prefs != null) {
      await _prefs!.setBool(_keyGuest, value);
    }
  }

  /// Clear active session and sign out
  Future<void> clearSession() async {
    _currentUser = null;
    _token = null;
    _isGuest = false;

    if (_prefs != null) {
      await _prefs!.remove(_keyUser);
      await _prefs!.remove(_keyToken);
      await _prefs!.remove(_keyRememberMe);
      await _prefs!.setBool(_keyGuest, false);
    }
  }

  /// Update and record the timestamp of the last successful cloud synchronization
  Future<void> setLastSyncTime(DateTime time) async {
    _lastSyncTime = time;
    if (_prefs != null) {
      await _prefs!.setString(_keyLastSync, time.toIso8601String());
    }
  }

  /// Custom device name setter
  Future<void> setDeviceName(String name) async {
    _deviceName = name;
    if (_prefs != null) {
      await _prefs!.setString(_keyDeviceName, name);
    }
  }

  String getPlatform() {
    if (Platform.isWindows) return "windows";
    if (Platform.isAndroid) return "android";
    if (Platform.isMacOS) return "macos";
    if (Platform.isIOS) return "ios";
    if (Platform.isLinux) return "linux";
    return "unknown";
  }

  String _detectDefaultDeviceName() {
    try {
      if (Platform.isWindows) {
        final host = Platform.environment['COMPUTERNAME'] ?? 'Windows PC';
        return 'Windows Laptop ($host)';
      } else if (Platform.isAndroid) {
        return 'Android Mobile Device';
      }
    } catch (_) {}
    return 'Cinematic Audio Terminal';
  }

  String _generateUniqueDeviceId() {
    final rand = math.Random();
    final prefix = Platform.isWindows ? 'win' : (Platform.isAndroid ? 'droid' : 'device');
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final randomPart = List.generate(8, (_) => rand.nextInt(16).toRadixString(16)).join();
    return '${prefix}_${timestamp}_$randomPart';
  }
}
