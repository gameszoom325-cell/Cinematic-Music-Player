import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/typography.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/models/song_model.dart';
import '../../../core/database/models/playlist_model.dart';
import '../../player/providers/player_provider.dart';
import '../../library/providers/library_provider.dart';
import '../../import/presentation/add_music_screen.dart';
import '../../hindi_collection/presentation/hindi_collection_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const List<String> categories = [
    "Hindi",
    "English",
    "Tamil",
    "Japanese",
    "Korean",
    "Instrumental",
    "Anime OST",
    "Lo-Fi",
  ];

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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PRIVATE COLLECTION",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text("Personal Vault", style: CinematicTypography.displayTitle),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CinematicColors.electricViolet,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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

            // Category Badges Bar
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isHindi = cat == "Hindi";
                    return GestureDetector(
                      onTap: () {
                        if (isHindi) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const HindiCollectionScreen()),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isHindi ? CinematicColors.electricViolet.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isHindi ? CinematicColors.electricViolet.withOpacity(0.6) : Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isHindi) ...[
                              const Icon(Icons.stars_rounded, color: CinematicColors.electricViolet, size: 14),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              cat,
                              style: TextStyle(
                                color: isHindi ? Colors.white : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Curated Hindi Vault Feature Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HindiCollectionScreen()),
                    );
                  },
                  child: CinematicGlassCard(
                    padding: const EdgeInsets.all(18),
                    borderRadius: 20,
                    borderColor: CinematicColors.electricViolet.withOpacity(0.35),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [CinematicColors.electricViolet, CinematicColors.deepPlum],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "CURATED COLLECTION",
                                    style: TextStyle(
                                      color: CinematicColors.electricViolet,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: CinematicColors.cyberCyan.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: CinematicColors.cyberCyan.withOpacity(0.4)),
                                    ),
                                    child: const Text(
                                      "19 TRACKS",
                                      style: TextStyle(color: CinematicColors.cyberCyan, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Trending Hits & Bollywood Classics",
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Arijit Singh, A.R. Rahman, Jasmine Sandlas & more",
                                style: TextStyle(color: Colors.white54, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Empty state notice
            if (allSongs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: CinematicGlassCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.audio_file_rounded, color: CinematicColors.electricViolet, size: 42),
                        const SizedBox(height: 14),
                        const Text("Your Vault is Empty", style: CinematicTypography.songTitleLarge),
                        const SizedBox(height: 6),
                        const Text(
                          "Import your local MP3, FLAC, WAV, M4A, or OGG tracks to experience real-time GPU audio visualizers and synchronized lyrics.",
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CinematicColors.electricViolet,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _openAddMusic(context),
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text("Import Music Collection", style: TextStyle(fontWeight: FontWeight.bold)),
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
          fontSize: 12,
          fontWeight: FontWeight.w800,
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
              borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(18),
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              "${album.artist} • ${album.songCount} tracks",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                width: 76,
                height: 76,
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
      child: CinematicGlassCard(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: playlist.id == 'favorites'
                      ? [CinematicColors.hotPink, CinematicColors.electricViolet]
                      : [CinematicColors.electricViolet, CinematicColors.neonCyan],
                ),
              ),
              child: Icon(
                playlist.id == 'favorites' ? Icons.favorite_rounded : Icons.queue_music_rounded,
                size: 20,
                color: Colors.white,
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
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CinematicColors.electricViolet.withOpacity(0.6),
            CinematicColors.obsidianCard,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 28),
      ),
    );
  }
}
