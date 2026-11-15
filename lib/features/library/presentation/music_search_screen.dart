import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/sources/music_source_type.dart';
import '../../../core/sources/music_source_repository.dart';
import '../../../core/database/models/song_model.dart';
import '../../../core/database/database_service.dart';
import '../../../web_search/web_search_page.dart';
import '../../player/providers/player_provider.dart';
import '../providers/music_source_provider.dart';

/// Modern Federated Music Search Screen (Metrolist & InnerTubeX Pattern).
/// Enables discovering music across Local Storage, Private Cloud, and Online Music.
class MusicSearchScreen extends ConsumerStatefulWidget {
  const MusicSearchScreen({super.key});

  @override
  ConsumerState<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends ConsumerState<MusicSearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final List<SongModel> _webPrefetchedSongs = [];
  late TabController _tabController;
  String _query = "";
  MusicSourceType? _selectedSource; // null = all sources

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(federatedSearchProvider(_query));

    return Scaffold(
      backgroundColor: CinematicColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Search Input
            _buildSearchHeader(),

            // Source Selector Chips
            _buildSourceFilterChips(),

            // Category Tab Bar (All, Songs, Artists, Albums)
            _buildTabBar(),

            // Search Content
            Expanded(
              child: _query.trim().isEmpty
                  ? _buildEmptyState()
                  : searchAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: CinematicColors.primary),
                      ),
                      error: (err, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            "Search error: $err",
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      data: (result) => _buildSearchResultsView(result),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToWebSearch(String query) async {
    final capturedSong = await Navigator.of(context).push<SongModel>(
      MaterialPageRoute(
        builder: (context) => WebSearchPage(initialQuery: query.trim()),
      ),
    );
    if (capturedSong != null && mounted) {
      setState(() {
        _webPrefetchedSongs.insert(0, capturedSong);
      });
    }
  }

  Widget _buildSearchHeader() {
    final canPop = Navigator.of(context).canPop();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          if (canPop) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: CinematicColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: CinematicColors.primary,
                decoration: InputDecoration(
                  hintText: "Search songs, artists, albums...",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: CinematicColors.primary, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = "");
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) {
                  setState(() => _query = val);
                },
              ),
            ),
          ),
          if (_query.trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: CinematicColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CinematicColors.primary.withOpacity(0.3)),
              ),
              child: IconButton(
                tooltip: "Search Web for '$_query'",
                icon: const Icon(Icons.travel_explore_rounded, color: CinematicColors.primary, size: 20),
                onPressed: () => _navigateToWebSearch(_query),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (_query.trim().isNotEmpty) ...[
            ActionChip(
              avatar: const Icon(Icons.travel_explore_rounded, size: 16, color: CinematicColors.primary),
              label: Text(
                "Search Web for '$_query'",
                style: const TextStyle(
                  color: CinematicColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: CinematicColors.primary.withOpacity(0.12),
              side: const BorderSide(color: CinematicColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              onPressed: () => _navigateToWebSearch(_query),
            ),
            const SizedBox(width: 8),
          ],
          _buildFilterChip("All Sources", null),
          const SizedBox(width: 8),
          _buildFilterChip("YouTube Music", MusicSourceType.youtube),
          const SizedBox(width: 8),
          _buildFilterChip("Jamendo Music", MusicSourceType.jamendo),
          const SizedBox(width: 8),
          _buildFilterChip("Bollywood Catalog", MusicSourceType.catalog),
          const SizedBox(width: 8),
          _buildFilterChip("Online Music (InnerTubeX)", MusicSourceType.online),
          const SizedBox(width: 8),
          _buildFilterChip("Private Cloud", MusicSourceType.cloud),
          const SizedBox(width: 8),
          _buildFilterChip("Local Storage", MusicSourceType.local),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, MusicSourceType? type) {
    final isSelected = _selectedSource == type;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSource = type);
        ref.read(activeSourceFilterProvider.notifier).state = type;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? CinematicColors.primary.withOpacity(0.2) : CinematicColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? CinematicColors.primary : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? CinematicColors.primary : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelColor: CinematicColors.primary,
        unselectedLabelColor: Colors.white38,
        indicatorColor: CinematicColors.primary,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: "Top Results"),
          Tab(text: "Songs"),
          Tab(text: "Artists"),
          Tab(text: "Albums"),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.travel_explore_rounded, size: 54, color: CinematicColors.primary.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text(
              "Discover Music Across All Sources",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Type to search songs, artists, or albums across your Offline Vault, Private Cloud, and Online Music.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                "Acoustic",
                "Lo-Fi",
                "Bollywood",
                "Neoclassical",
                "Ambient",
                "Classical",
              ].map((tag) => ActionChip(
                backgroundColor: CinematicColors.surfaceContainerLow,
                side: BorderSide(color: Colors.white.withOpacity(0.06)),
                label: Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                onPressed: () {
                  _searchCtrl.text = tag;
                  setState(() => _query = tag);
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsView(FederatedSearchResult result) {
    final effectiveSongs = [..._webPrefetchedSongs, ...result.songs];
    final effectiveResult = FederatedSearchResult(
      query: result.query,
      songs: effectiveSongs,
      artists: result.artists,
      albums: result.albums,
    );

    if (effectiveResult.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_off_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              "No results found for '$_query'",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: CinematicColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.travel_explore_rounded, size: 18),
              label: Text("Search Web for '$_query'", style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _navigateToWebSearch(_query),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // Tab 0: Top Results (All)
        _buildTopResultsTab(effectiveResult),

        // Tab 1: Songs
        _buildSongsTab(effectiveSongs),

        // Tab 2: Artists
        _buildArtistsTab(effectiveResult.artists),

        // Tab 3: Albums
        _buildAlbumsTab(effectiveResult.albums),
      ],
    );
  }

  Widget _buildTopResultsTab(FederatedSearchResult result) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (result.songs.isNotEmpty) ...[
          _buildSectionHeader("Songs", () => _tabController.animateTo(1)),
          ...result.songs.take(5).map((song) => _buildSongTile(song, result.songs)),
          const SizedBox(height: 16),
        ],
        if (result.artists.isNotEmpty) ...[
          _buildSectionHeader("Artists", () => _tabController.animateTo(2)),
          _buildArtistsHorizontalList(result.artists),
          const SizedBox(height: 16),
        ],
        if (result.albums.isNotEmpty) ...[
          _buildSectionHeader("Albums", () => _tabController.animateTo(3)),
          _buildAlbumsHorizontalList(result.albums),
        ],
      ],
    );
  }

  Widget _buildSongsTab(List<SongModel> songs) {
    if (songs.isEmpty) {
      return const Center(child: Text("No songs matched.", style: TextStyle(color: Colors.white38)));
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: songs.length,
      itemBuilder: (context, index) => _buildSongTile(songs[index], songs),
    );
  }

  Widget _buildArtistsTab(List<ArtistSummary> artists) {
    if (artists.isEmpty) {
      return const Center(child: Text("No artists matched.", style: TextStyle(color: Colors.white38)));
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: CinematicColors.surfaceContainerHigh,
            backgroundImage: artist.sampleArtworkPath != null && artist.sampleArtworkPath!.startsWith('http')
                ? NetworkImage(artist.sampleArtworkPath!)
                : null,
            child: artist.sampleArtworkPath == null
                ? const Icon(Icons.person_rounded, color: Colors.white54)
                : null,
          ),
          title: Text(
            artist.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            "${artist.songCount} track(s)",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          onTap: () {
            // Filter search directly to this artist
            _searchCtrl.text = artist.name;
            setState(() => _query = artist.name);
          },
        );
      },
    );
  }

  Widget _buildAlbumsTab(List<AlbumSummary> albums) {
    if (albums.isEmpty) {
      return const Center(child: Text("No albums matched.", style: TextStyle(color: Colors.white38)));
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: CinematicColors.surfaceContainerHigh,
              child: album.artworkPath != null && album.artworkPath!.startsWith('http')
                  ? Image.network(album.artworkPath!, fit: BoxFit.cover)
                  : const Icon(Icons.album_rounded, color: Colors.white54),
            ),
          ),
          title: Text(
            album.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            "${album.artist} • ${album.songCount} tracks",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          onTap: () {
            // Filter search directly to this album
            _searchCtrl.text = album.name;
            setState(() => _query = album.name);
          },
        );
      },
    );
  }

  Widget _buildSongTile(SongModel song, List<SongModel> contextList) {
    final playerState = ref.watch(playerProvider);
    final isCurrent = playerState.currentSong?.id == song.id;
    final isPlaying = isCurrent && playerState.isPlaying;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isCurrent ? CinematicColors.primary.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? CinematicColors.primary.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 44,
                height: 44,
                color: CinematicColors.surfaceContainerHigh,
                child: _buildArtworkWidget(song),
              ),
            ),
            if (isCurrent)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPlaying ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                  color: CinematicColors.primary,
                  size: 22,
                ),
              ),
          ],
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? CinematicColors.primary : Colors.white,
            fontSize: 14,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            _buildSourceBadge(song.sourceType),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "${song.artist} • ${song.album}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(song.durationMs),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                song.isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                color: song.isFavorite ? Colors.redAccent : Colors.white38,
                size: 18,
              ),
              onPressed: () {
                DatabaseService.instance.toggleFavorite(song.id, song);
                setState(() {});
              },
            ),
          ],
        ),
        onTap: () {
          if (song.isYouTube || song.sourceType.toLowerCase() == 'youtube') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => WebSearchPage(
                  initialQuery: song.title,
                  autoSubmit: true,
                ),
              ),
            );
            return;
          }
          final index = contextList.indexWhere((s) => s.id == song.id);
          ref.read(playerProvider.notifier).playTrack(contextList, index >= 0 ? index : 0);
        },
      ),
    );
  }

  Widget _buildArtworkWidget(SongModel song) {
    final art = song.artwork ?? song.artworkPath;
    if (art != null && art.isNotEmpty) {
      if (art.startsWith('http://') || art.startsWith('https://')) {
        return Image.network(
          art,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded, color: Colors.white38),
        );
      } else if (File(art).existsSync()) {
        return Image.file(
          File(art),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded, color: Colors.white38),
        );
      }
    }
    return const Icon(Icons.music_note_rounded, color: Colors.white38);
  }

  Widget _buildSourceBadge(String sourceType) {
    Color badgeColor;
    String label;

    switch (sourceType.toLowerCase()) {
      case 'youtube':
        badgeColor = const Color(0xFFEF4444); // YouTube Red
        label = "YOUTUBE";
        break;
      case 'jamendo':
        badgeColor = const Color(0xFF10B981); // Emerald Green
        label = "JAMENDO";
        break;
      case 'online':
        badgeColor = const Color(0xFF38BDF8); // Cyan
        label = "ONLINE";
        break;
      case 'cloud':
        badgeColor = const Color(0xFFA855F7); // Purple
        label = "CLOUD";
        break;
      case 'catalog':
        badgeColor = const Color(0xFFF59E0B); // Amber / Gold
        label = "CATALOG";
        break;
      case 'web_prefetch':
      case 'pagalworld':
      case 'web':
        badgeColor = const Color(0xFFEAB308); // Warm Gold
        label = "WEB MP3";
        break;
      case 'local':
      default:
        badgeColor = CinematicColors.primary;
        label = "VAULT";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: CinematicColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          InkWell(
            onTap: onSeeAll,
            child: const Text(
              "See all",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistsHorizontalList(List<ArtistSummary> artists) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: artists.length,
        itemBuilder: (context, index) {
          final artist = artists[index];
          return GestureDetector(
            onTap: () {
              _searchCtrl.text = artist.name;
              setState(() => _query = artist.name);
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: CinematicColors.surfaceContainerHigh,
                    backgroundImage: artist.sampleArtworkPath != null && artist.sampleArtworkPath!.startsWith('http')
                        ? NetworkImage(artist.sampleArtworkPath!)
                        : null,
                    child: artist.sampleArtworkPath == null
                        ? const Icon(Icons.person_rounded, color: Colors.white54)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlbumsHorizontalList(List<AlbumSummary> albums) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return GestureDetector(
            onTap: () {
              _searchCtrl.text = album.name;
              setState(() => _query = album.name);
            },
            child: Container(
              width: 95,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 95,
                      height: 80,
                      color: CinematicColors.surfaceContainerHigh,
                      child: album.artworkPath != null && album.artworkPath!.startsWith('http')
                          ? Image.network(album.artworkPath!, fit: BoxFit.cover)
                          : const Icon(Icons.album_rounded, color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
