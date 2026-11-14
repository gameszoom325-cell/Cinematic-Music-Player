import 'dart:async';
import 'package:flutter/foundation.dart';
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

  bool get isInitialized => _initialized && _handler != null;
  CinematicAudioHandler? get handler => _handler;

  Future<void> init() async {
    if (_initialized && _handler != null) return;
    try {
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
    } catch (e) {
      debugPrint("AudioEngine.init notice (running in safe fallback mode): $e");
      _initialized = false;
    }
  }

  // --- Playback Controls ---
  Future<void> play() async {
    try {
      await _handler?.play();
    } catch (e) {
      debugPrint("AudioEngine.play error: $e");
    }
  }

  Future<void> pause() async {
    try {
      await _handler?.pause();
    } catch (e) {
      debugPrint("AudioEngine.pause error: $e");
    }
  }

  Future<void> togglePlayPause() async {
    if (_handler == null) return;
    try {
      if (_handler!.player.playing) {
        await pause();
      } else {
        await play();
      }
    } catch (e) {
      debugPrint("AudioEngine.togglePlayPause error: $e");
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _handler?.seek(position);
    } catch (e) {
      debugPrint("AudioEngine.seek error: $e");
    }
  }

  Future<void> skipToNext() async {
    try {
      await _handler?.skipToNext();
    } catch (e) {
      debugPrint("AudioEngine.skipToNext error: $e");
    }
  }

  Future<void> skipToPrevious() async {
    try {
      await _handler?.skipToPrevious();
    } catch (e) {
      debugPrint("AudioEngine.skipToPrevious error: $e");
    }
  }

  Future<void> playTrack(List<SongModel> queue, int index) async {
    if (_handler == null) return;
    try {
      await _handler!.setQueue(queue, initialIndex: index);
      await _handler!.play();
    } catch (e) {
      debugPrint("AudioEngine.playTrack error: $e");
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _handler?.player.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> setSpeed(double speed) async {
    try {
      await _handler?.player.setSpeed(speed.clamp(0.5, 2.5));
    } catch (_) {}
  }

  // --- Shuffle & Repeat ---
  bool get isShuffleEnabled => _handler?.player.shuffleModeEnabled ?? false;

  Future<void> toggleShuffle() async {
    if (_handler == null) return;
    try {
      final next = !_handler!.player.shuffleModeEnabled;
      await _handler!.player.setShuffleModeEnabled(next);
    } catch (_) {}
  }

  LoopMode get loopMode => _handler?.player.loopMode ?? LoopMode.off;

  Future<void> cycleRepeatMode() async {
    if (_handler == null) return;
    try {
      switch (_handler!.player.loopMode) {
        case LoopMode.off:
          await _handler!.player.setLoopMode(LoopMode.all);
          break;
        case LoopMode.all:
          await _handler!.player.setLoopMode(LoopMode.one);
          break;
        case LoopMode.one:
          await _handler!.player.setLoopMode(LoopMode.off);
          break;
      }
    } catch (_) {}
  }

  // --- Safe Reactive Streams ---
  Stream<bool> get isPlayingStream => _handler?.player.playingStream ?? const Stream.empty();
  Stream<Duration> get positionStream => _handler?.player.positionStream ?? const Stream.empty();
  Stream<Duration?> get durationStream => _handler?.player.durationStream ?? const Stream.empty();
  Stream<Duration> get bufferedPositionStream => _handler?.player.bufferedPositionStream ?? const Stream.empty();
  Stream<int?> get currentIndexStream => _handler?.player.currentIndexStream ?? const Stream.empty();
}
