import 'package:flutter/material.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../legal/privacy_policy_page.dart';
import '../../legal/terms_condition_page.dart';

/// Spotify-style Desktop Navigation Sidebar for Cinematic Music Player.
/// Supports collapsible icon-only mode for narrower screens.
/// Features Home, Library, Web MP3, and Settings.
class DesktopSidebar extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
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

          // Primary Navigation Items: Home, Library, Web MP3
          _buildNavItem(
            icon: Icons.home_filled,
            label: "Home",
            index: 0,
            tooltip: "Home",
          ),
          _buildNavItem(
            icon: Icons.library_music_rounded,
            label: "Library",
            index: 1,
            tooltip: "Local Library",
          ),
          _buildNavItem(
            icon: Icons.travel_explore_rounded,
            label: "Web MP3",
            index: 2,
            tooltip: "WebView MP3 Search & Download (Pagalworld)",
          ),

          const Spacer(),

          // Settings at bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
          ),
          _buildNavItem(
            icon: Icons.settings_rounded,
            label: "Settings",
            index: 3,
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
