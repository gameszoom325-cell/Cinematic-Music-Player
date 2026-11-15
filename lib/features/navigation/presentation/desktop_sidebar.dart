import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/database/database_service.dart';
import '../../playlists/providers/playlist_provider.dart';
import '../../legal/privacy_policy_page.dart';
import '../../legal/terms_condition_page.dart';

/// Spotify-style Desktop Navigation Sidebar.
/// Supports collapsible icon-only mode for narrower screens.
/// Features Home, Search, Your Library, Liked Songs, and user playlists with "+ Create Playlist".
class DesktopSidebar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text("New Playlist", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "My Playlist",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CinematicColors.primary,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await DatabaseService.instance.createPlaylist(name);
                ref.read(playlistProvider.notifier).refreshPlaylists();
                Navigator.pop(ctx);
              }
            },
            child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playlistProvider);
    final playlists = DatabaseService.instance.getAllPlaylists();

    final width = isCollapsed ? 76.0 : 240.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Header & Collapse Toggle
          Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 16 : 20, vertical: 20),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                if (!isCollapsed)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: CinematicColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "CINEMATIC",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                IconButton(
                  icon: Icon(
                    isCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
                    color: Colors.white60,
                    size: 20,
                  ),
                  splashRadius: 18,
                  tooltip: isCollapsed ? "Expand Sidebar" : "Collapse Sidebar",
                  onPressed: onToggleCollapse,
                ),
              ],
            ),
          ),

          // Primary Navigation Items
          _buildNavItem(
            icon: Icons.home_filled,
            label: "Home",
            index: 0,
            tooltip: "Home",
          ),
          _buildNavItem(
            icon: Icons.search_rounded,
            label: "Search",
            index: 1,
            tooltip: "Search (Ctrl+K or /)",
          ),
          _buildNavItem(
            icon: Icons.library_music_rounded,
            label: "Your Library",
            index: 2,
            tooltip: "Your Library",
          ),
          _buildNavItem(
            icon: Icons.language_rounded,
            label: "Online (Jamendo)",
            index: 7,
            tooltip: "Online Music (Jamendo)",
          ),
          _buildNavItem(
            icon: Icons.music_video_rounded,
            label: "Bollywood (Saavn)",
            index: 8,
            tooltip: "Bollywood Streaming (JioSaavn Unofficial)",
          ),
          _buildNavItem(
            icon: Icons.travel_explore_rounded,
            label: "Web MP3 (Pagalworld)",
            index: 9,
            tooltip: "WebView MP3 Search & Download (Pagalworld)",
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
          ),
          const SizedBox(height: 14),

          // Sub-Items
          _buildNavItem(
            icon: Icons.favorite_rounded,
            label: "Liked Songs",
            index: 3,
            tooltip: "Liked Songs",
            iconColor: Colors.pinkAccent,
          ),
          _buildNavItem(
            icon: Icons.queue_music_rounded,
            label: "Playlists",
            index: 4,
            tooltip: "Playlists",
          ),

          // Create Playlist Action
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showCreatePlaylistDialog(context, ref),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Create Playlist",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // User Playlists Scrollable List
          if (!isCollapsed)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: playlists.length,
                itemBuilder: (context, idx) {
                  final pl = playlists[idx];
                  return InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      onItemSelected(4);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Text(
                        pl.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            const Spacer(),

          // Settings at bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
          ),
          _buildNavItem(
            icon: Icons.settings_rounded,
            label: "Settings",
            index: 5,
            tooltip: "Settings",
          ),
          if (!isCollapsed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        "Privacy",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  Text(" • ", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TermsConditionPage()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        "Terms",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required String tooltip,
    Color? iconColor,
  }) {
    final isSelected = selectedIndex == index;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 12, vertical: 3),
      child: Tooltip(
        message: isCollapsed ? tooltip : "",
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onItemSelected(index),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? (iconColor ?? CinematicColors.primary)
                      : (iconColor?.withOpacity(0.6) ?? Colors.white.withOpacity(0.6)),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
