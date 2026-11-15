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
  final double sensitivity;
  final double strokeWidth;
  final bool isGlowEnabled;
  final bool isEnabled;

  const VisualizerState({
    this.preset = VisualizerPresetType.minimalLine,
    this.lineStyle = VisualizerLineStyle.minimalWave,
    this.atmosphere = AtmosphereType.none,
    this.sensitivity = 1.0,
    this.strokeWidth = 2.0,
    this.isGlowEnabled = true,
    this.isEnabled = true,
  });

  VisualizerState copyWith({
    VisualizerPresetType? preset,
    VisualizerLineStyle? lineStyle,
    AtmosphereType? atmosphere,
    double? sensitivity,
    double? strokeWidth,
    bool? isGlowEnabled,
    bool? isEnabled,
  }) {
    return VisualizerState(
      preset: preset ?? this.preset,
      lineStyle: lineStyle ?? this.lineStyle,
      atmosphere: atmosphere ?? this.atmosphere,
      sensitivity: sensitivity ?? this.sensitivity,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isGlowEnabled: isGlowEnabled ?? this.isGlowEnabled,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
