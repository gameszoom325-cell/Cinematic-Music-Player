import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/audio_engine/audio_engine.dart';
import 'core/database/database_service.dart';
import 'core/services/sample_music_service.dart';
import 'core/theme/cinematic_colors.dart';
import 'auth/session_manager.dart';
import 'auth/auth_service.dart';
import 'auth/welcome_screen.dart';
import 'sync/sync_manager.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge system bar transparency on Android
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Desktop Window Management (Windows)
  if (Platform.isWindows) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1180, 780),
        minimumSize: Size(840, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        title: "Cinematic Music Player",
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint("Window manager init fallback: $e");
    }
  }

  // Initialize Core Services
  try {
    await DatabaseService.instance.init();
    await AudioEngine.instance.init();
    await SampleMusicService.ensureSampleTracks();
    await SessionManager.instance.init();
    await AuthService.instance.init();
    await SyncManager.instance.init();
  } catch (e) {
    debugPrint("Core service startup: $e");
  }

  runApp(
    const ProviderScope(
      child: CinematicMusicApp(),
    ),
  );
}

class CinematicMusicApp extends StatelessWidget {
  const CinematicMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cinematic Music Player',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CinematicColors.obsidianBlack,
        colorScheme: const ColorScheme.dark(
          primary: CinematicColors.electricViolet,
          secondary: CinematicColors.neonCyan,
          surface: CinematicColors.obsidianDark,
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

/// Dynamic routing gateway determining initial screen:
/// - If user is logged in or chose offline guest mode -> AppShell
/// - First launch or logged out -> WelcomeScreen
class AuthGateway extends ConsumerWidget {
  const AuthGateway({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isGuest = SessionManager.instance.isGuest;

    if (user != null || isGuest) {
      return const AppShell();
    }
    return const WelcomeScreen();
  }
}
