import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio_engine/fft_engine.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/database/models/song_model.dart';
import '../../../core/services/palette_service.dart';
import '../models/visualizer_preset.dart';

// Single global FFT engine instance
final fftEngineProvider = Provider<FFTEngine>((ref) {
  final engine = FFTEngine();
  engine.start();
  ref.onDispose(() => engine.dispose());
  return engine;
});

// Stream provider for high-frequency 60 FPS spectrum frames
final spectrumStreamProvider = StreamProvider.autoDispose<AudioSpectrumFrame>((ref) {
  final fft = ref.watch(fftEngineProvider);
  return fft.spectrumStream;
});

// Visualizer State Controller (Preset, Atmosphere, Sensitivity)
class VisualizerNotifier extends StateNotifier<VisualizerState> {
  VisualizerNotifier() : super(const VisualizerState());

  void setPreset(VisualizerPresetType preset) {
    state = state.copyWith(preset: preset);
  }

  void setAtmosphere(AtmosphereType atmosphere) {
    state = state.copyWith(atmosphere: atmosphere);
  }

  void setSensitivity(double sensitivity) {
    state = state.copyWith(sensitivity: sensitivity.clamp(0.2, 3.0));
  }

  void toggleGlow() {
    state = state.copyWith(isGlowEnabled: !state.isGlowEnabled);
  }
}

final visualizerProvider =
    StateNotifierProvider<VisualizerNotifier, VisualizerState>((ref) {
  return VisualizerNotifier();
});

// Dynamic Album Palette Provider
class DynamicPaletteNotifier extends StateNotifier<DynamicAlbumPalette> {
  DynamicPaletteNotifier() : super(DynamicAlbumPalette.fallback);

  Future<void> updateForSong(SongModel? song) async {
    final targetPalette = await PaletteService.extractPalette(song);
    state = targetPalette;
  }
}

final dynamicPaletteProvider =
    StateNotifierProvider<DynamicPaletteNotifier, DynamicAlbumPalette>((ref) {
  return DynamicPaletteNotifier();
});
