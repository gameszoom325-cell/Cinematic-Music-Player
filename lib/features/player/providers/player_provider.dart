import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio_engine/audio_engine.dart';
import '../../../core/audio_engine/waveform_analyzer.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/models/song_model.dart';
import '../models/player_state.dart';
import '../../visualizer/providers/visualizer_provider.dart';
import '../../../sync/sync_manager.dart';

class PlayerNotifier extends StateNotifier<CinematicPlayerState> {
  final Ref _ref;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _indexSub;

  PlayerNotifier(this._ref) : super(const CinematicPlayerState()) {
    _bindEngineStreams();
  }

  void _bindEngineStreams() {
    final engine = AudioEngine.instance;

    _playingSub = engine.isPlayingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
      _ref.read(fftEngineProvider).updatePlaybackState(playing);
    });

    _posSub = engine.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _durSub = engine.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });

    _indexSub = engine.currentIndexStream.listen((index) async {
      if (index != null && index >= 0 && index < state.queue.length) {
        final song = state.queue[index];
        state = state.copyWith(
          currentIndex: index,
          currentSong: song,
        );

        // Update dynamic album palette smoothly
        _ref.read(dynamicPaletteProvider.notifier).updateForSong(song);

        // Fetch / Pre-Analyze Waveform for scrub timeline
        final waveform = await WaveformAnalyzer.analyzeSong(song.id, song.path);
        state = state.copyWith(currentWaveform: waveform);

        // Record play count & history in local database
        DatabaseService.instance.recordPlay(song.id);
      }
    });
  }

  Future<void> playTrack(List<SongModel> queue, int index) async {
    state = state.copyWith(queue: queue, currentIndex: index);
    await AudioEngine.instance.playTrack(queue, index);
  }

  Future<void> togglePlayPause() async {
    await AudioEngine.instance.togglePlayPause();
  }

  Future<void> seek(Duration position) async {
    await AudioEngine.instance.seek(position);
  }

  Future<void> skipToNext() async {
    await AudioEngine.instance.skipToNext();
  }

  Future<void> skipToPrevious() async {
    await AudioEngine.instance.skipToPrevious();
  }

  Future<void> toggleShuffle() async {
    await AudioEngine.instance.toggleShuffle();
    state = state.copyWith(isShuffle: AudioEngine.instance.isShuffleEnabled);
  }

  Future<void> cycleRepeatMode() async {
    await AudioEngine.instance.cycleRepeatMode();
    final mode = AudioEngine.instance.loopMode.index;
    state = state.copyWith(repeatMode: mode);
  }

  Future<void> toggleFavorite() async {
    if (state.currentSong == null) return;
    final songId = state.currentSong!.id;
    await DatabaseService.instance.toggleFavorite(songId);

    final updated = DatabaseService.instance.getSongById(songId);
    if (updated != null) {
      state = state.copyWith(currentSong: updated);
      SyncManager.instance.syncAll();
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();
    _indexSub?.cancel();
    super.dispose();
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, CinematicPlayerState>((ref) {
  return PlayerNotifier(ref);
});
