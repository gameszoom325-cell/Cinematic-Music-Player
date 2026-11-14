import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../theme/cinematic_colors.dart';
import '../database/models/song_model.dart';

class PaletteService {
  static Future<DynamicAlbumPalette> extractPalette(SongModel? song) async {
    if (song == null) return DynamicAlbumPalette.fallback;

    if (song.artworkPath != null) {
      final file = File(song.artworkPath!);
      if (await file.exists()) {
        try {
          final paletteGenerator = await PaletteGenerator.fromImageProvider(
            FileImage(file),
            maximumColorCount: 16,
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

          return DynamicAlbumPalette(
            dominant: dominant,
            vibrant: vibrant,
            muted: muted,
            darkMuted: darkMuted,
            lightVibrant: lightVibrant,
          );
        } catch (_) {}
      }
    }

    // Procedural neon palette seeded from track title
    return _generateProceduralPalette(song.title + song.artist);
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
