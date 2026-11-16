import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import '../../../visualizer/providers/visualizer_provider.dart';
import '../../../../core/theme/cinematic_colors.dart';
import '../../../../core/database/models/song_model.dart';
import '../cinematic_player_screen.dart';

/// Full-featured Spotify-style persistent Now Playing Bar.
/// 
/// Left: Album art, Title, Artist, Heart (Like) button.
/// Center: Analog transport controls (Shuffle, Prev, Play/Pause, Next, Repeat)
///         and isolated lightweight draggable seek bar (does not rebuild parent).
/// Right: Volume slider with mute toggle, Queue button, Full-screen Cinema toggle.
class SpotifyNowPlayingBar extends ConsumerWidget {
  final VoidCallback? onToggleQueue;
  final bool isQueueOpen;

  const SpotifyNowPlayingBar({
    super.key,
    this.onToggleQueue,
    this.isQueueOpen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(playerProvider.select((s) => s.currentSong));
    if (currentSong == null) return const SizedBox.shrink();

    final palette = ref.watch(dynamicPaletteProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return RepaintBoundary(
      child: Container(
        height: isDesktop ? 88 : 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF141418),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: isDesktop
            ? _buildDesktopBar(context, ref, currentSong, palette.vibrant)
            : _buildMobileBar(context, ref, currentSong, palette.vibrant),
      ),
    );
  }

  Widget _buildDesktopBar(
    BuildContext context,
    WidgetRef ref,
    SongModel song,
    Color activeColor,
  ) {
    return Row(
      children: [
        // 1. Left Track Information Area (Fixed width ~260px)
        SizedBox(
          width: 260,
          child: _LeftTrackInfo(song: song, activeColor: activeColor),
        ),

        // 2. Center Transport Controls & High-Efficiency Seek Bar
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CenterControls(activeColor: activeColor),
              const SizedBox(height: 4),
              _IndependentSeekBar(activeColor: activeColor),
            ],
          ),
        ),

        // 3. Right Volume & Quick Action Deck (Fixed width ~260px)
        SizedBox(
          width: 260,
          child: _RightDeck(
            activeColor: activeColor,
            isQueueOpen: isQueueOpen,
            onToggleQueue: onToggleQueue,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBar(
    BuildContext context,
    WidgetRef ref,
    SongModel song,
    Color activeColor,
  ) {
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final isLoading = ref.watch(playerProvider.select((s) => s.isLoading));
    final playerNotifier = ref.read(playerProvider.notifier);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CinematicPlayerScreen()),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: _ThumbImage(path: song.artworkPath, fallbackColor: activeColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: song.isFavorite ? activeColor : Colors.white54,
                  size: 20,
                ),
                onPressed: () => playerNotifier.toggleFavorite(),
              ),
              if (isLoading)
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: CinematicColors.primary),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: () => playerNotifier.togglePlayPause(),
                ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 24),
                onPressed: () => playerNotifier.skipToNext(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _IndependentProgressBar(activeColor: activeColor),
        ],
      ),
    );
  }
}

// Left Track Info with Cover, Title, Artist, and Favorite
class _LeftTrackInfo extends ConsumerWidget {
  final SongModel song;
  final Color activeColor;

  const _LeftTrackInfo({required this.song, required this.activeColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerNotifier = ref.read(playerProvider.notifier);

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CinematicPlayerScreen()),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 52,
              child: _ThumbImage(path: song.artworkPath, fallbackColor: activeColor),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CinematicPlayerScreen()),
                  );
                },
                child: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "${song.artist} • ${song.album}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: song.isFavorite ? activeColor : Colors.white38,
            size: 20,
          ),
          splashRadius: 18,
          onPressed: () => playerNotifier.toggleFavorite(),
        ),
      ],
    );
  }
}

// Center Transport Controls
class _CenterControls extends ConsumerWidget {
  final Color activeColor;

  const _CenterControls({required this.activeColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final isLoading = ref.watch(playerProvider.select((s) => s.isLoading));
    final isShuffle = ref.watch(playerProvider.select((s) => s.isShuffle));
    final repeatMode = ref.watch(playerProvider.select((s) => s.repeatMode));
    final playerNotifier = ref.read(playerProvider.notifier);

    IconData repeatIcon = Icons.repeat_rounded;
    Color repeatColor = Colors.white54;
    if (repeatMode == 1) { // all
      repeatColor = activeColor;
    } else if (repeatMode == 2) { // one
      repeatIcon = Icons.repeat_one_rounded;
      repeatColor = activeColor;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            size: 18,
            color: isShuffle ? activeColor : Colors.white54,
          ),
          splashRadius: 18,
          tooltip: isShuffle ? "Shuffle On" : "Shuffle Off",
          onPressed: () => playerNotifier.toggleShuffle(),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 24, color: Colors.white),
          splashRadius: 20,
          tooltip: "Previous",
          onPressed: () => playerNotifier.skipToPrevious(),
        ),
        const SizedBox(width: 6),
        if (isLoading)
          const SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: CinematicColors.primary),
              ),
            ),
          )
        else
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black87,
                size: 24,
              ),
              onPressed: () => playerNotifier.togglePlayPause(),
            ),
          ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 24, color: Colors.white),
          splashRadius: 20,
          tooltip: "Next",
          onPressed: () => playerNotifier.skipToNext(),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(repeatIcon, size: 18, color: repeatColor),
          splashRadius: 18,
          tooltip: repeatMode == 2 ? "Repeat One" : (repeatMode == 1 ? "Repeat All" : "Repeat Off"),
          onPressed: () => playerNotifier.cycleRepeatMode(),
        ),
      ],
    );
  }
}

