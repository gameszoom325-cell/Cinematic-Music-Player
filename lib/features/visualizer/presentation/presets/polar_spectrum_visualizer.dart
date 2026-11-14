import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/audio_engine/fft_engine.dart';
import '../../../../core/theme/cinematic_colors.dart';

class PolarSpectrumVisualizer extends StatefulWidget {
  final AudioSpectrumFrame spectrum;
  final DynamicAlbumPalette palette;
  final Widget? centerChild;
  final double sensitivity;

  const PolarSpectrumVisualizer({
    super.key,
    required this.spectrum,
    required this.palette,
    this.centerChild,
    this.sensitivity = 1.0,
  });

  @override
  State<PolarSpectrumVisualizer> createState() => _PolarSpectrumVisualizerState();
}

class _PolarSpectrumVisualizerState extends State<PolarSpectrumVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _PolarSpectrumPainter(
                spectrum: widget.spectrum,
                palette: widget.palette,
                rotationAngle: _rotationController.value * math.pi * 2,
                sensitivity: widget.sensitivity,
              ),
            ),
            if (widget.centerChild != null)
              Center(child: widget.centerChild!),
          ],
        );
      },
    );
  }
}

class _PolarSpectrumPainter extends CustomPainter {
  final AudioSpectrumFrame spectrum;
  final DynamicAlbumPalette palette;
  final double rotationAngle;
  final double sensitivity;

  _PolarSpectrumPainter({
    required this.spectrum,
    required this.palette,
    required this.rotationAngle,
    required this.sensitivity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = math.min(size.width, size.height);
    
    // Bass pulse expands the core ring radius
    final baseRadius = (minDim * 0.28) + (spectrum.bass * 20.0 * sensitivity);
    const int barCount = 64;
    final double angleStep = (2 * math.pi) / barCount;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw ambient inner glow halo
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0 + (spectrum.bass * 16.0)
      ..color = palette.vibrant.withOpacity(0.25 + spectrum.bass * 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16.0);
    canvas.drawCircle(center, baseRadius, glowPaint);

    final List<double> interpolatedBands = _expandBands(spectrum.bands, barCount ~/ 2);

    for (int i = 0; i < barCount; i++) {
      // Mirrored layout (left and right channels meet symmetrically at top and bottom)
      final int halfIndex = i < barCount ~/ 2 ? i : (barCount - 1 - i);
      final double bandMag = (interpolatedBands[halfIndex] * sensitivity).clamp(0.0, 1.4);

      final double angle = (i * angleStep) + rotationAngle;
      final double barHeight = 8.0 + (bandMag * (minDim * 0.16));

      final double x1 = center.dx + math.cos(angle) * baseRadius;
      final double y1 = center.dy + math.sin(angle) * baseRadius;
      final double x2 = center.dx + math.cos(angle) * (baseRadius + barHeight);
      final double y2 = center.dy + math.sin(angle) * (baseRadius + barHeight);

      // Color transition from vibrant base to light accent tip
      final Color barColor = Color.lerp(
        palette.vibrant,
        palette.lightVibrant,
        (halfIndex / (barCount / 2)),
      )!;

      paint.color = barColor.withOpacity((0.35 + bandMag * 0.65).clamp(0.0, 1.0));
      paint.strokeWidth = math.max(2.5, (minDim * 0.008) * (1.0 + spectrum.beatEnergy * 0.3));

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  List<double> _expandBands(List<double> sourceBands, int targetCount) {
    final result = List.filled(targetCount, 0.0);
    for (int i = 0; i < targetCount; i++) {
      final double position = (i / (targetCount - 1)) * (sourceBands.length - 1);
      final int low = position.floor();
      final int high = math.min(sourceBands.length - 1, low + 1);
      final double t = position - low;
      result[i] = sourceBands[low] * (1.0 - t) + sourceBands[high] * t;
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _PolarSpectrumPainter old) => true;
}
