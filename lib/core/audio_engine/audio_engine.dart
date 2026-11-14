import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../database/models/song_model.dart';
import 'audio_service_handler.dart';

enum PlaybackRepeatMode { off, one, all }

class AudioEngine {
  static AudioEngine? _instance;
  static AudioEngine get instance => _instance ??= AudioEngine._();
  AudioEngine._();

  CinematicAudioHandler? _handler;
  bool _initialized = false;

  CinematicAudioHandler get handler {
    if (!_initialized || _handler == null) {
      throw StateError("AudioEngine not initialized. Call init() first.");
    }
    return _handler!;
  }

  Future<void> init() async {
    if (_initialized) return;
    _handler = await AudioService.init(
      builder: () => CinematicAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.cinematic.music.player.channel.audio',
        androidNotificationChannelName: 'Cinematic Music Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
    _initialized = true;
  }

  // --- Playback Controls ---
  Future<void> play() => handler.play();
  Future<void> pause() => handler.pause();
  Future<void> togglePlayPause() async {
    if (handler.player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) => handler.seek(position);
  Future<void> skipToNext() => handler.skipToNext();
  Future<void> skipToPrevious() => handler.skipToPrevious();

  Future<void> playTrack(List<SongModel> queue, int index) async {
    await handler.setQueue(queue, initialIndex: index);
    await handler.play();
  }

  Future<void> setVolume(double volume) => handler.player.setVolume(volume.clamp(0.0, 1.0));
  Future<void> setSpeed(double speed) => handler.player.setSpeed(speed.clamp(0.5, 2.5));

  // --- Shuffle & Repeat ---
  bool get isShuffleEnabled => handler.player.shuffleModeEnabled;
  Future<void> toggleShuffle() async {
    final next = !handler.player.shuffleModeEnabled;
    await handler.player.setShuffleModeEnabled(next);
  }

  LoopMode get loopMode => handler.player.loopMode;
  Future<void> cycleRepeatMode() async {
    switch (handler.player.loopMode) {
      case LoopMode.off:
        await handler.player.setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        await handler.player.setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        await handler.player.setLoopMode(LoopMode.off);
        break;
    }
  }

  // --- Reactive Streams ---
  Stream<bool> get isPlayingStream => handler.player.playingStream;
  Stream<Duration> get positionStream => handler.player.positionStream;
  Stream<Duration?> get durationStream => handler.player.durationStream;
  Stream<Duration> get bufferedPositionStream => handler.player.bufferedPositionStream;
  Stream<int?> get currentIndexStream => handler.player.currentIndexStream;
}