// Independent Draggable Seek Bar (Only listens to position & duration)
class _IndependentSeekBar extends ConsumerStatefulWidget {
  final Color activeColor;

  const _IndependentSeekBar({required this.activeColor});

  @override
  ConsumerState<_IndependentSeekBar> createState() => _IndependentSeekBarState();
}

class _IndependentSeekBarState extends ConsumerState<_IndependentSeekBar> {
  double? _dragValue;

  String _format(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final playerNotifier = ref.read(playerProvider.notifier);

    final totalMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
    final posMs = _dragValue != null
        ? (_dragValue! * totalMs).round()
        : position.inMilliseconds;
    final progress = (posMs / totalMs).clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 42,
          child: Text(
            _format(Duration(milliseconds: posMs)),
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 380,
          height: 18,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: widget.activeColor,
              inactiveTrackColor: Colors.white.withOpacity(0.12),
              thumbColor: Colors.white,
              overlayColor: widget.activeColor.withOpacity(0.2),
            ),
            child: Slider(
              value: progress,
              onChanged: (val) {
                setState(() => _dragValue = val);
              },
              onChangeEnd: (val) {
                final target = Duration(milliseconds: (val * totalMs).round());
                playerNotifier.seek(target);
                setState(() => _dragValue = null);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text(
            _format(duration),
            textAlign: TextAlign.left,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// Independent Mobile Progress Line
class _IndependentProgressBar extends ConsumerWidget {
  final Color activeColor;

  const _IndependentProgressBar({required this.activeColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));

    final totalMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
    final progress = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 2.5,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withOpacity(0.08),
          valueColor: AlwaysStoppedAnimation<Color>(activeColor),
        ),
      ),
    );
  }
}

// Right Action Deck: Volume, Queue, Full-screen
class _RightDeck extends ConsumerWidget {
  final Color activeColor;
  final bool isQueueOpen;
  final VoidCallback? onToggleQueue;

  const _RightDeck({
    required this.activeColor,
    required this.isQueueOpen,
    this.onToggleQueue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerProvider.select((s) => s.volume));
    final playerNotifier = ref.read(playerProvider.notifier);

    IconData volIcon = Icons.volume_up_rounded;
    if (volume <= 0.0) {
      volIcon = Icons.volume_off_rounded;
    } else if (volume < 0.5) {
      volIcon = Icons.volume_down_rounded;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(
            Icons.queue_music_rounded,
            size: 20,
            color: isQueueOpen ? activeColor : Colors.white60,
          ),
          splashRadius: 18,
          tooltip: "Queue",
          onPressed: onToggleQueue,
        ),
        IconButton(
          icon: const Icon(Icons.fullscreen_rounded, size: 22, color: Colors.white60),
          splashRadius: 18,
          tooltip: "Full Cinema View",
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CinematicPlayerScreen()),
            );
          },
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(volIcon, size: 20, color: Colors.white60),
          splashRadius: 18,
          tooltip: volume > 0 ? "Mute" : "Unmute",
          onPressed: () => playerNotifier.toggleMute(),
        ),
        SizedBox(
          width: 90,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: Colors.white70,
              inactiveTrackColor: Colors.white.withOpacity(0.12),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              onChanged: (val) => playerNotifier.setVolume(val),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThumbImage extends StatelessWidget {
  final String? path;
  final Color fallbackColor;

  const _ThumbImage({this.path, required this.fallbackColor});

  @override
  Widget build(BuildContext context) {
    if (path != null && path!.isNotEmpty) {
      if (path!.startsWith('http://') || path!.startsWith('https://')) {
        return Image.network(
          path!,
          fit: BoxFit.cover,
          cacheWidth: 104,
          cacheHeight: 104,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      }
      final file = File(path!);
      if (file.existsSync() && file.lengthSync() > 0) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 104,
          cacheHeight: 104,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      }
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: fallbackColor.withOpacity(0.2),
      child: const Icon(Icons.music_note_rounded, size: 24, color: Colors.white54),
    );
  }
}
