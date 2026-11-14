import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'user_model.dart';
import 'session_manager.dart';
import '../sync/cloud_database.dart';
import '../core/services/supabase_backend_client.dart';

/// Authentication service supporting real cloud backend authentication (Supabase GoTrue)
/// with seamless local offline vault caching and offline login fallback.
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

  /// Secure SHA-256 password hash with static system salt for offline storage
  String _hashPassword(String password, String salt) {
    const systemPepper = 'CINEMATIC_STUDIO_V1_PEPPER';
    final bytes = utf8.encode('$password::$salt::$systemPepper');
    return sha256.convert(bytes).toString();
  }

  /// Register a new cross-platform music account with real cloud backend
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

    UserModel? cloudUser;
    String? cloudError;

    // 1. Attempt real cloud registration via Supabase
    try {
      cloudUser = await SupabaseBackendClient.instance.signUp(
        email: cleanEmail,
        password: password,
        username: cleanUsername,
        profileImage: profileImage,
      );
    } catch (e) {
      cloudError = e.toString().replaceAll("Exception: ", "");
      debugPrint("Supabase online registration notice: $cloudError");
      // If error is duplicate user from Supabase, propagate error
      if (cloudError.toLowerCase().contains("already registered") ||
          cloudError.toLowerCase().contains("already exists")) {
        throw Exception("An account with this email already exists");
      }
    }

    final now = DateTime.now();
    final salt = now.microsecondsSinceEpoch.toString();
    final passwordHash = _hashPassword(password, salt);

    // If cloud succeeded, use cloud user; otherwise fallback to local offline vault creation
    final user = cloudUser ??
        UserModel(
          userId: 'usr_${now.millisecondsSinceEpoch.toRadixString(16)}',
          username: cleanUsername,
          email: cleanEmail,
          profileImage: profileImage ?? _getDefaultAvatar(cleanUsername),
          createdDate: now,
          token: 'tok_${sha256.convert(utf8.encode('$cleanEmail:$salt:$now')).toString().substring(0, 32)}',
          isGuest: false,
          devices: const [],
        );

    // Cache credentials in local vault for offline access
    final accounts = await _loadAccounts();
    final existingIdx = accounts.indexWhere((a) => (a['email'] as String).toLowerCase() == cleanEmail);
    final accountMap = {
      'userId': user.userId,
      'username': user.username,
      'email': cleanEmail,
      'passwordHash': passwordHash,
      'salt': salt,
      'profileImage': user.profileImage,
      'createdDate': user.createdDate.toIso8601String(),
      'token': user.token,
    };

    if (existingIdx >= 0) {
      accounts[existingIdx] = accountMap;
    } else {
      accounts.add(accountMap);
    }
    await _saveAccounts(accounts);

    // Persist session
    await SessionManager.instance.saveSession(user, token: user.token, rememberMe: true);

    // Register hardware device with cloud database & local vault
    final device = DeviceModel(
      deviceId: SessionManager.instance.deviceId,
      deviceName: SessionManager.instance.deviceName,
      platform: SessionManager.instance.getPlatform(),
      lastSyncTime: now,
      appVersion: '1.0.0',
      isCurrentDevice: true,
    );
    await CloudDatabase.instance.registerOrUpdateDevice(user.userId, device);

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
    UserModel? cloudUser;
    String? cloudError;

    // 1. Attempt real cloud login via Supabase
    try {
      cloudUser = await SupabaseBackendClient.instance.signIn(
        email: cleanEmail,
        password: password,
      );
    } catch (e) {
      cloudError = e.toString().replaceAll("Exception: ", "");
      debugPrint("Supabase cloud login notice: $cloudError");
      if (cloudError.toLowerCase().contains("invalid login") ||
          cloudError.toLowerCase().contains("invalid credentials")) {
        throw Exception("Invalid email or password");
      }
    }

    final accounts = await _loadAccounts();
    final localAccount = accounts.cast<Map<String, dynamic>?>().firstWhere(
          (a) => a != null && (a['email'] as String).toLowerCase() == cleanEmail,
          orElse: () => null,
        );

    // 2. If cloud login succeeded, update local offline cache
    if (cloudUser != null) {
      final now = DateTime.now();
      final salt = localAccount?['salt'] as String? ?? now.microsecondsSinceEpoch.toString();
      final passwordHash = _hashPassword(password, salt);

      final accountData = {
        'userId': cloudUser.userId,
        'username': cloudUser.username,
        'email': cleanEmail,
        'passwordHash': passwordHash,
        'salt': salt,
        'profileImage': cloudUser.profileImage,
        'createdDate': cloudUser.createdDate.toIso8601String(),
        'token': cloudUser.token,
      };

      if (localAccount != null) {
        final idx = accounts.indexOf(localAccount);
        accounts[idx] = accountData;
      } else {
        accounts.add(accountData);
      }
      await _saveAccounts(accounts);

      await SessionManager.instance.saveSession(cloudUser, token: cloudUser.token, rememberMe: rememberMe);

      final device = DeviceModel(
        deviceId: SessionManager.instance.deviceId,
        deviceName: SessionManager.instance.deviceName,
        platform: SessionManager.instance.getPlatform(),
        lastSyncTime: now,
        appVersion: '1.0.0',
        isCurrentDevice: true,
      );
      await CloudDatabase.instance.registerOrUpdateDevice(cloudUser.userId, device);

      return cloudUser;
    }

    // 3. Offline Mode: If cloud is unreachable, check local cached vault
    if (localAccount != null) {
      final salt = localAccount['salt'] as String;
      final expectedHash = localAccount['passwordHash'] as String;
      final providedHash = _hashPassword(password, salt);

      if (providedHash == expectedHash) {
        final userId = localAccount['userId'] as String;
        final token = localAccount['token'] as String? ??
            'tok_${sha256.convert(utf8.encode('$userId:$salt:${DateTime.now()}')).toString().substring(0, 32)}';

        final user = UserModel(
          userId: userId,
          username: localAccount['username'] as String,
          email: cleanEmail,
          profileImage: localAccount['profileImage'] as String?,
          createdDate: DateTime.tryParse(localAccount['createdDate'] as String? ?? '') ?? DateTime.now(),
          token: token,
          isGuest: false,
          devices: const [],
        );

        await SessionManager.instance.saveSession(user, token: token, rememberMe: rememberMe);
        return user;
      }
    }

    throw Exception(cloudError ?? "Invalid email or password");
  }

  /// Continue without account (Offline Guest Vault)
  Future<UserModel> continueWithoutAccount() async {
    await SessionManager.instance.setGuestMode(true);
    return UserModel.guest();
  }

  /// Sign out the current user session
  Future<void> logout() async {
    final token = SessionManager.instance.token;
    try {
      await SupabaseBackendClient.instance.signOut(token);
    } catch (_) {}
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
        final temp = File('${_accountsFile!.path}.tmp');
        await temp.writeAsString(jsonEncode(accounts), flush: true);
        if (await temp.exists()) {
          if (await _accountsFile!.exists()) await _accountsFile!.delete();
          await temp.rename(_accountsFile!.path);
        }
      }
    } catch (e) {
      debugPrint("Error saving accounts: $e");
    }
  }

  String _getDefaultAvatar(String username) {
    final hash = username.hashCode.abs() % 5;
    return 'avatar_preset_$hash';
  }
}
