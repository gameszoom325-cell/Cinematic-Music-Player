import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import '../../../visualizer/providers/visualizer_provider.dart';
import '../../../../core/theme/cinematic_colors.dart';
import '../../../../core/database/models/song_model.dart';

/// Desktop & Mobile sliding Queue Panel.
/// Supports drag-to-reorder, track deletion, queue clearing, and tap-to-skip.
class QueuePanel extends ConsumerWidget {
  final VoidCallback? onClose;

  const QueuePanel({super.key, this.onClose});

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final palette = ref.watch(dynamicPaletteProvider);

    final queue = playerState.queue;
    final currentIndex = playerState.currentIndex;
    final currentSong = playerState.currentSong;

    final upcoming = (currentIndex >= 0 && currentIndex < queue.length - 1)
        ? queue.sublist(currentIndex + 1)
        : <SongModel>[];

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF121216),
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.queue_music_rounded, color: CinematicColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "Play Queue",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${queue.length}",
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (queue.isNotEmpty)
                      TextButton(
                        onPressed: () => playerNotifier.clearQueue(),
                        child: Text(
                          "Clear",
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                      ),
                    if (onClose != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        onPressed: onClose,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_off_rounded, color: Colors.white.withOpacity(0.2), size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            "Queue is empty",
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Play a song or add tracks from your library to start your listening session.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Now Playing Section
                      if (currentSong != null) ...[
                        const Text(
                          "NOW PLAYING",
                          style: TextStyle(
                            color: CinematicColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: palette.vibrant.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.vibrant.withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: _buildThumb(currentSong, palette.vibrant),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentSong.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currentSong.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                playerState.isPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                                color: palette.vibrant,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Next in Queue
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "NEXT IN QUEUE",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            "${upcoming.length} tracks",
                            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (upcoming.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              "No upcoming tracks. Add tracks to queue from your library.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
                            ),
                          ),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: upcoming.length,
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) {
                            final actualOld = currentIndex + 1 + oldIndex;
                            final actualNew = currentIndex + 1 + newIndex;
                            playerNotifier.reorderQueue(actualOld, actualNew);
                          },
                          itemBuilder: (context, idx) {
                            final song = upcoming[idx];
                            final actualIndex = currentIndex + 1 + idx;

                            return Container(
                              key: ValueKey("queue_${song.id}_$actualIndex"),
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: idx,
                                    child: Icon(Icons.drag_indicator_rounded, color: Colors.white.withOpacity(0.3), size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: _buildThumb(song, CinematicColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          song.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(song.durationMs),
                                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    color: Colors.white38,
                                    splashRadius: 16,
                                    onPressed: () => playerNotifier.removeFromQueue(actualIndex),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumb(SongModel song, Color fallbackColor) {
    if (song.artworkPath != null && song.artworkPath!.isNotEmpty) {
      if (song.artworkPath!.startsWith('http://') || song.artworkPath!.startsWith('https://')) {
        return Image.network(
          song.artworkPath!,
          fit: BoxFit.cover,
          cacheWidth: 88,
          cacheHeight: 88,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _fallbackThumb(fallbackColor),
        );
      }
      final file = File(song.artworkPath!);
      if (file.existsSync() && file.lengthSync() > 0) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 88,
          cacheHeight: 88,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _fallbackThumb(fallbackColor),
        );
      }
    }
    return _fallbackThumb(fallbackColor);
  }

  Widget _fallbackThumb(Color color) {
    return Container(
      color: color.withOpacity(0.2),
      child: const Icon(Icons.music_note_rounded, size: 18, color: Colors.white54),
    );
  }
}
