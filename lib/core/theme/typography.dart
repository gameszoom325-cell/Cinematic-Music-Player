import 'package:flutter/material.dart';

class CinematicTypography {
  static const TextStyle displayTitle = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: Colors.white,
    height: 1.15,
  );

  static const TextStyle songTitleLarge = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: Colors.white,
    height: 1.2,
  );

  static const TextStyle songTitleMedium = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: Colors.white,
  );

  static const TextStyle artistSubtitle = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    color: Color(0xB3FFFFFF), // 70% white
  );

  static const TextStyle technicalBadge = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: Color(0xFF06B6D4), // Cyan highlight
  );

  static const TextStyle timestamp = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: 0.2,
    color: Color(0x99FFFFFF),
  );

  static TextStyle glowingTitle(Color glowColor) {
    return songTitleLarge.copyWith(
      shadows: [
        Shadow(
          color: glowColor.withOpacity(0.6),
          blurRadius: 16.0,
        ),
      ],
    );
  }
}
