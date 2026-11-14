import 'package:flutter/material.dart';

class CinematicColors {
  // Deep OLED Obsidian backgrounds
  static const Color obsidianBlack = Color(0xFF08080B);
  static const Color obsidianDark = Color(0xFF0E0E14);
  static const Color obsidianSurface = Color(0xFF14141E);
  static const Color obsidianCard = Color(0xFF1A1A28);

  // Glass specular borders & highlights
  static const Color glassHighlight = Color(0x33FFFFFF);
  static const Color glassBorder = Color(0x1FFFFFFF);
  static const Color glassBackground = Color(0x12FFFFFF);

  // Default Cinematic Neon Palette
  static const Color electricViolet = Color(0xFF8B5CF6);
  static const Color neonCyan = Color(0xFF06B6D4);
  static const Color hotPink = Color(0xFFEC4899);
  static const Color radioactiveGreen = Color(0xFF10B981);
  static const Color emberAmber = Color(0xFFF59E0B);
  static const Color deepPlum = Color(0xFF4C1D95);
  static const Color cyberCyan = Color(0xFF06B6D4);
  static const Color crimsonRed = Color(0xFFE11D48);

  // Audio Spectrum Perceptual Band Colors
  static const Color subBassColor = Color(0xFFE11D48); // Deep crimson
  static const Color bassColor = Color(0xFFF97316);    // Rich orange
  static const Color lowMidColor = Color(0xFFFBBF24);  // Warm amber
  static const Color midColor = Color(0xFF10B981);     // Emerald green
  static const Color upperMidColor = Color(0xFF06B6D4);// Bright cyan
  static const Color presenceColor = Color(0xFF6366F1);// Deep indigo
  static const Color brillianceColor = Color(0xFFA855F7); // Violet shimmer

  // Gradients
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1FFFFFFF),
      Color(0x05FFFFFF),
    ],
  );

  static LinearGradient dynamicGlowGradient(Color primary, Color secondary) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primary.withOpacity(0.65),
        secondary.withOpacity(0.35),
      ],
    );
  }
}

class DynamicAlbumPalette {
  final Color dominant;
  final Color vibrant;
  final Color muted;
  final Color darkMuted;
  final Color lightVibrant;

  const DynamicAlbumPalette({
    required this.dominant,
    required this.vibrant,
    required this.muted,
    required this.darkMuted,
    required this.lightVibrant,
  });

  static const fallback = DynamicAlbumPalette(
    dominant: Color(0xFF181829),
    vibrant: Color(0xFF8B5CF6),
    muted: Color(0xFF4338CA),
    darkMuted: Color(0xFF0F0F1A),
    lightVibrant: Color(0xFFC084FC),
  );

  static DynamicAlbumPalette lerp(
    DynamicAlbumPalette a,
    DynamicAlbumPalette b,
    double t,
  ) {
    return DynamicAlbumPalette(
      dominant: Color.lerp(a.dominant, b.dominant, t) ?? b.dominant,
      vibrant: Color.lerp(a.vibrant, b.vibrant, t) ?? b.vibrant,
      muted: Color.lerp(a.muted, b.muted, t) ?? b.muted,
      darkMuted: Color.lerp(a.darkMuted, b.darkMuted, t) ?? b.darkMuted,
      lightVibrant: Color.lerp(a.lightVibrant, b.lightVibrant, t) ?? b.lightVibrant,
    );
  }
}
