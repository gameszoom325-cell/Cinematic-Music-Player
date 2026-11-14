import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/visualizer_preset.dart';
import '../providers/visualizer_provider.dart';
import '../../../core/audio_engine/fft_engine.dart';
import '../../../core/theme/cinematic_colors.dart';
import 'presets/orb_shader_visualizer.dart';
import 'presets/polar_spectrum_visualizer.dart';
import 'presets/aurora_mesh_visualizer.dart';
import 'atmospheres/atmospheric_particles.dart';

class VisualizerViewport extends ConsumerWidget {
  final Widget? centerChild;

  const VisualizerViewport({super.key, this.centerChild});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visualizerState = ref.watch(visualizerProvider);
    final palette = ref.watch(dynamicPaletteProvider);
    final spectrumAsync = ref.watch(spectrumStreamProvider);
    final spectrum = spectrumAsync.value ?? AudioSpectrumFrame.empty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base Visualizer Preset Layer
        RepaintBoundary(
          child: _buildPreset(visualizerState.preset, spectrum, palette),
        ),

        // 2. Atmospheric Simulation Layer
        if (visualizerState.atmosphere != AtmosphereType.none)
          RepaintBoundary(
            child: AtmosphericParticlesOverlay(
              type: visualizerState.atmosphere,
              bassImpulse: spectrum.bass,
              accentColor: palette.vibrant,
            ),
          ),

        // 3. Center Injected Child (e.g. 3D Tilt Album Artwork for Polar Ring)
        if (centerChild != null && visualizerState.preset != VisualizerPresetType.polarRing)
          Center(child: centerChild!),
      ],
    );
  }

  Widget _buildPreset(
    VisualizerPresetType preset,
    AudioSpectrumFrame spectrum,
    DynamicAlbumPalette palette,
  ) {
    switch (preset) {
      case VisualizerPresetType.orb3d:
        return OrbShaderVisualizer(
          spectrum: spectrum,
          palette: palette,
        );
      case VisualizerPresetType.polarRing:
        return PolarSpectrumVisualizer(
          spectrum: spectrum,
          palette: palette,
          centerChild: centerChild,
        );
      case VisualizerPresetType.auroraMesh:
        return AuroraMeshVisualizer(
          spectrum: spectrum,
          palette: palette,
        );
    }
  }
}
