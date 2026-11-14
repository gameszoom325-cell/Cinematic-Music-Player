import '../../../core/database/models/song_model.dart';
import '../../../core/database/models/waveform_cache_model.dart';

class CinematicPlayerState {
  final SongModel? currentSong;
  final List<SongModel> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final bool isShuffle;
  final int repeatMode; // 0 = off, 1 = one, 2 = all
  final double volume;
  final double speed;
  final WaveformCacheModel? currentWaveform;

  const CinematicPlayerState({
    this.currentSong,
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.isShuffle = false,
    this.repeatMode = 0,
    this.volume = 1.0,
    this.speed = 1.0,
    this.currentWaveform,
  });

  CinematicPlayerState copyWith({
    SongModel? currentSong,
    List<SongModel>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    bool? isShuffle,
    int? repeatMode,
    double? volume,
    double? speed,
    WaveformCacheModel? currentWaveform,
  }) {
    return CinematicPlayerState(
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      currentWaveform: currentWaveform ?? this.currentWaveform,
    );
  }
}
