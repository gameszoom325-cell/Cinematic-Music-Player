import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/curated_catalogue.dart';
import '../database/models/song_model.dart';

class SmartMatchingService {
  // Normalize string for fuzzy matching
  static String normalize(String input) {
    String text = p.basenameWithoutExtension(input).toLowerCase();

    // Remove common prefixes e.g. "01 - ", "01. ", "01_", "Track 1 - "
    text = text.replaceAll(RegExp(r'^\d+[\s\.\-_]+'), '');
    text = text.replaceAll(RegExp(r'^track\s*\d+[\s\.\-_]+', caseSensitive: false), '');

    // Remove bracketed tag descriptions
    text = text.replaceAll(RegExp(r'\[.*?\]'), '');
    text = text.replaceAll(RegExp(r'\(.*?\)'), '');

    // Remove noise words
    final noiseWords = [
      'official audio', 'official video', 'full song', 'audio song',
      'lyric video', 'lyrics', 'remastered', '320kbps', '128kbps',
      'pagalworld', 'djmaza', 'mp3', 'flac', 'song', 'mp3song'
    ];
    for (final noise in noiseWords) {
      text = text.replaceAll(noise, '');
    }

    // Keep only letters, digits, and single spaces
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  // Attempt to match an imported audio file against the curated catalogue
  static CuratedSongEntry? findCatalogueMatch({
    required String filePath,
    required String tagTitle,
    required String tagArtist,
  }) {
    final normalizedFileName = normalize(p.basename(filePath));
    final normalizedTagTitle = normalize(tagTitle);
    final normalizedTagArtist = normalize(tagArtist);

    for (final entry in CuratedCatalogue.allSongs) {
      final normalizedEntryTitle = normalize(entry.title);

      // Exact normalized title match
      if (normalizedFileName == normalizedEntryTitle ||
          normalizedTagTitle == normalizedEntryTitle) {
        return entry;
      }

      // Substring containment match
      if (normalizedFileName.contains(normalizedEntryTitle) ||
          normalizedTagTitle.contains(normalizedEntryTitle)) {
        return entry;
      }

      // Check inverted: catalogue entry contained in file name
      if (normalizedEntryTitle.contains(normalizedFileName) &&
          normalizedFileName.length >= 4) {
        return entry;
      }
    }

    return null;
  }

  // Auto-enrich a SongModel with curated catalogue metadata and lyrics
  static Future<SongModel> enrichSongWithCatalogue({
    required SongModel song,
    required CuratedSongEntry match,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    final lyricsDir = Directory(p.join(docDir.path, 'CinematicMusicPlayer', 'lyrics'));
    if (!await lyricsDir.exists()) await lyricsDir.create(recursive: true);

    // Save or link companion .lrc file
    final lrcFile = File(p.join(lyricsDir.path, match.lrcFileName));
    if (!await lrcFile.exists() || (await lrcFile.length() == 0)) {
      await lrcFile.writeAsString(match.demoLyrics.trim());
    }

    debugPrint("✨ Smart Match Found: '${song.title}' -> '${match.title}' (${match.album})");

    return song.copyWith(
      title: match.title,
      artist: match.artist,
      album: match.album,
      language: match.language,
      genre: match.genre,
      year: match.year,
      lrcPath: lrcFile.path,
    );
  }
}
