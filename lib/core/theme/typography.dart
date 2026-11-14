import 'dart:ui';
import 'package:flutter/material.dart';
import 'cinematic_colors.dart';

/// "Acoustic Minimal" Editorial Typography
/// Optimized for spatial restraint, legibility, and high-end analog audio aesthetic.
class CinematicTypography {
  // Editorial Display Scale
  static const TextStyle displayLarge = TextStyle(
    fontSize: 40.0,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.8,
    color: CinematicColors.onSurface,
    height: 1.15,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: CinematicColors.onSurface,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
    color: CinematicColors.onSurface,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: CinematicColors.onSurface,
    height: 1.35,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: CinematicColors.onSurface,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    color: CinematicColors.onSurfaceVariant,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: CinematicColors.onSurfaceVariant,
    height: 1.5,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    color: CinematicColors.onSurfaceVariant,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    color: CinematicColors.outline,
  );

  // Backward-compatible aliases
  static const TextStyle displayTitle = TextStyle(
    fontSize: 30.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    color: CinematicColors.onSurface,
    height: 1.2,
  );

  static const TextStyle songTitleLarge = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: CinematicColors.onSurface,
    height: 1.25,
  );

  static const TextStyle songTitleMedium = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: CinematicColors.onSurface,
  );

  static const TextStyle artistSubtitle = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    color: CinematicColors.onSurfaceVariant,
  );

  static const TextStyle technicalBadge = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: CinematicColors.primary,
  );

  static const TextStyle timestamp = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: 0.2,
    color: CinematicColors.outline,
  );

  static TextStyle glowingTitle(Color glowColor) {
    return songTitleLarge.copyWith(
      shadows: [
        Shadow(
          color: glowColor.withOpacity(0.5),
          blurRadius: 14.0,
        ),
      ],
    );
  }
}
