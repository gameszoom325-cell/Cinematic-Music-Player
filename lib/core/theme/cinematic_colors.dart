import 'package:flutter/material.dart';

/// Professional Studio Design System Colors
/// Solid dark theme (#0F0F12) with high-contrast white text
/// and a single muted gold (#D4AF37) accent color.
class CinematicColors {
  // Solid Dark Surfaces (#0F0F12 canvas)
  static const Color background = Color(0xFF0F0F12);
  static const Color surface = Color(0xFF141418);
  static const Color surfaceDim = Color(0xFF0F0F12);
  static const Color surfaceBright = Color(0xFF26262B);
  static const Color surfaceContainerLowest = Color(0xFF0A0A0C);
  static const Color surfaceContainerLow = Color(0xFF141418);
  static const Color surfaceContainer = Color(0xFF1A1A20);
  static const Color surfaceContainerHigh = Color(0xFF222228);
  static const Color surfaceContainerHighest = Color(0xFF2A2A32);

  // Backward-compatible surface aliases
  static const Color obsidianBlack = Color(0xFF0A0A0C);
  static const Color obsidianDark = Color(0xFF0F0F12);
  static const Color obsidianSurface = Color(0xFF141418);
  static const Color obsidianCard = Color(0xFF1A1A20);

  // Text & Typography Tones - High Contrast White
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant = Color(0xFFA1A1AA);
  static const Color outline = Color(0xFF33333A);
  static const Color outlineVariant = Color(0xFF222228);

  // Tactile Hairlines & Frosted Glass
  static const Color hairlineBorder = Color(0x1AFFFFFF);
  static const Color glassHighlight = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x14FFFFFF);
  static const Color glassBackground = Color(0xCC141418);

  // Single Professional Accent Color: Muted Gold (#D4AF37)
  static const Color primary = Color(0xFFD4AF37);
  static const Color primaryContainer = Color(0xFF8C7324);
  static const Color onPrimary = Color(0xFF000000);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFFE5D5A5);
  static const Color secondaryContainer = Color(0xFF332F24);
  static const Color onSecondary = Color(0xFF000000);

  static const Color tertiary = Color(0xFFE0E0E0);
  static const Color tertiaryContainer = Color(0xFF2A2A30);

  // Legacy aliases mapped cleanly to the professional dark palette
  static const Color electricViolet = Color(0xFFD4AF37);
  static const Color neonCyan = Color(0xFFE5D5A5);
  static const Color emberAmber = Color(0xFFD4AF37);
  static const Color hotPink = Color(0xFFD4AF37);
  static const Color radioactiveGreen = Color(0xFF34D399);
  static const Color deepPlum = Color(0xFF141418);
  static const Color cyberCyan = Color(0xFFE5D5A5);
  static const Color crimsonRed = Color(0xFFE11D48);

  // Audio Spectrum Frequency Band Colors
  static const Color subBassColor = Color(0xFF8C7324);
  static const Color bassColor = Color(0xFFB8972E);
  static const Color lowMidColor = Color(0xFFD4AF37);
  static const Color midColor = Color(0xFFE5D5A5);
  static const Color upperMidColor = Color(0xFFF0E6C8);
  static const Color presenceColor = Color(0xFFE0E0E0);
  static const Color brillianceColor = Color(0xFFFFFFFF);

  // Subtle Linear Gradients (solid dark / subtle monochrome tone, NO purple/neon gradients)
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x0FFFFFFF),
      Color(0x05FFFFFF),
    ],
  );

  static LinearGradient dynamicGlowGradient(Color primary, Color secondary) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primary.withOpacity(0.20),
        secondary.withOpacity(0.08),
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
    dominant: Color(0xFF1B1B1D),
    vibrant: Color(0xFFFFB77D),
    muted: Color(0xFFA1A1AA),
    darkMuted: Color(0xFF131315),
    lightVibrant: Color(0xFFFFB95F),
  );
}
