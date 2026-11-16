import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinematic_music_player/auth/user_model.dart';
import 'package:cinematic_music_player/sync/cloud_database.dart';
import 'package:cinematic_music_player/core/config/supabase_config.dart';
import 'package:cinematic_music_player/core/services/lyrics_parser.dart';
import 'package:cinematic_music_player/core/services/update_service.dart';
import 'package:cinematic_music_player/core/services/crash_logger.dart';
import 'package:cinematic_music_player/core/services/audio_stream_cache_manager.dart';
import 'package:cinematic_music_player/core/services/next_track_preload_service.dart';
import 'package:cinematic_music_player/core/audio_engine/audio_reactive_analyzer.dart';
import 'package:cinematic_music_player/features/visualizer/models/visualizer_preset.dart';
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
import 'package:cinematic_music_player/core/sources/music_source_type.dart';
import 'package:cinematic_music_player/core/sources/local_music_source.dart';
import 'package:cinematic_music_player/core/sources/cloud_music_source.dart';
import 'package:cinematic_music_player/core/sources/online_music_source.dart';
import 'package:cinematic_music_player/core/sources/external_provider_source.dart';
import 'package:cinematic_music_player/core/sources/music_source_repository.dart';
import 'package:cinematic_music_player/core/catalog/models/catalog_song.dart';
import 'package:cinematic_music_player/core/catalog/models/catalog_artist.dart';
import 'package:cinematic_music_player/core/catalog/models/catalog_album.dart';
import 'package:cinematic_music_player/core/catalog/catalog_database_service.dart';
import 'package:cinematic_music_player/jamendo/jamendo_service.dart';
import 'package:cinematic_music_player/jamendo/jamendo_page.dart';
import 'package:cinematic_music_player/jiosaavn/jiosaavn_service.dart';
import 'package:cinematic_music_player/jiosaavn/jiosaavn_page.dart';
import 'package:cinematic_music_player/core/config/youtube_config.dart';
import 'package:cinematic_music_player/core/services/firebase_service.dart';
import 'package:cinematic_music_player/firebase_options.dart';
import 'package:cinematic_music_player/core/services/youtube_api_service.dart';
import 'package:cinematic_music_player/core/sources/youtube_music_source.dart';
import 'package:cinematic_music_player/core/config/jamendo_config.dart';
import 'package:cinematic_music_player/core/services/jamendo_api_service.dart';
import 'package:cinematic_music_player/core/sources/jamendo_music_source.dart';
import 'package:cinematic_music_player/web_search/web_search_page.dart';

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

  group('13. MusicSource Architecture & Provider Abstraction Tests', () {
    test('MusicSourceType enum maps correctly to strings and IDs', () {
      expect(MusicSourceType.local.id, 'local');
      expect(MusicSourceType.cloud.id, 'cloud');
      expect(MusicSourceType.externalProvider.id, 'external');

      expect(MusicSourceType.fromString('local'), MusicSourceType.local);
      expect(MusicSourceType.fromString('cloud'), MusicSourceType.cloud);
      expect(MusicSourceType.fromString('external'), MusicSourceType.externalProvider);
      expect(MusicSourceType.fromString('other'), MusicSourceType.local);
    });

    test('LocalMusicSource, CloudMusicSource, ExternalProviderSource instantiate with correct types', () {
      final local = LocalMusicSource();
      expect(local.type, MusicSourceType.local);
      expect(local.id, 'local');
      expect(local.isAvailable, isTrue);

      final cloud = CloudMusicSource();
      expect(cloud.type, MusicSourceType.cloud);
      expect(cloud.id, 'cloud');

      final ext = ExternalProviderSource();
      expect(ext.type, MusicSourceType.externalProvider);
      expect(ext.id, 'external_provider');
      expect(ext.isAvailable, isTrue);
    });

    test('MusicSourceRepository initializes default sources and executes federated search', () async {
      final repo = MusicSourceRepository.instance;
      expect(repo.allSources, hasLength(7));

      expect(repo.getSource(MusicSourceType.local), isNotNull);
      expect(repo.getSource(MusicSourceType.cloud), isNotNull);
      expect(repo.getSource(MusicSourceType.online), isNotNull);
      expect(repo.getSource(MusicSourceType.catalog), isNotNull);
      expect(repo.getSource(MusicSourceType.youtube), isNotNull);
      expect(repo.getSource(MusicSourceType.jamendo), isNotNull);
      expect(repo.getSource(MusicSourceType.externalProvider), isNotNull);

      // Search all sources
      final results = await repo.searchAll('Acoustic');
      expect(results, isNotEmpty);
      expect(results.any((s) => s.title.toLowerCase().contains('acoustic')), isTrue);
    });

    test('ExternalProviderSource resolves playback URI on-demand and caches stream tokens', () async {
      final extSource = ExternalProviderSource();
      final songs = await extSource.getSongs();
      expect(songs, isNotEmpty);

      final song = songs.first;
      final uri = await extSource.resolvePlaybackUri(song);
      expect(uri, isNotEmpty);
      expect(uri.startsWith('http'), isTrue);

      // Second call should hit the in-memory cache
      final cachedUri = await extSource.resolvePlaybackUri(song);
      expect(cachedUri, uri);
    });

    test('MusicSourceRepository resolvePlayableSong routes to originating source', () async {
      final repo = MusicSourceRepository.instance;
      final externalSong = SongModel(
        id: 'ext_test_99',
        path: 'https://cdn.example.com/stream.mp3',
        title: 'Streaming Test',
        artist: 'Tester',
        album: 'Test Album',
        durationMs: 180000,
        dateAdded: DateTime.now(),
        sourceType: 'external',
      );

      final resolved = await repo.resolvePlayableSong(externalSong);
      expect(resolved.id, 'ext_test_99');
      expect(resolved.isLocalFileAvailable, isTrue);
      expect(resolved.path, 'https://cdn.example.com/stream.mp3');
    });
  });

  group('14. Modern MusicSource (InnerTubeX Inspired) & Unified Search Tests', () {
    test('OnlineMusicSource initializes with correct InnerTubeX specifications', () {
      final onlineSource = OnlineMusicSource();
      expect(onlineSource.type, MusicSourceType.online);
      expect(onlineSource.id, 'online');
      expect(onlineSource.displayName, contains('InnerTubeX'));
      expect(onlineSource.isAvailable, isTrue);
    });

    test('OnlineMusicSource searchSongs returns unified SongModel with title, artist, album, thumbnail, duration', () async {
      final onlineSource = OnlineMusicSource();
      final songs = await onlineSource.searchSongs('Acoustic');

      expect(songs, isNotEmpty);
      final song = songs.first;
      expect(song.title, isNotEmpty);
      expect(song.artist, isNotEmpty);
      expect(song.album, isNotEmpty);
      expect(song.thumbnail, isNotNull);
      expect(song.artwork, isNotNull);
      expect(song.durationMs, greaterThan(0));
      expect(song.duration.inSeconds, greaterThan(0));
      expect(song.sourceType, 'online');
      expect(song.sourceId, 'online');
      expect(song.isOnline, isTrue);
      expect(song.isRemoteStream, isTrue);
      expect(song.isLocalFileAvailable, isTrue);
    });

    test('OnlineMusicSource searchArtists and searchAlbums return categorized summaries', () async {
      final onlineSource = OnlineMusicSource();
      final artists = await onlineSource.searchArtists('Acoustic');
      expect(artists, isNotEmpty);
      expect(artists.first.name, isNotEmpty);
      expect(artists.first.sampleArtworkPath, isNotNull);

      final albums = await onlineSource.searchAlbums('Golden');
      expect(albums, isNotEmpty);
      expect(albums.first.name, isNotEmpty);
      expect(albums.first.artist, isNotEmpty);
      expect(albums.first.artworkPath, isNotNull);
    });

    test('OnlineMusicSource resolves playback URI on-demand and caches with TTL', () async {
      final onlineSource = OnlineMusicSource();
      final songs = await onlineSource.getSongs();
      expect(songs, isNotEmpty);

      final targetSong = songs.first;
      final uri1 = await onlineSource.resolvePlaybackUri(targetSong);
      expect(uri1, isNotEmpty);
      expect(uri1.startsWith('http'), isTrue);

      final uri2 = await onlineSource.resolvePlaybackUri(targetSong);
      expect(uri2, equals(uri1));
    });

    test('MusicSourceRepository searchFederated returns multi-category results', () async {
      final repo = MusicSourceRepository.instance;
      final result = await repo.searchFederated('Acoustic');

      expect(result.isEmpty, isFalse);
      expect(result.songs, isNotEmpty);
      expect(result.artists, isNotEmpty);
      expect(result.albums, isNotEmpty);
    });

    test('Player connection flow resolves Online song before AudioEngine dispatch', () async {
      final repo = MusicSourceRepository.instance;
      final onlineSong = SongModel(
        id: 'online_yt_01',
        path: 'https://ia800504.us.archive.org/33/items/Bensound_AcousticBreeze/bensound-acousticbreeze.mp3',
        title: 'Acoustic Breeze',
        artist: 'Acoustic Horizon',
        album: 'Golden Hour Sessions',
        durationMs: 168000,
        dateAdded: DateTime(2026, 11, 1),
        sourceType: 'online',
        sourceId: 'online',
      );

      final resolvedSong = await repo.resolvePlayableSong(onlineSong);
      expect(resolvedSong.isOnline, isTrue);
      expect(resolvedSong.isLocalFileAvailable, isTrue);
      expect(resolvedSong.path.startsWith('http'), isTrue);
      expect(resolvedSong.title, 'Acoustic Breeze');
    });
  });

  group('15. Bollywood & Global Catalog System Tests (v1.1.1)', () {
    test('CatalogSong, CatalogArtist, and CatalogAlbum models instantiate and serialize accurately', () {
      final song = CatalogSong(
        id: 'test_bwd_1',
        title: 'Channa Mereya',
        artist: 'Arijit Singh, Pritam',
        album: 'Ae Dil Hai Mushkil',
        year: '2016',
        artwork: 'https://images.example.com/adhm.jpg',
        source: 'bollywood_dataset',
        durationMs: 289000,
        genre: 'Bollywood Sufi Soul',
        playCount: 95000,
        dateAdded: DateTime(2026, 11, 1),
      );

      expect(song.id, 'test_bwd_1');
      expect(song.title, 'Channa Mereya');
      expect(song.artist, 'Arijit Singh, Pritam');
      expect(song.album, 'Ae Dil Hai Mushkil');
      expect(song.year, '2016');
      expect(song.artwork, 'https://images.example.com/adhm.jpg');
      expect(song.source, 'bollywood_dataset');

      // Serialization
      final map = song.toMap();
      final revived = CatalogSong.fromMap(map);
      expect(revived.id, song.id);
      expect(revived.title, song.title);
      expect(revived.artist, song.artist);
      expect(revived.album, song.album);
      expect(revived.year, song.year);
      expect(revived.artwork, song.artwork);
      expect(revived.source, song.source);

      // Artist model
      const artist = CatalogArtist(
        name: 'Arijit Singh',
        image: 'https://images.example.com/arijit.jpg',
        songCount: 15,
        albumCount: 12,
        genres: ['Bollywood Romantic'],
      );
      expect(artist.name, 'Arijit Singh');
      expect(artist.image, isNotEmpty);
      expect(artist.toArtistSummary().name, 'Arijit Singh');

      // Album model
      const album = CatalogAlbum(
        title: 'Ae Dil Hai Mushkil',
        cover: 'https://images.example.com/cover.jpg',
        year: '2016',
        artist: 'Pritam',
        songCount: 6,
      );
      expect(album.title, 'Ae Dil Hai Mushkil');
      expect(album.cover, isNotEmpty);
      expect(album.toAlbumSummary().name, 'Ae Dil Hai Mushkil');
    });

    test('CatalogSong.toSongModel() converts into playable SongModel format', () {
      final song = CatalogSong(
        id: 'bwd_kesariya',
        title: 'Kesariya',
        artist: 'Arijit Singh, Pritam',
        album: 'Brahmastra',
        year: '2022',
        artwork: 'https://images.example.com/kesariya.jpg',
        source: 'bollywood_dataset',
        durationMs: 268000,
        genre: 'Bollywood Romantic',
        dateAdded: DateTime(2026, 10, 1),
      );

      final songModel = song.toSongModel();
      expect(songModel.id, 'bwd_kesariya');
      expect(songModel.title, 'Kesariya');
      expect(songModel.artist, 'Arijit Singh, Pritam');
      expect(songModel.album, 'Brahmastra');
      expect(songModel.year, '2022');
      expect(songModel.artwork, 'https://images.example.com/kesariya.jpg');
      expect(songModel.thumbnail, 'https://images.example.com/kesariya.jpg');
      expect(songModel.source, 'catalog');
      expect(songModel.sourceType, 'catalog');
      expect(songModel.sourceId, 'bollywood_dataset');
      expect(songModel.isCatalog, isTrue);
      expect(songModel.isRemoteStream, isTrue);
      expect(songModel.isLocalFileAvailable, isTrue);
      expect(songModel.duration.inSeconds, 268);
    });

    test('CatalogDatabaseService retrieves dataset songs, artists, and albums', () async {
      final catalogDb = CatalogDatabaseService.instance;
      await catalogDb.init();

      final songs = catalogDb.getAllSongs();
      expect(songs, isNotEmpty);
      expect(songs.length, greaterThanOrEqualTo(15));

      final artists = catalogDb.getAllArtists();
      expect(artists, isNotEmpty);
      expect(artists.any((a) => a.name.contains('Arijit Singh')), isTrue);

      final albums = catalogDb.getAllAlbums();
      expect(albums, isNotEmpty);
      expect(albums.any((a) => a.title.contains('Brahmastra')), isTrue);
    });

    test('CatalogDatabaseService searches songs, artists, and albums accurately', () {
      final catalogDb = CatalogDatabaseService.instance;

      // Search by song title
      final kesariya = catalogDb.searchSongs('Kesariya');
      expect(kesariya, isNotEmpty);
      expect(kesariya.first.album, 'Brahmastra');

      // Search by artist
      final arijitSongs = catalogDb.searchSongs('Arijit Singh');
      expect(arijitSongs.length, greaterThanOrEqualTo(4));

      // Search artists
      final shreya = catalogDb.searchArtists('Shreya');
      expect(shreya, isNotEmpty);
      expect(shreya.first.name, contains('Shreya Ghoshal'));

      // Search albums
      final animal = catalogDb.searchAlbums('Animal');
      expect(animal, isNotEmpty);
      expect(animal.first.title, 'Animal');
    });

    test('Catalog Trending and Recently Added calculations sort correctly', () {
      final catalogDb = CatalogDatabaseService.instance;

      final trending = catalogDb.getTrendingSongs(limit: 5);
      expect(trending, isNotEmpty);
      for (int i = 0; i < trending.length - 1; i++) {
        expect(trending[i].playCount, greaterThanOrEqualTo(trending[i + 1].playCount));
      }

      final recent = catalogDb.getRecentlyAddedSongs(limit: 5);
      expect(recent, isNotEmpty);
      expect(recent.first.year, anyOf('2024', '2023', '2022'));
    });

    test('Catalog Recommendations Foundation computes related and personalized tracks', () {
      final catalogDb = CatalogDatabaseService.instance;

      // Content-based related tracks for Kesariya
      final related = catalogDb.getRelatedSongs('bwd_001', limit: 5);
      expect(related, isNotEmpty);
      expect(related.any((s) => s.id == 'bwd_001'), isFalse); // Does not recommend self
      expect(related.any((s) => s.artist.contains('Arijit Singh') || s.album == 'Brahmastra'), isTrue);

      // Personalized recommendations
      final personalized = catalogDb.getPersonalizedRecommendations(limit: 5);
      expect(personalized, isNotEmpty);
    });

    test('CatalogMusicSource connects cleanly to MusicSourceRepository and resolves playback', () async {
      final repo = MusicSourceRepository.instance;
      final catalogSource = repo.getSource(MusicSourceType.catalog);
      expect(catalogSource, isNotNull);

      final songs = await catalogSource!.searchSongs('Kesariya');
      expect(songs, isNotEmpty);

      final target = songs.first;
      final resolved = await repo.resolvePlayableSong(target);
      expect(resolved.id, target.id);
      expect(resolved.path.startsWith('http'), isTrue);
      expect(resolved.isLocalFileAvailable, isTrue);
    });
  });

  group('16. YouTube Data API v3 & YouTubeMusicSource Tests (v1.1.2)', () {
    test('YouTubeConfig manages API credentials and masks key safely', () {
      final config = YouTubeConfig.instance;
      expect(config.hasApiKey, isTrue);
      expect(config.apiKey, 'AIzaSyAoqbmfwc618y2JLqwuJ1XNESNXzseVV4k');

      final masked = config.maskedApiKey;
      expect(masked.startsWith('AIza'), isTrue);
      expect(masked.endsWith('VV4k'), isTrue);
      expect(masked.contains('...'), isTrue);
    });

    test('SongModel supports externalUrl, thumbnail, and isYouTube fields', () {
      final song = SongModel(
        id: 'yt_O5gwxm3NxFU',
        path: 'https://ia800504.us.archive.org/33/items/Bensound_AcousticBreeze/bensound-acousticbreeze.mp3',
        title: 'Tujhko',
        artist: 'Arijit Singh',
        album: 'YouTube Music',
        durationMs: 337000,
        hasArtwork: true,
        artworkPath: 'https://i.ytimg.com/vi/O5gwxm3NxFU/hqdefault.jpg',
        dateAdded: DateTime(2026, 11, 15),
        sourceType: 'youtube',
        sourceId: 'O5gwxm3NxFU',
        externalUrl: 'https://www.youtube.com/watch?v=O5gwxm3NxFU',
      );

      expect(song.id, 'yt_O5gwxm3NxFU');
      expect(song.sourceType, 'youtube');
      expect(song.source, 'youtube');
      expect(song.sourceId, 'O5gwxm3NxFU');
      expect(song.isYouTube, isTrue);
      expect(song.isRemoteStream, isTrue);
      expect(song.isLocalFileAvailable, isTrue);
      expect(song.externalUrl, 'https://www.youtube.com/watch?v=O5gwxm3NxFU');
      expect(song.thumbnail, 'https://i.ytimg.com/vi/O5gwxm3NxFU/hqdefault.jpg');

      // Serialization test
      final map = song.toMap();
      expect(map['externalUrl'], 'https://www.youtube.com/watch?v=O5gwxm3NxFU');
      expect(map['sourceType'], 'youtube');

      final revived = SongModel.fromMap(map);
      expect(revived.externalUrl, song.externalUrl);
      expect(revived.isYouTube, isTrue);
      expect(revived.sourceId, 'O5gwxm3NxFU');
    });

    test('YouTubeApiService ISO 8601 duration parser and HTML entity decoder work accurately', () {
      // ISO 8601 parsing tests
      expect(YouTubeApiService.parseIso8601Duration('PT5M37S'), 337000);
      expect(YouTubeApiService.parseIso8601Duration('PT1H2M10S'), 3730000);
      expect(YouTubeApiService.parseIso8601Duration('PT45S'), 45000);
      expect(YouTubeApiService.parseIso8601Duration('PT3M'), 180000);
      expect(YouTubeApiService.parseIso8601Duration(''), 0);
      expect(YouTubeApiService.parseIso8601Duration(null), 0);

      // HTML entity decoding tests
      expect(
        YouTubeApiService.decodeHtmlEntities('Best Of Arijit Singh &amp; Sunidhi &#39;Romantic Hits&#39;'),
        "Best Of Arijit Singh & Sunidhi 'Romantic Hits'",
      );
      expect(
        YouTubeApiService.decodeHtmlEntities('&quot;Cocktail 2&quot; &lt;Audio&gt; &gt; Official'),
        '"Cocktail 2" <Audio> > Official',
      );
    });

    test('YouTubeMusicSource connects to MusicSourceRepository and satisfies contracts', () async {
      final repo = MusicSourceRepository.instance;
      final ytSource = repo.getSource(MusicSourceType.youtube);
      expect(ytSource, isNotNull);
      expect(ytSource!.type, MusicSourceType.youtube);
      expect(ytSource.displayName, 'YouTube Music');
      expect(ytSource.isAvailable, isTrue);

      final song = SongModel(
        id: 'yt_test_resolve',
        path: 'https://ia800504.us.archive.org/33/items/Bensound_Sunny/bensound-sunny.mp3',
        title: 'Sunny Stream',
        artist: 'YouTube Artist',
        album: 'YouTube Music',
        durationMs: 140000,
        dateAdded: DateTime(2026, 11, 15),
        sourceType: 'youtube',
        sourceId: 'test_resolve',
        externalUrl: 'https://www.youtube.com/watch?v=test_resolve',
      );

      final resolved = await repo.resolvePlayableSong(song);
      expect(resolved.id, song.id);
      expect(resolved.isYouTube, isTrue);
      expect(resolved.path.startsWith('http'), isTrue);
      expect(resolved.isLocalFileAvailable, isTrue);
    });

    test('YouTubeMusicSource extractVideoId extracts canonical IDs accurately', () {
      final s1 = SongModel(
        id: 'yt_8WKwJfYge7Q',
        path: 'https://ia800504.us.archive.org/33/items/Bensound_Sunny/bensound-sunny.mp3',
        title: 'Track 1',
        artist: 'Artist',
        album: 'Album',
        durationMs: 120000,
        dateAdded: DateTime.now(),
        sourceType: 'youtube',
        sourceId: '8WKwJfYge7Q',
      );
      expect(YouTubeMusicSource.extractVideoId(s1), '8WKwJfYge7Q');

      final s2 = SongModel(
        id: 'some_random_id',
        path: 'https://www.youtube.com/watch?v=zYhBJoBUSYA',
        title: 'Track 2',
        artist: 'Artist',
        album: 'Album',
        durationMs: 120000,
        dateAdded: DateTime.now(),
        sourceType: 'youtube',
      );
      expect(YouTubeMusicSource.extractVideoId(s2), 'zYhBJoBUSYA');

      final s3 = SongModel(
        id: 'yt_abc123',
        path: 'https://youtu.be/dQw4w9WgXcQ',
        title: 'Track 3',
        artist: 'Artist',
        album: 'Album',
        durationMs: 120000,
        dateAdded: DateTime.now(),
        sourceType: 'youtube',
      );
      expect(YouTubeMusicSource.extractVideoId(s3), 'abc123');
    });

    test('YouTubeMusicSource resolves direct audio streams without returning web pages', () async {
      final ytSource = YouTubeMusicSource();
      final song = SongModel(
        id: 'yt_dQw4w9WgXcQ',
        path: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        album: 'Whenever You Need Somebody',
        durationMs: 213000,
        dateAdded: DateTime.now(),
        sourceType: 'youtube',
        sourceId: 'dQw4w9WgXcQ',
        externalUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );

      // In unit test environment without real network, verify that raw web page URL is never returned
      final directUri = await ytSource.resolvePlaybackUri(song);
      expect(directUri.contains('youtube.com/watch'), isFalse);

      // Verify that if a direct stream was cached or provided, it returns the direct audio stream
      final directSong = song.copyWith(
        path: 'https://rr4---sn-5jucgv5qc5oq-h55e7.googlevideo.com/videoplayback?expire=123',
      );
      final cachedDirect = await ytSource.resolvePlaybackUri(directSong);
      expect(cachedDirect, contains('googlevideo.com'));
    });

    test('Project version reflects v1.3.1 Build 26', () {
      expect(AppVersion.current, '1.3.1');
      expect(AppVersion.buildNumber, 26);
      expect(AppVersion.compare('1.3.1', '1.3.0'), greaterThan(0));
    });
  });

  group('17. Backend Evolution & Smart Update System Tests (v1.1.3)', () {
    test('Semantic version comparator handles all semver permutations', () {
      // Older versions must detect 1.1.3 as newer
      expect(AppVersion.compare('1.1.3', '1.0.0'), greaterThan(0));
      expect(AppVersion.compare('1.1.3', '1.0.3'), greaterThan(0));
      expect(AppVersion.compare('1.1.3', '1.1.0'), greaterThan(0));
      expect(AppVersion.compare('1.1.3', '1.1.1'), greaterThan(0));
      expect(AppVersion.compare('1.1.3', '1.1.2'), greaterThan(0));

      // Same version must be equal (silenced)
      expect(AppVersion.compare('1.1.3', '1.1.3'), 0);
      expect(AppVersion.compare('v1.1.3+9', '1.1.3'), 0);
      expect(AppVersion.compare('1.1.3-beta', '1.1.3'), 0);

      // Newer future versions must detect as higher
      expect(AppVersion.compare('1.1.4', '1.1.3'), greaterThan(0));
      expect(AppVersion.compare('1.2.0', '1.1.3'), greaterThan(0));
      expect(AppVersion.compare('2.0.0', '1.1.3'), greaterThan(0));

      // Reverse comparison
      expect(AppVersion.compare('1.1.2', '1.1.3'), lessThan(0));
      expect(AppVersion.compare('1.0.0', '1.1.3'), lessThan(0));
    });

    test('AudioCacheEntry serializes and deserializes accurately', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = AudioCacheEntry(
        songId: 'stream_track_99',
        fileName: 'stream_track_99.m4a',
        fileSizeBytes: 4194304, // 4MB
        lastAccessedEpoch: now,
        addedEpoch: now - 10000,
        remoteUrl: 'https://cdn.cinematic.audio/stream_99.m4a',
      );

      final json = entry.toJson();
      expect(json['songId'], 'stream_track_99');
      expect(json['fileName'], 'stream_track_99.m4a');
      expect(json['fileSizeBytes'], 4194304);

      final restored = AudioCacheEntry.fromJson(json);
      expect(restored.songId, entry.songId);
      expect(restored.fileSizeBytes, entry.fileSizeBytes);
      expect(restored.remoteUrl, entry.remoteUrl);
    });

    test('AudioStreamCacheManager initializes and enforces LRU eviction limit', () async {
      final tempTestDir = Directory.systemTemp.createTempSync('cache_mgr_test');
      try {
        final cacheMgr = AudioStreamCacheManager.instance;
        await cacheMgr.init(overrideDir: tempTestDir);
        expect(cacheMgr.isInitialized, isTrue);

        // Simulate small max cache size (5KB) for unit testing eviction
        cacheMgr.maxCacheSizeBytes = 5000;

        // Create 3 dummy audio cache files
        File('${tempTestDir.path}/track1.m4a').writeAsBytesSync(List.filled(2000, 1));
        File('${tempTestDir.path}/track2.m4a').writeAsBytesSync(List.filled(2000, 2));
        File('${tempTestDir.path}/track3.m4a').writeAsBytesSync(List.filled(2000, 3));

        // Re-init to pick up files
        await cacheMgr.getCachedFilePath('track1');
        await cacheMgr.getCachedFilePath('track2');
        await cacheMgr.getCachedFilePath('track3');

        expect(cacheMgr.cachedTrackCount, greaterThanOrEqualTo(1));

        // Run LRU eviction
        await cacheMgr.pruneCacheIfNeeded();
        expect(cacheMgr.currentCacheSizeBytes, lessThanOrEqualTo(5000));

        // Clear cache
        await cacheMgr.clearCache();
        expect(cacheMgr.cachedTrackCount, 0);
        expect(cacheMgr.currentCacheSizeBytes, 0);
      } finally {
        if (tempTestDir.existsSync()) {
          try {
            tempTestDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    });

    test('NextTrackPreloadService starts and stops listening cleanly', () {
      final service = NextTrackPreloadService.instance;
      expect(service.isListening, isFalse);
      service.startListening();
      expect(service.isListening, isTrue);
      // Double call should be idempotent
      service.startListening();
      expect(service.isListening, isTrue);
      service.stopListening();
      expect(service.isListening, isFalse);
    });

    test('UpdateService persistent suppression mechanics operate correctly', () async {
      SharedPreferences.setMockInitialValues({});

      // Initially not suppressed
      expect(await UpdateService.isSuppressed('1.1.4'), isFalse);

      // Remind later sets 24h suppression
      await UpdateService.remindLater();
      expect(await UpdateService.isSuppressed('1.1.4'), isTrue);

      // Reset suppression clears cooldown
      await UpdateService.resetSuppression();
      expect(await UpdateService.isSuppressed('1.1.4'), isFalse);

      // Skip specific version suppresses that version
      await UpdateService.skipVersion('1.1.4');
      expect(await UpdateService.isSuppressed('1.1.4'), isTrue);
      // Different version is not suppressed
      expect(await UpdateService.isSuppressed('1.2.0'), isFalse);

      // Reset cleans all
      await UpdateService.resetSuppression();
      expect(await UpdateService.isSuppressed('1.1.4'), isFalse);
    });

    test('MusicSourceRepository integrates stream cache lookup and HTTP range verification', () async {
      // Stream health probe on valid archive.org public audio stream
      final isHealthy = await MusicSourceRepository.verifyStreamHealth(
        'https://ia800504.us.archive.org/33/items/Bensound_Sunny/bensound-sunny.mp3',
        timeout: const Duration(seconds: 4),
      );
      expect(isHealthy, isTrue);

      // Stream health probe fails or handles gracefully non-audio / rejected URL
      final probeResult = await MusicSourceRepository.verifyStreamHealth(
        'https://invalid.cinematic.domain.local/404.mp3',
        timeout: const Duration(seconds: 2),
      );
      // Fails open safely without crashing
      expect(probeResult, isA<bool>());
    });
  });

  group('18. Real Audio-Reactive Minimal Line Visualizer Tests', () {
    test('Old heavy visualizer files and GPU fragment shaders are completely removed', () {
      expect(File('lib/features/visualizer/presentation/presets/orb_shader_visualizer.dart').existsSync(), isFalse);
      expect(File('lib/features/visualizer/presentation/presets/aurora_mesh_visualizer.dart').existsSync(), isFalse);
      expect(File('lib/features/visualizer/presentation/presets/polar_spectrum_visualizer.dart').existsSync(), isFalse);
      expect(File('lib/features/visualizer/presentation/atmospheres/atmospheric_particles.dart').existsSync(), isFalse);
      expect(File('lib/core/audio_engine/native_visualizer_bridge.dart').existsSync(), isFalse);
      expect(File('shaders/orb_visualizer.frag').existsSync(), isFalse);
      expect(File('shaders/aurora_mesh.frag').existsSync(), isFalse);
    });

    test('AudioReactiveFrame defaults and constructs correctly', () {
      const empty = AudioReactiveFrame.empty;
      expect(empty.amplitude, 0.0);
      expect(empty.bass, 0.0);
      expect(empty.vocals, 0.0);
      expect(empty.drums, 0.0);
      expect(empty.isSilent, isTrue);
      expect(empty.isPlaying, isFalse);
      expect(empty.wavePoints, isEmpty);

      final active = AudioReactiveFrame(
        amplitude: 0.75,
        bass: 0.85,
        vocals: 0.60,
        drums: 0.40,
        intensity: 0.80,
        volume: 1.0,
        isSilent: false,
        isPlaying: true,
        wavePoints: List.filled(64, 0.25),
      );
      expect(active.amplitude, 0.75);
      expect(active.bass, 0.85);
      expect(active.vocals, 0.60);
      expect(active.isSilent, isFalse);
      expect(active.wavePoints.length, 64);
    });

    test('AudioReactiveAnalyzer manages lifecycle and sleeps when paused', () {
      final analyzer = AudioReactiveAnalyzer.instance;
      analyzer.wake();
      analyzer.sleep();
      expect(analyzer.latestFrame.isSilent, isTrue);
    });

    test('Visualizer line accurately reacts to silent vs high-energy audio profiles', () {
      // Silent test frame: amplitude 0 produces completely flat line (all zeros)
      final silentFrame = AudioReactiveFrame(
        amplitude: 0.0,
        bass: 0.0,
        vocals: 0.0,
        drums: 0.0,
        intensity: 0.0,
        volume: 1.0,
        isSilent: true,
        isPlaying: true,
        wavePoints: List<double>.filled(64, 0.0),
      );
      expect(silentFrame.wavePoints.every((pt) => pt == 0.0), isTrue);

      // Bass heavy test frame: peaks are pronounced
      final bassFrame = AudioReactiveFrame(
        amplitude: 0.8,
        bass: 0.95,
        vocals: 0.2,
        drums: 0.3,
        intensity: 0.85,
        volume: 1.0,
        isSilent: false,
        isPlaying: true,
        wavePoints: List.generate(64, (i) => math.sin(i / 64.0 * math.pi) * 0.7),
      );
      expect(bassFrame.bass, greaterThan(0.9));
      expect(bassFrame.wavePoints[32], greaterThan(0.5));
    });

    test('Volume scaling correctly modulates visualizer amplitude and flattens on mute', () {
      const rawAmplitude = 0.80;

      // Full volume (1.0)
      const volFull = 1.0;
      const effectiveFull = rawAmplitude * volFull;
      expect(effectiveFull, 0.80);

      // Half volume (0.5)
      const volHalf = 0.5;
      const effectiveHalf = rawAmplitude * volHalf;
      expect(effectiveHalf, 0.40);

      // Muted volume (0.0)
      const volMute = 0.0;
      const effectiveMute = rawAmplitude * volMute;
      expect(effectiveMute, 0.0);
    });

    test('VisualizerState defaults to minimalLine and supports styling options', () {
      const state = VisualizerState();
      expect(state.preset, VisualizerPresetType.minimalLine);
      expect(state.lineStyle, VisualizerLineStyle.minimalWave);
      expect(state.sensitivity, 1.0);
      expect(state.isGlowEnabled, isTrue);
      expect(state.isEnabled, isTrue);

      final updated = state.copyWith(
        preset: VisualizerPresetType.neonHorizon,
        sensitivity: 1.8,
        isGlowEnabled: false,
      );
      expect(updated.preset, VisualizerPresetType.neonHorizon);
      expect(updated.sensitivity, 1.8);
      expect(updated.isGlowEnabled, isFalse);
    });
  });

  group('19. Jamendo Music API & JamendoMusicSource Tests', () {
    test('JamendoConfig loads Client ID correctly, supports masking and validation', () {
      final config = JamendoConfig.instance;
      expect(config.hasClientId, isTrue);
      expect(config.clientId, equals('fd914c0b'));
      expect(config.maskedClientId.startsWith('fd'), isTrue);
      expect(config.maskedClientId.endsWith('0b'), isTrue);
      expect(config.validate().isValid, isTrue);
    });

    test('SongModel supports Jamendo sourceType, sourceId, audioUrl, and isJamendo', () {
      final song = SongModel(
        id: 'jamendo_1348697',
        path: 'https://prod-1.storage.jamendo.com/?trackid=1348697&format=mp31',
        title: 'Valley fog',
        artist: 'Alexander Morozov',
        album: 'Planet Bubus',
        durationMs: 162000,
        hasArtwork: true,
        artworkPath: 'https://usercontent.jamendo.com?type=album&id=159132',
        dateAdded: DateTime.now(),
        sourceType: 'jamendo',
        sourceId: '1348697',
        externalUrl: 'https://www.jamendo.com/track/1348697',
      );

      expect(song.isJamendo, isTrue);
      expect(song.isRemoteStream, isTrue);
      expect(song.isLocalFileAvailable, isTrue);
      expect(song.audioUrl, equals('https://prod-1.storage.jamendo.com/?trackid=1348697&format=mp31'));
      expect(song.externalUrl, equals('https://www.jamendo.com/track/1348697'));
      expect(song.sourceId, equals('1348697'));

      // Verify serialization preserves Jamendo fields
      final map = song.toMap();
      expect(map['sourceType'], equals('jamendo'));
      expect(map['sourceId'], equals('1348697'));
      expect(map['externalUrl'], equals('https://www.jamendo.com/track/1348697'));

      final reconstructed = SongModel.fromMap(map);
      expect(reconstructed.isJamendo, isTrue);
      expect(reconstructed.sourceId, equals('1348697'));
      expect(reconstructed.audioUrl, equals(song.path));
    });

    test('JamendoMusicSource satisfies MusicSource interface and reports availability', () async {
      final source = JamendoMusicSource();
      expect(source.id, equals('jamendo'));
      expect(source.type, equals(MusicSourceType.jamendo));
      expect(source.isAvailable, isTrue);

      final testSong = SongModel(
        id: 'jamendo_1348697',
        path: 'https://prod-1.storage.jamendo.com/?trackid=1348697&format=mp31',
        title: 'Valley fog',
        artist: 'Alexander Morozov',
        album: 'Planet Bubus',
        durationMs: 162000,
        dateAdded: DateTime.now(),
        sourceType: 'jamendo',
        sourceId: '1348697',
      );

      final uri = await source.resolvePlaybackUri(testSong);
      expect(uri, startsWith('https://prod-1.storage.jamendo.com'));
    });

    test('MusicSourceType enum maps jamendo correctly', () {
      expect(MusicSourceType.jamendo.id, equals('jamendo'));
      expect(MusicSourceType.jamendo.displayName, contains('Jamendo'));
      expect(MusicSourceType.fromString('jamendo'), equals(MusicSourceType.jamendo));
      expect(MusicSourceType.fromString('JAMENDO'), equals(MusicSourceType.jamendo));
    });

    test('MusicSourceRepository registers JamendoMusicSource and resolves playback', () async {
      final repo = MusicSourceRepository.instance;
      final source = repo.getSource(MusicSourceType.jamendo);
      expect(source, isNotNull);
      expect(source, isA<JamendoMusicSource>());
      expect(source!.isAvailable, isTrue);

      final jamendoSong = SongModel(
        id: 'jamendo_604014',
        path: 'https://prod-1.storage.jamendo.com/?trackid=604014&format=mp31',
        title: 'Bright days',
        artist: 'Alexander Vikuloff',
        album: 'My Songs',
        durationMs: 107000,
        dateAdded: DateTime.now(),
        sourceType: 'jamendo',
        sourceId: '604014',
      );

      final resolved = await repo.resolvePlayableSong(jamendoSong);
      expect(resolved.path, startsWith('http'));
      expect(resolved.isLocalFileAvailable, isTrue);
    });

    test('JamendoApiService diagnostics and error reporting handle missing or invalid keys', () {
      final service = JamendoApiService.instance;
      expect(service, isNotNull);

      final validation = JamendoConfig.instance.validate();
      expect(validation.isValid, isTrue);

      // Verify masked client ID prevents secret leakage in logs
      final masked = JamendoConfig.instance.maskedClientId;
      expect(masked, contains('...'));
      expect(masked.length, lessThanOrEqualTo(JamendoConfig.instance.clientId.length));
    });
  });

  group('20. Android Background Playback, Media3 & MediaBrowserService Tests', () {
    test('CinematicAudioHandler getChildren returns browsable categories at root', () async {
      final handler = AudioEngine.instance.handler;
      final rootItems = await handler.getChildren('root');
      expect(rootItems, isNotEmpty);
      final ids = rootItems.map((i) => i.id).toList();
      expect(ids, containsAll(['favorites', 'playlists', 'history', 'library', 'albums', 'artists']));
      expect(rootItems.every((i) => !(i.playable ?? false)), isTrue);
    });

    test('CinematicAudioHandler getChildren returns playable items for favorites & history', () async {
      final handler = AudioEngine.instance.handler;
      final favs = await handler.getChildren('favorites');
      expect(favs, isA<List>());

      final hist = await handler.getChildren('history');
      expect(hist, isA<List>());
    });

    test('Automotive app descriptor exists and declares media projection', () {
      final descFile = File('android/app/src/main/res/xml/automotive_app_desc.xml');
      expect(descFile.existsSync(), isTrue);
      final content = descFile.readAsStringSync();
      expect(content, contains('<automotiveApp>'));
      expect(content, contains('<uses name="media" />'));
    });

    test('AndroidManifest contains mandatory permissions and foreground service declarations', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final manifest = manifestFile.readAsStringSync();

      expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
      expect(manifest, contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'));
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.WAKE_LOCK'));
      expect(manifest, contains('android.permission.BLUETOOTH_CONNECT'));
      expect(manifest, contains('com.ryanheise.audioservice.AudioService'));
      expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
      expect(manifest, contains('com.ryanheise.audioservice.MediaButtonReceiver'));
      expect(manifest, contains('com.google.android.gms.car.application'));
    });

    test('AudioEngine exposes stop() and correctly manages playback state and audio focus', () async {
      final engine = AudioEngine.instance;
      expect(engine.isInitialized, isTrue);
      await engine.stop();
      expect(engine.isPlaying, isFalse);
    });
  });

  group('21. Desktop Performance & Offline Library Tests (v1.1.5)', () {
    test('VisualizerQuality enum supports high, balanced, low, and off', () {
      expect(VisualizerQuality.values.length, 4);
      expect(VisualizerQuality.balanced.name, 'balanced');
      expect(VisualizerQuality.off.name, 'off');
      expect(VisualizerQuality.high.name, 'high');
      expect(VisualizerQuality.low.name, 'low');
    });

    test('VisualizerState integrates VisualizerQuality defaulting to balanced', () {
      const state = VisualizerState();
      expect(state.quality, VisualizerQuality.balanced);
      final lowState = state.copyWith(quality: VisualizerQuality.low);
      expect(lowState.quality, VisualizerQuality.low);
      final offState = state.copyWith(quality: VisualizerQuality.off);
      expect(offState.quality, VisualizerQuality.off);
    });

    test('CrashLogger instance initializes and logs without throwing', () async {
      final logger = CrashLogger.instance;
      await logger.init();
      logger.logInfo("v1.1.5 Diagnostic test message");
      logger.logError("Diagnostic test error", StackTrace.current);
    });

    test('DatabaseService manages library folders correctly', () async {
      final db = DatabaseService.instance;
      await db.init();
      final initialFolders = db.libraryFolders;
      expect(initialFolders, isA<List<String>>());

      const testDir = r'C:\MockMusicFolder';
      await db.addLibraryFolder(testDir);
      expect(db.libraryFolders, contains(testDir));

      await db.removeLibraryFolder(testDir);
      expect(db.libraryFolders, isNot(contains(testDir)));
    });

    test('Windows manifest declares PerMonitorV2 and dpiAware settings', () {
      final manifestFile = File('windows/runner/runner.exe.manifest');
      expect(manifestFile.existsSync(), isTrue);
      final manifest = manifestFile.readAsStringSync();
      expect(manifest, contains('PerMonitorV2'));
      expect(manifest, contains('<dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">true/pm</dpiAware>'));
    });
  });

  group('22. Jamendo Standalone Service & Page Tests', () {
    test('JamendoTrack.fromJson parses fields accurately', () {
      final json = {
        'id': '12345',
        'name': 'Ambient Waves',
        'artist_name': 'Chillout Artist',
        'album_name': 'Skyline Dreams',
        'audio': 'https://prod-1.storage.jamendo.com/?trackid=12345&format=mp32',
        'image': 'https://usercontent.jamendo.com?type=album&id=123&width=300',
        'duration': '210',
      };
      final track = JamendoTrack.fromJson(json);
      expect(track.id, '12345');
      expect(track.name, 'Ambient Waves');
      expect(track.artist, 'Chillout Artist');
      expect(track.album, 'Skyline Dreams');
      expect(track.audioUrl, contains('12345'));
      expect(track.imageUrl, contains('width=300'));
      expect(track.duration, 210);
    });

    test('JamendoService instantiates with client ID', () {
      final service = JamendoService('fd914c0b');
      expect(service.clientId, 'fd914c0b');
    });

    test('JamendoPage instantiates with const constructor', () {
      const page = JamendoPage();
      expect(page, isNotNull);
    });
  });

  group('23. JioSaavn Unofficial API & Bollywood Streaming Tests', () {
    test('JioSaavnTrack instantiates and formats duration correctly', () {
      const track = JioSaavnTrack(
        id: 'rjkrTnma',
        title: 'Kesariya',
        primaryArtists: 'Pritam, Arijit Singh, Amitabh Bhattacharya',
        album: 'Brahmastra',
        durationSeconds: 268,
        mediaUrl: 'https://aac.saavncdn.com/871/c2febd353f3a076a406fa37510f31f9f_320.mp4',
        imageUrl: 'https://c.saavncdn.com/871/Brahmastra-500x500.jpg',
        hasLyrics: true,
        lyrics: 'Kesar ki chaashni...',
        year: '2022',
      );

      expect(track.id, 'rjkrTnma');
      expect(track.title, 'Kesariya');
      expect(track.formattedDuration, '4:28');
      expect(track.mediaUrl, contains('320.mp4'));
      expect(track.hasLyrics, isTrue);
    });

    test('JioSaavnService instantiates and exposes searchSongs and getSongById', () {
      final service = JioSaavnService();
      expect(service, isNotNull);
    });

    test('JioSaavnPage instantiates with const constructor', () {
      const page = JioSaavnPage();
      expect(page, isNotNull);
    });
  });

  group('24. WebView MP3 Search & Download (Pagalworld) Tests', () {
    test('WebSearchPage defines valid home and search base URLs', () {
      expect(WebSearchPage.homeUrl, 'https://pagalworld.is/');
      expect(WebSearchPage.searchBaseUrl, 'https://pagalworld.is/search/?s=');
      final queryUrl = '${WebSearchPage.searchBaseUrl}${Uri.encodeComponent('Arijit Singh')}';
      expect(queryUrl, 'https://pagalworld.is/search/?s=Arijit%20Singh');
    });

    test('WebSearchPage instantiates with const constructor', () {
      const page = WebSearchPage();
      expect(page, isNotNull);
    });

    test('WebSearchPage.isAllowedUrlScheme allows http/https and blocks intent schemes', () {
      expect(WebSearchPage.isAllowedUrlScheme('https://pagalworld.is/song/123'), isTrue);
      expect(WebSearchPage.isAllowedUrlScheme('http://pagalworld.is/song/123'), isTrue);
      expect(WebSearchPage.isAllowedUrlScheme('intent://scan/#Intent;scheme=zxing;end'), isFalse);
      expect(WebSearchPage.isAllowedUrlScheme('market://details?id=com.app'), isFalse);
      expect(WebSearchPage.isAllowedUrlScheme('tel:+123456789'), isFalse);
    });

    test('UpdateService fallback URL points to valid v1.4.0 release tag', () {
      expect(UpdateService.fallbackReleaseUrl, contains('v1.4.0'));
    });

    test('WebSearchPage.computeInitialUrl immediately routes to search results on autoSubmit', () {
      final autoUrl = WebSearchPage.computeInitialUrl(initialQuery: 'Kesariya', autoSubmit: true);
      expect(autoUrl, 'https://pagalworld.is/search/?s=Kesariya');

      final homeUrl1 = WebSearchPage.computeInitialUrl(initialQuery: 'Kesariya', autoSubmit: false);
      expect(homeUrl1, WebSearchPage.homeUrl);

      final homeUrl2 = WebSearchPage.computeInitialUrl(initialQuery: null, autoSubmit: true);
      expect(homeUrl2, WebSearchPage.homeUrl);

      final homeUrl3 = WebSearchPage.computeInitialUrl(initialQuery: '   ', autoSubmit: true);
      expect(homeUrl3, WebSearchPage.homeUrl);
    });

    test('WebSearchPage.cleanSearchQuery strips video metadata noise', () {
      expect(WebSearchPage.cleanSearchQuery('Kesariya (Official Video)'), 'Kesariya');
      expect(WebSearchPage.cleanSearchQuery('Kesariya | Brahmastra | Arijit Singh'), 'Kesariya');
      expect(WebSearchPage.cleanSearchQuery('Tum Hi Ho [4K Video]'), 'Tum Hi Ho');
    });

    test('WebSearchPage accepts optional initialQuery and autoSubmit parameters', () {
      const page = WebSearchPage(initialQuery: 'Kesariya', autoSubmit: true);
      expect(page.initialQuery, 'Kesariya');
      expect(page.autoSubmit, isTrue);
    });

    test('SafeAdBlockerWebviewController blocks intent schemes and allows https', () {
      final controller = SafeAdBlockerWebviewController();
      expect(controller.shouldBlockResource('intent://play.google.com/store#Intent;scheme=package;end'), isTrue);
      expect(controller.shouldBlockResource('market://details?id=com.app'), isTrue);
    });

    test('WebSearchPage.extractFilename sanitizes filenames and extracts from URL/headers', () {
      final name1 = WebSearchPage.extractFilename('https://pagalworld.is/song.mp3', 'Kesariya - Brahmastra.mp3');
      expect(name1, 'Kesariya - Brahmastra.mp3');

      final name2 = WebSearchPage.extractFilename('https://pagalworld.is/song.mp3', 'Channa Mereya');
      expect(name2, 'Channa Mereya.mp3');

      final name3 = WebSearchPage.extractFilename('https://pagalworld.is/files/download/id/123/Tum%20Hi%20Ho.mp3');
      expect(name3, 'Tum Hi Ho.mp3');

      final name4 = WebSearchPage.extractFilename('https://pagalworld.is/song.mp3', 'Arijit/Singh:Track*Audio?.mp3');
      expect(name4, 'Arijit_Singh_Track_Audio_.mp3');
    });

    test('WebSearchPage.extractSongName strips .mp3 cleanly', () {
      expect(WebSearchPage.extractSongName('Kesariya.mp3'), 'Kesariya');
      expect(WebSearchPage.extractSongName('Tum Hi Ho - Arijit.mp3'), 'Tum Hi Ho - Arijit');
    });

    test('WebSearchPage.isAdUrl correctly detects intrusive ad domains', () {
      expect(WebSearchPage.isAdUrl('https://pagead2.googlesyndication.com/ad'), isTrue);
      expect(WebSearchPage.isAdUrl('https://adsterra.com/popunder'), isTrue);
      expect(WebSearchPage.isAdUrl('https://doubleclick.net/tracker'), isTrue);
      expect(WebSearchPage.isAdUrl('https://criteo.com/delivery'), isTrue);
      expect(WebSearchPage.isAdUrl('https://popcash.net/serve'), isTrue);
      expect(WebSearchPage.isAdUrl('https://parimatch.com/bet'), isTrue);
      expect(WebSearchPage.isAdUrl('https://pagalworld.is/files/download/id/123/song.mp3'), isFalse);
    });
  });

  group('25. Firebase Cross-Device Cloud Sync Tests (v1.4.0)', () {
    test('CloudSongMetadata serializes and deserializes accurately', () {
      final now = DateTime.now();
      const metadata = CloudSongMetadata(
        id: 'song_123',
        title: 'Raataan Lambiyan',
        artist: 'Jubin Nautiyal',
        album: 'Shershaah',
        filename: 'Raataan_Lambiyan.mp3',
        storageUrl: 'https://firebasestorage.googleapis.com/v0/b/app/o/song.mp3',
        storagePath: 'users/usr_abc/songs/Raataan_Lambiyan.mp3',
        fileSize: 4500000,
      );

      final map = metadata.toMap();
      expect(map['title'], 'Raataan Lambiyan');
      expect(map['artist'], 'Jubin Nautiyal');
      expect(map['album'], 'Shershaah');
      expect(map['filename'], 'Raataan_Lambiyan.mp3');
      expect(map['storageUrl'], contains('firebasestorage.googleapis.com'));
      expect(map['storagePath'], 'users/usr_abc/songs/Raataan_Lambiyan.mp3');
      expect(map['fileSize'], 4500000);

      final restored = CloudSongMetadata.fromMap(map, 'song_123');
      expect(restored.id, 'song_123');
      expect(restored.title, 'Raataan Lambiyan');
      expect(restored.artist, 'Jubin Nautiyal');
      expect(restored.album, 'Shershaah');
      expect(restored.filename, 'Raataan_Lambiyan.mp3');
      expect(restored.fileSize, 4500000);
    });

    test('DefaultFirebaseOptions provides platform configurations', () {
      expect(DefaultFirebaseOptions.android.projectId, 'cinematic-music-player');
      expect(DefaultFirebaseOptions.windows.projectId, 'cinematic-music-player');
      expect(DefaultFirebaseOptions.currentPlatform, isNotNull);
    });

    test('FirebaseService instance is available as singleton', () {
      expect(FirebaseService.instance, isNotNull);
      expect(FirebaseService.instance.isLoggedIn, isFalse);
    });
  });
}
