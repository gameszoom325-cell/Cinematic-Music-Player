import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinematic_music_player/auth/user_model.dart';
import 'package:cinematic_music_player/sync/cloud_database.dart';
import 'package:cinematic_music_player/core/config/supabase_config.dart';
import 'package:cinematic_music_player/core/services/lyrics_parser.dart';
import 'package:cinematic_music_player/core/services/update_service.dart';
import 'package:cinematic_music_player/core/database/models/song_model.dart';
import 'package:cinematic_music_player/core/services/shader_capability_service.dart';
import 'package:cinematic_music_player/core/audio_engine/audio_service_handler.dart';
import 'package:cinematic_music_player/core/audio_engine/audio_engine.dart';
import 'package:cinematic_music_player/features/player/models/player_state.dart';
import 'package:cinematic_music_player/core/services/audio_metadata_parser.dart';
import 'package:cinematic_music_player/core/database/models/cloud_song_model.dart';
import 'package:cinematic_music_player/core/database/models/cloud_artist_model.dart';
import 'package:cinematic_music_player/core/database/models/cloud_album_model.dart';
import 'package:cinematic_music_player/core/services/cloud_music_service.dart';
import 'package:cinematic_music_player/core/database/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('1. UserModel & DeviceModel Schema Tests', () {
    test('UserModel serialization and deserialization preserves all fields', () {
      final now = DateTime.now();
      final user = UserModel(
        userId: 'usr_abc123',
        username: 'AestheticAuditor',
        email: 'auditor@cinematic.local',
        profileImage: 'avatar_preset_2',
        createdDate: now,
        token: 'jwt_mock_token_secret',
        isGuest: false,
        devices: [
          {'deviceId': 'win_1', 'platform': 'windows'},
          {'deviceId': 'droid_1', 'platform': 'android'},
        ],
      );

      final json = user.toJson();
      expect(json['userId'], 'usr_abc123');
      expect(json['username'], 'AestheticAuditor');
      expect(json['email'], 'auditor@cinematic.local');
      expect(json['devices'], hasLength(2));

      final serialized = user.serialize();
      final deserialized = UserModel.deserialize(serialized);
      expect(deserialized, isNotNull);
      expect(deserialized!.userId, user.userId);
      expect(deserialized.email, user.email);
      expect(deserialized.isGuest, false);
    });

    test('DeviceModel creates valid hardware profile', () {
      final device = DeviceModel(
        deviceId: 'win_x64_test',
        deviceName: 'Windows Laptop (Workstation)',
        platform: 'windows',
        lastSyncTime: DateTime.now(),
        appVersion: '1.0.0',
        isCurrentDevice: true,
      );

      expect(device.platform, 'windows');
      expect(device.isCurrentDevice, true);
      final json = device.toJson();
      expect(json['deviceId'], 'win_x64_test');
    });
  });

  group('2. Cloud Database Sync Payload Tests', () {
    test('CloudSyncPayload empty factory generates valid schema', () {
      final payload = CloudSyncPayload.empty('usr_test');
      expect(payload.userId, 'usr_test');
      expect(payload.version, 1);
      expect(payload.playlists, isEmpty);
      expect(payload.favorites, isEmpty);
      expect(payload.userPreferences['shuffleMode'], false);
      expect(payload.visualizerSettings['preset'], 'orb3d');
      expect(payload.lyricsPreferences['activeLineBloom'], true);

      final json = payload.toJson();
      final parsed = CloudSyncPayload.fromJson(json);
      expect(parsed.userId, 'usr_test');
      expect(parsed.visualizerSettings['preset'], 'orb3d');
    });
  });

  group('3. Supabase Configuration Tests', () {
    test('SupabaseConfig defaults to valid HTTP/HTTPS URL', () {
      final config = SupabaseConfig.instance;
      expect(config.isConfigured, true);
      expect(config.url.startsWith('http'), true);
      expect(config.anonKey.isNotEmpty, true);
    });
  });

  group('4. Synced LRC Lyrics Engine Tests', () {
    test('LyricsParser extracts timestamps and lyric lines correctly', () {
      const sampleLrc = '''
[ti:Midnight Drive]
[ar:Synthwave Collective]
[00:00.00]Intro
[00:04.50]Neon lights against the rain
[00:08.20]Shadows dancing on the glass
[00:15.80]Fade into the cyber night
''';

      final synced = LyricsParser.parseLrcString(sampleLrc);
      expect(synced.lines, isNotEmpty);
      expect(synced.lines.length, greaterThanOrEqualTo(4));
      expect(synced.lines[1].text, 'Neon lights against the rain');
      expect(synced.lines[1].timestamp.inMilliseconds, 4500);
      expect(synced.lines[2].timestamp.inMilliseconds, 8200);
      expect(synced.title, 'Midnight Drive');
      expect(synced.artist, 'Synthwave Collective');
    });

    test('SyncedLyrics active line index lookup responds accurately', () {
      const sampleLrc = '''
[00:00.00]Line 0
[00:05.00]Line 1
[00:10.00]Line 2
''';
      final synced = LyricsParser.parseLrcString(sampleLrc);
      expect(synced.getActiveIndex(const Duration(seconds: 2)), 0);
      expect(synced.getActiveIndex(const Duration(seconds: 7)), 1);
      expect(synced.getActiveIndex(const Duration(seconds: 12)), 2);
    });
  });

  group('5. Semantic Version & Auto Update Comparator Tests', () {
    test('AppVersion.compare correctly calculates version diffs', () {
      expect(AppVersion.compare('1.0.0', '1.0.0'), 0);
      expect(AppVersion.compare('1.0.1', '1.0.0'), greaterThan(0));
      expect(AppVersion.compare('1.1.0', '1.0.0'), greaterThan(0));
      expect(AppVersion.compare('2.0.0', '1.9.9'), greaterThan(0));
      expect(AppVersion.compare('1.0.0', '1.0.1'), lessThan(0));
      expect(AppVersion.compare('v1.2.0', '1.1.9'), greaterThan(0));
    });
  });

  group('6. SongModel Metadata Extraction Tests', () {
    test('SongModel stores audio properties accurately', () {
      final song = SongModel(
        id: 'track_1',
        title: 'Neon Odyssey',
        artist: 'Cyber Ensemble',
        album: 'Future Horizon',
        path: 'C:\\Music\\NeonOdyssey.mp3',
        durationMs: 225000,
        fileSize: 8492011,
        dateAdded: DateTime.now(),
        bitrate: 320,
        isFavorite: true,
      );

      expect(song.title, 'Neon Odyssey');
      expect(song.bitrate, 320);
      expect(song.isFavorite, true);
      expect(song.durationMs, 225000);
    });
  });

  group('7. ShaderCapabilityService Runtime Fallback Tests', () {
    test('ShaderCapabilityService defaults safely and detects fallback without crashing', () async {
      final service = ShaderCapabilityService.instance;
      expect(service, isNotNull);
      // In headless test environments, checkShaderSupport should execute cleanly and safely default
      await service.checkShaderSupport();
      expect(service.hasBeenChecked, isTrue);
      expect(service.areShadersSupported, isA<bool>());

      // Test manual fallback switch
      service.forceCanvasFallback();
      expect(service.areShadersSupported, isFalse);
    });
  });

  group('8. Real Audio File & Metadata Parsing Tests', () {
    test('AudioMetadataParser parses real MP3 audio properties accurately', () async {
      final mp3File = File('assets/audio/bairan_demo.mp3');
      if (mp3File.existsSync()) {
        final parsed = await AudioMetadataParser.parseFile(mp3File);
        expect(parsed.format, equals('MP3'));
        expect(parsed.durationMs, greaterThan(0));
        expect(parsed.title, isNotEmpty);
      }
    });

    test('parseAudioUri parses content and file schemes safely', () {
      final fileUri = CinematicAudioHandler.parseAudioUri('/storage/emulated/0/Music/song.mp3');
      expect(fileUri.scheme, equals('file'));

      final contentUri = CinematicAudioHandler.parseAudioUri('content://media/external/audio/123');
      expect(contentUri.scheme, equals('content'));

      final emptyUri = CinematicAudioHandler.parseAudioUri('');
      expect(emptyUri.toString(), equals(''));
    });
  });

  group('9. Playable Song Availability Verification Tests', () {
    test('SongModel.isLocalFileAvailable returns false for non-existent paths', () {
      final fakeSong = SongModel(
        id: 'fake_1',
        title: 'Non Existent Track',
        artist: 'Ghost',
        album: 'Void',
        path: 'C:\\NonExistentFolder\\ghost_track.mp3',
        durationMs: 180000,
        dateAdded: DateTime.now(),
      );
      expect(fakeSong.isLocalFileAvailable, isFalse);
    });

    test('SongModel.isLocalFileAvailable returns true for existing local files', () {
      final tempFile = File('${Directory.systemTemp.path}/cinematic_test_audio.mp3');
      tempFile.writeAsBytesSync([0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      final validSong = SongModel(
        id: 'real_1',
        title: 'Local Test Track',
        artist: 'Artist',
        album: 'Album',
        path: tempFile.path,
        durationMs: 151000,
        dateAdded: DateTime.now(),
      );
      expect(validSong.isLocalFileAvailable, isTrue);
      if (tempFile.existsSync()) tempFile.deleteSync();
    });
  });

  group('10. AudioEngine Architecture & Handler Availability Tests', () {
    test('AudioEngine instance is available immediately and handler is non-null', () {
      final engine = AudioEngine.instance;
      expect(engine, isNotNull);
      expect(engine.isInitialized, isTrue);
      expect(engine.handler, isNotNull);
      expect(engine.isPlayingStream, isNotNull);
      expect(engine.positionStream, isNotNull);
      expect(engine.durationStream, isNotNull);
      expect(engine.currentIndexStream, isNotNull);
      expect(engine.processingStateStream, isNotNull);
    });

    test('CinematicPlayerState supports isLoading state', () {
      const state = CinematicPlayerState();
      expect(state.isLoading, isFalse);

      final loadingState = state.copyWith(isLoading: true);
      expect(loadingState.isLoading, isTrue);

      final resetState = loadingState.copyWith(isLoading: false);
      expect(resetState.isLoading, isFalse);
    });
  });

  group('11. Private Cloud Streaming Models & Conversion Tests', () {
    test('CloudSongModel converts cleanly to playback-ready SongModel with streaming URL', () {
      final cloudSong = CloudSongModel(
        id: 'cloud_test_101',
        title: 'Raag Yaman (Moonlight Stream)',
        artist: 'Ustad Rashid',
        album: 'Hindustani Classical Vol 1',
        coverImage: 'https://cdn.cinematic.cloud/covers/raag_yaman.jpg',
        genre: 'Classical',
        duration: 320,
        audioUrl: 'https://cdn.cinematic.cloud/audio/raag_yaman.mp3',
        playCount: 1540,
        createdAt: DateTime.now(),
      );

      final songModel = cloudSong.toSongModel();
      expect(songModel.id, 'cloud_test_101');
      expect(songModel.title, 'Raag Yaman (Moonlight Stream)');
      expect(songModel.path, 'https://cdn.cinematic.cloud/audio/raag_yaman.mp3');
      expect(songModel.isCloudSong, isTrue);
      expect(songModel.isLocalFileAvailable, isTrue);
      expect(songModel.durationMs, 320000);
      expect(songModel.hasArtwork, isTrue);
      expect(songModel.artworkPath, 'https://cdn.cinematic.cloud/covers/raag_yaman.jpg');
    });

    test('CloudArtistModel & CloudAlbumModel serialize correctly', () {
      final artist = CloudArtistModel(
        id: 'artist_arijit',
        name: 'Arijit Singh',
        image: 'https://images.example.com/arijit.jpg',
        biography: 'Soulful Bollywood playback legend.',
        songCount: 12,
        albumCount: 4,
      );

      final map = artist.toMap();
      expect(map['name'], 'Arijit Singh');
      expect(map['song_count'], 12);
      expect(map['album_count'], 4);

      final revived = CloudArtistModel.fromMap(map);
      expect(revived.id, 'artist_arijit');
      expect(revived.name, 'Arijit Singh');

      final album = CloudAlbumModel(
        id: 'album_monsoon',
        title: 'Monsoon Diaries',
        artist: 'Kabir Das',
        artwork: 'https://images.example.com/monsoon.jpg',
        releaseInfo: 'Studio Master 2024',
        songCount: 8,
      );

      final albumMap = album.toMap();
      expect(albumMap['title'], 'Monsoon Diaries');
      final revivedAlbum = CloudAlbumModel.fromMap(albumMap);
      expect(revivedAlbum.artist, 'Kabir Das');
      expect(revivedAlbum.songCount, 8);
    });
  });

  group('12. CloudMusicService Discovery & Streaming Catalogue Tests', () {
    test('CloudMusicService returns default curated streaming songs', () async {
      final songs = await CloudMusicService.instance.fetchSongs();
      expect(songs, isNotEmpty);
      expect(songs.length, greaterThanOrEqualTo(5));

      final first = songs.first;
      expect(first.audioUrl.startsWith('http'), isTrue);
      expect(first.toSongModel().isLocalFileAvailable, isTrue);
    });

    test('fetchTrendingSongs returns songs ordered by play count', () async {
      final trending = await CloudMusicService.instance.fetchTrendingSongs(limit: 3);
      expect(trending, hasLength(3));
      expect(trending[0].playCount, greaterThanOrEqualTo(trending[1].playCount));
      expect(trending[1].playCount, greaterThanOrEqualTo(trending[2].playCount));
    });

    test('fetchArtists & fetchAlbums extract catalog groupings', () async {
      final artists = await CloudMusicService.instance.fetchArtists();
      expect(artists, isNotEmpty);
      expect(artists.any((a) => a.name.isNotEmpty), isTrue);

      final albums = await CloudMusicService.instance.fetchAlbums();
      expect(albums, isNotEmpty);
      expect(albums.any((a) => a.title.isNotEmpty), isTrue);
    });

    test('DatabaseService checks favorites for cloud songs accurately', () {
      final db = DatabaseService.instance;
      expect(db.isFavorite('non_existent_cloud_song'), isFalse);
    });
  });
}
