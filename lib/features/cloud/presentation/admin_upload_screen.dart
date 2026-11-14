import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/services/audio_metadata_parser.dart';
import '../../../core/services/cloud_music_service.dart';
import '../../../core/database/models/cloud_song_model.dart';
import '../../../core/audio_engine/audio_engine.dart';

class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _albumCtrl = TextEditingController();
  final _genreCtrl = TextEditingController(text: "Bollywood");
  final _releaseInfoCtrl = TextEditingController();

  File? _selectedAudioFile;
  File? _selectedCoverFile;
  Uint8List? _embeddedCoverBytes;

  int _extractedDurationSec = 210;
  bool _isUploading = false;
  String _uploadStatus = "";
  double _uploadProgress = 0.0;

  List<CloudSongModel> _managedSongs = [];
  bool _isLoadingSongs = true;

  @override
  void initState() {
    super.initState();
    _loadManagedSongs();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _genreCtrl.dispose();
    _releaseInfoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadManagedSongs() async {
    setState(() => _isLoadingSongs = true);
    final songs = await CloudMusicService.instance.fetchSongs();
    if (mounted) {
      setState(() {
        _managedSongs = songs;
        _isLoadingSongs = false;
      });
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        setState(() {
          _selectedAudioFile = file;
          _uploadStatus = "Extracting ID3/Vorbis audio metadata...";
        });

        // Auto extract metadata
        final meta = await AudioMetadataParser.parseFile(file);

        setState(() {
          _titleCtrl.text = meta.title.isNotEmpty ? meta.title : p.basenameWithoutExtension(file.path);
          _artistCtrl.text = meta.artist.isNotEmpty && meta.artist != 'Unknown Artist' ? meta.artist : '';
          _albumCtrl.text = meta.album.isNotEmpty && meta.album != 'Unknown Album' ? meta.album : 'Single';
          if (meta.genre.isNotEmpty && meta.genre != 'Uncategorized') {
            _genreCtrl.text = meta.genre;
          }
          _extractedDurationSec = (meta.durationMs / 1000).round();
          if (_extractedDurationSec <= 0) _extractedDurationSec = 210;
          _embeddedCoverBytes = meta.pictureBytes;
          _uploadStatus = "Metadata auto-extracted successfully.";
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking audio file: $e")),
        );
      }
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedCoverFile = File(result.files.single.path!);
          _embeddedCoverBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking cover image: $e")),
        );
      }
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedAudioFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an audio file to upload.")),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.2;
      _uploadStatus = "Uploading audio master to Supabase Storage (music-files)...";
    });

    try {
      // 1. Upload audio file
      final audioUrl = await CloudMusicService.instance.uploadAudioFile(
        _selectedAudioFile!,
        onProgress: (p) => setState(() => _uploadProgress = 0.2 + (p * 0.4)),
      );

      setState(() {
        _uploadProgress = 0.65;
        _uploadStatus = "Uploading album artwork (album-covers)...";
      });

      // 2. Upload cover artwork
      String coverUrl = "";
      if (_selectedCoverFile != null) {
        coverUrl = await CloudMusicService.instance.uploadCoverImage(file: _selectedCoverFile);
      } else if (_embeddedCoverBytes != null && _embeddedCoverBytes!.isNotEmpty) {
        coverUrl = await CloudMusicService.instance.uploadCoverImage(
          rawBytes: _embeddedCoverBytes,
          preferredName: "${_titleCtrl.text.replaceAll(' ', '_')}_art.jpg",
        );
      } else {
        coverUrl = "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80";
      }

      setState(() {
        _uploadProgress = 0.85;
        _uploadStatus = "Writing song, artist, and album records to Cloud Database...";
      });

      // 3. Register Song in Supabase
      final songId = "song_${DateTime.now().millisecondsSinceEpoch}";
      final cloudSong = CloudSongModel(
        id: songId,
        title: _titleCtrl.text.trim(),
        artist: _artistCtrl.text.trim().isNotEmpty ? _artistCtrl.text.trim() : "Unknown Artist",
        album: _albumCtrl.text.trim().isNotEmpty ? _albumCtrl.text.trim() : "Single",
        coverImage: coverUrl,
        genre: _genreCtrl.text.trim().isNotEmpty ? _genreCtrl.text.trim() : "Bollywood",
        duration: _extractedDurationSec,
        audioUrl: audioUrl,
        playCount: 1,
        createdAt: DateTime.now(),
      );

      await CloudMusicService.instance.addSongToCloud(cloudSong);

      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
        _uploadStatus = "Track successfully published to Private Cloud Library!";
        _selectedAudioFile = null;
        _selectedCoverFile = null;
        _embeddedCoverBytes = null;
      });

      _titleCtrl.clear();
      _artistCtrl.clear();
      _albumCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Published '${cloudSong.title}' to Cloud Library!"),
            backgroundColor: CinematicColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await _loadManagedSongs();
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = "Upload failed: $e";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading song: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleDeleteSong(CloudSongModel song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CinematicColors.surfaceContainerLow,
        title: const Text("Delete Cloud Track", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete '${song.title}' from the Cloud Library?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CloudMusicService.instance.deleteSong(song.id);
      await _loadManagedSongs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Deleted '${song.title}' from cloud catalog")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinematicColors.background,
      appBar: AppBar(
        backgroundColor: CinematicColors.surfaceContainerLowest,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: CinematicColors.primary, size: 22),
            SizedBox(width: 10),
            Text(
              "Admin Music Library",
              style: TextStyle(
                color: CinematicColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CinematicColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CinematicColors.primary.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: CinematicColors.primary, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PRIVATE CLOUD PUBLISHER",
                          style: TextStyle(
                            color: CinematicColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Upload high-bitrate master audio and album art directly to your cloud storage. Metadata is extracted automatically.",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Select Audio Master Section
            const Text(
              "1. Audio Master File",
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickAudioFile,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: CinematicColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedAudioFile != null
                        ? CinematicColors.primary
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CinematicColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _selectedAudioFile != null ? Icons.audio_file_rounded : Icons.upload_file_rounded,
                        color: _selectedAudioFile != null ? CinematicColors.primary : Colors.white60,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAudioFile != null
                                ? p.basename(_selectedAudioFile!.path)
                                : "Choose Audio Master (.mp3, .flac, .wav, .m4a)",
                            style: TextStyle(
                              color: _selectedAudioFile != null ? Colors.white : Colors.white60,
                              fontWeight: _selectedAudioFile != null ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedAudioFile != null
                                ? "Size: ${(_selectedAudioFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB • Auto-extracting metadata"
                                : "Click to browse local files",
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CinematicColors.surfaceContainerHigh,
                        foregroundColor: CinematicColors.primary,
                        elevation: 0,
                      ),
                      onPressed: _pickAudioFile,
                      child: Text(_selectedAudioFile != null ? "Change" : "Browse"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Metadata Form
            const Text(
              "2. Metadata & Artwork",
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Row for Cover Art and Title/Artist
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover Artwork Preview
                      GestureDetector(
                        onTap: _pickCoverImage,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: CinematicColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: _selectedCoverFile != null
                                ? Image.file(_selectedCoverFile!, fit: BoxFit.cover)
                                : (_embeddedCoverBytes != null
                                    ? Image.memory(_embeddedCoverBytes!, fit: BoxFit.cover)
                                    : const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate_rounded, color: Colors.white38, size: 28),
                                          SizedBox(height: 4),
                                          Text("Cover Art", style: TextStyle(color: Colors.white38, fontSize: 11)),
                                        ],
                                      )),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Title & Artist
                      Expanded(
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _titleCtrl,
                              label: "Song Title",
                              hint: "e.g. Tum Hi Ho",
                              validator: (v) => v == null || v.trim().isEmpty ? "Title is required" : null,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _artistCtrl,
                              label: "Artist",
                              hint: "e.g. Arijit Singh",
                              validator: (v) => v == null || v.trim().isEmpty ? "Artist is required" : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Album & Genre
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _albumCtrl,
                          label: "Album / Movie",
                          hint: "e.g. Aashiqui 2",
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildTextField(
                          controller: _genreCtrl,
                          label: "Genre",
                          hint: "e.g. Bollywood, Lo-Fi, Sufi",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Upload Progress & Action Button
            if (_isUploading) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: CinematicColors.surfaceContainerHigh,
                valueColor: const AlwaysStoppedAnimation<Color>(CinematicColors.primary),
              ),
              const SizedBox(height: 10),
              Text(
                _uploadStatus,
                style: const TextStyle(color: CinematicColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
            ] else if (_uploadStatus.isNotEmpty) ...[
              Text(
                _uploadStatus,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CinematicColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isUploading ? null : _handleUpload,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text(
                  "Publish Song to Cloud Library",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 36),

            // Manage Existing Songs in Cloud Library
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Active Cloud Catalog (${_managedSongs.length})",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  onPressed: _loadManagedSongs,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoadingSongs)
              const Center(child: CircularProgressIndicator(color: CinematicColors.primary))
            else if (_managedSongs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: CinematicColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    "No songs uploaded to cloud yet. Select an audio file above to publish.",
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _managedSongs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final s = _managedSongs[idx];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: CinematicColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: s.coverImage.startsWith('http')
                              ? Image.network(
                                  s.coverImage,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 44,
                                    height: 44,
                                    color: CinematicColors.surfaceContainerHigh,
                                    child: const Icon(Icons.music_note_rounded, color: Colors.white38),
                                  ),
                                )
                              : Container(
                                  width: 44,
                                  height: 44,
                                  color: CinematicColors.surfaceContainerHigh,
                                  child: const Icon(Icons.music_note_rounded, color: Colors.white38),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${s.artist} • ${s.album} • ${s.genre}",
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded, color: CinematicColors.primary, size: 26),
                          tooltip: "Test Stream",
                          onPressed: () {
                            AudioEngine.instance.playTrack([s.toSongModel()], 0);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          tooltip: "Delete from Cloud",
                          onPressed: () => _handleDeleteSong(s),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: CinematicColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CinematicColors.primary),
        ),
      ),
    );
  }
}
