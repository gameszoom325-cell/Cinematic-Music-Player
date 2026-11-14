import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/models/song_model.dart';
import '../../../core/services/scanner_service.dart';

class LibraryState {
  final List<SongModel> songs;
  final bool isScanning;
  final int scanProgress;
  final int scanTotal;
  final String searchQuery;

  const LibraryState({
    this.songs = const [],
    this.isScanning = false,
    this.scanProgress = 0,
    this.scanTotal = 0,
    this.searchQuery = "",
  });

  LibraryState copyWith({
    List<SongModel>? songs,
    bool? isScanning,
    int? scanProgress,
    int? scanTotal,
    String? searchQuery,
  }) {
    return LibraryState(
      songs: songs ?? this.songs,
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
  }

  void refreshLibrary() {
    final songs = DatabaseService.instance.searchSongs(state.searchQuery);
    state = state.copyWith(songs: songs);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    refreshLibrary();
  }

  Future<void> scanFolder(String folderPath) async {
    state = state.copyWith(isScanning: true, scanProgress: 0, scanTotal: 0);

    final dir = Directory(folderPath);
    await ScannerService.scanDirectory(
      dir,
      onProgress: (current, total) {
        state = state.copyWith(scanProgress: current, scanTotal: total);
      },
    );

    state = state.copyWith(isScanning: false);
    refreshLibrary();
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier();
});
