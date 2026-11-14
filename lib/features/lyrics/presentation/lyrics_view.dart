import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/lyrics_parser.dart';
import '../../player/providers/player_provider.dart';
import '../../visualizer/providers/visualizer_provider.dart';

class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  SyncedLyrics _syncedLyrics = SyncedLyrics.empty;
  String? _loadedSongId;
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;

  @override
  void initState() {
    super.initState();
    _loadLyricsForCurrentSong();
  }

  Future<void> _loadLyricsForCurrentSong() async {
    final song = ref.read(playerProvider).currentSong;
    if (song == null) return;
    _loadedSongId = song.id;

    // 1. Try companion .lrc file first
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

    // 2. Try embedded text if it contains timestamp tags
    if ((lyrics == null || lyrics.isEmpty) && song.lyrics != null && song.lyrics!.isNotEmpty) {
      lyrics = LyricsParser.parseLrcString(song.lyrics!);
    }

    if (mounted) {
      setState(() {
        _syncedLyrics = lyrics ?? SyncedLyrics.empty;
      });
    }
  }

  void _scrollToActiveIndex(int index) {
    if (_userIsScrolling || !_scrollController.hasClients || index < 0) return;

    // Estimate item height ~72dp; center in viewport
    const double itemHeight = 72.0;
    final double targetOffset = (index * itemHeight) - 180.0;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final palette = ref.watch(dynamicPaletteProvider);
    final song = playerState.currentSong;

    // Reload if song changed
    if (song != null && song.id != _loadedSongId) {
      _loadLyricsForCurrentSong();
    }

    final activeIndex = _syncedLyrics.isNotEmpty
        ? _syncedLyrics.getActiveIndex(playerState.position)
        : -1;

    if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveIndex(activeIndex);
      });
    }

    return Scaffold(
      backgroundColor: CinematicColors.obsidianBlack,
      body: Stack(
        children: [
          // Ambient Dynamic Album Backdrop Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.4),
                  radius: 1.4,
                  colors: [
                    palette.vibrant.withOpacity(0.35),
                    palette.dominant.withOpacity(0.2),
                    CinematicColors.obsidianBlack,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
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
                                _syncedLyrics.isNotEmpty
                                    ? "SYNCHRONIZED LYRICS"
                                    : "LYRICS VAULT",
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            song?.title ?? "No Track",
                            style: CinematicTypography.songTitleLarge.copyWith(fontSize: 20),
                          ),
                        ],
                      ),
                      GlassIconButton(
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.of(context).maybePop(),
                        size: 42,
                        iconSize: 22,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Lyrics Content
                Expanded(
                  child: _syncedLyrics.isNotEmpty
                      ? _buildSyncedLyricsList(activeIndex, palette, playerNotifier)
                      : _buildUnsyncedLyricsView(song, palette),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncedLyricsList(
    int activeIndex,
    dynamic palette,
    PlayerNotifier playerNotifier,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _userIsScrolling = true;
        } else if (notification is ScrollEndNotification) {
          // Resume auto-scroll tracking after 2.5 seconds of inactivity
          Future.delayed(const Duration(milliseconds: 2500), () {
            if (mounted) _userIsScrolling = false;
          });
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
        itemCount: _syncedLyrics.lines.length,
        itemBuilder: (context, index) {
          final line = _syncedLyrics.lines[index];
          final bool isActive = index == activeIndex;
          final bool isPast = index < activeIndex;

          final Color textColor = isActive
              ? Colors.white
              : (isPast
                  ? Colors.white.withOpacity(0.35)
                  : Colors.white.withOpacity(0.45));

          final double fontSize = isActive ? 26.0 : 20.0;
          final FontWeight fontWeight = isActive ? FontWeight.w800 : FontWeight.w600;

          return GestureDetector(
            onTap: () {
              // Interactive tap-to-seek: Seek audio directly to this lyric timestamp!
              playerNotifier.seek(line.timestamp);
              setState(() {
                _lastActiveIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isActive ? Colors.white.withOpacity(0.08) : Colors.transparent,
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 280),
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  height: 1.4,
                  shadows: isActive
                      ? [
                          Shadow(
                            color: (palette.vibrant as Color).withOpacity(0.8),
                            blurRadius: 24,
                          ),
                          Shadow(
                            color: Colors.white.withOpacity(0.4),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Text(line.text),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnsyncedLyricsView(dynamic song, dynamic palette) {
    final rawLyrics = song?.lyrics ??
        "No synchronized .lrc file found for this track.\n\nPlace a companion '${song?.title ?? "Song"}.lrc' file in the same folder as the audio track, and it will automatically sync and highlight word-by-word with the music.";

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Text(
        rawLyrics,
        style: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontSize: 18,
          height: 1.8,
          fontWeight: FontWeight.w500,
          shadows: [
            Shadow(
              color: (palette.vibrant as Color).withOpacity(0.4),
              blurRadius: 16,
            ),
          ],
        ),
      ),
    );
  }
}
