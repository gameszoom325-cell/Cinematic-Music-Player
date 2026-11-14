import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_service.dart';
import '../core/database/models/playlist_model.dart';
import '../auth/session_manager.dart';
import 'cloud_database.dart';

/// Core cloud synchronization logic.
/// Handles packaging, diffing, two-way merging, and cross-device reconciliation.
class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  /// Perform a full bidirectional cloud synchronization.
  Future<bool> syncAll(String userId) async {
    if (userId.isEmpty || userId == 'guest_vault_user') return false;

    try {
      final db = DatabaseService.instance;
      final prefs = await SharedPreferences.getInstance();

      // 1. Fetch current cloud payload
      final cloudPayload = await CloudDatabase.instance.fetchSyncPayload(userId);

      // 2. Build local snapshot
      final localPayload = await _buildLocalPayload(userId, db, prefs);

      // 3. Reconcile / Merge
      final mergedPayload = _mergePayloads(userId, localPayload, cloudPayload, db);

      // 4. Apply merged state to local device
      await _applyPayloadLocally(mergedPayload, db, prefs);

      // 5. Upload merged snapshot to cloud
      final uploaded = await CloudDatabase.instance.uploadSyncPayload(userId, mergedPayload);

      // 6. Update device heartbeat and sync timestamp
      final now = DateTime.now();
      await SessionManager.instance.setLastSyncTime(now);

      final device = DeviceModel(
        deviceId: SessionManager.instance.deviceId,
        deviceName: SessionManager.instance.deviceName,
        platform: SessionManager.instance.getPlatform(),
        lastSyncTime: now,
        appVersion: '1.0.0',
        isCurrentDevice: true,
      );
      await CloudDatabase.instance.registerOrUpdateDevice(userId, device);

      return uploaded;
    } catch (e, stack) {
      debugPrint("SyncService.syncAll failed: $e\n$stack");
      return false;
    }
  }

  /// Package current local state into a CloudSyncPayload
  Future<CloudSyncPayload> _buildLocalPayload(
    String userId,
    DatabaseService db,
    SharedPreferences prefs,
  ) async {
    final allSongs = db.getAllSongs();
    final allPlaylists = db.getAllPlaylists();
    final favSongs = db.getFavorites();
    final recentSongs = db.getRecentlyPlayedSongs();

    // Map song ID to title/artist signature for cross-device resolution
    final Map<String, String> idToSignature = {
      for (final s in allSongs) s.id: "${s.title.trim().toLowerCase()}:::${s.artist.trim().toLowerCase()}"
    };

    // 1. Playlists
    final List<Map<String, dynamic>> playlistsList = allPlaylists.map((pl) {
      final songSignatures = pl.songIds.map((id) => idToSignature[id] ?? id).toList();
      return {
        'id': pl.id,
        'name': pl.name,
        'description': pl.description,
        'songIds': pl.songIds,
        'songSignatures': songSignatures,
        'createdAt': pl.createdAt.toIso8601String(),
        'updatedAt': pl.updatedAt.toIso8601String(),
        'isSmartPlaylist': pl.isSmartPlaylist,
      };
    }).toList();

    // 2. Favorites
    final List<Map<String, dynamic>> favList = favSongs.map((s) {
      return {
        'id': s.id,
        'title': s.title,
        'artist': s.artist,
        'album': s.album,
        'signature': "${s.title.trim().toLowerCase()}:::${s.artist.trim().toLowerCase()}",
      };
    }).toList();

    // 3. Recently played
    final List<Map<String, dynamic>> recentList = recentSongs.map((s) {
      return {
        'id': s.id,
        'title': s.title,
        'artist': s.artist,
        'signature': "${s.title.trim().toLowerCase()}:::${s.artist.trim().toLowerCase()}",
        'lastPlayedAt': s.lastPlayedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      };
    }).toList();

    // 4. Listening history (play counts)
    final Map<String, dynamic> historyMap = {};
    for (final s in allSongs) {
      if (s.playCount > 0) {
        final sig = "${s.title.trim().toLowerCase()}:::${s.artist.trim().toLowerCase()}";
        historyMap[sig] = s.playCount;
      }
    }

    // 5. User preferences
    final userPrefs = {
      'shuffleMode': prefs.getBool('cinematic_shuffle_mode') ?? false,
      'repeatMode': prefs.getString('cinematic_repeat_mode') ?? 'all',
      'volume': prefs.getDouble('cinematic_volume') ?? 1.0,
    };

    // 6. Visualizer settings
    final vizSettings = {
      'preset': prefs.getString('cinematic_visualizer_preset') ?? 'orb3d',
      'atmosphere': prefs.getString('cinematic_atmosphere_type') ?? 'rain',
      'sensitivity': prefs.getDouble('cinematic_visualizer_sensitivity') ?? 1.0,
    };

    // 7. Theme settings
    final themeSettings = {
      'accentColor': prefs.getInt('cinematic_accent_color') ?? 0xFF8B5CF6,
      'glassBlur': prefs.getDouble('cinematic_glass_blur') ?? 24.0,
      'glassOpacity': prefs.getDouble('cinematic_glass_opacity') ?? 0.08,
    };

    // 8. Lyrics preferences
    final lyricsPrefs = {
      'fontSize': prefs.getDouble('cinematic_lyrics_font_size') ?? 24.0,
      'autoScroll': prefs.getBool('cinematic_lyrics_auto_scroll') ?? true,
      'activeLineBloom': prefs.getBool('cinematic_lyrics_bloom') ?? true,
      'tapToSeek': prefs.getBool('cinematic_lyrics_tap_seek') ?? true,
    };

    return CloudSyncPayload(
      userId: userId,
      version: 1,
      updatedAt: DateTime.now(),
      playlists: playlistsList,
      favorites: favList,
      recentlyPlayed: recentList,
      listeningHistory: historyMap,
      userPreferences: userPrefs,
      visualizerSettings: vizSettings,
      themeSettings: themeSettings,
      lyricsPreferences: lyricsPrefs,
    );
  }

  /// Two-way merge combining local and remote snapshots with Last-Write-Wins arbitration
  CloudSyncPayload _mergePayloads(
    String userId,
    CloudSyncPayload local,
    CloudSyncPayload? cloud,
    DatabaseService db,
  ) {
    if (cloud == null) return local;

    // 1. Playlists union
    final Map<String, Map<String, dynamic>> mergedPlaylists = {};
    for (final pl in local.playlists) {
      mergedPlaylists[pl['id'] as String] = pl;
    }
    for (final cPl in cloud.playlists) {
      final id = cPl['id'] as String;
      if (!mergedPlaylists.containsKey(id)) {
        mergedPlaylists[id] = cPl;
      } else {
        // Resolve conflict by updatedAt
        final localUpdated = DateTime.tryParse(mergedPlaylists[id]!['updatedAt'] as String? ?? '') ?? DateTime(2000);
        final cloudUpdated = DateTime.tryParse(cPl['updatedAt'] as String? ?? '') ?? DateTime(2000);
        if (cloudUpdated.isAfter(localUpdated)) {
          mergedPlaylists[id] = cPl;
        }
      }
    }

    // 2. Favorites union
    final Map<String, Map<String, dynamic>> mergedFavs = {};
    for (final f in local.favorites) {
      final sig = f['signature'] as String? ?? f['id'] as String;
      mergedFavs[sig] = f;
    }
    for (final f in cloud.favorites) {
      final sig = f['signature'] as String? ?? f['id'] as String;
      mergedFavs[sig] = f;
    }

    // 3. Listening History merge (take highest play count)
    final Map<String, dynamic> mergedHistory = Map.from(local.listeningHistory);
    cloud.listeningHistory.forEach((sig, count) {
      final localCount = (mergedHistory[sig] as int?) ?? 0;
      final cloudCount = (count as int?) ?? 0;
      mergedHistory[sig] = localCount > cloudCount ? localCount : cloudCount;
    });

    // 4. Recently played merge (interleave by lastPlayedAt)
    final List<Map<String, dynamic>> combinedRecents = [
      ...local.recentlyPlayed,
      ...cloud.recentlyPlayed,
    ];
    combinedRecents.sort((a, b) {
      final da = DateTime.tryParse(a['lastPlayedAt'] as String? ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['lastPlayedAt'] as String? ?? '') ?? DateTime(2000);
      return db.compareTo(da);
    });

    final Set<String> seenSigs = {};
    final List<Map<String, dynamic>> mergedRecents = [];
    for (final r in combinedRecents) {
      final sig = r['signature'] as String? ?? r['id'] as String;
      if (!seenSigs.contains(sig)) {
        seenSigs.add(sig);
        mergedRecents.add(r);
        if (mergedRecents.length >= 100) break;
      }
    }

    // 5. Settings: Cloud wins if cloud is newer than local, else local
    final isCloudNewer = cloud.updatedAt.isAfter(local.updatedAt);
    final mergedUserPrefs = isCloudNewer ? cloud.userPreferences : local.userPreferences;
    final mergedVizSettings = isCloudNewer ? cloud.visualizerSettings : local.visualizerSettings;
    final mergedThemeSettings = isCloudNewer ? cloud.themeSettings : local.themeSettings;
    final mergedLyricsPrefs = isCloudNewer ? cloud.lyricsPreferences : local.lyricsPreferences;

    return CloudSyncPayload(
      userId: userId,
      version: (cloud.version > local.version ? cloud.version : local.version) + 1,
      updatedAt: DateTime.now(),
      playlists: mergedPlaylists.values.toList(),
      favorites: mergedFavs.values.toList(),
      recentlyPlayed: mergedRecents,
      listeningHistory: mergedHistory,
      userPreferences: mergedUserPrefs,
      visualizerSettings: mergedVizSettings,
      themeSettings: mergedThemeSettings,
      lyricsPreferences: mergedLyricsPrefs,
    );
  }

  /// Write merged payload data into local database and SharedPreferences
  Future<void> _applyPayloadLocally(
    CloudSyncPayload payload,
    DatabaseService db,
    SharedPreferences prefs,
  ) async {
    try {
      final allSongs = db.getAllSongs();
      final Map<String, String> sigToSongId = {
        for (final s in allSongs) "${s.title.trim().toLowerCase()}:::${s.artist.trim().toLowerCase()}": s.id
      };

      // 1. Apply Playlists
      final List<PlaylistModel> playlistsToApply = [];
      for (final pMap in payload.playlists) {
        final rawSongIds = (pMap['songIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final rawSigs = (pMap['songSignatures'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

        // Map signatures to local song IDs when possible
        final Set<String> resolvedSongIds = Set.from(rawSongIds.where((id) => db.getSongById(id) != null));
        for (final sig in rawSigs) {
          final localId = sigToSongId[sig];
          if (localId != null) resolvedSongIds.add(localId);
        }

        final playlistId = pMap['id']?.toString() ?? 'pl_${DateTime.now().millisecondsSinceEpoch}';
        final playlistName = pMap['name']?.toString() ?? 'Playlist';
        final isSmart = pMap['isSmartPlaylist'] == true || pMap['isSmartPlaylist'] == 1 || pMap['isSmartPlaylist'] == 'true';

        playlistsToApply.add(
          PlaylistModel(
            id: playlistId,
            name: playlistName,
            description: pMap['description']?.toString() ?? '',
            songIds: resolvedSongIds.toList(),
            createdAt: DateTime.tryParse(pMap['createdAt']?.toString() ?? '') ?? DateTime.now(),
            updatedAt: DateTime.tryParse(pMap['updatedAt']?.toString() ?? '') ?? DateTime.now(),
            isSmartPlaylist: isSmart,
          ),
        );
      }
      await db.applyCloudPlaylists(playlistsToApply);

      // 2. Apply Favorites
      final Set<String> favSignatures = {};
      for (final f in payload.favorites) {
        final sig = f['signature']?.toString() ?? '';
        if (sig.isNotEmpty) favSignatures.add(sig);
        final id = f['id']?.toString() ?? '';
        if (id.isNotEmpty) favSignatures.add(id);
      }
      await db.applyCloudFavorites(favSignatures);

      // 3. Apply History & Recents
      final Map<String, int> playCounts = {};
      payload.listeningHistory.forEach((k, v) {
        if (v is num) playCounts[k] = v.toInt();
      });

      final List<String> recentSignatures = payload.recentlyPlayed
          .map((r) => r['signature']?.toString() ?? r['id']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      await db.applyCloudHistory(playCounts, recentSignatures);

      // 4. Apply Preferences & Settings to SharedPreferences
      final up = payload.userPreferences;
      if (up.containsKey('shuffleMode') && up['shuffleMode'] is bool) {
        await prefs.setBool('cinematic_shuffle_mode', up['shuffleMode'] as bool);
      }
      if (up.containsKey('repeatMode') && up['repeatMode'] != null) {
        await prefs.setString('cinematic_repeat_mode', up['repeatMode'].toString());
      }
      if (up.containsKey('volume') && up['volume'] is num) {
        await prefs.setDouble('cinematic_volume', (up['volume'] as num).toDouble());
      }

      final vs = payload.visualizerSettings;
      if (vs.containsKey('preset') && vs['preset'] != null) {
        await prefs.setString('cinematic_visualizer_preset', vs['preset'].toString());
      }
      if (vs.containsKey('atmosphere') && vs['atmosphere'] != null) {
        await prefs.setString('cinematic_atmosphere_type', vs['atmosphere'].toString());
      }
      if (vs.containsKey('sensitivity') && vs['sensitivity'] is num) {
        await prefs.setDouble('cinematic_visualizer_sensitivity', (vs['sensitivity'] as num).toDouble());
      }

      final ts = payload.themeSettings;
      if (ts.containsKey('accentColor') && ts['accentColor'] is num) {
        await prefs.setInt('cinematic_accent_color', (ts['accentColor'] as num).toInt());
      }
      if (ts.containsKey('glassBlur') && ts['glassBlur'] is num) {
        await prefs.setDouble('cinematic_glass_blur', (ts['glassBlur'] as num).toDouble());
      }
      if (ts.containsKey('glassOpacity') && ts['glassOpacity'] is num) {
        await prefs.setDouble('cinematic_glass_opacity', (ts['glassOpacity'] as num).toDouble());
      }

      final lp = payload.lyricsPreferences;
      if (lp.containsKey('fontSize') && lp['fontSize'] is num) {
        await prefs.setDouble('cinematic_lyrics_font_size', (lp['fontSize'] as num).toDouble());
      }
      if (lp.containsKey('autoScroll') && lp['autoScroll'] is bool) {
        await prefs.setBool('cinematic_lyrics_auto_scroll', lp['autoScroll'] as bool);
      }
      if (lp.containsKey('activeLineBloom') && lp['activeLineBloom'] is bool) {
        await prefs.setBool('cinematic_lyrics_bloom', lp['activeLineBloom'] as bool);
      }
      if (lp.containsKey('tapToSeek') && lp['tapToSeek'] is bool) {
        await prefs.setBool('cinematic_lyrics_tap_seek', lp['tapToSeek'] as bool);
      }
    } catch (e, stack) {
      debugPrint("Warning: _applyPayloadLocally encountered error (continuing safely): $e\n$stack");
    }
  }
}
