import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../../visualizer/providers/visualizer_provider.dart';
import '../../../core/theme/cinematic_colors.dart';
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
                    begin: const Offset(0.0, 0.12),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: CinematicColors.surfaceContainerLow.withOpacity(0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Small Glowing Album Art Thumbnail with cacheWidth/Height
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: _buildThumb(currentSong, palette.vibrant),
                  ),
                ),
                const SizedBox(width: 12),

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
                        style: CinematicTypography.songTitleMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CinematicColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${currentSong.artist} • ${currentSong.format.toUpperCase()}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CinematicTypography.artistSubtitle.copyWith(
                          fontSize: 11,
                          color: CinematicColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Favorite Button
                IconButton(
                  icon: Icon(
                    currentSong.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: currentSong.isFavorite ? palette.vibrant : Colors.white54,
                    size: 20,
                  ),
                  onPressed: () => playerNotifier.toggleFavorite(),
                ),

                // Play / Pause Button
                playerState.isLoading
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(CinematicColors.primary),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.vibrant,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            playerState.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black87,
                            size: 22,
                          ),
                          onPressed: () => playerNotifier.togglePlayPause(),
                        ),
                      ),
                const SizedBox(width: 4),

                // Next Button
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 22),
                  onPressed: () => playerNotifier.skipToNext(),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Continuous Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 2.5,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.08),
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
      if (file.existsSync() && file.lengthSync() > 0) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 120,
          cacheHeight: 120,
          errorBuilder: (context, error, stackTrace) => Container(
            color: fallbackColor.withOpacity(0.3),
            child: const Icon(Icons.music_note_rounded, size: 22, color: Colors.white70),
          ),
        );
      }
    }
    return Container(
      color: fallbackColor.withOpacity(0.3),
      child: const Icon(Icons.music_note_rounded, size: 22, color: Colors.white70),
    );
  }
}
