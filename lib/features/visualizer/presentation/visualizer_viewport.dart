import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/visualizer_provider.dart';
import 'cinematic_line_visualizer.dart';

/// Lightweight viewport hosting the minimal horizontal line visualizer.
/// 
/// Free of heavy 3D GPU raymarching, particles, and compute overhead.
/// Renders an audio-reactive horizontal waveform line in pure Canvas 2D.
class VisualizerViewport extends ConsumerWidget {
  final Widget? centerChild;
  final double verticalAlignment;

  const VisualizerViewport({
    super.key,
    this.centerChild,
    this.verticalAlignment = 0.52,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visualizerState = ref.watch(visualizerProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    if (!visualizerState.isEnabled) {
      if (centerChild != null) {
        return Center(child: centerChild!);
      }
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Real-time Minimal Horizontal Waveform Line
        Positioned.fill(
          child: CinematicLineVisualizer(
            activeColor: palette.vibrant,
            verticalAlignment: verticalAlignment,
            strokeWidth: visualizerState.strokeWidth,
            isGlowEnabled: visualizerState.isGlowEnabled,
          ),
        ),

        // 2. Center Injected Child
        if (centerChild != null)
          Center(child: centerChild!),
      ],
    );
  }
}
