import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/library_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/models/song_model.dart';
import '../../../core/services/scanner_service.dart';

enum LibraryTab { songs, albums, artists, folders }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryTab _activeTab = LibraryTab.songs;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _handleAddFolder() async {
    try {
      final path = await ScannerService.pickMusicFolder();
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Scanning folder: $path..."),
            backgroundColor: CinematicColors.primaryContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await ref.read(libraryProvider.notifier).addAndScanFolder(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Folder pick notice: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showTrackMenu(BuildContext context, SongModel song, WidgetRef ref) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final libraryNotifier = ref.read(libraryProvider.notifier);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              ListTile(
                dense: true,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: _buildThumb(song.artworkPath, CinematicColors.primary),
                  ),
                ),
                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ),
              const Divider(color: Colors.white12),

              ListTile(
                leading: const Icon(Icons.playlist_play_rounded, color: Colors.white70),
                title: const Text("Play Next", style: TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  playerNotifier.playNext(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Will play '${song.title}' next"), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded, color: Colors.white70),
                title: const Text("Add to Queue", style: TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  playerNotifier.addToQueue(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Added '${song.title}' to queue"), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              ListTile(
                leading: Icon(song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.pinkAccent),
                title: Text(song.isFavorite ? "Remove from Liked Songs" : "Save to Liked Songs", style: const TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  playerNotifier.toggleFavorite();
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: Colors.white70),
                title: const Text("Add to Playlist", style: TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistDialog(context, song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text("Remove from Library", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await libraryNotifier.removeSong(song.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Removed '${song.title}' from library"), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, SongModel song) {
    final playlists = DatabaseService.instance.getAllPlaylists();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add to Playlist", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          child: playlists.isEmpty
              ? const Text("No playlists available. Create one first in the sidebar.", style: TextStyle(color: Colors.white60))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, idx) {
                    final pl = playlists[idx];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.queue_music_rounded, color: CinematicColors.primary),
                      title: Text(pl.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text("${pl.songIds.length} tracks", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                      onTap: () async {
                        await DatabaseService.instance.addSongToPlaylist(pl.id, song.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Added to '${pl.name}'"), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Close", style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
        ],
      ),
    );
  }

  void _openAlbumDetail(AlbumSummary album) {
    final songs = DatabaseService.instance.getSongsForAlbum(album.name);
    _showCollectionDetail(title: album.name, subtitle: album.artist, artworkPath: album.artworkPath, songs: songs);
  }

  void _openArtistDetail(ArtistSummary artist) {
    final songs = DatabaseService.instance.getSongsForArtist(artist.name);
    _showCollectionDetail(title: artist.name, subtitle: "${artist.songCount} Tracks • ${artist.albumCount} Albums", artworkPath: artist.sampleArtworkPath, songs: songs);
  }

  void _showCollectionDetail({
    required String title,
    required String subtitle,
    required String? artworkPath,
    required List<SongModel> songs,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141418),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollCtrl) {
          return Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: _buildThumb(artworkPath, CinematicColors.primary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CinematicColors.primary,
                                  foregroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                onPressed: () {
                                  if (songs.isNotEmpty) {
                                    ref.read(playerProvider.notifier).playTrack(songs, 0);
                                    Navigator.pop(ctx);
                                  }
                                },
                                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                label: const Text("Play", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                onPressed: () {
                                  if (songs.isNotEmpty) {
                                    final shuffled = List<SongModel>.from(songs)..shuffle();
                                    ref.read(playerProvider.notifier).playTrack(shuffled, 0);
                                    Navigator.pop(ctx);
                                  }
                                },
                                icon: const Icon(Icons.shuffle_rounded, size: 18),
                                label: const Text("Shuffle"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),

              // Tracks List
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: songs.length,
                  itemExtent: 60.0,
                  itemBuilder: (context, idx) {
                    final song = songs[idx];
                    return ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 28,
                        child: Text("${idx + 1}", textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                      ),
                      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                      trailing: Text(_formatDuration(song.durationMs), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                      onTap: () {
                        ref.read(playerProvider.notifier).playTrack(songs, idx);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final db = DatabaseService.instance;

    final allAlbums = db.getAllAlbums();
    final allArtists = db.getAllArtists();
    final savedFolders = libraryState.folders;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Bar
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 550;
                  final titleWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your Library",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        "${libraryState.songs.length} tracks • ${allAlbums.length} albums • ${allArtists.length} artists",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ],
                  );

                  final buttonsWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: libraryState.isScanning ? null : () => libraryNotifier.rescanAll(),
                        icon: libraryState.isScanning
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: CinematicColors.primary))
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(libraryState.isScanning ? "Scanning..." : "Rescan", style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CinematicColors.primary,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: _handleAddFolder,
                        icon: const Icon(Icons.create_new_folder_rounded, size: 16),
                        label: const Text("Add Folder", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: titleWidget),
                        buttonsWidget,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 10),
                      buttonsWidget,
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Scanning Progress Notice
              if (libraryState.isScanning)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: CinematicColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: CinematicColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: CinematicColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          libraryState.scanTotal > 0
                              ? "Scanning library: ${libraryState.scanProgress} / ${libraryState.scanTotal} tracks..."
                              : "Scanning audio files in your local music folders...",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: CinematicColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Sub-Tabs Header (Songs, Albums, Artists, Folders)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  final chips = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildTabChip("Songs (${libraryState.songs.length})", LibraryTab.songs),
                        const SizedBox(width: 8),
                        _buildTabChip("Albums (${allAlbums.length})", LibraryTab.albums),
                        const SizedBox(width: 8),
                        _buildTabChip("Artists (${allArtists.length})", LibraryTab.artists),
                        const SizedBox(width: 8),
                        _buildTabChip("Folders (${savedFolders.length})", LibraryTab.folders),
                      ],
                    ),
                  );

                  Widget buildSearchField() => TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => libraryNotifier.setSearchQuery(val),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: "Filter library...",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 16),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    ),
                  );

                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(child: chips),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 200,
                          height: 34,
                          child: buildSearchField(),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      chips,
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 34,
                        child: buildSearchField(),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Main Tab Content Area
              Expanded(
                child: _buildActiveTabView(
                  libraryState: libraryState,
                  playerState: playerState,
                  playerNotifier: playerNotifier,
                  albums: allAlbums,
                  artists: allArtists,
                  folders: savedFolders,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(String label, LibraryTab tab) {
    final isSelected = _activeTab == tab;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black87 : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabView({
    required LibraryState libraryState,
    required dynamic playerState,
    required dynamic playerNotifier,
    required List<AlbumSummary> albums,
    required List<ArtistSummary> artists,
    required List<String> folders,
  }) {
    switch (_activeTab) {
      case LibraryTab.songs:
        return _buildSongsList(libraryState.songs, playerState, playerNotifier);
      case LibraryTab.albums:
        return _buildAlbumsGrid(albums);
      case LibraryTab.artists:
        return _buildArtistsGrid(artists);
      case LibraryTab.folders:
        return _buildFoldersList(folders);
    }
  }

  // Spotify-style Track Table List
  Widget _buildSongsList(List<SongModel> songs, dynamic playerState, dynamic playerNotifier) {
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music_rounded, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text("Your song library is empty", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text("Click 'Add Folder' above or drag and drop MP3s into the app window.", style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08)))),
          child: Row(
            children: [
              SizedBox(width: 32, child: Text("#", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 44),
              const Expanded(flex: 4, child: Text("TITLE", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
              const Expanded(flex: 3, child: Text("ALBUM", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
              SizedBox(width: 70, child: Text("TIME", textAlign: TextAlign.right, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 48),
            ],
          ),
        ),

        // Virtualized ListView with itemExtent: 58.0
        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
            itemExtent: 58.0,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, idx) {
              final song = songs[idx];
              final isCurrent = playerState.currentSong?.id == song.id;
              final isPlaying = isCurrent && playerState.isPlaying;

              return RepaintBoundary(
                child: InkWell(
                  onTap: () async {
                    if (!song.isLocalFileAvailable) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Audio file unavailable. Please import this song again."), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }
                    await playerNotifier.playTrack(songs, idx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: isCurrent ? CinematicColors.primary.withOpacity(0.10) : Colors.transparent,
                    child: Row(
                      children: [
                        // # / Equalizer
                        SizedBox(
                          width: 32,
                          child: isPlaying
                              ? const Icon(Icons.equalizer_rounded, color: CinematicColors.primary, size: 16)
                              : Text("${idx + 1}", style: TextStyle(color: isCurrent ? CinematicColors.primary : Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                        ),

                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 38,
                            height: 38,
                            child: _buildThumb(song.artworkPath, CinematicColors.primary),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Artist
                        Expanded(
                          flex: 4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent ? CinematicColors.primary : Colors.white,
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                              ),
                            ],
                          ),
                        ),

                        // Album
                        Expanded(
                          flex: 3,
                          child: Text(
                            song.album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                        ),

                        // Duration
                        SizedBox(
                          width: 70,
                          child: Text(
                            _formatDuration(song.durationMs),
                            textAlign: TextAlign.right,
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                        ),

                        // Menu button (...)
                        IconButton(
                          icon: const Icon(Icons.more_horiz_rounded, size: 18),
                          color: Colors.white54,
                          splashRadius: 18,
                          onPressed: () => _showTrackMenu(context, song, ref),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Albums Grid View
  Widget _buildAlbumsGrid(List<AlbumSummary> albums) {
    if (albums.isEmpty) {
      return Center(
        child: Text("No albums found in library", style: TextStyle(color: Colors.white.withOpacity(0.4))),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (context, idx) {
        final album = albums[idx];
        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _openAlbumDetail(album),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: double.infinity,
                      child: _buildThumb(album.artworkPath, CinematicColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text("${album.artist} • ${album.songCount} songs", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Artists Grid View
  Widget _buildArtistsGrid(List<ArtistSummary> artists) {
    if (artists.isEmpty) {
      return Center(
        child: Text("No artists found in library", style: TextStyle(color: Colors.white.withOpacity(0.4))),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: artists.length,
      itemBuilder: (context, idx) {
        final artist = artists[idx];
        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _openArtistDetail(artist),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: _buildThumb(artist.sampleArtworkPath, CinematicColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text("${artist.songCount} tracks", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Folders Management List
  Widget _buildFoldersList(List<String> folders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Configured Music Folders", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _handleAddFolder,
              icon: const Icon(Icons.add_rounded, size: 16, color: CinematicColors.primary),
              label: const Text("Add Another Folder", style: TextStyle(color: CinematicColors.primary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (folders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_off_rounded, color: Colors.white.withOpacity(0.2), size: 48),
                  const SizedBox(height: 12),
                  const Text("No local folders configured", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  const Text("Click 'Add Folder' to select where your MP3 and FLAC audio files are located.", style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: folders.length,
              itemBuilder: (context, idx) {
                final folder = folders[idx];
                final exists = Directory(folder).existsSync();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: exists ? Colors.white10 : Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_rounded, color: exists ? CinematicColors.primary : Colors.redAccent, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(folder, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              exists ? "Active and monitored" : "Folder not found or moved",
                              style: TextStyle(color: exists ? Colors.white54 : Colors.redAccent, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white70),
                        tooltip: "Scan This Folder",
                        onPressed: () => ref.read(libraryProvider.notifier).scanFolder(folder),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        tooltip: "Remove Folder",
                        onPressed: () => ref.read(libraryProvider.notifier).removeFolder(folder),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildThumb(String? path, Color fallbackColor) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          cacheWidth: 80,
          cacheHeight: 80,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _fallbackThumb(fallbackColor),
        );
      }
      final file = File(path);
      if (file.existsSync() && file.lengthSync() > 0) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 80,
          cacheHeight: 80,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _fallbackThumb(fallbackColor),
        );
      }
    }
    return _fallbackThumb(fallbackColor);
  }

  Widget _fallbackThumb(Color color) {
    return Container(
      color: color.withOpacity(0.18),
      child: const Center(child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 18)),
    );
  }
}
