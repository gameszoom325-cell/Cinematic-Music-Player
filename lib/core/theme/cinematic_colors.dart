import 'package:flutter/material.dart';

/// "Acoustic Minimal" Studio Design System Colors
/// Inspired by high-end analog audio equipment, vinyl packaging,
/// and minimalist editorial publications.
class CinematicColors {
  // Acoustic Studio Charcoal Canvas & Surfaces
  static const Color background = Color(0xFF131315);
  static const Color surface = Color(0xFF131315);
  static const Color surfaceDim = Color(0xFF131315);
  static const Color surfaceBright = Color(0xFF39393B);
  static const Color surfaceContainerLowest = Color(0xFF0E0E10);
  static const Color surfaceContainerLow = Color(0xFF1B1B1D);
  static const Color surfaceContainer = Color(0xFF201F21);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2C);
  static const Color surfaceContainerHighest = Color(0xFF353437);

  // Backward-compatible surface aliases
  static const Color obsidianBlack = Color(0xFF0E0E10);
  static const Color obsidianDark = Color(0xFF131315);
  static const Color obsidianSurface = Color(0xFF1B1B1D);
  static const Color obsidianCard = Color(0xFF201F21);

  // Text & Typography Tones
  static const Color onSurface = Color(0xFFE5E1E4);         // Unbleached parchment
  static const Color onSurfaceVariant = Color(0xFFA1A1AA);  // Muted editorial secondary
  static const Color outline = Color(0xFFA38C7C);           // Warm cardstock outline
  static const Color outlineVariant = Color(0xFF554336);

  // Tactile Hairlines & Translucent Frosted Glass
  static const Color hairlineBorder = Color(0x14FFFFFF);    // 1px tactile hairline
  static const Color glassHighlight = Color(0x26FFFFFF);
  static const Color glassBorder = Color(0x14FFFFFF);
  static const Color glassBackground = Color(0xBF1B1B1D);   // 75% frosted studio charcoal

  // Acoustic Amber & Honey Primary Accents
  static const Color primary = Color(0xFFFFB77D);           // Warm amber light
  static const Color primaryContainer = Color(0xFFD97707);  // Deep acoustic amber
  static const Color onPrimary = Color(0xFF4D2600);
  static const Color onPrimaryContainer = Color(0xFF432100);

  static const Color secondary = Color(0xFFFFB95F);         // Radiant warm sand / honey
  static const Color secondaryContainer = Color(0xFFEE9800);
  static const Color onSecondary = Color(0xFF472A00);

  static const Color tertiary = Color(0xFFC6C6C6);
  static const Color tertiaryContainer = Color(0xFF909191);

  // Vibrant legacy aliases mapped gracefully to the new acoustic warm palette
  static const Color electricViolet = Color(0xFFFFB77D);     // Primary accent mapped to warm amber
  static const Color neonCyan = Color(0xFFFFB95F);           // Secondary accent mapped to honey sand
  static const Color emberAmber = Color(0xFFF59E0B);
  static const Color hotPink = Color(0xFFFFB77D);
  static const Color radioactiveGreen = Color(0xFF10B981);
  static const Color deepPlum = Color(0xFF201F21);
  static const Color cyberCyan = Color(0xFFFFB95F);
  static const Color crimsonRed = Color(0xFFE11D48);

  // Audio Spectrum Frequency Band Colors
  static const Color subBassColor = Color(0xFFD97707);      // Deep amber
  static const Color bassColor = Color(0xFFF59E0B);         // Warm honey
  static const Color lowMidColor = Color(0xFFFFB77D);       // Light amber
  static const Color midColor = Color(0xFFE5E1E4);          // Parchment
  static const Color upperMidColor = Color(0xFFC6C6C6);     // Slate
  static const Color presenceColor = Color(0xFFA38C7C);     // Cardstock
  static const Color brillianceColor = Color(0xFF909191);   // Silver

  // Tactile Gradients
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1AFFFFFF),
      Color(0x05FFFFFF),
    ],
  );

  static LinearGradient dynamicGlowGradient(Color primary, Color secondary) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primary.withOpacity(0.55),
        secondary.withOpacity(0.25),
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
