import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'user_model.dart';
import 'session_manager.dart';
import '../sync/cloud_database.dart';

/// Authentication service for creating, logging in, and managing cross-device user accounts.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  File? _accountsFile;

  Future<void> init() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final authDir = Directory(p.join(docDir.path, 'CinematicMusicPlayer', 'cloud_vault', 'auth'));
      if (!await authDir.exists()) {
        await authDir.create(recursive: true);
      }
      _accountsFile = File(p.join(authDir.path, 'accounts.json'));
      if (!await _accountsFile!.exists()) {
        await _accountsFile!.writeAsString(jsonEncode([]));
      }
    } catch (e) {
      debugPrint("AuthService init error: $e");
    }
  }

  /// Secure SHA-256 password hash with static system salt
  String _hashPassword(String password, String salt) {
    const systemPepper = 'CINEMATIC_STUDIO_V1_PEPPER';
    final bytes = utf8.encode('$password::$salt::$systemPepper');
    return sha256.convert(bytes).toString();
  }

  /// Register a new cross-platform music account
  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
    String? profileImage,
  }) async {
    if (_accountsFile == null) await init();

    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim();

    if (cleanUsername.isEmpty) {
      throw Exception("Username cannot be empty");
    }
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw Exception("Please provide a valid email address");
    }
    if (password.length < 6) {
      throw Exception("Password must be at least 6 characters long");
    }

    final accounts = await _loadAccounts();

    // Check email uniqueness
    if (accounts.any((a) => (a['email'] as String).toLowerCase() == cleanEmail)) {
      throw Exception("An account with this email already exists");
    }

    final userId = 'usr_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final passwordHash = _hashPassword(password, salt);
    final token = 'tok_${sha256.convert(utf8.encode('$userId:$salt:${DateTime.now()}')).toString().substring(0, 32)}';
    final now = DateTime.now();

    final user = UserModel(
      userId: userId,
      username: cleanUsername,
      email: cleanEmail,
      profileImage: profileImage ?? _getDefaultAvatar(cleanUsername),
      createdDate: now,
      token: token,
      isGuest: false,
    );

    accounts.add({
      'userId': userId,
      'username': cleanUsername,
      'email': cleanEmail,
      'passwordHash': passwordHash,
      'salt': salt,
      'profileImage': user.profileImage,
      'createdDate': now.toIso8601String(),
      'token': token,
    });

    await _saveAccounts(accounts);
    await SessionManager.instance.saveSession(user, token: token, rememberMe: true);

    // Register hardware device with cloud vault
    final device = DeviceModel(
      deviceId: SessionManager.instance.deviceId,
      deviceName: SessionManager.instance.deviceName,
      platform: SessionManager.instance.getPlatform(),
      lastSyncTime: DateTime.now(),
      appVersion: '1.0.0',
      isCurrentDevice: true,
    );
    await CloudDatabase.instance.registerOrUpdateDevice(userId, device);

    return user;
  }

  /// Login to an existing account across Windows Desktop or Android Mobile
  Future<UserModel> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    if (_accountsFile == null) await init();

    final cleanEmail = email.trim().toLowerCase();
    final accounts = await _loadAccounts();

    final account = accounts.firstWhere(
      (a) => (a['email'] as String).toLowerCase() == cleanEmail,
      orElse: () => throw Exception("Invalid email or password"),
    );

    final salt = account['salt'] as String;
    final expectedHash = account['passwordHash'] as String;
    final providedHash = _hashPassword(password, salt);

    if (providedHash != expectedHash) {
      throw Exception("Invalid email or password");
    }

    final userId = account['userId'] as String;
    final token = 'tok_${sha256.convert(utf8.encode('$userId:$salt:${DateTime.now()}')).toString().substring(0, 32)}';

    // Update account with new session token
    account['token'] = token;
    await _saveAccounts(accounts);

    final user = UserModel(
      userId: userId,
      username: account['username'] as String,
      email: cleanEmail,
      profileImage: account['profileImage'] as String?,
      createdDate: DateTime.tryParse(account['createdDate'] as String? ?? '') ?? DateTime.now(),
      token: token,
      isGuest: false,
    );

    await SessionManager.instance.saveSession(user, token: token, rememberMe: rememberMe);

    // Register this device with user's account
    final device = DeviceModel(
      deviceId: SessionManager.instance.deviceId,
      deviceName: SessionManager.instance.deviceName,
      platform: SessionManager.instance.getPlatform(),
      lastSyncTime: DateTime.now(),
      appVersion: '1.0.0',
      isCurrentDevice: true,
    );
    await CloudDatabase.instance.registerOrUpdateDevice(userId, device);

    return user;
  }

  /// Continue without account (Offline Guest Vault)
  Future<UserModel> continueWithoutAccount() async {
    await SessionManager.instance.setGuestMode(true);
    return UserModel.guest();
  }

  /// Sign out the current user session
  Future<void> logout() async {
    await SessionManager.instance.clearSession();
  }

  /// Update user profile details
  Future<UserModel> updateProfile({String? username, String? profileImage}) async {
    final current = SessionManager.instance.currentUser;
    if (current == null || current.isGuest) {
      throw Exception("Must be signed in to update profile");
    }

    final accounts = await _loadAccounts();
    final index = accounts.indexWhere((a) => a['userId'] == current.userId);
    if (index >= 0) {
      if (username != null && username.isNotEmpty) {
        accounts[index]['username'] = username;
      }
      if (profileImage != null) {
        accounts[index]['profileImage'] = profileImage;
      }
      await _saveAccounts(accounts);
    }

    final updated = current.copyWith(
      username: username,
      profileImage: profileImage,
    );

    await SessionManager.instance.saveSession(updated);
    return updated;
  }

  UserModel? getCurrentUser() => SessionManager.instance.currentUser;

  Future<List<Map<String, dynamic>>> _loadAccounts() async {
    try {
      if (_accountsFile != null && await _accountsFile!.exists()) {
        final content = await _accountsFile!.readAsString();
        return (jsonDecode(content) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      debugPrint("Error reading accounts: $e");
    }
    return [];
  }

  Future<void> _saveAccounts(List<Map<String, dynamic>> accounts) async {
    try {
      if (_accountsFile != null) {
        await _accountsFile!.writeAsString(jsonEncode(accounts));
      }
    } catch (e) {
      debugPrint("Error saving accounts: $e");
    }
  }

  String _getDefaultAvatar(String username) {
    // Holographic gradient avatar preset
    final hash = username.hashCode.abs() % 5;
    return 'avatar_preset_$hash';
  }
}
