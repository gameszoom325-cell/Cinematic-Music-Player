import 'dart:async';
import 'package:flutter/foundation.dart';
import '../audio_engine/audio_engine.dart';
import '../database/models/song_model.dart';
import '../sources/music_source_repository.dart';
import 'audio_stream_cache_manager.dart';

/// Predictive Lookahead Preloading Service inspired by Metrolist's NextTrackPreloadTrigger.
/// 
/// Monitors ongoing audio playback. When a song approaches completion (>= 80% progress
/// or <= 30 seconds remaining), it proactively resolves and primes the next song in the
/// queue into the [AudioStreamCacheManager]. This eliminates inter-track buffering delays.
class NextTrackPreloadService {
  NextTrackPreloadService._internal();

  static final NextTrackPreloadService instance = NextTrackPreloadService._internal();

  StreamSubscription? _positionSubscription;
  StreamSubscription? _indexSubscription;

  String? _lastPreloadedSongId;
  bool _isPreloading = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  /// Starts listening to the audio engine pipeline events.
  void startListening() {
    if (_isListening) return;
    _isListening = true;

    final handler = AudioEngine.instance.handler;

    // Reset preload lock when current track changes
    _indexSubscription = handler.player.currentIndexStream.listen((index) {
      _lastPreloadedSongId = null;
      _isPreloading = false;
    });

    // Monitor position for the lookahead threshold
    _positionSubscription = handler.player.positionStream.listen((position) {
      _checkPreloadTrigger(position);
    });

    debugPrint("NextTrackPreloadService: Active and listening for preload thresholds.");
  }

  void stopListening() {
    _positionSubscription?.cancel();
    _indexSubscription?.cancel();
    _positionSubscription = null;
    _indexSubscription = null;
    _isListening = false;
  }

  void _checkPreloadTrigger(Duration currentPosition) {
    if (_isPreloading) return;

    final currentSong = AudioEngine.instance.currentSong;
    if (currentSong == null) return;

    // Already preloaded for this track
    if (_lastPreloadedSongId == currentSong.id) return;

    final duration = AudioEngine.instance.duration;
    if (duration == null || duration.inSeconds < 10) return;

    final progress = currentPosition.inMilliseconds / duration.inMilliseconds;
    final remaining = duration - currentPosition;

    // Trigger preload when >= 80% through track OR remaining time <= 30 seconds
    final shouldTrigger = progress >= 0.8 || remaining.inSeconds <= 30;

    if (shouldTrigger) {
      _triggerPreloadForNextTrack(currentSong.id);
    }
  }

  Future<void> _triggerPreloadForNextTrack(String currentSongId) async {
    _isPreloading = true;
    _lastPreloadedSongId = currentSongId;

    try {
      final handler = AudioEngine.instance.handler;
      final queue = handler.currentQueue;
      final currentIndex = handler.currentIndex;

      if (currentIndex >= 0 && currentIndex + 1 < queue.length) {
        final nextSong = queue[currentIndex + 1];
        await preloadTrack(nextSong);
      }
    } catch (e) {
      debugPrint("NextTrackPreloadService preload trigger error: $e");
    } finally {
      _isPreloading = false;
    }
  }

  /// Manually or predictively resolves and primes a target track into cache
  Future<void> preloadTrack(SongModel targetSong) async {
    debugPrint("NextTrackPreloadService: Proactively priming '${targetSong.title}' [${targetSong.id}]");

    // Local files require no network lookahead
    if (!targetSong.isRemoteStream && targetSong.isLocalFileAvailable) {
      return;
    }

    try {
      // 1. Resolve playback song
      final resolved = await MusicSourceRepository.instance.resolvePlayableSong(targetSong);
      
      // 2. If it's a remote URL, prefetch into AudioStreamCacheManager
      if (resolved.path.startsWith('http://') || resolved.path.startsWith('https://')) {
        AudioStreamCacheManager.instance.prefetch(resolved, resolved.path);
      }
    } catch (e) {
      debugPrint("NextTrackPreloadService: Error preloading ${targetSong.title}: $e");
    }
  }
}
