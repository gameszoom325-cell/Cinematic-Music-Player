enum VisualizerQuality {
  high,      // Full 60 FPS, full resolution, dynamic bloom
  balanced,  // 30 FPS cap, ~50% scale, moderate glow (Default)
  low,       // Static/minimal wave, no glow, 15 FPS / static, no particles
  off,       // No visualizer rendering, analyzer stopped
}

enum VisualizerLineStyle {
  minimalWave,  // Minimal clean horizontal waveform line
  neonHorizon,  // Radiant glowing horizon beam with dual-pass bloom
  pulseRibbon,  // Multi-harmonic audio-reactive ribbon
}

enum VisualizerPresetType {
  minimalLine,  // Default: Minimalist Horizontal Waveform Line
  neonHorizon,  // Glowing Horizon Beam
  pulseRibbon,  // Multi-Harmonic Ribbon
  // Legacy aliases for backward compatibility
  orb3d,
  polarRing,
  auroraMesh,
}

enum AtmosphereType {
  none,
  subtle,
  dust,
  rain,
  snow,
  fireflies,
}

class VisualizerState {
  final VisualizerPresetType preset;
  final VisualizerLineStyle lineStyle;
  final AtmosphereType atmosphere;
  final VisualizerQuality quality;
  final double sensitivity;
  final double strokeWidth;
  final bool isGlowEnabled;
  final bool isEnabled;

  const VisualizerState({
    this.preset = VisualizerPresetType.minimalLine,
    this.lineStyle = VisualizerLineStyle.minimalWave,
    this.atmosphere = AtmosphereType.none,
    this.quality = VisualizerQuality.balanced,
    this.sensitivity = 1.0,
    this.strokeWidth = 2.0,
    this.isGlowEnabled = true,
    this.isEnabled = true,
  });

  VisualizerState copyWith({
    VisualizerPresetType? preset,
    VisualizerLineStyle? lineStyle,
    AtmosphereType? atmosphere,
    VisualizerQuality? quality,
    double? sensitivity,
    double? strokeWidth,
    bool? isGlowEnabled,
    bool? isEnabled,
  }) {
    return VisualizerState(
      preset: preset ?? this.preset,
      lineStyle: lineStyle ?? this.lineStyle,
      atmosphere: atmosphere ?? this.atmosphere,
      quality: quality ?? this.quality,
      sensitivity: sensitivity ?? this.sensitivity,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isGlowEnabled: isGlowEnabled ?? this.isGlowEnabled,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
