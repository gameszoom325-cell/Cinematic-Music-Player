import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/library_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/database/models/song_model.dart';
import '../../import/presentation/add_music_screen.dart';
import 'music_search_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = "All";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> _getCategories(List<SongModel> songs) {
    final genres = songs
        .map((s) => s.genre.trim())
        .where((g) => g.isNotEmpty && g.toLowerCase() != 'unknown' && g.toLowerCase() != 'other')
        .toSet()
        .toList()
      ..sort();
    return ["All", ...genres];
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  void _openAddMusic() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddMusicScreen()),
    );
  }

  List<SongModel> _filterSongs(List<SongModel> songs) {
    if (_selectedCategory == "All") return songs;

    final lowerCat = _selectedCategory.toLowerCase();
    return songs.where((s) {
      final genre = s.genre.toLowerCase();
      final title = s.title.toLowerCase();
      final album = s.album.toLowerCase();
      final artist = s.artist.toLowerCase();

      return genre.contains(lowerCat) ||
          title.contains(lowerCat) ||
          album.contains(lowerCat) ||
          artist.contains(lowerCat);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);

    final categories = _getCategories(libraryState.songs);
    final activeCategory = categories.contains(_selectedCategory) ? _selectedCategory : "All";
    final filteredSongs = _filterSongs(libraryState.songs);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Add Music Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Acoustic Vault",
                        style: TextStyle(
                          color: CinematicColors.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        "${libraryState.songs.length} audio tracks in storage",
                        style: const TextStyle(color: CinematicColors.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search_rounded, color: CinematicColors.primary),
                        tooltip: "Search & Discover",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MusicSearchScreen()),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CinematicColors.primary.withOpacity(0.18),
                          foregroundColor: CinematicColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: CinematicColors.primary.withOpacity(0.5)),
                          ),
                        ),
                        onPressed: _openAddMusic,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          "Add Music",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: CinematicColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => libraryNotifier.setSearchQuery(val),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    icon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                    hintText: "Search your acoustic vault...",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    border: InputBorder.none,
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              libraryNotifier.setSearchQuery("");
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Category Filter Chips
              if (categories.length > 1) ...[
                SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = activeCategory == cat;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? CinematicColors.primary
                                : CinematicColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? CinematicColors.primary
                                  : Colors.white.withOpacity(0.08),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.black87 : Colors.white70,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Virtualized Song List with itemExtent: 68.0 for 60 FPS scrolling over 10k items
              Expanded(
                child: filteredSongs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: filteredSongs.length,
                        itemExtent: 68.0,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final song = filteredSongs[index];
                          final isCurrent = playerState.currentSong?.id == song.id;

                          return RepaintBoundary(
                            child: _SongListTile(
                              song: song,
                              isCurrent: isCurrent,
                              isPlaying: isCurrent && playerState.isPlaying,
                              formattedDuration: _formatDuration(song.durationMs),
                              onTap: () async {
                                if (!song.isLocalFileAvailable) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Audio file unavailable. Please import this song again."),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                final success = await playerNotifier.playTrack(filteredSongs, index);
                                if (!success && context.mounted) {
                                  final err = ref.read(playerProvider).errorMessage ??
                                      "Audio file unavailable. Please import this song again.";
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(err),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music_rounded, size: 56, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 14),
          Text(
            _selectedCategory == "All"
                ? "Your library is empty"
                : "No songs in '$_selectedCategory'",
            style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            "Tap 'Add Music' or drag and drop audio files here.",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SongListTile extends StatelessWidget {
  final SongModel song;
  final bool isCurrent;
  final bool isPlaying;
  final String formattedDuration;
  final VoidCallback onTap;

  const _SongListTile({
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    required this.formattedDuration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? CinematicColors.surfaceContainerHigh
            : CinematicColors.surfaceContainerLow.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: CinematicColors.primary.withOpacity(0.5), width: 1)
            : Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44,
            height: 44,
            child: _buildArtworkThumb(song),
          ),
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? CinematicColors.primary : Colors.white,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          "${song.artist} • ${song.format.toUpperCase()}${song.year.isNotEmpty ? ' • ${song.year}' : ''}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (song.lrcPath != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: CinematicColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "LRC",
                  style: TextStyle(color: CinematicColors.primary, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (isCurrent && isPlaying) ...[
              const Icon(Icons.equalizer_rounded, color: CinematicColors.primary, size: 16),
              const SizedBox(width: 8),
            ],
            Text(
              formattedDuration,
              style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtworkThumb(SongModel song) {
    if (song.artworkPath != null && song.artworkPath!.isNotEmpty) {
      if (song.artworkPath!.startsWith('http://') || song.artworkPath!.startsWith('https://')) {
        return Image.network(
          song.artworkPath!,
          fit: BoxFit.cover,
          cacheWidth: 120,
          cacheHeight: 120,
          errorBuilder: (context, error, stackTrace) => _fallbackThumb(),
        );
      }
      final file = File(song.artworkPath!);
      if (file.existsSync() && file.lengthSync() > 0) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 120,
          cacheHeight: 120,
          errorBuilder: (context, error, stackTrace) => _fallbackThumb(),
        );
      }
    }
    return _fallbackThumb();
  }

  Widget _fallbackThumb() {
    return Container(
      decoration: BoxDecoration(
        color: CinematicColors.surfaceContainerHighest,
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white38, size: 20),
      ),
    );
  }
}
