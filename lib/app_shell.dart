import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/cinematic_colors.dart';
import 'core/services/update_service.dart';
import 'core/services/scanner_service.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/library/presentation/library_screen.dart';
import 'features/library/presentation/music_search_screen.dart';
import 'features/library/providers/library_provider.dart';
import 'features/cloud/presentation/cloud_library_screen.dart';
import 'features/favorites/presentation/favorites_screen.dart';
import 'features/playlists/presentation/playlist_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'jamendo/jamendo_page.dart';
import 'jiosaavn/jiosaavn_page.dart';
import 'features/player/presentation/widgets/spotify_now_playing_bar.dart';
import 'features/player/presentation/widgets/queue_panel.dart';
import 'features/player/presentation/cinematic_player_screen.dart';
import 'features/navigation/presentation/desktop_sidebar.dart';
import 'features/player/providers/player_provider.dart';
import 'features/player/models/player_state.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0; // Default to Home
  bool _isSidebarCollapsed = false;
  bool _isQueueOpen = false;

  final List<Widget> _screens = const [
    HomeScreen(),           // 0: Home
    MusicSearchScreen(),    // 1: Search
    LibraryScreen(),        // 2: Your Library
    FavoritesScreen(),      // 3: Liked Songs
    PlaylistScreen(),       // 4: Playlists
    SettingsScreen(),       // 5: Settings
    CloudLibraryScreen(),   // 6: Cloud Library
    JamendoPage(),          // 7: Online (Jamendo)
    JioSaavnPage(),         // 8: Bollywood (JioSaavn)
  ];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // Setup native Windows drag-and-drop receiver
    const MethodChannel('cinematic/drag_drop').setMethodCallHandler((call) async {
      if (call.method == 'onDropFiles') {
        final dynamic raw = call.arguments;
        if (raw is List) {
          final paths = raw.map((e) => e.toString()).toList();
          if (paths.isNotEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Importing ${paths.length} dropped audio file(s)..."),
                backgroundColor: CinematicColors.primaryContainer,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
            await ScannerService.importFiles(paths.map((p) => File(p)).toList());
            ref.read(libraryProvider.notifier).refreshLibrary();
          }
        }
      }
    });

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

  // Windows Desktop Keyboard Shortcuts & Media Key Handler
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Focus Search: '/' or 'Ctrl+K'
      if (event.logicalKey == LogicalKeyboardKey.slash ||
          (event.logicalKey == LogicalKeyboardKey.keyK && HardwareKeyboard.instance.isControlPressed) ||
          (event.logicalKey == LogicalKeyboardKey.keyF && HardwareKeyboard.instance.isControlPressed)) {
        setState(() => _selectedIndex = 1);
        return true;
      }

      final playerNotifier = ref.read(playerProvider.notifier);
      final playerState = ref.read(playerProvider);

      // Play / Pause: Space or MediaPlayPause
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
        playerNotifier.togglePlayPause();
        return true;
      }

      // Next / Previous: Ctrl+Right / Ctrl+Left or Media Keys
      if ((HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.arrowRight) ||
          event.logicalKey == LogicalKeyboardKey.keyN ||
          event.logicalKey == LogicalKeyboardKey.mediaTrackNext) {
        playerNotifier.skipToNext();
        return true;
      } else if ((HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.arrowLeft) ||
          event.logicalKey == LogicalKeyboardKey.keyP ||
          event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious) {
        playerNotifier.skipToPrevious();
        return true;
      }

      // Seek +-5s: Bare Left / Right Arrows
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        final newPos = playerState.position - const Duration(seconds: 5);
        playerNotifier.seek(newPos < Duration.zero ? Duration.zero : newPos);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        final newPos = playerState.position + const Duration(seconds: 5);
        playerNotifier.seek(newPos > playerState.duration ? playerState.duration : newPos);
        return true;
      }

      // Volume Up / Down: ArrowUp / ArrowDown
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        playerNotifier.setVolume(playerState.volume + 0.05);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        playerNotifier.setVolume(playerState.volume - 0.05);
        return true;
      }

      // Mute / Unmute: 'M'
      if (event.logicalKey == LogicalKeyboardKey.keyM) {
        playerNotifier.toggleMute();
        return true;
      }

      // Full Cinema View: 'F'
      if (event.logicalKey == LogicalKeyboardKey.keyF && !HardwareKeyboard.instance.isControlPressed) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CinematicPlayerScreen()),
        );
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CinematicPlayerState>(playerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: "OK",
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        return Scaffold(
          backgroundColor: CinematicColors.background,
          body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        );
      },
    );
  }

  // Desktop Tri-Pane Layout (Spotify-style)
  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // 1. Left Sidebar
              DesktopSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
                isCollapsed: _isSidebarCollapsed,
                onToggleCollapse: () {
                  setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
                },
              ),

              // 2. Main Center Screen Content
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _screens,
                ),
              ),

              // 3. Sliding Queue Panel
              if (_isQueueOpen)
                QueuePanel(
                  onClose: () => setState(() => _isQueueOpen = false),
                ),
            ],
          ),
        ),

        // 4. Persistent Bottom Spotify-style Now Playing Bar
        SpotifyNowPlayingBar(
          isQueueOpen: _isQueueOpen,
          onToggleQueue: () {
            setState(() => _isQueueOpen = !_isQueueOpen);
          },
        ),
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
        SpotifyNowPlayingBar(
          isQueueOpen: false,
          onToggleQueue: null,
        ),
        _buildBottomNav(),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMobileNavIcon(Icons.home_filled, "Home", 0),
          _buildMobileNavIcon(Icons.search_rounded, "Search", 1),
          _buildMobileNavIcon(Icons.library_music_rounded, "Library", 2),
          _buildMobileNavIcon(Icons.language_rounded, "Online", 7),
          _buildMobileNavIcon(Icons.favorite_rounded, "Liked", 3),
          _buildMobileNavIcon(Icons.tune_rounded, "Settings", 5),
        ],
      ),
    );
  }

  Widget _buildMobileNavIcon(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? CinematicColors.primary : Colors.white38,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? CinematicColors.primary : Colors.white38,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
