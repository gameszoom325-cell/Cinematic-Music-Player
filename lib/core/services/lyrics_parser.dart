import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });
}

class SyncedLyrics {
  final List<LyricLine> lines;
  final String? title;
  final String? artist;
  final String? album;
  final int offsetMs;

  const SyncedLyrics({
    required this.lines,
    this.title,
    this.artist,
    this.album,
    this.offsetMs = 0,
  });

  static const empty = SyncedLyrics(lines: []);

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  // Find the active lyric line index for current playback position
  int getActiveIndex(Duration position) {
    if (lines.isEmpty) return -1;
    final targetMs = position.inMilliseconds + offsetMs;

    int activeIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].timestamp.inMilliseconds <= targetMs) {
        activeIndex = i;
      } else {
        break;
      }
    }
    return activeIndex;
  }
}

class LyricsParser {
  // RegExp matching [mm:ss.xx] or [mm:ss] or [mm:ss.xxx]
  static final RegExp _timestampRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
  static final RegExp _tagRegex = RegExp(r'\[(ti|ar|al|offset):([^\]]+)\]', caseSensitive: false);

  // Discover and parse companion .lrc file next to audio file
  static Future<SyncedLyrics?> findAndParseLrc(String audioFilePath) async {
    final audioFile = File(audioFilePath);
    if (!await audioFile.exists()) return null;

    final dir = audioFile.parent.path;
    final baseName = p.basenameWithoutExtension(audioFilePath);

    // 1. Check exact match: Song.lrc
    final lrcFile = File(p.join(dir, '$baseName.lrc'));
    if (await lrcFile.exists()) {
      return await parseLrcFile(lrcFile);
    }

    // 2. Check case-insensitive match
    try {
      await for (final entity in audioFile.parent.list(followLinks: false)) {
        if (entity is File && p.extension(entity.path).toLowerCase() == '.lrc') {
          if (p.basenameWithoutExtension(entity.path).toLowerCase() == baseName.toLowerCase()) {
            return await parseLrcFile(entity);
          }
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<SyncedLyrics> parseLrcFile(File file) async {
    try {
      final content = await file.readAsString();
      return parseLrcString(content);
    } catch (e) {
      debugPrint("Error reading .lrc file ${file.path}: $e");
      return SyncedLyrics.empty;
    }
  }

  static SyncedLyrics parseLrcString(String lrcText) {
    final lines = lrcText.split(RegExp(r'\r?\n'));
    final List<LyricLine> lyricLines = [];

    String? title;
    String? artist;
    String? album;
    int offsetMs = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Check metadata tags e.g. [ti:Song Title]
      final tagMatch = _tagRegex.firstMatch(line);
      if (tagMatch != null) {
        final tag = tagMatch.group(1)?.toLowerCase();
        final value = tagMatch.group(2)?.trim() ?? "";
        if (tag == 'ti') title = value;
        if (tag == 'ar') artist = value;
        if (tag == 'al') album = value;
        if (tag == 'offset') offsetMs = int.tryParse(value) ?? 0;
        continue;
      }

      // Check timestamp matches (can be multiple on one line)
      final matches = _timestampRegex.allMatches(line).toList();
      if (matches.isNotEmpty) {
        final text = line.replaceAll(_timestampRegex, '').trim();

        for (final match in matches) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final fractionStr = match.group(3) ?? "0";
          
          int millis = 0;
          if (fractionStr.length == 1) {
            millis = int.parse(fractionStr) * 100;
          } else if (fractionStr.length == 2) {
            millis = int.parse(fractionStr) * 10;
          } else if (fractionStr.length >= 3) {
            millis = int.parse(fractionStr.substring(0, 3));
          }

          final duration = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: millis,
          );

          if (text.isNotEmpty) {
            lyricLines.add(LyricLine(timestamp: duration, text: text));
          }
        }
      }
    }

    // Sort chronologically
    lyricLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return SyncedLyrics(
      lines: lyricLines,
      title: title,
      artist: artist,
      album: album,
      offsetMs: offsetMs,
    );
  }
}
