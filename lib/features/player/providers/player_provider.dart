import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
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
  StreamSubscription? _processingSub;

  PlayerNotifier(this._ref) : super(const CinematicPlayerState()) {
    _bindEngineStreams();
  }

  void _bindEngineStreams() {
    try {
      final engine = AudioEngine.instance;

      _playingSub = engine.isPlayingStream.listen(
        (playing) {
          state = state.copyWith(isPlaying: playing);
          try {
            _ref.read(fftEngineProvider).updatePlaybackState(playing);
          } catch (_) {}
        },
        onError: (e) => debugPrint("isPlayingStream error: $e"),
      );

      _processingSub = engine.processingStateStream.listen(
        (processing) {
          final isLoading = processing == ProcessingState.loading ||
              processing == ProcessingState.buffering;
          state = state.copyWith(isLoading: isLoading);
        },
        onError: (e) => debugPrint("processingStateStream error: $e"),
      );

      _posSub = engine.positionStream.listen(
        (pos) {
          state = state.copyWith(position: pos);
        },
        onError: (e) => debugPrint("positionStream error: $e"),
      );

      _durSub = engine.durationStream.listen(
        (dur) {
          if (dur != null) {
            state = state.copyWith(duration: dur);
          }
        },
        onError: (e) => debugPrint("durationStream error: $e"),
      );

      _indexSub = engine.currentIndexStream.listen(
        (index) async {
          try {
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
          } catch (e) {
            debugPrint("Index stream handling error: $e");
          }
        },
        onError: (e) => debugPrint("currentIndexStream error: $e"),
      );
    } catch (e) {
      debugPrint("PlayerNotifier._bindEngineStreams error: $e");
    }
  }

  Future<bool> playTrack(List<SongModel> queue, int index) async {
    if (queue.isEmpty || index < 0 || index >= queue.length) {
      state = state.copyWith(errorMessage: "No playable track selected.", isLoading: false);
      return false;
    }

    final targetSong = queue[index];
    if (!targetSong.isLocalFileAvailable) {
      const msg = "Audio file unavailable. Please import this song again.";
      debugPrint("Blocked playTrack: '${targetSong.title}' file does not exist at '${targetSong.path}'");
      state = state.copyWith(errorMessage: msg, isPlaying: false, isLoading: false);
      return false;
    }

    // Filter queue to verified local audio files
    final validQueue = queue.where((s) => s.isLocalFileAvailable).toList();
    final validIndex = validQueue.indexWhere((s) => s.id == targetSong.id);

    try {
      state = state.copyWith(
        queue: validQueue,
        currentIndex: validIndex >= 0 ? validIndex : 0,
        currentSong: targetSong,
        isLoading: true,
        clearError: true,
      );
      final success = await AudioEngine.instance.playTrack(validQueue, validIndex >= 0 ? validIndex : 0);
      if (!success) {
        state = state.copyWith(
          errorMessage: "Unable to start playback for '${targetSong.title}'. Please verify the audio file.",
          isPlaying: false,
          isLoading: false,
        );
        return false;
      }
      return true;
    } catch (e, stack) {
      final msg = "Unable to start playback for '${targetSong.title}'.";
      debugPrint("Playback error for '${targetSong.title}': $e\n$stack");
      state = state.copyWith(errorMessage: msg, isPlaying: false, isLoading: false);
      return false;
    }
  }

  Future<void> togglePlayPause() async {
    try {
      if (state.currentSong == null) {
        final playable = DatabaseService.instance.getPlayableSongs();
        if (playable.isNotEmpty) {
          await playTrack(playable, 0);
          return;
        } else {
          state = state.copyWith(errorMessage: "Your music library is empty. Please import audio files first.");
          return;
        }
      }

      if (!state.currentSong!.isLocalFileAvailable) {
        state = state.copyWith(
          errorMessage: "Audio file unavailable. Please import this song again.",
          isPlaying: false,
        );
        return;
      }

      await AudioEngine.instance.togglePlayPause();
    } catch (e, stack) {
      final msg = "Playback toggle error: $e";
      debugPrint("CRITICAL PLAYBACK TOGGLE ERROR: $msg\n$stack");
      state = state.copyWith(errorMessage: msg);
    }
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

  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: v);
    await AudioEngine.instance.setVolume(v);
  }

  double _previousVolume = 1.0;
  Future<void> toggleMute() async {
    if (state.volume > 0.0) {
      _previousVolume = state.volume;
      await setVolume(0.0);
    } else {
      await setVolume(_previousVolume > 0.0 ? _previousVolume : 1.0);
    }
  }

  void setAmbientLevel(double level) {
    state = state.copyWith(ambientLevel: level.clamp(0.0, 1.0));
  }

  void toggleRainMode() {
    final next = !state.rainModeActive;
    state = state.copyWith(
      rainModeActive: next,
      ambientLevel: next ? (state.ambientLevel > 0 ? state.ambientLevel : 0.35) : 0.0,
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();
    _indexSub?.cancel();
    _processingSub?.cancel();
    super.dispose();
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, CinematicPlayerState>((ref) {
  return PlayerNotifier(ref);
});
