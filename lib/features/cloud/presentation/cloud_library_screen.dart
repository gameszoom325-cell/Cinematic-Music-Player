import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/services/cloud_music_service.dart';
import '../../../core/database/models/cloud_song_model.dart';
import '../../../core/database/models/cloud_artist_model.dart';
import '../../../core/database/models/cloud_album_model.dart';
import '../../../core/database/database_service.dart';
import '../../../core/catalog/catalog_database_service.dart';
import '../../player/providers/player_provider.dart';
import '../../library/presentation/music_search_screen.dart';
import 'admin_upload_screen.dart';

class CloudLibraryScreen extends ConsumerStatefulWidget {
  const CloudLibraryScreen({super.key});

  @override
  ConsumerState<CloudLibraryScreen> createState() => _CloudLibraryScreenState();
}

class _CloudLibraryScreenState extends ConsumerState<CloudLibraryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<CloudSongModel> _allSongs = [];
  List<CloudSongModel> _trendingSongs = [];
  List<CloudSongModel> _recentSongs = [];
  List<CloudArtistModel> _artists = [];
  List<CloudAlbumModel> _albums = [];

  bool _isLoading = true;
  String _activeCategory = "All";
  String? _selectedArtistFilter;
  String? _selectedAlbumFilter;

  final List<String> _categories = [
    "All",
    "Trending",
    "Recently Added",
    "Artists",
    "Albums",
    "Bollywood",
    "Lo-Fi",
    "Sufi",
    "Classical",
  ];

  @override
  void initState() {
    super.initState();
    _fetchCloudData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCloudData() async {
    setState(() => _isLoading = true);
    try {
      final songsFuture = CloudMusicService.instance.fetchSongs();
      final trendingFuture = CloudMusicService.instance.fetchTrendingSongs();
      final recentFuture = CloudMusicService.instance.fetchRecentlyAddedSongs();
      final artistsFuture = CloudMusicService.instance.fetchArtists();
      final albumsFuture = CloudMusicService.instance.fetchAlbums();

      final results = await Future.wait([
        songsFuture,
        trendingFuture,
        recentFuture,
        artistsFuture,
        albumsFuture,
      ]);

      // Integrate synthesized open-source Bollywood & Global Catalog
      final catalogDb = CatalogDatabaseService.instance;
      final catalogSongs = catalogDb.getAllSongs().map((s) => CloudSongModel(
        id: s.id,
        title: s.title,
        artist: s.artist,
        album: s.album,
        coverImage: s.artwork,
        genre: s.genre,
        duration: s.durationMs ~/ 1000,
        audioUrl: s.audioUrl ?? "https://ia800504.us.archive.org/33/items/Bensound_AcousticBreeze/bensound-acousticbreeze.mp3",
        playCount: s.playCount,
        createdAt: s.dateAdded,
      )).toList();

      final catalogTrending = catalogDb.getTrendingSongs().map((s) => CloudSongModel(
        id: s.id,
        title: s.title,
        artist: s.artist,
        album: s.album,
        coverImage: s.artwork,
        genre: s.genre,
        duration: s.durationMs ~/ 1000,
        audioUrl: s.audioUrl ?? "https://ia800504.us.archive.org/33/items/Bensound_AcousticBreeze/bensound-acousticbreeze.mp3",
        playCount: s.playCount,
        createdAt: s.dateAdded,
      )).toList();

      final catalogRecent = catalogDb.getRecentlyAddedSongs().map((s) => CloudSongModel(
        id: s.id,
        title: s.title,
        artist: s.artist,
        album: s.album,
        coverImage: s.artwork,
        genre: s.genre,
        duration: s.durationMs ~/ 1000,
        audioUrl: s.audioUrl ?? "https://ia800504.us.archive.org/33/items/Bensound_AcousticBreeze/bensound-acousticbreeze.mp3",
        playCount: s.playCount,
        createdAt: s.dateAdded,
      )).toList();

      final catalogArtists = catalogDb.getAllArtists().map((a) => CloudArtistModel(
        id: 'artist_${a.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        name: a.name,
        image: a.image,
        biography: a.genres.join(', '),
        songCount: a.songCount,
      )).toList();

      final catalogAlbums = catalogDb.getAllAlbums().map((al) => CloudAlbumModel(
        id: 'album_${al.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        title: al.title,
        artwork: al.cover,
        artist: al.artist,
        releaseInfo: al.year,
        songCount: al.songCount,
      )).toList();

      final rawSongs = results[0] as List<CloudSongModel>;
      final rawTrending = results[1] as List<CloudSongModel>;
      final rawRecent = results[2] as List<CloudSongModel>;
      final rawArtists = results[3] as List<CloudArtistModel>;
      final rawAlbums = results[4] as List<CloudAlbumModel>;

      // Deduplicate songs by ID
      final Set<String> seenSongIds = {};
      final List<CloudSongModel> mergedSongs = [];
      for (final s in [...rawSongs, ...catalogSongs]) {
        if (!seenSongIds.contains(s.id)) {
          seenSongIds.add(s.id);
          mergedSongs.add(s);
        }
      }

      final Set<String> seenTrendingIds = {};
      final List<CloudSongModel> mergedTrending = [];
      for (final s in [...rawTrending, ...catalogTrending]) {
        if (!seenTrendingIds.contains(s.id)) {
          seenTrendingIds.add(s.id);
          mergedTrending.add(s);
        }
      }

      final Set<String> seenRecentIds = {};
      final List<CloudSongModel> mergedRecent = [];
      for (final s in [...rawRecent, ...catalogRecent]) {
        if (!seenRecentIds.contains(s.id)) {
          seenRecentIds.add(s.id);
          mergedRecent.add(s);
        }
      }

      final Set<String> seenArtistNames = {};
      final List<CloudArtistModel> mergedArtists = [];
      for (final a in [...rawArtists, ...catalogArtists]) {
        if (!seenArtistNames.contains(a.name.toLowerCase())) {
          seenArtistNames.add(a.name.toLowerCase());
          mergedArtists.add(a);
        }
      }

      final Set<String> seenAlbumTitles = {};
      final List<CloudAlbumModel> mergedAlbums = [];
      for (final al in [...rawAlbums, ...catalogAlbums]) {
        if (!seenAlbumTitles.contains(al.title.toLowerCase())) {
          seenAlbumTitles.add(al.title.toLowerCase());
          mergedAlbums.add(al);
        }
      }

      if (mounted) {
        setState(() {
          _allSongs = mergedSongs;
          _trendingSongs = mergedTrending;
          _recentSongs = mergedRecent;
          _artists = mergedArtists;
          _albums = mergedAlbums;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAdminUpload() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminUploadScreen()),
    ).then((_) => _fetchCloudData());
  }

  void _playSong(CloudSongModel song, List<CloudSongModel> contextQueue) {
    // Increment play count asynchronously in Supabase
    CloudMusicService.instance.incrementPlayCount(song.id);

    final queue = contextQueue.map((s) => s.toSongModel()).toList();
    final index = contextQueue.indexWhere((s) => s.id == song.id);

    ref.read(playerProvider.notifier).playTrack(
      queue,
      index != -1 ? index : 0,
    );
  }

  void _toggleFavorite(CloudSongModel song) {
    final songModel = song.toSongModel();
    final db = DatabaseService.instance;
    final isFav = db.isFavorite(song.id);
    db.toggleFavorite(song.id);

    // If song was not in local db yet, save it
    if (db.getSongById(song.id) == null) {
      db.upsertSongs([songModel.copyWith(isFavorite: !isFav)]);
    }

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!isFav ? "Added to Favorites" : "Removed from Favorites"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<CloudSongModel> _getFilteredSongs() {
    var list = List<CloudSongModel>.from(_allSongs);

    if (_selectedArtistFilter != null) {
      list = list.where((s) => s.artist == _selectedArtistFilter).toList();
    }
    if (_selectedAlbumFilter != null) {
      list = list.where((s) => s.album == _selectedAlbumFilter).toList();
    }

    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((s) =>
        s.title.toLowerCase().contains(query) ||
        s.artist.toLowerCase().contains(query) ||
        s.album.toLowerCase().contains(query) ||
        s.genre.toLowerCase().contains(query)
      ).toList();
    }

    if (_activeCategory == "Trending") {
      list.sort((a, b) => b.playCount.compareTo(a.playCount));
    } else if (_activeCategory == "Recently Added") {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_activeCategory != "All" && _activeCategory != "Artists" && _activeCategory != "Albums") {
      list = list.where((s) => s.genre.toLowerCase().contains(_activeCategory.toLowerCase())).toList();
    }

    return list;
  }

  String _formatDuration(int secOrMs) {
    final seconds = secOrMs > 10000 ? (secOrMs / 1000).round() : secOrMs;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final currentlyPlayingId = playerState.currentSong?.id;
    final filteredSongs = _getFilteredSongs();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          color: CinematicColors.primary,
          backgroundColor: CinematicColors.surfaceContainerLow,
          onRefresh: _fetchCloudData,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Top Bar & Admin Upload Pill
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.cloud_done_rounded, color: CinematicColors.primary, size: 14),
                              SizedBox(width: 6),
                              Text(
                                "PRIVATE CLOUD STREAM",
                                style: TextStyle(
                                  color: CinematicColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Cloud Library",
                            style: TextStyle(
                              color: CinematicColors.onSurface,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.search_rounded, color: CinematicColors.primary),
                            tooltip: "Discover Music",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MusicSearchScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CinematicColors.primary.withOpacity(0.18),
                              foregroundColor: CinematicColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(color: CinematicColors.primary.withOpacity(0.5)),
                              ),
                            ),
                            onPressed: _openAdminUpload,
                            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                            label: const Text(
                              "Admin Upload",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Search Box
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Search songs, artists, albums, or genres...",
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: CinematicColors.primary, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: CinematicColors.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: CinematicColors.primary),
                      ),
                    ),
                  ),
                ),
              ),

              // Filter Chips
              SliverToBoxAdapter(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final cat = _categories[idx];
                      final isSelected = _activeCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _activeCategory = cat;
                            _selectedArtistFilter = null;
                            _selectedAlbumFilter = null;
                          });
                        },
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        selectedColor: CinematicColors.primary,
                        backgroundColor: CinematicColors.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: isSelected ? CinematicColors.primary : Colors.white.withOpacity(0.06),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Active Filter Pill (if artist or album selected)
              if (_selectedArtistFilter != null || _selectedAlbumFilter != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          "Filtering by: ${_selectedArtistFilter ?? _selectedAlbumFilter}",
                          style: const TextStyle(color: CinematicColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectedArtistFilter = null;
                            _selectedAlbumFilter = null;
                          }),
                          child: const Icon(Icons.cancel_rounded, color: Colors.white54, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: CinematicColors.primary),
                  ),
                )
              else ...[
                // TRENDING SECTION (if not filtered by specific query)
                if (_searchCtrl.text.isEmpty && _activeCategory == "All" && _trendingSongs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_fire_department_rounded, color: CinematicColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Trending Now",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "${_trendingSongs.length} tracks",
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 190,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: _trendingSongs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, idx) {
                          final song = _trendingSongs[idx];
                          final isCurrent = song.id == currentlyPlayingId;
                          return _buildTrendingCard(song, isCurrent);
                        },
                      ),
                    ),
                  ),
                ],

                // BROWSE ARTISTS SECTION
                if (_searchCtrl.text.isEmpty && (_activeCategory == "All" || _activeCategory == "Artists") && _artists.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Featured Artists",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${_artists.length} artists",
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 125,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: _artists.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, idx) {
                          final artist = _artists[idx];
                          final isSelected = _selectedArtistFilter == artist.name;
                          return _buildArtistAvatar(artist, isSelected);
                        },
                      ),
                    ),
                  ),
                ],

                // BROWSE ALBUMS SECTION
                if (_searchCtrl.text.isEmpty && (_activeCategory == "All" || _activeCategory == "Albums") && _albums.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Featured Albums",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${_albums.length} albums",
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 175,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: _albums.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, idx) {
                          final album = _albums[idx];
                          final isSelected = _selectedAlbumFilter == album.title;
                          return _buildAlbumCard(album, isSelected);
                        },
                      ),
                    ),
                  ),
                ],

                // RECENTLY ADDED SECTION
                if (_searchCtrl.text.isEmpty && _activeCategory == "Recently Added" && _recentSongs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Recently Added to Cloud",
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text("${_recentSongs.length} tracks", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],

                // MASTER CLOUD TRACKS LIST HEADER
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _searchCtrl.text.isNotEmpty
                              ? "Search Results (${filteredSongs.length})"
                              : "All Cloud Tracks (${filteredSongs.length})",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (filteredSongs.isNotEmpty)
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: CinematicColors.primary),
                            onPressed: () => _playSong(filteredSongs.first, filteredSongs),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text("Play All", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),

                // TRACKS LIST
                if (filteredSongs.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: CinematicColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: Colors.white30, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            "No cloud tracks match your criteria.",
                            style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Tap 'Admin Upload' to publish audio master tracks to your private cloud.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CinematicColors.primary,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: _openAdminUpload,
                            icon: const Icon(Icons.cloud_upload_rounded),
                            label: const Text("Open Upload Panel"),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = filteredSongs[index];
                        final isPlayingThis = song.id == currentlyPlayingId && playerState.isPlaying;
                        final isFavorite = DatabaseService.instance.isFavorite(song.id);

                        return RepaintBoundary(
                          child: InkWell(
                            onTap: () => _playSong(song, filteredSongs),
                            child: Container(
                              height: 68,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: isPlayingThis
                                    ? CinematicColors.primary.withOpacity(0.08)
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(color: Colors.white.withOpacity(0.03)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Artwork
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: song.coverImage.startsWith('http')
                                        ? Image.network(
                                            song.coverImage,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            cacheWidth: 120,
                                            cacheHeight: 120,
                                            errorBuilder: (_, __, ___) => _buildSongArtPlaceholder(),
                                          )
                                        : _buildSongArtPlaceholder(),
                                  ),
                                  const SizedBox(width: 14),

                                  // Track metadata
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isPlayingThis
                                                ? CinematicColors.primary
                                                : CinematicColors.onSurface,
                                            fontSize: 14,
                                            fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          "${song.artist} • ${song.album}",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Cloud stream badge & duration
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatDuration(song.duration),
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${song.playCount} plays",
                                        style: const TextStyle(color: CinematicColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),

                                  // Favorite button
                                  IconButton(
                                    icon: Icon(
                                      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: isFavorite ? Colors.redAccent : Colors.white30,
                                      size: 20,
                                    ),
                                    onPressed: () => _toggleFavorite(song),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filteredSongs.length,
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingCard(CloudSongModel song, bool isCurrent) {
    return GestureDetector(
      onTap: () => _playSong(song, _trendingSongs),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: CinematicColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent ? CinematicColors.primary : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork with Play Count Pill
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: song.coverImage.startsWith('http')
                      ? Image.network(
                          song.coverImage,
                          width: 140,
                          height: 110,
                          fit: BoxFit.cover,
                          cacheWidth: 200,
                          cacheHeight: 180,
                          errorBuilder: (_, __, ___) => _buildSongArtPlaceholder(height: 110),
                        )
                      : _buildSongArtPlaceholder(height: 110),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: CinematicColors.primary, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          "${song.playCount}",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? CinematicColors.primary : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistAvatar(CloudArtistModel artist, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedArtistFilter = isSelected ? null : artist.name;
        });
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? CinematicColors.primary : Colors.white.withOpacity(0.12),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: CinematicColors.surfaceContainerHigh,
              backgroundImage: artist.image.startsWith('http') ? NetworkImage(artist.image) : null,
              child: !artist.image.startsWith('http')
                  ? const Icon(Icons.person_rounded, color: Colors.white54, size: 30)
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            artist.name,
            style: TextStyle(
              color: isSelected ? CinematicColors.primary : Colors.white,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(CloudAlbumModel album, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAlbumFilter = isSelected ? null : album.title;
        });
      },
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? CinematicColors.primary : Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: album.artwork.startsWith('http')
                    ? Image.network(
                        album.artwork,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        cacheWidth: 150,
                        cacheHeight: 150,
                        errorBuilder: (_, __, ___) => _buildSongArtPlaceholder(height: 110),
                      )
                    : _buildSongArtPlaceholder(height: 110),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? CinematicColors.primary : Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            Text(
              album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongArtPlaceholder({double height = 48}) {
    return Container(
      width: height,
      height: height,
      color: CinematicColors.surfaceContainerHigh,
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white38, size: 22),
      ),
    );
  }
}
