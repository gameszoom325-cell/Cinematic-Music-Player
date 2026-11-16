import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/cinematic_colors.dart';
import 'core/services/update_service.dart';
import 'core/services/scanner_service.dart';
import 'core/services/firebase_service.dart';
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
import 'web_search/web_search_page.dart';
import 'features/legal/privacy_policy_page.dart';
import 'features/legal/terms_condition_page.dart';
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
    WebSearchPage(),        // 9: Web MP3 (Pagalworld)
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

    // Check for updates & desktop cloud sync after shell renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          UpdateService.checkAndShowDialog(context, isManual: false);
        }
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          _checkDesktopCloudSync();
        }
      });
    });
  }

  /// Desktop Sync Flow (Windows):
  /// When the user logs in on the Windows app, read users/{userId}/library from Firestore.
  /// Compare it to the local Windows library. If there are missing songs, show a dialog:
  /// "You have {count} songs synced from your mobile account. Download to this PC?"
  /// If the user clicks "Yes", download the files from Firebase Storage to the Windows
  /// local music folder and add them to the local library database.
  Future<void> _checkDesktopCloudSync({bool isManual = false}) async {
    if (!Platform.isWindows) return;
    if (!FirebaseService.instance.isLoggedIn) {
      if (isManual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please sign in to sync your cloud songs to this PC."),
            backgroundColor: Color(0xFF1B1B22),
          ),
        );
      }
      return;
    }

    try {
      final missingSongs = await FirebaseService.instance.findMissingSongsOnDesktop();
      if (missingSongs.isEmpty) {
        if (isManual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Your Windows library is already up to date with your cloud account!"),
              backgroundColor: CinematicColors.primary,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      final shouldDownload = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141418),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.cloud_download_rounded, color: CinematicColors.primary, size: 24),
              SizedBox(width: 10),
              Text(
                "Cross-Device Cloud Sync",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            "You have ${missingSongs.length} song${missingSongs.length == 1 ? '' : 's'} synced from your mobile account. Download to this PC?",
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Not Now", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CinematicColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yes, Download All", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (shouldDownload == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text("Downloading ${missingSongs.length} synced songs from cloud..."),
              ],
            ),
            backgroundColor: const Color(0xFF1B1B22),
            duration: const Duration(seconds: 15),
          ),
        );

        final downloaded = await FirebaseService.instance.downloadCloudSongsToLocal(
          songs: missingSongs,
        );

        ref.read(libraryProvider.notifier).refreshLibrary();

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Successfully synced $downloaded songs to your Windows music library!"),
              backgroundColor: CinematicColors.primary,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Desktop cloud sync notice: $e");
    }
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
          drawer: _buildAppDrawer(),
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
        const SpotifyNowPlayingBar(
          isQueueOpen: false,
          onToggleQueue: null,
        ),
        _buildBottomNav(),
      ],
    );
  }

  Widget _buildAppDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF141418),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CinematicColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "CINEMATIC",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      Text(
                        "Music Player",
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(Icons.home_filled, "Home", 0),
                  _buildDrawerItem(Icons.search_rounded, "Search", 1),
                  _buildDrawerItem(Icons.library_music_rounded, "Your Library", 2),
                  _buildDrawerItem(Icons.favorite_rounded, "Liked Songs", 3),
                  _buildDrawerItem(Icons.queue_music_rounded, "Playlists", 4),
                  _buildDrawerItem(Icons.cloud_queue_rounded, "Cloud Library", 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Colors.white12, height: 1),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Text(
                      "ONLINE & STREAMING",
                      style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                  _buildDrawerItem(Icons.language_rounded, "Online (Jamendo)", 7),
                  _buildDrawerItem(Icons.music_video_rounded, "Bollywood (JioSaavn)", 8),
                  _buildDrawerItem(Icons.travel_explore_rounded, "Web MP3 (Pagalworld)", 9),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Colors.white12, height: 1),
                  ),
                  _buildDrawerItem(Icons.settings_rounded, "Settings", 5),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Colors.white12, height: 1),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Text(
                      "LEGAL",
                      style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white60, size: 22),
                    title: const Text("Privacy Policy", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: Colors.white60, size: 22),
                    title: const Text("Terms & Conditions", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TermsConditionPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? CinematicColors.primary : Colors.white60,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildMobileNavIcon(Icons.home_filled, "Home", 0),
            _buildMobileNavIcon(Icons.search_rounded, "Search", 1),
            _buildMobileNavIcon(Icons.library_music_rounded, "Library", 2),
            _buildMobileNavIcon(Icons.music_video_rounded, "Bollywood", 8),
            _buildMobileNavIcon(Icons.travel_explore_rounded, "Web MP3", 9),
            Expanded(
              child: Builder(
                builder: (ctx) => InkWell(
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.menu_rounded,
                        color: Colors.white38,
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "More",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavIcon(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? CinematicColors.primary : Colors.white38,
              size: 20,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? CinematicColors.primary : Colors.white38,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
