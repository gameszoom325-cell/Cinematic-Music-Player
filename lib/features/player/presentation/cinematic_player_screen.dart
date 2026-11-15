import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../../visualizer/providers/visualizer_provider.dart';
import '../../visualizer/models/visualizer_preset.dart';
import '../../visualizer/presentation/visualizer_viewport.dart';
import '../../../core/audio_engine/audio_reactive_analyzer.dart';
import 'widgets/acoustic_art_ring.dart';
import 'widgets/tilt_album_art.dart';
import 'widgets/waveform_scrubber.dart';
import 'widgets/tactile_control_island.dart';
import '../../lyrics/presentation/lyrics_view.dart';
import '../../../core/services/lyrics_parser.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/database/models/song_model.dart';

enum PlayerSideTab { lyrics, queue }

class CinematicPlayerScreen extends ConsumerStatefulWidget {
  const CinematicPlayerScreen({super.key});

  @override
  ConsumerState<CinematicPlayerScreen> createState() => _CinematicPlayerScreenState();
}

class _CinematicPlayerScreenState extends ConsumerState<CinematicPlayerScreen> {
  PlayerSideTab _activeTab = PlayerSideTab.lyrics;
  final ScrollController _lyricsScrollCtrl = ScrollController();
  final ScrollController _queueScrollCtrl = ScrollController();
  SyncedLyrics _syncedLyrics = SyncedLyrics.empty;
  String? _loadedSongId;
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void dispose() {
    _lyricsScrollCtrl.dispose();
    _queueScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    final song = ref.read(playerProvider).currentSong;
    if (song == null) return;
    _loadedSongId = song.id;

    SyncedLyrics? lyrics;
    if (song.lrcPath != null) {
      final file = File(song.lrcPath!);
      if (await file.exists()) {
        lyrics = await LyricsParser.parseLrcFile(file);
      }
    }
    if (lyrics == null || lyrics.isEmpty) {
      lyrics = await LyricsParser.findAndParseLrc(song.path);
    }
    if ((lyrics == null || lyrics.isEmpty) && song.lyrics != null && song.lyrics!.isNotEmpty) {
      lyrics = LyricsParser.parseLrcString(song.lyrics!);
    }

    if (mounted) {
      setState(() {
        _syncedLyrics = lyrics ?? SyncedLyrics.empty;
      });
    }
  }

