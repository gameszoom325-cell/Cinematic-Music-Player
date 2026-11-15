// This uses an unofficial JioSaavn wrapper. It may break without notice and may violate JioSaavn's terms of service. Use for personal/testing only.

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'jiosaavn_service.dart';

/// Bollywood Music Streaming Page powered by the unofficial JioSaavn wrapper.
///
/// Provides:
/// - Real-time search for songs, artists, and albums
/// - Live stream URL resolution and playback via `just_audio`
/// - "Get Song Details by ID" modal with fresh media_url and lyrics inspection
class JioSaavnPage extends StatefulWidget {
  const JioSaavnPage({super.key});

  @override
  State<JioSaavnPage> createState() => _JioSaavnPageState();
}

class _JioSaavnPageState extends State<JioSaavnPage> {
  final JioSaavnService _service = JioSaavnService();
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _searchCtrl = TextEditingController(text: 'Kesariya Arijit Singh');

  List<JioSaavnTrack> _tracks = [];
  JioSaavnTrack? _currentTrack;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _quickSuggestions = const [
    'Kesariya',
    'Apna Bana Le',
    'Chaleya',
    'Tum Hi Ho',
    'Heeriye',
    'Arijit Singh',
  ];

  @override
  void initState() {
    super.initState();
    // Perform initial search
    _executeSearch(_searchCtrl.text);
  }

  @override
  void dispose() {
    _player.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _executeSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // [UNOFFICIAL JIOSAAVN API CALL] Executes search via JioSaavnService
      final results = await _service.searchSongs(clean);
      if (mounted) {
        setState(() {
          _tracks = results;
          _isLoading = false;
          if (results.isEmpty) {
            _errorMessage = 'No results found for "$clean". Try another Bollywood song or artist.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to fetch search results. Check network or API availability.\n$e';
        });
      }
    }
  }

  /// 4. PASS MEDIA_URL TO AUDIO PLAYER:
  /// Passes the fresh streaming URL to `just_audio` AudioPlayer.
  Future<void> _playTrack(JioSaavnTrack track) async {
    setState(() => _currentTrack = track);

    try {
      // Validate that mediaUrl is non-empty
      if (track.mediaUrl.isEmpty) {
        // [UNOFFICIAL JIOSAAVN API CALL] Fallback: fetch fresh URL by ID if track had empty URL
        final fresh = await _service.getSongById(track.id);
        if (fresh == null || fresh.mediaUrl.isEmpty) {
          throw Exception("Unable to resolve playable stream URL for this track.");
        }
        track = fresh;
        setState(() => _currentTrack = fresh);
      }

      debugPrint('[JioSaavnPage] Feeding media_url into audio player: ${track.mediaUrl}');

      // Set URL and play via just_audio
      await _player.setUrl(track.mediaUrl);
      await _player.play();
    } catch (e) {
      debugPrint('[JioSaavnPage] Playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot play "${track.title}": $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 3. GET SONG BY ID INSPECTION DIALOG:
  /// Calls `getSongById` to demonstrate on-demand fresh metadata and lyrics retrieval.
  Future<void> _inspectSongDetails(String songId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // [UNOFFICIAL JIOSAAVN API CALL] Fetch fresh song details by ID
    final detailedTrack = await _service.getSongById(songId, fetchLyrics: true);

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading dialog

    if (detailedTrack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch song details for this ID.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        detailedTrack.imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: Colors.white12,
                          child: const Icon(Icons.music_note, color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detailedTrack.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            detailedTrack.primaryArtists,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            'Album: ${detailedTrack.album} (${detailedTrack.year})',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          Text(
                            'Duration: ${detailedTrack.formattedDuration}',
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                const Text(
                  'Fresh Media Stream URL:',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  detailedTrack.mediaUrl,
                  style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 16),
                if (detailedTrack.lyrics != null && detailedTrack.lyrics!.isNotEmpty) ...[
                  const Text(
                    'Lyrics:',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      detailedTrack.lyrics!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Lyrics: Not available for this track',
                    style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play Fresh Stream', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _playTrack(detailedTrack);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131315),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1F),
        elevation: 0,
        title: const Text(
          'Bollywood Stream (JioSaavn Unofficial)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search Bollywood song or artist...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.amberAccent),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchCtrl.clear();
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onSubmitted: _executeSearch,
                ),
              ),

              // Quick Filter Chips
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _quickSuggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, idx) {
                    final term = _quickSuggestions[idx];
                    return ActionChip(
                      backgroundColor: Colors.white.withOpacity(0.06),
                      label: Text(term, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      onPressed: () {
                        _searchCtrl.text = term;
                        _executeSearch(term);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomPlayer(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.amberAccent),
            SizedBox(height: 16),
            Text('Fetching Bollywood tracks from JioSaavn...', style: TextStyle(color: Colors.white60)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black87),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Search'),
                onPressed: () => _executeSearch(_searchCtrl.text),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _tracks.length,
      itemBuilder: (_, i) {
        final t = _tracks[i];
        final isSelected = _currentTrack?.id == t.id;

        return Card(
          color: isSelected ? Colors.amberAccent.withOpacity(0.12) : const Color(0xFF1E1E24),
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? Colors.amberAccent : Colors.white.withOpacity(0.04),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                t.imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.white12,
                  child: const Icon(Icons.music_note, color: Colors.white54),
                ),
              ),
            ),
            title: Text(
              t.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? Colors.amberAccent : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  '${t.primaryArtists} · ${t.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t.formattedDuration,
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (t.hasLyrics)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LYRICS',
                          style: TextStyle(color: Colors.tealAccent, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 20),
                  tooltip: 'Inspect Fresh Details by ID',
                  onPressed: () => _inspectSongDetails(t.id),
                ),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (_, snap) {
                    final isPlayingThis = isSelected && (snap.data?.playing ?? false);
                    return IconButton(
                      icon: Icon(
                        isPlayingThis ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: Colors.amberAccent,
                        size: 36,
                      ),
                      onPressed: () {
                        if (isPlayingThis) {
                          _player.pause();
                        } else {
                          _playTrack(t);
                        }
                      },
                    );
                  },
                ),
              ],
            ),
            onTap: () => _playTrack(t),
          ),
        );
      },
    );
  }

  Widget? _buildBottomPlayer() {
    if (_currentTrack == null) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E24),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    _currentTrack!.imageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentTrack!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${_currentTrack!.primaryArtists} · via JioSaavn (Unofficial)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (_, snap) {
                    final playing = snap.data?.playing ?? false;
                    return IconButton(
                      icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                      onPressed: () => playing ? _player.pause() : _player.play(),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.stop_rounded, color: Colors.white54),
                  onPressed: () {
                    _player.stop();
                    setState(() => _currentTrack = null);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
