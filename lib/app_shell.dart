import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/cinematic_colors.dart';
import 'core/theme/glassmorphism.dart';
import 'core/services/update_service.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/hindi_collection/presentation/hindi_collection_screen.dart';
import 'features/library/presentation/library_screen.dart';
import 'features/playlists/presentation/playlist_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/player/presentation/mini_player_bar.dart';
import 'features/player/presentation/cinematic_player_screen.dart';
import 'features/player/providers/player_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    HindiCollectionScreen(),
    LibraryScreen(),
    PlaylistScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // Check for updates 3 seconds after shell renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          UpdateService.checkAndShowDialog(context, isManual: false);
        }
      });
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  // Windows Desktop Keyboard & Media Key Handler
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final playerNotifier = ref.read(playerProvider.notifier);

      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
        playerNotifier.togglePlayPause();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.mediaTrackNext) {
        playerNotifier.skipToNext();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious) {
        playerNotifier.skipToPrevious();
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: CinematicColors.obsidianBlack,
          body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        );
      },
    );
  }

  // Desktop Tri-Pane Layout (Windows)
  Widget _buildDesktopLayout() {
    return Column(
      children: [
        // Top Glass Titlebar Drag Region
        _buildDesktopTitlebar(),

        Expanded(
          child: Row(
            children: [
              // Left Navigation Sidebar
              Container(
                width: 240,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  border: Border(right: BorderSide(color: Colors.white.withOpacity(0.08))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 20, 24, 28),
                      child: Row(
                        children: [
                          Icon(Icons.graphic_eq_rounded, color: CinematicColors.electricViolet, size: 28),
                          SizedBox(width: 10),
                          Text(
                            "CINEMATIC",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildNavItem(Icons.home_filled, "Home", 0),
                    _buildNavItem(Icons.stars_rounded, "Hindi Vault", 1),
                    _buildNavItem(Icons.library_music_rounded, "Library", 2),
                    _buildNavItem(Icons.queue_music_rounded, "Playlists", 3),
                    _buildNavItem(Icons.tune_rounded, "Settings", 4),
                    const Spacer(),
                    // Cinema Fullscreen Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CinematicPlayerScreen()),
                          );
                        },
                        child: CinematicGlassCard(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(12),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fullscreen_rounded, color: Colors.white70, size: 20),
                              SizedBox(width: 8),
                              Text("Cinema View", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Center Screen Content
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
        ),

        // Bottom Deck: Mini Player Bar
        const MiniPlayerBar(),
      ],
    );
  }

  // Mobile Adaptive Layout (Android)
  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
        ),
        const MiniPlayerBar(),
        _buildBottomNav(),
      ],
    );
  }

  Widget _buildDesktopTitlebar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: const Row(
        children: [
          Icon(Icons.blur_on_rounded, size: 16, color: Colors.white38),
          SizedBox(width: 8),
          Text(
            "Cinematic Music Player • Studio Edition",
            style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? CinematicColors.electricViolet.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: CinematicColors.electricViolet.withOpacity(0.5)) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isSelected ? CinematicColors.electricViolet : Colors.white60),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: CinematicColors.obsidianDark,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMobileNavIcon(Icons.home_filled, "Home", 0),
          _buildMobileNavIcon(Icons.stars_rounded, "Hindi Vault", 1),
          _buildMobileNavIcon(Icons.library_music_rounded, "Library", 2),
          _buildMobileNavIcon(Icons.queue_music_rounded, "Playlists", 3),
          _buildMobileNavIcon(Icons.tune_rounded, "Settings", 4),
        ],
      ),
    );
  }

  Widget _buildMobileNavIcon(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? CinematicColors.electricViolet : Colors.white54, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white38,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
