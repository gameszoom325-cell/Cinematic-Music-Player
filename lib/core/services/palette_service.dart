import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../theme/cinematic_colors.dart';
import '../database/models/song_model.dart';

class PaletteService {
  static final Map<String, DynamicAlbumPalette> _cache = {};

  static Future<DynamicAlbumPalette> extractPalette(SongModel? song) async {
    if (song == null) return DynamicAlbumPalette.fallback;

    final cacheKey = song.id.isNotEmpty ? song.id : (song.artworkPath ?? song.title);
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    if (song.artworkPath != null && song.artworkPath!.isNotEmpty) {
      ImageProvider? imgProvider;
      if (song.artworkPath!.startsWith('http://') || song.artworkPath!.startsWith('https://')) {
        imgProvider = NetworkImage(song.artworkPath!);
      } else {
        final file = File(song.artworkPath!);
        if (file.existsSync()) {
          imgProvider = FileImage(file);
        }
      }

      if (imgProvider != null) {
        try {
          // Downsample image to 96x96 to eliminate UI isolate thread blocks and latency
          final resizedProvider = ResizeImage(
            imgProvider,
            width: 96,
            height: 96,
            allowUpscaling: false,
          );

          final paletteGenerator = await PaletteGenerator.fromImageProvider(
            resizedProvider,
            maximumColorCount: 12,
          );

          final dominant = paletteGenerator.dominantColor?.color ??
              paletteGenerator.darkMutedColor?.color ??
              const Color(0xFF181829);
          final vibrant = paletteGenerator.vibrantColor?.color ??
              paletteGenerator.lightVibrantColor?.color ??
              CinematicColors.electricViolet;
          final muted = paletteGenerator.mutedColor?.color ??
              const Color(0xFF4338CA);
          final darkMuted = paletteGenerator.darkMutedColor?.color ??
              const Color(0xFF0F0F1A);
          final lightVibrant = paletteGenerator.lightVibrantColor?.color ??
              CinematicColors.neonCyan;

          final palette = DynamicAlbumPalette(
            dominant: dominant,
            vibrant: vibrant,
            muted: muted,
            darkMuted: darkMuted,
            lightVibrant: lightVibrant,
          );
          _cache[cacheKey] = palette;
          return palette;
        } catch (_) {}
      }
    }

    // Procedural neon palette seeded from track title
    final procedural = _generateProceduralPalette(song.title + song.artist);
    _cache[cacheKey] = procedural;
    return procedural;
  }

  static DynamicAlbumPalette _generateProceduralPalette(String seed) {
    final rand = math.Random(seed.hashCode);
    final hue1 = (rand.nextDouble() * 360).roundToDouble();
    final hue2 = ((hue1 + 60 + rand.nextDouble() * 90) % 360).roundToDouble();

    final vibrant = HSLColor.fromAHSL(1.0, hue1, 0.85, 0.60).toColor();
    final lightVibrant = HSLColor.fromAHSL(1.0, hue2, 0.90, 0.70).toColor();
    final dominant = HSLColor.fromAHSL(1.0, hue1, 0.40, 0.12).toColor();
    final muted = HSLColor.fromAHSL(1.0, hue2, 0.45, 0.25).toColor();
    final darkMuted = HSLColor.fromAHSL(1.0, hue1, 0.30, 0.08).toColor();

    return DynamicAlbumPalette(
      dominant: dominant,
      vibrant: vibrant,
      muted: muted,
      darkMuted: darkMuted,
      lightVibrant: lightVibrant,
    );
  }
}
