import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../database/database_service.dart';
import '../database/models/song_model.dart';

/// Central AudioHandler connecting Flutter UI and AudioEngine to
/// Android MediaSession, MediaBrowserService (Android Auto), and system media controls.
class CinematicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer(
    handleInterruptions: false, // Managed authoritatively by AudioSession in AudioEngine
    handleAudioSessionActivation: false, // Activated explicitly during playback
    androidApplyAudioAttributes: true,
  );

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
    // 1. Broadcast playback state on any Exoplayer event (position discontinuity, buffering, etc.)
    _player.playbackEventStream.listen(
      (PlaybackEvent event) => _broadcastPlaybackState(event),
      onError: (Object e, StackTrace stack) {
        debugPrint("CinematicAudioHandler playbackEventStream error: $e\n$stack");
      },
    );

    // 2. Broadcast playback state immediately when playing/paused or processing state changes
    _player.playerStateStream.listen(
      (_) => _broadcastPlaybackState(),
      onError: (Object e, StackTrace stack) {
        debugPrint("CinematicAudioHandler playerStateStream error: $e\n$stack");
      },
    );

    // 3. Listen to current track index changes to update lock screen / notification metadata
    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _currentQueue.length) {
        _currentIndex = index;
        final song = _currentQueue[index];
        _updateSystemMediaItem(song);
      }
    });
  }

  /// Broadcasts reactive PlaybackState to Android MediaSession, lock screen, and notification
  void _broadcastPlaybackState([PlaybackEvent? event]) {
    final playing = _player.playing;
    final processingState = _player.processingState;

    playbackState.add(
      PlaybackState(
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
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.playPause,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[processingState] ?? AudioProcessingState.idle,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event?.currentIndex ?? _currentIndex,
        updateTime: DateTime.now(), // Essential for Android Media3/Notification position interpolation
      ),
    );
  }

  static Uri parseAudioUri(String path) {
    if (path.isEmpty) return Uri();
    final lower = path.toLowerCase();
    if (lower.startsWith('content://') ||
        lower.startsWith('file://') ||
        lower.startsWith('http://') ||
        lower.startsWith('https://')) {
      return Uri.parse(path);
    }
    return Uri.file(path);
  }

  void _updateSystemMediaItem(SongModel song) {
    mediaItem.add(
      MediaItem(
        id: song.id,
        album: song.album,
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        artUri: song.artworkPath != null ? parseAudioUri(song.artworkPath!) : null,
        extras: {
          'format': song.format,
          'bitrate': song.bitrate,
          'sampleRate': song.sampleRate,
          'sourceType': song.sourceType,
          'path': song.path,
        },
      ),
    );
  }

  static MediaItem songToMediaItem(SongModel song) {
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: song.artworkPath != null ? parseAudioUri(song.artworkPath!) : null,
      playable: true,
      extras: {
        'path': song.path,
        'sourceType': song.sourceType,
      },
    );
  }

  Future<void> setQueue(List<SongModel> songs, {int initialIndex = 0}) async {
    final validSongs = songs.where((s) => s.isLocalFileAvailable).toList();
    if (validSongs.isEmpty) {
      throw StateError("Cannot play: No valid playable audio files found in queue.");
    }

    _currentQueue.clear();
    _currentQueue.addAll(validSongs);

    queue.add(validSongs.map((s) => songToMediaItem(s)).toList());

    for (int i = 0; i < validSongs.length; i++) {
      final s = validSongs[i];
      debugPrint(">>> CinematicAudioHandler.setQueue [just_audio item $i]: title='${s.title}', sourceType='${s.sourceType}', path='${s.path}'");
    }

    final sources = validSongs.map((s) => AudioSource.uri(parseAudioUri(s.path))).toList();
    final newPlaylist = ConcatenatingAudioSource(children: sources);
    
    _currentIndex = initialIndex.clamp(0, validSongs.length - 1);
    try {
      final currentTarget = validSongs[_currentIndex];
      debugPrint(">>> CinematicAudioHandler [just_audio setAudioSource]: index=$_currentIndex, title='${currentTarget.title}', sourceType='${currentTarget.sourceType}', url='${currentTarget.path}'");
      await _player.setAudioSource(
        newPlaylist,
        initialIndex: _currentIndex,
        initialPosition: Duration.zero,
      );
      _updateSystemMediaItem(validSongs[_currentIndex]);
    } catch (e, stack) {
      debugPrint("CinematicAudioHandler.setAudioSource error: $e\n$stack");
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
    _broadcastPlaybackState();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _broadcastPlaybackState();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_currentQueue.isNotEmpty) {
      await _player.seek(Duration.zero, index: 0);
    }
    _broadcastPlaybackState();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (_currentQueue.isNotEmpty) {
      await _player.seek(Duration.zero, index: _currentQueue.length - 1);
    }
    _broadcastPlaybackState();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _broadcastPlaybackState();
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

  // --- Android Auto & MediaBrowserService Implementation ---

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    final db = DatabaseService.instance;
    await db.init();

    switch (parentMediaId) {
      case AudioService.recentRootId:
      case 'history':
        return db.getRecentlyPlayedSongs().map((s) => songToMediaItem(s)).toList();

      case 'favorites':
        return db.getFavorites().map((s) => songToMediaItem(s)).toList();

      case 'library':
        return db.getPlayableSongs().map((s) => songToMediaItem(s)).toList();

      case 'playlists':
        return db.getAllPlaylists().map((pl) => MediaItem(
          id: 'playlist_${pl.id}',
          title: pl.name,
          playable: false,
          extras: {'isFolder': true, 'songCount': pl.songIds.length},
        )).toList();

      case 'albums':
        return db.getAllAlbums().map((alb) => MediaItem(
          id: 'album_${alb.name}',
          title: alb.name,
          artist: alb.artist,
          artUri: alb.artworkPath != null ? parseAudioUri(alb.artworkPath!) : null,
          playable: false,
          extras: {'isFolder': true, 'songCount': alb.songCount},
        )).toList();

      case 'artists':
        return db.getAllArtists().map((art) => MediaItem(
          id: 'artist_${art.name}',
          title: art.name,
          artUri: art.sampleArtworkPath != null ? parseAudioUri(art.sampleArtworkPath!) : null,
          playable: false,
          extras: {'isFolder': true, 'songCount': art.songCount},
        )).toList();

      case AudioService.browsableRootId:
      default:
        // Querying a specific playlist
        if (parentMediaId.startsWith('playlist_')) {
          final plId = parentMediaId.replaceFirst('playlist_', '');
          final pl = db.getPlaylistById(plId);
          if (pl != null) {
            final songs = pl.songIds
                .map((id) => db.getSongById(id))
                .whereType<SongModel>()
                .toList();
            return songs.map((s) => songToMediaItem(s)).toList();
          }
          return [];
        }

        // Return Root Content Navigation Tree
        return const [
          MediaItem(
            id: 'favorites',
            title: 'Favorites',
            playable: false,
            extras: {'isFolder': true},
          ),
          MediaItem(
            id: 'playlists',
            title: 'Playlists',
            playable: false,
            extras: {'isFolder': true},
          ),
          MediaItem(
            id: 'history',
            title: 'Recently Played',
            playable: false,
            extras: {'isFolder': true},
          ),
          MediaItem(
            id: 'library',
            title: 'All Songs',
            playable: false,
            extras: {'isFolder': true},
          ),
          MediaItem(
            id: 'albums',
            title: 'Albums',
            playable: false,
            extras: {'isFolder': true},
          ),
          MediaItem(
            id: 'artists',
            title: 'Artists',
            playable: false,
            extras: {'isFolder': true},
          ),
        ];
    }
  }

  Future<MediaItem?> getItem(String mediaId) async {
    final song = DatabaseService.instance.getSongById(mediaId);
    if (song != null) return songToMediaItem(song);
    return null;
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    final db = DatabaseService.instance;
    await db.init();

    // 1. Direct song request
    final song = db.getSongById(mediaId);
    if (song != null) {
      final queue = db.getPlayableSongs();
      final index = queue.indexWhere((s) => s.id == song.id);
      await setQueue(queue, initialIndex: index >= 0 ? index : 0);
      await play();
      return;
    }

    // 2. Folder/Playlist request (play all items inside folder)
    final items = await getChildren(mediaId);
    final songIds = items.where((i) => i.playable ?? false).map((i) => i.id).toList();
    if (songIds.isNotEmpty) {
      final songs = songIds
          .map((id) => db.getSongById(id))
          .whereType<SongModel>()
          .toList();
      if (songs.isNotEmpty) {
        await setQueue(songs, initialIndex: 0);
        await play();
      }
    }
  }

  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return;

    final db = DatabaseService.instance;
    await db.init();

    final all = db.getPlayableSongs();
    final matches = all.where((s) =>
      s.title.toLowerCase().contains(clean) ||
      s.artist.toLowerCase().contains(clean) ||
      s.album.toLowerCase().contains(clean)
    ).toList();

    if (matches.isNotEmpty) {
      await setQueue(matches, initialIndex: 0);
      await play();
    }
  }
}
