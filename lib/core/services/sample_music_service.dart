import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/models/song_model.dart';
import '../database/database_service.dart';
import '../database/curated_catalogue.dart';
import '../audio_engine/waveform_analyzer.dart';
import 'audio_metadata_parser.dart';

class SampleMusicService {
  static Future<void> ensureSampleTracks() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final sampleDir = Directory(p.join(docDir.path, 'CinematicMusicPlayer', 'demo_audio'));
      final artDir = Directory(p.join(docDir.path, 'CinematicMusicPlayer', 'art_cache'));
      final lyricsDir = Directory(p.join(docDir.path, 'CinematicMusicPlayer', 'lyrics'));

      if (!await sampleDir.exists()) await sampleDir.create(recursive: true);
      if (!await artDir.exists()) await artDir.create(recursive: true);
      if (!await lyricsDir.exists()) await lyricsDir.create(recursive: true);

      // Pre-seed all 19 Curated Hindi LRC files in the lyrics/ repository
      for (final entry in CuratedCatalogue.allSongs) {
        final lrcFile = File(p.join(lyricsDir.path, entry.lrcFileName));
        if (!await lrcFile.exists() || (await lrcFile.length() == 0)) {
          await lrcFile.writeAsString(entry.demoLyrics.trim());
        }
      }

      final List<SongModel> demoTracks = [];

      // 1. Bundled Real MP3 Demo: Bairan
      final mp3File = File(p.join(sampleDir.path, 'bairan_demo.mp3'));
      if (!await mp3File.exists() || await mp3File.length() == 0) {
        try {
          final byteData = await rootBundle.load('assets/audio/bairan_demo.mp3');
          await mp3File.writeAsBytes(byteData.buffer.asUint8List());
        } catch (e) {
          debugPrint("Note: Could not load assets/audio/bairan_demo.mp3 from bundle: $e");
        }
      }

      if (await mp3File.exists() && await mp3File.length() > 0) {
        final parsed = await AudioMetadataParser.parseFile(mp3File);
        String? artworkPath;
        if (parsed.pictureBytes != null && parsed.pictureBytes!.isNotEmpty) {
          final artFile = File(p.join(artDir.path, 'demo_bairan.jpg'));
          await artFile.writeAsBytes(parsed.pictureBytes!);
          artworkPath = artFile.path;
        }

        final bairanSong = SongModel(
          id: "demo_track_bairan",
          path: mp3File.path,
          title: "Bairan (Demo)",
          artist: parsed.artist != "Unknown Artist" ? "${parsed.artist} (Demo)" : "Amit Trivedi (Demo)",
          album: "Cinematic Demos",
          durationMs: parsed.durationMs > 0 ? parsed.durationMs : 151000,
          bitrate: parsed.bitrate > 0 ? parsed.bitrate : 320,
          sampleRate: parsed.sampleRate > 0 ? parsed.sampleRate : 44100,
          format: "MP3",
          fileSize: await mp3File.length(),
          hasArtwork: artworkPath != null,
          artworkPath: artworkPath,
          bpm: 104.0,
          genre: "Bollywood / Hindi (Demo)",
          year: "2024",
          isFavorite: true,
          dateAdded: DateTime.now(),
        );
        demoTracks.add(bairanSong);
      }

      // 2. Track 1: Neon Horizon (Synthwave 120 BPM Demo)
      final track1 = await _generateTrack(
        sampleDir: sampleDir,
        artDir: artDir,
        id: "demo_track_1",
        filename: "neon_horizon.wav",
        title: "Neon Horizon (Demo)",
        artist: "Aura Synths (Demo)",
        album: "Cinematic Demos",
        bpm: 120.0,
        durationSeconds: 16,
        baseFreq: 55.0,
        format: "WAV",
        colorHex: 0xFF8B5CF6,
      );
      demoTracks.add(track1);

