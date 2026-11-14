import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/playlist_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/typography.dart';
import '../../../core/database/models/playlist_model.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key});

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CinematicColors.obsidianCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          title: const Text("New Playlist", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: textCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Playlist Title",
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                textCtrl.dispose();
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CinematicColors.electricViolet,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final name = textCtrl.text.trim();
                if (name.isNotEmpty) {
                  ref.read(playlistProvider.notifier).createPlaylist(name);
                }
                Navigator.pop(context);
                textCtrl.dispose();
              },
              child: const Text("Create", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);
    final playlistNotifier = ref.read(playlistProvider.notifier);
    final playerNotifier = ref.read(playerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Playlists", style: CinematicTypography.displayTitle),
                  GlassIconButton(
                    icon: Icons.add_rounded,
                    onPressed: () => _showCreateDialog(context, ref),
                    size: 44,
                    iconSize: 24,
                    tooltip: "Create Playlist",
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: playlists.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.queue_music_rounded,
                              size: 64,
                              color: Colors.white.withOpacity(0.25),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No playlists created yet",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Tap '+' to create your first custom playlist.",
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final pl = playlists[index];
                          return _PlaylistCard(
                            playlist: pl,
                            onTap: () {
                              final songs = playlistNotifier.getSongsForPlaylist(pl);
                              if (songs.isNotEmpty) {
                                playerNotifier.playTrack(songs, 0);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Playlist '${pl.name}' is empty"),
                                    backgroundColor: CinematicColors.obsidianCard,
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
}

class _PlaylistCard extends StatelessWidget {
  final PlaylistModel playlist;
  final VoidCallback onTap;

  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CinematicGlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Playlist Art Icon Box
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: playlist.id == 'favorites'
                        ? [CinematicColors.hotPink.withOpacity(0.8), CinematicColors.electricViolet]
                        : [CinematicColors.electricViolet.withOpacity(0.7), CinematicColors.neonCyan.withOpacity(0.5)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    playlist.id == 'favorites'
                        ? Icons.favorite_rounded
                        : (playlist.isSmartPlaylist ? Icons.history_rounded : Icons.queue_music_rounded),
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CinematicTypography.songTitleMedium.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              "${playlist.songIds.length} tracks",
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
