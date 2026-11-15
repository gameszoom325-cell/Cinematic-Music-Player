import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/models/song_model.dart';
import '../../../core/database/models/playlist_model.dart';
import '../../player/providers/player_provider.dart';
import '../../library/providers/library_provider.dart';
import '../../import/presentation/add_music_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openAddMusic(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddMusicScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(libraryProvider);
    final playerNotifier = ref.read(playerProvider.notifier);

    final db = DatabaseService.instance;
    final recentlyPlayed = db.getRecentlyPlayedSongs();
    final mostPlayed = db.getMostPlayedSongs();
    final recentlyAdded = db.getRecentlyAddedSongs();
    final albums = db.getAllAlbums();
    final artists = db.getAllArtists();
    final playlists = db.getAllPlaylists();
    final allSongs = db.getAllSongs();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allSongs.isEmpty ? "LIBRARY" : "${allSongs.length} SONGS",
                          style: const TextStyle(
                            color: CinematicColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Your Music",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
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
                      onPressed: () => _openAddMusic(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text("Add Music", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

            // Empty state notice
            if (allSongs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: CinematicColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: CinematicColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.library_music_rounded, color: CinematicColors.primary, size: 24),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No Local Music Added",
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Add a local music folder or import audio files to begin offline playback.",
                          style: TextStyle(color: CinematicColors.onSurfaceVariant, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CinematicColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => _openAddMusic(context),
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text("Import Music Files", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 1. Recently Played Carousel
            if (recentlyPlayed.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader("RECENTLY PLAYED"),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 175,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recentlyPlayed.length,
                    itemBuilder: (context, index) {
                      final song = recentlyPlayed[index];
                      return _buildRecentCard(song, () {
                        playerNotifier.playTrack(recentlyPlayed, index);
                      });
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // 2. Most Played
            if (mostPlayed.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader("MOST PLAYED"),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 175,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: mostPlayed.length,
                    itemBuilder: (context, index) {
                      final song = mostPlayed[index];
                      return _buildRecentCard(song, () {
                        playerNotifier.playTrack(mostPlayed, index);
                      });
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // 3. Recently Added
            if (recentlyAdded.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader("RECENTLY ADDED"),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 175,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recentlyAdded.length,
                    itemBuilder: (context, index) {
                      final song = recentlyAdded[index];
                      return _buildRecentCard(song, () {
                        playerNotifier.playTrack(recentlyAdded, index);
                      });
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // 2. Albums Section
            if (albums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader("ALBUMS"),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 195,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return _buildAlbumCard(album, () {
                        final albumSongs = album.songIds
                            .map((id) => db.getSongById(id))
                            .whereType<SongModel>()
                            .toList();
                        if (albumSongs.isNotEmpty) {
                          playerNotifier.playTrack(albumSongs, 0);
                        }
                      });
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // 3. Artists Section
            if (artists.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader("ARTISTS"),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: artists.length,
                    itemBuilder: (context, index) {
                      final artist = artists[index];
                      return _buildArtistCard(artist, () {
                        final artistSongs = allSongs
                            .where((s) => s.artist == artist.name)
                            .toList();
                        if (artistSongs.isNotEmpty) {
                          playerNotifier.playTrack(artistSongs, 0);
                        }
                      });
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // 4. Playlists Quick Row
            if (playlists.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader("PLAYLISTS"),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 2.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final pl = playlists[index];
                      return _buildPlaylistTile(pl, () {
                        final plSongs = pl.songIds
                            .map((id) => db.getSongById(id))
                            .whereType<SongModel>()
                            .toList();
                        if (plSongs.isNotEmpty) {
                          playerNotifier.playTrack(plSongs, 0);
                        }
                      });
                    },
                    childCount: playlists.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildRecentCard(SongModel song, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: _buildThumb(song.artworkPath, song.title),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumCard(AlbumSummary album, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: _buildThumb(album.artworkPath, album.name),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              "${album.songIds.length} tracks",
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistCard(ArtistSummary artist, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            ClipOval(
              child: SizedBox(
                width: 72,
                height: 72,
                child: _buildThumb(artist.sampleArtworkPath, artist.name),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(PlaylistModel playlist, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CinematicColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: CinematicColors.primary.withOpacity(0.15),
              ),
              child: Icon(
                playlist.id == 'favorites' ? Icons.favorite_rounded : Icons.queue_music_rounded,
                size: 18,
                color: CinematicColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    "${playlist.songIds.length} songs",
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

  Widget _buildThumb(String? path, String fallbackSeed) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          cacheWidth: 160,
          cacheHeight: 160,
          errorBuilder: (context, error, stackTrace) => _fallbackThumb(),
        );
      }
      final file = File(path);
      if (file.existsSync() && file.lengthSync() > 0) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 160,
          cacheHeight: 160,
          errorBuilder: (context, error, stackTrace) => _fallbackThumb(),
        );
      }
    }
    return _fallbackThumb();
  }

  Widget _fallbackThumb() {
    return Container(
      color: CinematicColors.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white38, size: 24),
      ),
    );
  }
}
