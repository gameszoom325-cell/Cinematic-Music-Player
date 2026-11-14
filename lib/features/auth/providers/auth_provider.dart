import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/user_model.dart';
import '../../../auth/session_manager.dart';
import '../../../auth/auth_service.dart';
import '../../../sync/sync_manager.dart';

class AuthNotifier extends StateNotifier<UserModel?> {
  AuthNotifier() : super(SessionManager.instance.currentUser);

  Future<void> login(String email, String password, {bool rememberMe = true}) async {
    final user = await AuthService.instance.login(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
    state = user;
    await SyncManager.instance.syncAll();
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? profileImage,
  }) async {
    final user = await AuthService.instance.register(
      username: username,
      email: email,
      password: password,
      profileImage: profileImage,
    );
    state = user;
    await SyncManager.instance.syncAll();
  }

  Future<void> continueWithoutAccount() async {
    final guest = await AuthService.instance.continueWithoutAccount();
    state = guest;
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    state = null;
  }

  void refresh() {
    state = SessionManager.instance.currentUser;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier();
});
