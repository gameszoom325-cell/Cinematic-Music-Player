enum VisualizerPresetType {
  orb3d,        // Preset 1: 3D Liquid Raymarched Orb
  polarRing,    // Preset 2: Polar Circular Spectrum Ring
  auroraMesh,   // Preset 3: Aurora Dynamic Mesh Gradient
}

enum AtmosphereType {
  none,
  rain,
  snow,
  dust,
  fireflies,
}

class VisualizerState {
  final VisualizerPresetType preset;
  final AtmosphereType atmosphere;
  final double sensitivity;
  final double speed;
  final bool isGlowEnabled;

  const VisualizerState({
    this.preset = VisualizerPresetType.orb3d,
    this.atmosphere = AtmosphereType.dust,
    this.sensitivity = 1.0,
    this.speed = 1.0,
    this.isGlowEnabled = true,
  });

  VisualizerState copyWith({
    VisualizerPresetType? preset,
    AtmosphereType? atmosphere,
    double? sensitivity,
    double? speed,
    bool? isGlowEnabled,
  }) {
    return VisualizerState(
      preset: preset ?? this.preset,
      atmosphere: atmosphere ?? this.atmosphere,
      sensitivity: sensitivity ?? this.sensitivity,
      speed: speed ?? this.speed,
      isGlowEnabled: isGlowEnabled ?? this.isGlowEnabled,
    );
  }
}
