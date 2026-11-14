import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../database/models/song_model.dart';

class CinematicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  final List<SongModel> _currentQueue = [];
  int _currentIndex = -1;

  AudioPlayer get player => _player;
  List<SongModel> get currentQueue => List.unmodifiable(_currentQueue);
  int get currentIndex => _currentIndex;
  SongModel? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _currentQueue.length)
          ? _currentQueue[_currentIndex]
          : null;

  CinematicAudioHandler() {
    _initPipeline();
  }

  void _initPipeline() {
    // Pipe JustAudio playback events into AudioService system state
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      final processingState = _player.processingState;

      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            playing ? MediaControl.pause : MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.setShuffleMode,
            MediaAction.setRepeatMode,
          },
          androidCompactActionIndices: const [0, 1, 3],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ),
      );
    });

    // Listen to current sequence index changes to update lock screen / SMTC metadata
    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _currentQueue.length) {
        _currentIndex = index;
        final song = _currentQueue[index];
        _updateSystemMediaItem(song);
      }
    });
  }

  void _updateSystemMediaItem(SongModel song) {
    mediaItem.add(
      MediaItem(
        id: song.id,
        album: song.album,
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        artUri: song.artworkPath != null ? Uri.file(song.artworkPath!) : null,
        extras: {
          'format': song.format,
          'bitrate': song.bitrate,
          'sampleRate': song.sampleRate,
        },
      ),
    );
  }

  Future<void> setQueue(List<SongModel> songs, {int initialIndex = 0}) async {
    _currentQueue.clear();
    _currentQueue.addAll(songs);

    queue.add(songs.map((s) => MediaItem(
      id: s.id,
      album: s.album,
      title: s.title,
      artist: s.artist,
      duration: s.duration,
      artUri: s.artworkPath != null ? Uri.file(s.artworkPath!) : null,
    )).toList());

    if (songs.isNotEmpty) {
      final sources = songs.map((s) => AudioSource.uri(Uri.file(s.path))).toList();
      final newPlaylist = ConcatenatingAudioSource(children: sources);
      
      _currentIndex = initialIndex.clamp(0, songs.length - 1);
      await _player.setAudioSource(
        newPlaylist,
        initialIndex: _currentIndex,
        initialPosition: Duration.zero,
      );
      _updateSystemMediaItem(songs[_currentIndex]);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_currentQueue.isNotEmpty) {
      // Loop around if at end
      await _player.seek(Duration.zero, index: 0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enable = shuffleMode != AudioServiceShuffleMode.none;
    await _player.setShuffleModeEnabled(enable);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }
}
