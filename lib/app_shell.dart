import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/cinematic_colors.dart';
import 'core/services/update_service.dart';
import 'core/services/scanner_service.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/library/presentation/library_screen.dart';
import 'features/library/providers/library_provider.dart';
import 'features/playlists/presentation/playlist_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/player/presentation/mini_player_bar.dart';
import 'features/player/presentation/cinematic_player_screen.dart';
import 'features/player/providers/player_provider.dart';
import 'features/player/models/player_state.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    LibraryScreen(),
    PlaylistScreen(),
    SettingsScreen(),
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
      final playerNotifier = ref.read(playerProvider.notifier);
      final playerState = ref.read(playerProvider);

      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
        playerNotifier.togglePlayPause();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        final newPos = playerState.position - const Duration(seconds: 5);
        playerNotifier.seek(newPos < Duration.zero ? Duration.zero : newPos);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        final newPos = playerState.position + const Duration(seconds: 5);
        playerNotifier.seek(newPos > playerState.duration ? playerState.duration : newPos);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        playerNotifier.setVolume(playerState.volume + 0.05);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        playerNotifier.setVolume(playerState.volume - 0.05);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyN ||
          event.logicalKey == LogicalKeyboardKey.mediaTrackNext) {
        playerNotifier.skipToNext();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyP ||
          event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious) {
        playerNotifier.skipToPrevious();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        playerNotifier.toggleMute();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
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
        final isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: CinematicColors.background,
          body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        );
      },
    );
  }

  // Desktop Tri-Pane Layout (Windows)
  Widget _buildDesktopLayout() {
    final playerState = ref.watch(playerProvider);
    final currentSong = playerState.currentSong;

    return Column(
      children: [
        // Top Acoustic Header Bar
        _buildDesktopHeader(currentSong),

        Expanded(
          child: Row(
            children: [
              // Left Vault Navigation Sidebar
              _buildDesktopSidebar(),

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

  Widget _buildDesktopHeader(dynamic currentSong) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: CinematicColors.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Brand
          Row(
            children: [
              const Icon(Icons.album_rounded, color: CinematicColors.primary, size: 22),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    color: CinematicColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                  children: [
                    TextSpan(text: "STILL"),
                    TextSpan(text: ".", style: TextStyle(color: CinematicColors.primary)),
                    TextSpan(text: "AUDIO"),
                  ],
                ),
              ),
            ],
          ),

          // Central Navigation Pills
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: CinematicColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeaderPill("Now Playing", 0),
                _buildHeaderPill("Library", 1),
                _buildHeaderPill("Playlists", 2),
                _buildHeaderPill("Settings", 3),
              ],
            ),
          ),

          // Right Technical Badge & Rain Mode Indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CinematicColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (currentSong != null && currentSong.technicalSpecs.isNotEmpty)
                      ? currentSong.technicalSpecs
                      : "Direct DAC • Lossless",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Cinema View Pill
              IconButton(
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white70, size: 22),
                tooltip: "Open Full Cinema View (F)",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CinematicPlayerScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPill(String label, int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? CinematicColors.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? CinematicColors.primary : CinematicColors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: CinematicColors.surfaceContainerLowest,
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              "THE VAULT",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          _buildSidebarNavItem(Icons.graphic_eq_rounded, "Daily Flow", 0),
          _buildSidebarNavItem(Icons.library_music_rounded, "Acoustic Vault", 1),
          _buildSidebarNavItem(Icons.queue_music_rounded, "Playlists", 2),
          _buildSidebarNavItem(Icons.tune_rounded, "Studio Settings", 3),

          const Spacer(),

          // Analog Signal status box
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CinematicColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ANALOG SIGNAL",
                    style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Direct DAC", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text("Bitperfect", style: TextStyle(color: CinematicColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? CinematicColors.surfaceContainerHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? CinematicColors.primary : CinematicColors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? CinematicColors.onSurface : CinematicColors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildBottomNav() {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: CinematicColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMobileNavIcon(Icons.graphic_eq_rounded, "Flow", 0),
          _buildMobileNavIcon(Icons.library_music_rounded, "Library", 1),
          _buildMobileNavIcon(Icons.queue_music_rounded, "Playlists", 2),
          _buildMobileNavIcon(Icons.tune_rounded, "Settings", 3),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
