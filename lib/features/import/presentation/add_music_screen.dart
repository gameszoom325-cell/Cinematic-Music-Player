import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/scanner_service.dart';
import '../../library/providers/library_provider.dart';

class AddMusicScreen extends ConsumerStatefulWidget {
  const AddMusicScreen({super.key});

  @override
  ConsumerState<AddMusicScreen> createState() => _AddMusicScreenState();
}

class _AddMusicScreenState extends ConsumerState<AddMusicScreen> {
  bool _isImporting = false;
  String _statusText = "";
  int _current = 0;
  int _total = 0;

  Future<void> _handleSelectFolder() async {
    final folderPath = await ScannerService.pickMusicFolder();
    if (folderPath != null) {
      _startDirectoryScan(Directory(folderPath));
    }
  }

  Future<void> _handleImportFiles() async {
    final files = await ScannerService.pickAudioFiles();
    if (files != null && files.isNotEmpty) {
      setState(() {
        _isImporting = true;
        _current = 0;
        _total = files.length;
        _statusText = "Importing selected audio tracks...";
      });

      await ScannerService.importFiles(
        files,
        onProgress: (current, total) {
          setState(() {
            _current = current;
            _total = total;
          });
        },
      );

      ref.read(libraryProvider.notifier).refreshLibrary();
      setState(() {
        _isImporting = false;
        _statusText = "Successfully imported ${files.length} tracks!";
      });
      _showSuccessSnackbar("Imported ${files.length} songs into your personal library");
    }
  }

  Future<void> _handleScanDevice() async {
    final granted = await ScannerService.requestStoragePermissions();
    if (!granted && defaultTargetPlatform == TargetPlatform.android) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Storage / Audio permission required to scan device music folders."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final dirs = ScannerService.getStandardMusicDirectories();
    setState(() {
      _isImporting = true;
      _current = 0;
      _total = 0;
      _statusText = "Scanning standard storage directories...";
    });

    int totalAdded = 0;
    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        final songs = await ScannerService.scanDirectory(
          dir,
          onProgress: (c, t) {
            setState(() {
              _current = c;
              _total = t;
              _statusText = "Scanning: ${dir.path} ($c/$t)";
            });
          },
        );
        totalAdded += songs.length;
      }
    }

    ref.read(libraryProvider.notifier).refreshLibrary();
    setState(() {
      _isImporting = false;
      _statusText = "Scan complete. Found $totalAdded tracks.";
    });
    _showSuccessSnackbar("Device scan found $totalAdded audio tracks");
  }

  Future<void> _startDirectoryScan(Directory dir) async {
    setState(() {
      _isImporting = true;
      _current = 0;
      _total = 0;
      _statusText = "Scanning directory: ${dir.path}...";
    });

    final songs = await ScannerService.scanDirectory(
      dir,
      onProgress: (current, total) {
        setState(() {
          _current = current;
          _total = total;
          _statusText = "Extracting metadata & artwork ($current / $total)...";
        });
      },
    );

    ref.read(libraryProvider.notifier).refreshLibrary();
    setState(() {
      _isImporting = false;
      _statusText = "Completed: Added ${songs.length} tracks.";
    });
    _showSuccessSnackbar("Imported ${songs.length} songs from folder");
  }

  void _showSuccessSnackbar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: CinematicColors.electricViolet,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinematicColors.obsidianBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Add Music", style: CinematicTypography.displayTitle),
                  GlassIconButton(
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context).maybePop(),
                    size: 42,
                    iconSize: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Import your private audio collection into your offline vault.",
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 28),

              // Option 1: Select Music Folder
              _buildImportOption(
                icon: Icons.folder_open_rounded,
                title: "Select Music Folder",
                subtitle: "Recursively scan a directory for MP3, FLAC, WAV, M4A, OGG",
                accentColor: CinematicColors.electricViolet,
                onTap: _isImporting ? null : _handleSelectFolder,
              ),
              const SizedBox(height: 16),

              // Option 2: Import Specific Audio Files
              _buildImportOption(
                icon: Icons.audio_file_rounded,
                title: "Import Audio Files",
                subtitle: "Pick one or multiple audio tracks directly from storage",
                accentColor: CinematicColors.neonCyan,
                onTap: _isImporting ? null : _handleImportFiles,
              ),
              const SizedBox(height: 16),

              // Option 3: Scan Device Storage
              _buildImportOption(
                icon: Icons.phonelink_setup_rounded,
                title: "Scan Device Storage",
                subtitle: "Automatically inspect standard Music and Download locations",
                accentColor: CinematicColors.hotPink,
                onTap: _isImporting ? null : _handleScanDevice,
              ),
              const SizedBox(height: 28),

              // Live Status / Progress Panel
              if (_isImporting || _statusText.isNotEmpty)
                CinematicGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (_isImporting)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: CinematicColors.electricViolet,
                              ),
                            )
                          else
                            const Icon(Icons.check_circle_rounded, color: CinematicColors.radioactiveGreen, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusText,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (_isImporting && _total > 0) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _total > 0 ? (_current / _total).clamp(0.0, 1.0) : null,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation(CinematicColors.electricViolet),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "$_current of $_total files processed",
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),

              const Spacer(),

              // Supported Formats Indicator
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: const Text(
                    "SUPPORTED FORMATS:  MP3 • FLAC • WAV • M4A • OGG  (100% OFFLINE)",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: CinematicGlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: accentColor.withOpacity(0.18),
                border: Border.all(color: accentColor.withOpacity(0.4), width: 1.2),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}
