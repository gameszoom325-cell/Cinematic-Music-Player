import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/library_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/typography.dart';
import '../../../core/database/models/song_model.dart';
import '../../import/presentation/add_music_screen.dart';

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

  static const List<String> categories = [
    "All",
    "Hindi",
    "English",
    "Tamil",
    "Japanese",
    "Korean",
    "Instrumental",
    "Anime OST",
    "Lo-Fi",
  ];

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
                  const Text("Library", style: CinematicTypography.displayTitle),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CinematicColors.electricViolet.withOpacity(0.25),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: CinematicColors.electricViolet.withOpacity(0.5)),
                          ),
                        ),
                        onPressed: _openAddMusic,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text("Add Music", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              CinematicGlassCard(
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => libraryNotifier.setSearchQuery(val),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    icon: const Icon(Icons.search_rounded, color: Colors.white60, size: 20),
                    hintText: "Search your private vault...",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    border: InputBorder.none,
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              libraryNotifier.setSearchQuery("");
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Premium Category Filter Chips
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _selectedCategory == cat;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CinematicColors.electricViolet
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? CinematicColors.electricViolet
                                : Colors.white.withOpacity(0.12),
                            width: 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: CinematicColors.electricViolet.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Song List
              Expanded(
                child: filteredSongs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: filteredSongs.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final song = filteredSongs[index];
                          final isCurrent = playerState.currentSong?.id == song.id;

                          return _SongListTile(
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
                                final err = ref.read(playerProvider).errorMessage ?? "Audio file unavailable. Please import this song again.";
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(err),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
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
          Icon(Icons.library_music_rounded, size: 64, color: Colors.white.withOpacity(0.25)),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == "All"
                ? "Your library is empty"
                : "No songs in '$_selectedCategory'",
            style: CinematicTypography.songTitleMedium.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tap 'Add Music' to import your private audio collection.",
            style: TextStyle(color: Colors.white38, fontSize: 13),
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.white.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: isCurrent
            ? Border.all(color: CinematicColors.electricViolet.withOpacity(0.5), width: 1)
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
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
            color: isCurrent ? CinematicColors.electricViolet : Colors.white,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          "${song.artist} • ${song.format}${song.year.isNotEmpty ? ' • ${song.year}' : ''}${song.genre != 'Uncategorized' ? ' • ${song.genre}' : ''}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (song.lrcPath != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CinematicColors.neonCyan.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text("LRC", style: TextStyle(color: CinematicColors.neonCyan, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
            ],
            if (isCurrent && isPlaying) ...[
              const Icon(Icons.equalizer_rounded, color: CinematicColors.electricViolet, size: 18),
              const SizedBox(width: 8),
            ],
            Text(formattedDuration, style: CinematicTypography.timestamp),
          ],
        ),
      ),
    );
  }

  Widget _buildArtworkThumb(SongModel song) {
    if (song.artworkPath != null) {
      final file = File(song.artworkPath!);
      if (file.existsSync() && file.lengthSync() > 0) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackThumb(),
        );
      }
    }
    return _fallbackThumb();
  }

  Widget _fallbackThumb() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CinematicColors.electricViolet.withOpacity(0.35),
            CinematicColors.obsidianDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white70, size: 22),
      ),
    );
  }
}
