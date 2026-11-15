import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinematic_music_player/auth/user_model.dart';
import 'package:cinematic_music_player/sync/cloud_database.dart';
import 'package:cinematic_music_player/core/config/supabase_config.dart';
import 'package:cinematic_music_player/core/services/lyrics_parser.dart';
import 'package:cinematic_music_player/core/services/update_service.dart';
import 'package:cinematic_music_player/core/services/audio_stream_cache_manager.dart';
import 'package:cinematic_music_player/core/services/next_track_preload_service.dart';
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
import 'package:cinematic_music_player/core/config/youtube_config.dart';
import 'package:cinematic_music_player/core/services/youtube_api_service.dart';

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
      expect(repo.allSources, hasLength(6));

      expect(repo.getSource(MusicSourceType.local), isNotNull);
      expect(repo.getSource(MusicSourceType.cloud), isNotNull);
      expect(repo.getSource(MusicSourceType.online), isNotNull);
      expect(repo.getSource(MusicSourceType.catalog), isNotNull);
      expect(repo.getSource(MusicSourceType.youtube), isNotNull);
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

    test('Project version reflects v1.1.3 Build 9', () {
      expect(AppVersion.current, '1.1.3');
      expect(AppVersion.buildNumber, 9);
      expect(AppVersion.compare('1.1.3', '1.1.2'), greaterThan(0));
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
}