      // 3. Track 2: Deep Space Pulse (Ambient 90 BPM Demo)
      final track2 = await _generateTrack(
        sampleDir: sampleDir,
        artDir: artDir,
        id: "demo_track_2",
        filename: "deep_space_pulse.wav",
        title: "Deep Space Pulse (Demo)",
        artist: "Cosmic Frequency (Demo)",
        album: "Cinematic Demos",
        bpm: 90.0,
        durationSeconds: 20,
        baseFreq: 65.41,
        format: "WAV",
        colorHex: 0xFF06B6D4,
      );
      demoTracks.add(track2);

      // 4. Track 3: Solar Flare (Melodic DnB 140 BPM Demo)
      final track3 = await _generateTrack(
        sampleDir: sampleDir,
        artDir: artDir,
        id: "demo_track_3",
        filename: "solar_flare.wav",
        title: "Solar Flare (Demo)",
        artist: "Hyperion (Demo)",
        album: "Cinematic Demos",
        bpm: 140.0,
        durationSeconds: 14,
        baseFreq: 73.42,
        format: "WAV",
        colorHex: 0xFFEC4899,
      );
      demoTracks.add(track3);

      // Only upsert playable tracks with valid local files
      final validDemoTracks = demoTracks.where((t) => t.isLocalFileAvailable).toList();
      await DatabaseService.instance.upsertSongs(validDemoTracks);

      // Ensure Demo Playlist exists
      final allPlaylists = DatabaseService.instance.getAllPlaylists();
      final hasDemoPlaylist = allPlaylists.any((p) => p.name == "Cinematic Demos");
      if (!hasDemoPlaylist) {
        await DatabaseService.instance.createPlaylist(
          "Cinematic Demos",
          description: "Studio high-fidelity demo tracks with audio reactive visualizers.",
        );
      }

      final pl = DatabaseService.instance.getAllPlaylists().firstWhere(
        (p) => p.name == "Cinematic Demos",
        orElse: () => allPlaylists.first,
      );

