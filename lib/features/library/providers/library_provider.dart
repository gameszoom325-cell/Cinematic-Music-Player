import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/models/song_model.dart';
import '../../../core/services/scanner_service.dart';

class LibraryState {
  final List<SongModel> songs;
  final List<String> folders;
  final bool isScanning;
  final int scanProgress;
  final int scanTotal;
  final String searchQuery;

  const LibraryState({
    this.songs = const [],
    this.folders = const [],
    this.isScanning = false,
    this.scanProgress = 0,
    this.scanTotal = 0,
    this.searchQuery = "",
  });

  LibraryState copyWith({
    List<SongModel>? songs,
    List<String>? folders,
    bool? isScanning,
    int? scanProgress,
    int? scanTotal,
    String? searchQuery,
  }) {
    return LibraryState(
      songs: songs ?? this.songs,
      folders: folders ?? this.folders,
      isScanning: isScanning ?? this.isScanning,
      scanProgress: scanProgress ?? this.scanProgress,
      scanTotal: scanTotal ?? this.scanTotal,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  LibraryNotifier() : super(const LibraryState()) {
    refreshLibrary();
    _autoRescanSavedFoldersOnStartup();
  }

  void refreshLibrary() {
    final songs = DatabaseService.instance.searchSongs(state.searchQuery);
    final folders = DatabaseService.instance.libraryFolders;
    state = state.copyWith(songs: songs, folders: folders);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    refreshLibrary();
  }

  Future<void> addAndScanFolder(String folderPath) async {
    final clean = folderPath.trim();
    if (clean.isEmpty) return;

    await DatabaseService.instance.addLibraryFolder(clean);
    await scanFolder(clean);
  }

  Future<void> removeFolder(String folderPath) async {
    await DatabaseService.instance.removeLibraryFolder(folderPath);
    refreshLibrary();
  }

  Future<void> removeSong(String songId) async {
    await DatabaseService.instance.removeSong(songId);
    refreshLibrary();
  }

  Future<void> rescanAll() async {
    state = state.copyWith(isScanning: true, scanProgress: 0, scanTotal: 0);

    try {
      await DatabaseService.instance.rescanLibrary(
        onProgress: (current, total) {
          state = state.copyWith(scanProgress: current, scanTotal: total);
        },
      );
    } catch (_) {}

    state = state.copyWith(isScanning: false);
    refreshLibrary();
  }

  Future<void> scanFolder(String folderPath) async {
    state = state.copyWith(isScanning: true, scanProgress: 0, scanTotal: 0);

    final dir = Directory(folderPath);
    if (await dir.exists()) {
      await ScannerService.scanDirectory(
        dir,
        onProgress: (current, total) {
          state = state.copyWith(scanProgress: current, scanTotal: total);
        },
      );
    }

    state = state.copyWith(isScanning: false);
    refreshLibrary();
  }

  void _autoRescanSavedFoldersOnStartup() {
    Future.microtask(() async {
      final folders = DatabaseService.instance.libraryFolders;
      if (folders.isNotEmpty) {
        await rescanAll();
      }
    });
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier();
});