  void _scrollToActiveLyric(int index) {
    if (!_lyricsScrollCtrl.hasClients || index < 0) return;
    const double itemHeight = 68.0;
    final double target = (index * itemHeight) - 140.0;
    _lyricsScrollCtrl.animateTo(
      target.clamp(0.0, _lyricsScrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final palette = ref.watch(dynamicPaletteProvider);
    final visualizerState = ref.watch(visualizerProvider);
    final visualizerNotifier = ref.read(visualizerProvider.notifier);
    final reactiveFrame = ref.watch(audioReactiveFrameProvider).value ?? AudioReactiveFrame.empty;
    final currentSong = playerState.currentSong;

    if (currentSong != null && currentSong.id != _loadedSongId) {
      _loadLyrics();
    }

    final activeLyricIndex = _syncedLyrics.isNotEmpty
        ? _syncedLyrics.getActiveIndex(playerState.position)
        : -1;

    if (activeLyricIndex != _lastActiveIndex && activeLyricIndex >= 0) {
      _lastActiveIndex = activeLyricIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLyric(activeLyricIndex);
      });
    }

    final totalMs = playerState.duration.inMilliseconds;
    final posMs = playerState.position.inMilliseconds;
    final progress = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: CinematicColors.background,
      body: Stack(
        children: [
          // 1. Real-time Minimal Horizontal Waveform Line Visualizer
          const Positioned.fill(
            child: VisualizerViewport(),
          ),

          // 2. Diffused Warm Amber Acoustic Bloom Overlay
          Positioned(
            top: 60,
            left: 80,
            child: IgnorePointer(
              child: Container(
                width: 480,
                height: 480,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.vibrant.withOpacity(0.06),
                ),
              ),
            ),
          ),

          // 3. Foreground Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;

                return Column(
                  children: [
                    // Top Session Header
                    _buildTopHeader(context, currentSong, palette, visualizerState, visualizerNotifier, playerState, playerNotifier),

                    // Main Content Split (Wide 2-column or Narrow scrollable)
                    Expanded(
                      child: isWide
                          ? _buildWideStage(context, currentSong, playerState, playerNotifier, palette, progress, activeLyricIndex, reactiveFrame: reactiveFrame)
                          : _buildNarrowStage(context, currentSong, playerState, playerNotifier, palette, progress, activeLyricIndex, reactiveFrame: reactiveFrame),
                    ),

                    // Bottom Centerpiece Tactile Control Island
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: TactileControlIsland(
                        isPlaying: playerState.isPlaying,
                        isLoading: playerState.isLoading,
                        isShuffle: playerState.isShuffle,
                        repeatMode: playerState.repeatMode,
                        volume: playerState.volume,
                        ambientLevel: playerState.ambientLevel,
                        activeColor: palette.vibrant,
                        onPlayPause: () => playerNotifier.togglePlayPause(),
                        onNext: () => playerNotifier.skipToNext(),
                        onPrevious: () => playerNotifier.skipToPrevious(),
                        onToggleShuffle: () => playerNotifier.toggleShuffle(),
                        onCycleRepeat: () => playerNotifier.cycleRepeatMode(),
                        onVolumeChanged: (vol) => playerNotifier.setVolume(vol),
                        onAmbientChanged: (amb) => playerNotifier.setAmbientLevel(amb),
                        onToggleMute: () => playerNotifier.toggleMute(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(
    BuildContext context,
    SongModel? song,
    dynamic palette,
    VisualizerState visualizerState,
    VisualizerNotifier visualizerNotifier,
    dynamic playerState,
    PlayerNotifier playerNotifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: Colors.white),
              ),
            ),
          ),

          // Listening Chamber Session Badge
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: CinematicColors.surfaceContainerLow.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.vibrant.withOpacity(0.3)),
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
                        BoxShadow(color: palette.vibrant, blurRadius: 6, spreadRadius: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      (song != null && song.technicalSpecs.trim().isNotEmpty)
                          ? "Listening Chamber • ${song.technicalSpecs}"
                          : "Listening Chamber • Studio Master",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinematicTypography.technicalBadge.copyWith(
                        color: palette.lightVibrant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right Action Pills: Rain Mode & Preset Switcher
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rain Mode Capsule
              GestureDetector(
                onTap: () => playerNotifier.toggleRainMode(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: playerState.rainModeActive
                        ? CinematicColors.primary.withOpacity(0.2)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: playerState.rainModeActive
                          ? CinematicColors.primary.withOpacity(0.6)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.water_drop_rounded,
                        size: 14,
                        color: playerState.rainModeActive ? CinematicColors.primary : Colors.white60,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Rain Mode",
                        style: TextStyle(
                          color: playerState.rainModeActive ? CinematicColors.primary : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Visualizer Preset Switcher
              _buildPresetSelector(context, visualizerState, visualizerNotifier),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWideStage(
    BuildContext context,
    SongModel? song,
    dynamic playerState,
    PlayerNotifier playerNotifier,
    dynamic palette,
    double progress,
    int activeLyricIndex, {
    AudioReactiveFrame reactiveFrame = AudioReactiveFrame.empty,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column (58%): Album Art, Perimeter Ring, Title, Tactile Scrubber
          Expanded(
            flex: 7,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Album Art with Acoustic Perimeter Ring
                    Center(
                      child: AcousticArtRing(
                        size: 320,
                        progress: progress,
                        bassEnergy: playerState.isPlaying ? reactiveFrame.bass : 0.0,
                        midEnergy: playerState.isPlaying ? reactiveFrame.vocals : 0.0,
                        activeColor: palette.vibrant,
                        child: TiltAlbumArtwork(
                          song: song,
                          size: 260,
                          borderRadius: 20,
                          glowColor: palette.vibrant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Badges row
                    Row(
                      children: [
                        _buildFormatBadge(song?.format.toUpperCase() ?? "AUDIO", palette.vibrant),
                        const SizedBox(width: 8),
                        if (song != null && song.technicalSpecs.isNotEmpty)
                          _buildFormatBadge(song.technicalSpecs, Colors.white60),
                        const Spacer(),
                        // Favorite Star/Heart
                        IconButton(
                          icon: Icon(
                            (song?.isFavorite ?? false)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: (song?.isFavorite ?? false)
                                ? palette.vibrant
                                : Colors.white54,
                            size: 24,
                          ),
                          onPressed: () => playerNotifier.toggleFavorite(),
                          tooltip: "Favorite Track",
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Track Title & Artist
                    Text(
                      song?.title ?? "No Track Loaded",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinematicTypography.headlineLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${song?.artist ?? 'Select a track'} • ${song?.album ?? 'Vault'}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinematicTypography.bodyLarge.copyWith(
                        color: CinematicColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 52-bar Tactile Waveform Scrubber
                    WaveformScrubber(
                      position: playerState.position,
                      duration: playerState.duration,
                      waveform: playerState.currentWaveform,
                      activeGlowColor: palette.vibrant,
                      onSeek: (pos) => playerNotifier.seek(pos),
                    ),
                    const SizedBox(height: 8),

                    // Acoustic Master Info Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.graphic_eq_rounded, size: 14, color: palette.vibrant),
                            const SizedBox(width: 6),
                            const Text(
                              "Acoustic Warmth: 432Hz Master",
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        Text(
                          song?.bitrate != null && song!.bitrate > 0
                              ? "Bitrate: ${song.bitrate} kbps"
                              : "Lossless Direct Stream",
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right Column (42%): Dual Editorial Tabs (Synced Lyrics & Dynamic Queue)
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: CinematicColors.surfaceContainerLow.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  // Tab Selector Capsule
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: _buildTabCapsule(playerState.queue.length),
                  ),

                  // Tab View Content
                  Expanded(
                    child: _activeTab == PlayerSideTab.lyrics
                        ? _buildLyricsPanel(playerState, activeLyricIndex, palette.vibrant)
                        : _buildQueuePanel(playerState, playerNotifier, palette.vibrant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowStage(
    BuildContext context,
    SongModel? song,
    dynamic playerState,
    PlayerNotifier playerNotifier,
    dynamic palette,
    double progress,
    int activeLyricIndex, {
    AudioReactiveFrame reactiveFrame = AudioReactiveFrame.empty,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album Art with Acoustic Perimeter Ring
          Center(
            child: AcousticArtRing(
              size: 240,
              progress: progress,
              bassEnergy: playerState.isPlaying ? reactiveFrame.bass : 0.0,
              midEnergy: playerState.isPlaying ? reactiveFrame.vocals : 0.0,
              activeColor: palette.vibrant,
              child: TiltAlbumArtwork(
                song: song,
                size: 190,
                borderRadius: 18,
                glowColor: palette.vibrant,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Title & Artist & Favorite
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song?.title ?? "No Track Loaded",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinematicTypography.headlineLarge.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song?.artist ?? "Select a track",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinematicTypography.bodyLarge.copyWith(
                        fontSize: 13,
                        color: CinematicColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  (song?.isFavorite ?? false)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: (song?.isFavorite ?? false) ? palette.vibrant : Colors.white54,
                ),
                onPressed: () => playerNotifier.toggleFavorite(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 52-bar Tactile Scrubber
          WaveformScrubber(
            position: playerState.position,
            duration: playerState.duration,
            waveform: playerState.currentWaveform,
            activeGlowColor: palette.vibrant,
            onSeek: (pos) => playerNotifier.seek(pos),
          ),
          const SizedBox(height: 14),

          // Tab Selector Capsule & Content
          _buildTabCapsule(playerState.queue.length),
          const SizedBox(height: 10),

          SizedBox(
            height: 280,
            child: _activeTab == PlayerSideTab.lyrics
                ? _buildLyricsPanel(playerState, activeLyricIndex, palette.vibrant)
                : _buildQueuePanel(playerState, playerNotifier, palette.vibrant),
          ),
        ],
      ),
    );
  }

  Widget _buildTabCapsule(int queueCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CinematicColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = PlayerSideTab.lyrics),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == PlayerSideTab.lyrics
                      ? CinematicColors.surfaceContainerHigh
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lyrics_rounded,
                      size: 16,
                      color: _activeTab == PlayerSideTab.lyrics
                          ? CinematicColors.primary
                          : Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Synced Lyrics",
                      style: TextStyle(
                        color: _activeTab == PlayerSideTab.lyrics
                            ? CinematicColors.primary
                            : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = PlayerSideTab.queue),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == PlayerSideTab.queue
                      ? CinematicColors.surfaceContainerHigh
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.queue_music_rounded,
                      size: 16,
                      color: _activeTab == PlayerSideTab.queue
                          ? CinematicColors.primary
                          : Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Up Next ($queueCount)",
                      style: TextStyle(
                        color: _activeTab == PlayerSideTab.queue
                            ? CinematicColors.primary
                            : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsPanel(dynamic playerState, int activeIndex, Color accentColor) {
    if (_syncedLyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            const Text(
              "No Synchronized Lyrics",
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Place a companion .lrc file next to your audio file.",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _lyricsScrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _syncedLyrics.lines.length,
      itemBuilder: (context, index) {
        final line = _syncedLyrics.lines[index];
        final isActive = index == activeIndex;
        final isPast = index < activeIndex;

        return GestureDetector(
          onTap: () {
            ref.read(playerProvider.notifier).seek(line.timestamp);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isActive ? 12 : 8,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? CinematicColors.surfaceContainerHigh
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(color: accentColor.withOpacity(0.4), width: 1)
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timestamp indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? accentColor.withOpacity(0.2)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "[${_formatDuration(line.timestamp.inMilliseconds)}]",
                    style: TextStyle(
                      color: isActive ? accentColor : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Lyric Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isActive) ...[
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "ACTIVE NOW",
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        line.text,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : (isPast ? Colors.white38 : Colors.white60),
                          fontSize: isActive ? 16 : 14,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQueuePanel(dynamic playerState, PlayerNotifier playerNotifier, Color accentColor) {
    final List<SongModel> queue = playerState.queue;

    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            const Text(
              "Queue is Empty",
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _queueScrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final song = queue[index];
        final isCurrent = index == playerState.currentIndex;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => playerNotifier.playTrack(queue, index),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrent
                    ? CinematicColors.surfaceContainerHigh
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isCurrent
                    ? Border.all(color: accentColor.withOpacity(0.5), width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  // Track Art or Number
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: _buildQueueThumb(song, accentColor, isCurrent && playerState.isPlaying),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Track Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent ? accentColor : Colors.white,
                            fontSize: 13,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${song.artist} • ${_formatDuration(song.durationMs)}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "LIVE",
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQueueThumb(SongModel song, Color accentColor, bool isPlaying) {
    Widget base;
    if (song.artworkPath != null && song.artworkPath!.isNotEmpty) {
      if (song.artworkPath!.startsWith('http://') || song.artworkPath!.startsWith('https://')) {
        base = Image.network(
          song.artworkPath!,
          fit: BoxFit.cover,
          cacheWidth: 100,
          cacheHeight: 100,
          errorBuilder: (_, __, ___) => _fallbackThumb(accentColor),
        );
      } else {
        final file = File(song.artworkPath!);
        if (file.existsSync() && file.lengthSync() > 0) {
          base = Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: 100,
            cacheHeight: 100,
            errorBuilder: (_, __, ___) => _fallbackThumb(accentColor),
          );
        } else {
          base = _fallbackThumb(accentColor);
        }
      }
    } else {
      base = _fallbackThumb(accentColor);
    }

    if (isPlaying) {
      return Stack(
        fit: StackFit.expand,
        children: [
          base,
          Container(
            color: Colors.black.withOpacity(0.4),
            child: Icon(Icons.equalizer_rounded, size: 20, color: accentColor),
          ),
        ],
      );
    }
    return base;
  }

  Widget _fallbackThumb(Color accentColor) {
    return Container(
      color: CinematicColors.surfaceContainerHighest,
      child: const Icon(Icons.music_note_rounded, size: 20, color: Colors.white38),
    );
  }

  Widget _buildFormatBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CinematicColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPresetSelector(
    BuildContext context,
    VisualizerState state,
    VisualizerNotifier notifier,
  ) {
    return PopupMenuButton<VisualizerPresetType>(
      tooltip: "Visualizer Waveform Style",
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Icon(Icons.waves_rounded, size: 18, color: Colors.white),
      ),
      color: CinematicColors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      onSelected: (preset) => notifier.setPreset(preset),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: VisualizerPresetType.minimalLine,
          child: Text("Minimal Horizon Line", style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const PopupMenuItem(
          value: VisualizerPresetType.neonHorizon,
          child: Text("Neon Beam Waveform", style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const PopupMenuItem(
          value: VisualizerPresetType.pulseRibbon,
          child: Text("Cinematic Pulse Ribbon", style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
    );
  }
}
