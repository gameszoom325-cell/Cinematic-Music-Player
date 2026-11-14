import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/config/supabase_config.dart';
import 'core/services/shader_capability_service.dart';
import 'core/audio_engine/audio_engine.dart';
import 'core/database/database_service.dart';
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

  // Global Flutter Runtime Error Handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("CRITICAL FLUTTER ERROR: ${details.exceptionAsString()}");
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("ASYNC PLATFORM ERROR: $error\n$stack");
    return true; // prevent application crash
  };

  // Safe Fallback Error Widget instead of Blank / Black Screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0C),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    "Cinematic Visual System Note",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exceptionAsString(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      runApp(const ProviderScope(child: CinematicMusicApp()));
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text("Continue to App", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

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
        backgroundColor: Color(0xFF0A0A0C),
        skipTaskbar: false,
        title: "Cinematic Music Player",
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
      // Safety guarantee: explicitly show window
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint("Window manager init fallback: $e");
    }
  }

  // Initialize Core Services with individual resilience
  try {
    await DatabaseService.instance.init();
  } catch (e) {
    debugPrint("DatabaseService init note: $e");
  }

  try {
    await SupabaseConfig.instance.init();
  } catch (e) {
    debugPrint("SupabaseConfig init note: $e");
  }

  try {
    await ShaderCapabilityService.instance.checkShaderSupport();
  } catch (e) {
    debugPrint("ShaderCapabilityService check note: $e");
  }

  try {
    await AudioEngine.instance.init();
  } catch (e) {
    debugPrint("AudioEngine init note: $e");
  }

  try {
    await SessionManager.instance.init();
  } catch (e) {
    debugPrint("SessionManager init note: $e");
  }

  try {
    await AuthService.instance.init();
  } catch (e) {
    debugPrint("AuthService init note: $e");
  }

  try {
    await SyncManager.instance.init();
  } catch (e) {
    debugPrint("SyncManager init note: $e");
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
