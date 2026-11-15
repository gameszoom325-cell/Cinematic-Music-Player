import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio_engine/audio_reactive_analyzer.dart';
import '../../../core/audio_engine/fft_engine.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/database/models/song_model.dart';
import '../../../core/services/palette_service.dart';
import '../models/visualizer_preset.dart';

/// Single global AudioReactiveAnalyzer provider
final audioReactiveAnalyzerProvider = Provider<AudioReactiveAnalyzer>((ref) {
  return AudioReactiveAnalyzer.instance;
});

/// High-efficiency stream provider emitting real-time audio-reactive frames
final audioReactiveFrameProvider = StreamProvider.autoDispose<AudioReactiveFrame>((ref) {
  final analyzer = ref.watch(audioReactiveAnalyzerProvider);
  return analyzer.frameStream;
});

/// Single global FFT engine instance (facade for backward compatibility)
final fftEngineProvider = Provider<FFTEngine>((ref) {
  final engine = FFTEngine();
  engine.start();
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Stream provider for spectrum frames (backward compatibility)
final spectrumStreamProvider = StreamProvider.autoDispose<AudioSpectrumFrame>((ref) {
  final fft = ref.watch(fftEngineProvider);
  return fft.spectrumStream;
});

/// Visualizer State Controller (Preset, Sensitivity, Glow)
class VisualizerNotifier extends StateNotifier<VisualizerState> {
  VisualizerNotifier() : super(const VisualizerState());

  void setPreset(VisualizerPresetType preset) {
    state = state.copyWith(preset: preset);
  }

  void setLineStyle(VisualizerLineStyle lineStyle) {
    state = state.copyWith(lineStyle: lineStyle);
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

  void toggleEnabled() {
    state = state.copyWith(isEnabled: !state.isEnabled);
  }
}

final visualizerProvider =
    StateNotifierProvider<VisualizerNotifier, VisualizerState>((ref) {
  return VisualizerNotifier();
});

/// Dynamic Album Palette Provider
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
