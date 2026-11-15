import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/models/song_model.dart';
import '../../player/providers/player_provider.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final favorites = db.getFavorites();
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final currentSong = playerState.currentSong;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "FAVORITES",
                        style: TextStyle(
                          color: CinematicColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${favorites.length} Tracks",
                        style: const TextStyle(
                          color: CinematicColors.onSurface,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  if (favorites.isNotEmpty)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shuffle_rounded, color: CinematicColors.primary),
                          tooltip: "Shuffle Favorites",
                          onPressed: () {
                            final shuffled = List<SongModel>.from(favorites)..shuffle();
                            playerNotifier.playTrack(shuffled, 0);
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CinematicColors.primary,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () {
                            playerNotifier.playTrack(favorites, 0);
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text(
                            "Play All",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Favorites List
              Expanded(
                child: favorites.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 64,
                              color: Colors.white.withOpacity(0.15),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No Favorites Saved Yet",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                "Tap the heart icon on any local or cloud track to add it to your synchronized favorites.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white38, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemExtent: 68.0,
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          final song = favorites[index];
                          final isPlayingThis = song.id == currentSong?.id && playerState.isPlaying;

                          return RepaintBoundary(
                            child: InkWell(
                              onTap: () {
                                playerNotifier.playTrack(favorites, index);
                              },
                              child: Container(
                                height: 68.0,
                                decoration: BoxDecoration(
                                  color: isPlayingThis
                                      ? CinematicColors.primary.withOpacity(0.08)
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.white.withOpacity(0.04),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Artwork
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildArtwork(song),
                                    ),
                                    const SizedBox(width: 14),

                                    // Song metadata
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isPlayingThis
                                                  ? CinematicColors.primary
                                                  : CinematicColors.onSurface,
                                              fontSize: 14,
                                              fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            "${song.artist} • ${song.album}",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Duration
                                    Text(
                                      _formatDuration(song.durationMs),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Unfavorite Button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.favorite_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        db.toggleFavorite(song.id);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
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

  Widget _buildArtwork(SongModel song) {
    if (song.artworkPath != null && song.artworkPath!.isNotEmpty) {
      if (song.artworkPath!.startsWith('http://') || song.artworkPath!.startsWith('https://')) {
        return Image.network(
          song.artworkPath!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          cacheWidth: 120,
          cacheHeight: 120,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
      final file = File(song.artworkPath!);
      if (file.existsSync() && file.lengthSync() > 0) {
        return Image.file(
          file,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          cacheWidth: 120,
          cacheHeight: 120,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      color: CinematicColors.surfaceContainerHigh,
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white38, size: 22),
      ),
    );
  }
}
