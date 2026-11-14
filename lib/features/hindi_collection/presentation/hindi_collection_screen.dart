import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/typography.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/curated_catalogue.dart';
import '../../../core/database/models/song_model.dart';
import '../../player/providers/player_provider.dart';
import '../../library/providers/library_provider.dart';
import '../../../core/services/scanner_service.dart';
import '../../import/presentation/add_music_screen.dart';

class HindiCollectionScreen extends ConsumerStatefulWidget {
  const HindiCollectionScreen({super.key});

  @override
  ConsumerState<HindiCollectionScreen> createState() => _HindiCollectionScreenState();
}

class _HindiCollectionScreenState extends ConsumerState<HindiCollectionScreen> {
  int _selectedFilterIndex = 0; // 0 = Trending, 1 = Classics, 2 = Favorites, 3 = All

  Future<void> _handleLinkAudio(CuratedSongEntry entry) async {
    final files = await ScannerService.pickAudioFiles();
    if (files != null && files.isNotEmpty) {
      final file = files.first;
      await ScannerService.importFiles([file]);
      ref.read(libraryProvider.notifier).refreshLibrary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Linked '${p_basename(file.path)}' to '${entry.title}'"),
            backgroundColor: CinematicColors.electricViolet,
          ),
        );
      }
    }
  }

  String p_basename(String path) {
    final idx = path.lastIndexOf(RegExp(r'[\\/]'));
    return idx != -1 ? path.substring(idx + 1) : path;
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryProvider);
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final db = DatabaseService.instance;
    final allDbSongs = db.getAllSongs();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "HINDI MUSIC COLLECTION",
                          style: TextStyle(
                            color: CinematicColors.electricViolet,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text("Curated Vault", style: CinematicTypography.displayTitle),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CinematicColors.electricViolet,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddMusicScreen()),
                        );
                      },
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: const Text("Import Audio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),

            // Filter Tabs: Trending | Classics | Favorites | All
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip("Trending Hits", 0, Icons.local_fire_department_rounded),
                    const SizedBox(width: 10),
                    _buildFilterChip("Classics", 1, Icons.auto_awesome_rounded),
                    const SizedBox(width: 10),
                    _buildFilterChip("Favorites", 2, Icons.favorite_rounded),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Section 1: Trending Hindi Hits
            if (_selectedFilterIndex == 0 || _selectedFilterIndex == 3) ...[
              SliverToBoxAdapter(
                child: _buildSectionTitle("TRENDING HINDI HITS", "Top trending cinema anthems"),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = CuratedCatalogue.trendingHits[index];
                      final matchedSong = _findMatchedSong(allDbSongs, entry);
                      final isCurrent = playerState.currentSong?.title.toLowerCase() == entry.title.toLowerCase();

                      return _buildCatalogueTile(
                        entry: entry,
                        matchedSong: matchedSong,
                        isCurrent: isCurrent,
                        isPlaying: isCurrent && playerState.isPlaying,
                        onTap: () {
                          if (matchedSong != null && matchedSong.isLocalFileAvailable) {
                            playerNotifier.playTrack([matchedSong], 0);
                          } else {
                            _handleLinkAudio(entry);
                          }
                        },
                      );
                    },
                    childCount: CuratedCatalogue.trendingHits.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // Section 2: Hindi Classics
            if (_selectedFilterIndex == 1 || _selectedFilterIndex == 3) ...[
              SliverToBoxAdapter(
                child: _buildSectionTitle("HINDI CLASSICS", "Timeless masterpieces & golden era"),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = CuratedCatalogue.classics[index];
                      final matchedSong = _findMatchedSong(allDbSongs, entry);
                      final isCurrent = playerState.currentSong?.title.toLowerCase() == entry.title.toLowerCase();

                      return _buildCatalogueTile(
                        entry: entry,
                        matchedSong: matchedSong,
                        isCurrent: isCurrent,
                        isPlaying: isCurrent && playerState.isPlaying,
                        onTap: () {
                          if (matchedSong != null && matchedSong.isLocalFileAvailable) {
                            playerNotifier.playTrack([matchedSong], 0);
                          } else {
                            _handleLinkAudio(entry);
                          }
                        },
                      );
                    },
                    childCount: CuratedCatalogue.classics.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // Section 3: Favorites (when selected)
            if (_selectedFilterIndex == 2) ...[
              SliverToBoxAdapter(
                child: _buildSectionTitle("FAVORITES", "Your starred tracks"),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final favs = db.getFavorites();
                      if (favs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              "No favorites yet. Star your favorite tracks in the player!",
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          ),
                        );
                      }
                      final song = favs[index];
                      final isCurrent = playerState.currentSong?.id == song.id;

                      return ListTile(
                        onTap: () => playerNotifier.playTrack(favs, index),
                        title: Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("${song.artist} • ${song.album}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: Text(_formatDuration(song.durationMs), style: CinematicTypography.timestamp),
                      );
                    },
                    childCount: db.getFavorites().isEmpty ? 1 : db.getFavorites().length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  SongModel? _findMatchedSong(List<SongModel> songs, CuratedSongEntry entry) {
    for (final s in songs) {
      if (s.title.toLowerCase().trim() == entry.title.toLowerCase().trim()) {
        return s;
      }
    }
    return null;
  }

  Widget _buildFilterChip(String label, int index, IconData icon) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? CinematicColors.electricViolet : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? CinematicColors.electricViolet : Colors.white.withOpacity(0.12),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogueTile({
    required CuratedSongEntry entry,
    required SongModel? matchedSong,
    required bool isCurrent,
    required bool isPlaying,
    required VoidCallback onTap,
  }) {
    final bool isLinked = matchedSong != null && matchedSong.isLocalFileAvailable;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? Colors.white.withOpacity(0.08)
            : (isLinked ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? CinematicColors.electricViolet
              : (isLinked ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.05)),
          width: isCurrent ? 1.4 : 1.0,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 48,
            height: 48,
            child: _buildTileArtwork(matchedSong, entry),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrent ? CinematicColors.electricViolet : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            if (isLinked)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CinematicColors.radioactiveGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text("LINKED", style: TextStyle(color: CinematicColors.radioactiveGreen, fontSize: 9, fontWeight: FontWeight.bold)),
              )
            else
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text("READY TO LINK", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Text(
          "${entry.artist} • ${entry.album} (${entry.year})",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrent && isPlaying) ...[
              const Icon(Icons.equalizer_rounded, color: CinematicColors.electricViolet, size: 20),
              const SizedBox(width: 8),
            ],
            Icon(
              isLinked ? Icons.play_circle_fill_rounded : Icons.link_rounded,
              color: isLinked ? CinematicColors.electricViolet : Colors.white38,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTileArtwork(SongModel? song, CuratedSongEntry entry) {
    if (song?.artworkPath != null) {
      final file = File(song!.artworkPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CinematicColors.electricViolet.withOpacity(0.7),
            CinematicColors.hotPink.withOpacity(0.5),
          ],
        ),
      ),
      child: Center(
        child: Text(
          entry.title.substring(0, 1),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
