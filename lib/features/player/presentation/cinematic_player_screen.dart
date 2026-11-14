import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../../visualizer/providers/visualizer_provider.dart';
import '../../visualizer/models/visualizer_preset.dart';
import '../../visualizer/presentation/visualizer_viewport.dart';
import 'widgets/tilt_album_art.dart';
import 'widgets/waveform_scrubber.dart';
import 'widgets/player_controls.dart';
import '../../lyrics/presentation/lyrics_view.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/typography.dart';

class CinematicPlayerScreen extends ConsumerWidget {
  const CinematicPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final palette = ref.watch(dynamicPaletteProvider);
    final visualizerState = ref.watch(visualizerProvider);
    final visualizerNotifier = ref.read(visualizerProvider.notifier);

    final currentSong = playerState.currentSong;

    return Scaffold(
      backgroundColor: CinematicColors.obsidianBlack,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 680;
          final artSize = (constraints.maxHeight * (isCompact ? 0.28 : 0.35)).clamp(160.0, 300.0);
          final ringArtSize = (constraints.maxHeight * 0.25).clamp(130.0, 230.0);

          return Stack(
            children: [
              // 1. Cinematic Background Visualizer & Atmospheric Stage
              Positioned.fill(
                child: VisualizerViewport(
                  centerChild: visualizerState.preset == VisualizerPresetType.polarRing
                      ? TiltAlbumArtwork(
                          song: currentSong,
                          size: ringArtSize,
                          glowColor: palette.vibrant,
                        )
                      : null,
                ),
              ),

              // 2. Glassmorphic HUD & Player Deck
              SafeArea(
                child: Column(
                  children: [
                    // Top App Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GlassIconButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            onPressed: () => Navigator.of(context).maybePop(),
                            size: 42,
                            iconSize: 26,
                          ),

                          // Format & Hi-Res Audio Technical Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: palette.vibrant.withOpacity(0.4),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: palette.vibrant,
                                    boxShadow: [
                                      BoxShadow(
                                        color: palette.vibrant,
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  currentSong?.technicalSpecs ?? "STUDIO MASTER • 24-BIT",
                                  style: CinematicTypography.technicalBadge.copyWith(
                                    color: palette.lightVibrant,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Row(
                            children: [
                              GlassIconButton(
                                icon: Icons.lyrics_rounded,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      pageBuilder: (context, anim, secAnim) => const LyricsView(),
                                      transitionsBuilder: (context, anim, secAnim, child) {
                                        return FadeTransition(opacity: anim, child: child);
                                      },
                                    ),
                                  );
                                },
                                size: 42,
                                iconSize: 20,
                                tooltip: "Synchronized Lyrics",
                              ),
                              const SizedBox(width: 8),
                              // Visualizer Preset Switcher Menu
                              _buildPresetSelector(context, visualizerState, visualizerNotifier),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Center Stage: 3D Tilt Album Artwork (Only when not Polar Ring)
                    if (visualizerState.preset != VisualizerPresetType.polarRing) ...[
                      TiltAlbumArtwork(
                        song: currentSong,
                        size: artSize,
                        glowColor: palette.vibrant,
                      ),
                      SizedBox(height: isCompact ? 12 : 24),
                    ],

                    const Spacer(),

                    // Bottom Glassmorphic Control Deck
                    CinematicGlassCard(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  borderRadius: 28,
                  tintColor: palette.dominant,
                  tintOpacity: 0.25,
                  borderOpacity: 0.22,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Song Title, Artist & Star Favorite Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentSong?.title ?? "No Track Loaded",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CinematicTypography.songTitleLarge.copyWith(
                                    shadows: [
                                      Shadow(
                                        color: palette.vibrant.withOpacity(0.4),
                                        blurRadius: 16.0,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${currentSong?.artist ?? 'Select a track'} • ${currentSong?.album ?? ''}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CinematicTypography.artistSubtitle,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GlassIconButton(
                            icon: (currentSong?.isFavorite ?? false)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            onPressed: () => playerNotifier.toggleFavorite(),
                            size: 44,
                            iconSize: 22,
                            glowColor: CinematicColors.hotPink,
                            isSelected: currentSong?.isFavorite ?? false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Audio Waveform Scrubber
                      WaveformScrubber(
                        position: playerState.position,
                        duration: playerState.duration,
                        waveform: playerState.currentWaveform,
                        activeGlowColor: palette.vibrant,
                        onSeek: (pos) => playerNotifier.seek(pos),
                      ),
                      const SizedBox(height: 18),

                      // Player Controls (Play, Pause, Skip, Shuffle, Repeat)
                      PlayerControls(
                        isPlaying: playerState.isPlaying,
                        isShuffle: playerState.isShuffle,
                        repeatMode: playerState.repeatMode,
                        isFavorite: currentSong?.isFavorite ?? false,
                        activeGlow: palette.vibrant,
                        onPlayPause: () => playerNotifier.togglePlayPause(),
                        onNext: () => playerNotifier.skipToNext(),
                        onPrevious: () => playerNotifier.skipToPrevious(),
                        onToggleShuffle: () => playerNotifier.toggleShuffle(),
                        onCycleRepeat: () => playerNotifier.cycleRepeatMode(),
                        onToggleFavorite: () => playerNotifier.toggleFavorite(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

  Widget _buildPresetSelector(
    BuildContext context,
    VisualizerState state,
    VisualizerNotifier notifier,
  ) {
    return PopupMenuButton<VisualizerPresetType>(
      tooltip: "Visualizer Preset",
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.white),
      ),
      color: CinematicColors.obsidianCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      onSelected: (preset) => notifier.setPreset(preset),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: VisualizerPresetType.orb3d,
          child: Text("3D Liquid Raymarched Orb", style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: VisualizerPresetType.polarRing,
          child: Text("Polar Spectrum Ring", style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: VisualizerPresetType.auroraMesh,
          child: Text("Aurora Dynamic Mesh", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
