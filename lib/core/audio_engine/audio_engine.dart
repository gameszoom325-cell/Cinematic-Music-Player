import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../database/models/song_model.dart';
import 'audio_service_handler.dart';

enum PlaybackRepeatMode { off, one, all }

class AudioEngine {
  static final AudioEngine instance = AudioEngine._();

  final CinematicAudioHandler _handler;
  Completer<void>? _serviceInitCompleter;
  bool _audioServiceRegistered = false;
  AudioSession? _audioSession;

  AudioEngine._() : _handler = CinematicAudioHandler();

  bool get isInitialized => true;
  bool get isAudioServiceRegistered => _audioServiceRegistered;
  CinematicAudioHandler get handler => _handler;

  /// Initializes the background AudioService and links it to the active CinematicAudioHandler.
  /// If the system foreground service fails to register, the standalone handler remains 100% operational.
  Future<void> init() async {
    if (_serviceInitCompleter != null) {
      return _serviceInitCompleter!.future;
    }
    final completer = Completer<void>();
    _serviceInitCompleter = completer;

    // AudioSession & AudioService provide background media session & audio focus on Android/iOS.
    // On Windows desktop, just_audio directly handles audio output through WASAPI.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _audioSession = await AudioSession.instance;
        await _audioSession!.configure(const AudioSessionConfiguration.music());
        
        // Handle headphone unplug / Bluetooth disconnect automatically
        _audioSession!.becomingNoisyEventStream.listen((_) {
          debugPrint("AudioEngine: Becoming noisy event received - pausing playback");
          _handler.pause();
        });

        // Handle system audio interruptions (e.g. phone calls, alarms)
        _audioSession!.interruptionEventStream.listen((event) {
          if (event.begin) {
            switch (event.type) {
              case AudioInterruptionType.duck:
                _handler.player.setVolume(0.3);
                break;
              case AudioInterruptionType.pause:
              case AudioInterruptionType.unknown:
                _handler.pause();
                break;
            }
          } else {
            switch (event.type) {
              case AudioInterruptionType.duck:
                _handler.player.setVolume(1.0);
                break;
              case AudioInterruptionType.pause:
                _handler.play();
                break;
              case AudioInterruptionType.unknown:
                break;
            }
          }
        });

        await AudioService.init(
          builder: () => _handler,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.cinematic.music.player.channel.audio',
            androidNotificationChannelName: 'Cinematic Music Playback',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
            androidNotificationIcon: 'mipmap/ic_launcher',
            androidShowNotificationBadge: true,
          ),
        );
        _audioServiceRegistered = true;
        debugPrint("AudioEngine: AudioService & AudioSession registered successfully.");
      } catch (e, stack) {
        debugPrint("AudioEngine: AudioService platform registration notice (standalone handler active): $e\n$stack");
      }
    } else {
      _audioServiceRegistered = false;
      debugPrint("AudioEngine: Desktop mode active; using direct hardware audio pipeline.");
    }

    if (!completer.isCompleted) {
      completer.complete();
    }

    return _serviceInitCompleter!.future;
  }

  /// Ensures that service initialization has run before executing high-priority playback actions.
  Future<void> ensureInitialized() async {
    if (_serviceInitCompleter == null) {
      await init();
    } else if (!_serviceInitCompleter!.isCompleted) {
      try {
        await _serviceInitCompleter!.future.timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  // --- Playback Controls ---
  Future<void> play() async {
    await ensureInitialized();
    try {
      await _handler.play();
    } catch (e) {
      debugPrint("AudioEngine.play error: $e");
    }
  }

  Future<void> pause() async {
    try {
      await _handler.pause();
    } catch (e) {
      debugPrint("AudioEngine.pause error: $e");
    }
  }

  Future<void> togglePlayPause() async {
    await ensureInitialized();
    try {
      if (_handler.player.playing) {
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
      await _handler.seek(position);
    } catch (e) {
      debugPrint("AudioEngine.seek error: $e");
    }
  }

  Future<void> skipToNext() async {
    try {
      await _handler.skipToNext();
    } catch (e) {
      debugPrint("AudioEngine.skipToNext error: $e");
    }
  }

  Future<void> skipToPrevious() async {
    try {
      await _handler.skipToPrevious();
    } catch (e) {
      debugPrint("AudioEngine.skipToPrevious error: $e");
    }
  }

  Future<bool> playTrack(List<SongModel> queue, int index) async {
    await ensureInitialized();
    try {
      await _handler.setQueue(queue, initialIndex: index);
      await _handler.play();
      return true;
    } catch (e, stack) {
      debugPrint("AudioEngine.playTrack primary queue error: $e\n$stack");
      // Resilient fallback: direct player playback without throwing handler errors
      try {
        if (queue.isNotEmpty && index >= 0 && index < queue.length) {
          final target = queue[index];
          await _handler.player.setAudioSource(
            AudioSource.uri(CinematicAudioHandler.parseAudioUri(target.path)),
          );
          await _handler.player.play();
          return true;
        }
      } catch (fallbackErr) {
        debugPrint("AudioEngine.playTrack fallback error: $fallbackErr");
      }
      return false;
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _handler.player.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> setSpeed(double speed) async {
    try {
      await _handler.player.setSpeed(speed.clamp(0.5, 2.5));
    } catch (_) {}
  }

  // --- Shuffle & Repeat ---
  bool get isShuffleEnabled => _handler.player.shuffleModeEnabled;

  Future<void> toggleShuffle() async {
    try {
      final next = !_handler.player.shuffleModeEnabled;
      await _handler.player.setShuffleModeEnabled(next);
    } catch (_) {}
  }

  LoopMode get loopMode => _handler.player.loopMode;

  Future<void> cycleRepeatMode() async {
    try {
      switch (_handler.player.loopMode) {
        case LoopMode.off:
          await _handler.player.setLoopMode(LoopMode.all);
          break;
        case LoopMode.all:
          await _handler.player.setLoopMode(LoopMode.one);
          break;
        case LoopMode.one:
          await _handler.player.setLoopMode(LoopMode.off);
          break;
      }
    } catch (_) {}
  }

  // --- Reactive Streams (Always Active & Non-Null) ---
  Stream<bool> get isPlayingStream => _handler.player.playingStream;
  Stream<Duration> get positionStream => _handler.player.positionStream;
  Stream<Duration?> get durationStream => _handler.player.durationStream;
  Stream<Duration> get bufferedPositionStream => _handler.player.bufferedPositionStream;
  Stream<int?> get currentIndexStream => _handler.player.currentIndexStream;
  Stream<ProcessingState> get processingStateStream => _handler.player.processingStateStream;
}
