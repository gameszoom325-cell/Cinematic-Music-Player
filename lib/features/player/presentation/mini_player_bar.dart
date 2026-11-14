import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../../visualizer/providers/visualizer_provider.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/typography.dart';
import '../../../core/database/models/song_model.dart';
import 'cinematic_player_screen.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final palette = ref.watch(dynamicPaletteProvider);

    final currentSong = playerState.currentSong;
    if (currentSong == null) return const SizedBox.shrink();

    final totalMs = playerState.duration.inMilliseconds;
    final posMs = playerState.position.inMilliseconds;
    final progress = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, anim, secAnim) => const CinematicPlayerScreen(),
            transitionsBuilder: (context, anim, secAnim, child) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.15),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      child: CinematicGlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        borderRadius: 22,
        tintColor: palette.dominant,
        tintOpacity: 0.35,
        borderOpacity: 0.25,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Small Glowing Album Art Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: _buildThumb(currentSong, palette.vibrant),
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentSong.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CinematicTypography.songTitleMedium.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentSong.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CinematicTypography.artistSubtitle.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Controls
                GlassIconButton(
                  icon: (currentSong.isFavorite)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  onPressed: () => playerNotifier.toggleFavorite(),
                  size: 38,
                  iconSize: 18,
                  glowColor: CinematicColors.hotPink,
                  isSelected: currentSong.isFavorite,
                ),
                const SizedBox(width: 8),

                playerState.isLoading
                    ? const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      )
                    : GlassIconButton(
                        icon: playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        onPressed: () => playerNotifier.togglePlayPause(),
                        size: 44,
                        iconSize: 24,
                        glowColor: palette.vibrant,
                        isSelected: true,
                      ),
                const SizedBox(width: 6),

                GlassIconButton(
                  icon: Icons.skip_next_rounded,
                  onPressed: () => playerNotifier.skipToNext(),
                  size: 38,
                  iconSize: 20,
                  glowColor: palette.vibrant,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Continuous Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(palette.vibrant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb(SongModel song, Color fallbackColor) {
    if (song.artworkPath != null) {
      final file = File(song.artworkPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Container(
      color: fallbackColor.withOpacity(0.4),
      child: const Icon(Icons.music_note_rounded, size: 24, color: Colors.white),
    );
  }
}