      for (final s in validDemoTracks) {
        await DatabaseService.instance.addSongToPlaylist(pl.id, s.id);
        WaveformAnalyzer.analyzeSong(s.id, s.path).ignore();
      }
    } catch (e) {
      debugPrint("Error creating sample demo tracks: $e");
    }
  }

  static Future<SongModel> _generateTrack({
    required Directory sampleDir,
    required Directory artDir,
    required String id,
    required String filename,
    required String title,
    required String artist,
    required String album,
    required double bpm,
    required int durationSeconds,
    required double baseFreq,
    required String format,
    required int colorHex,
  }) async {
    final audioFile = File(p.join(sampleDir.path, filename));
    final artFile = File(p.join(artDir.path, '$id.bmp'));
    final lrcFile = File(p.join(sampleDir.path, '${p.basenameWithoutExtension(filename)}.lrc'));

    if (!await audioFile.exists()) {
      final wavBytes = _synthesizeWav(durationSeconds, bpm, baseFreq);
      await audioFile.writeAsBytes(wavBytes);
    }

    if (!await artFile.exists()) {
      final bmpBytes = _generateBmpArtwork(colorHex);
      await artFile.writeAsBytes(bmpBytes);
    }

    if (!await lrcFile.exists()) {
      final lrcContent = """
[ti:$title]
[ar:$artist]
[al:$album]
[00:00.00] (Instrumental Intro • Harmonic Synthesizer)
[00:03.50] Gliding through the obsidian sky
[00:06.80] Neon pulses passing by
[00:10.20] Audio reactive frequencies align
[00:13.50] Cinematic rhythm in the mind
""";
      await lrcFile.writeAsString(lrcContent.trim());
    }

    return SongModel(
      id: id,
      path: audioFile.path,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationSeconds * 1000,
      bitrate: 1411,
      sampleRate: 44100,
      format: format,
      fileSize: await audioFile.length(),
      hasArtwork: true,
      artworkPath: artFile.path,
      bpm: bpm,
      genre: "Electronic / Cinematic",
      year: "2024",
      lrcPath: lrcFile.path,
      dateAdded: DateTime.now(),
    );
  }

  static Uint8List _synthesizeWav(int seconds, double bpm, double rootFreq) {
    const int sampleRate = 44100;
    const int numChannels = 2;
    const int bytesPerSample = 2;
    final int totalSamples = seconds * sampleRate;
    final int dataSize = totalSamples * numChannels * bytesPerSample;
    final int fileSize = 36 + dataSize;

    final bytes = Uint8List(44 + dataSize);
    final bd = ByteData.sublistView(bytes);

    bytes.setRange(0, 4, 'RIFF'.codeUnits);
    bd.setUint32(4, fileSize, Endian.little);
    bytes.setRange(8, 12, 'WAVE'.codeUnits);

    bytes.setRange(12, 16, 'fmt '.codeUnits);
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, numChannels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * numChannels * bytesPerSample, Endian.little);
    bd.setUint16(32, numChannels * bytesPerSample, Endian.little);
    bd.setUint16(34, 16, Endian.little);

    bytes.setRange(36, 40, 'data'.codeUnits);
    bd.setUint32(40, dataSize, Endian.little);

    final double beatInterval = 60.0 / bpm;
    int offset = 44;

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      final double beatPhase = (t % beatInterval) / beatInterval;

      final double kickEnvelope = math.exp(-beatPhase * 12.0);
      final double kickPitch = rootFreq + (120.0 * kickEnvelope);
      final double kick = math.sin(2.0 * math.pi * kickPitch * t) * kickEnvelope * 0.7;

      final double chord = (math.sin(2.0 * math.pi * rootFreq * 2.0 * t) +
              math.sin(2.0 * math.pi * rootFreq * 2.378 * t) +
              math.sin(2.0 * math.pi * rootFreq * 2.996 * t)) *
          0.18;

      final double hihatPhase = ((t + beatInterval * 0.5) % beatInterval) / beatInterval;
      final double hihatEnvelope = math.exp(-hihatPhase * 35.0);
      final double noise = ((math.sin(t * 84210.0) + math.sin(t * 19283.0)) * 0.5) * hihatEnvelope * 0.2;

      final double sampleValue = (kick + chord + noise).clamp(-1.0, 1.0);
      final int intSample = (sampleValue * 32767.0).round();

      bd.setInt16(offset, intSample, Endian.little);
      bd.setInt16(offset + 2, intSample, Endian.little);
      offset += 4;
    }

    return bytes;
  }

  static Uint8List _generateBmpArtwork(int colorHex) {
    const int width = 128;
    const int height = 128;
    const int headerSize = 54;
    const int rowSize = width * 3;
    const int imageSize = rowSize * height;
    const int fileSize = headerSize + imageSize;

    final bytes = Uint8List(fileSize);
    final bd = ByteData.sublistView(bytes);

    bytes[0] = 0x42;
    bytes[1] = 0x4D;
    bd.setUint32(2, fileSize, Endian.little);
    bd.setUint32(10, headerSize, Endian.little);

    bd.setUint32(14, 40, Endian.little);
    bd.setInt32(18, width, Endian.little);
    bd.setInt32(22, height, Endian.little);
    bd.setUint16(26, 1, Endian.little);
    bd.setUint16(28, 24, Endian.little);
    bd.setUint32(34, imageSize, Endian.little);

    final r = (colorHex >> 16) & 0xFF;
    final g = (colorHex >> 8) & 0xFF;
    final b = colorHex & 0xFF;

    int offset = headerSize;
    for (int y = 0; y < height; y++) {
      final double v = y / height;
      for (int x = 0; x < width; x++) {
        final double u = x / width;
        final double grad = (u + v) * 0.5;

        bytes[offset] = (b * grad).round().clamp(0, 255);
        bytes[offset + 1] = (g * grad).round().clamp(0, 255);
        bytes[offset + 2] = (r * grad).round().clamp(0, 255);
        offset += 3;
      }
    }

    return bytes;
  }
}
