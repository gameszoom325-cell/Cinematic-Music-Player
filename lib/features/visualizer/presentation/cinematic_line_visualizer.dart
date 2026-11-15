import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/audio_engine/audio_reactive_analyzer.dart';
import '../../../core/theme/cinematic_colors.dart';

/// Minimalist, audio-reactive horizontal waveform line visualizer.
/// 
/// Replaces heavy 3D GPU shaders with an ultra-lightweight, high-performance
/// pure Canvas 2D vector wave. Accurately reacts to real-time audio amplitude,
/// bass hits, vocal harmonics, percussion, and volume adjustments.
class CinematicLineVisualizer extends StatefulWidget {
  final Color activeColor;
  final double height;
  final double verticalAlignment; // 0.0 (top) to 1.0 (bottom), default 0.5 (center)
  final double strokeWidth;
  final bool showBaseline;
  final bool isGlowEnabled;

  const CinematicLineVisualizer({
    super.key,
    this.activeColor = CinematicColors.neonCyan,
    this.height = 140.0,
    this.verticalAlignment = 0.5,
    this.strokeWidth = 2.0,
    this.showBaseline = true,
    this.isGlowEnabled = true,
  });

  @override
  State<CinematicLineVisualizer> createState() => _CinematicLineVisualizerState();
}

class _CinematicLineVisualizerState extends State<CinematicLineVisualizer> {
  StreamSubscription<AudioReactiveFrame>? _streamSub;
  AudioReactiveFrame _currentFrame = AudioReactiveFrame.empty;

  @override
  void initState() {
    super.initState();
    _currentFrame = AudioReactiveAnalyzer.instance.latestFrame;
    _streamSub = AudioReactiveAnalyzer.instance.frameStream.listen((frame) {
      if (mounted) {
        setState(() {
          _currentFrame = frame;
        });
      }
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _MinimalWaveformLinePainter(
            frame: _currentFrame,
            activeColor: widget.activeColor,
            verticalAlignment: widget.verticalAlignment,
            strokeWidth: widget.strokeWidth,
            showBaseline: widget.showBaseline,
            isGlowEnabled: widget.isGlowEnabled,
          ),
        ),
      ),
    );
  }
}

class _MinimalWaveformLinePainter extends CustomPainter {
  final AudioReactiveFrame frame;
  final Color activeColor;
  final double verticalAlignment;
  final double strokeWidth;
  final bool showBaseline;
  final bool isGlowEnabled;

  _MinimalWaveformLinePainter({
    required this.frame,
    required this.activeColor,
    required this.verticalAlignment,
    required this.strokeWidth,
    required this.showBaseline,
    required this.isGlowEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final centerY = size.height * verticalAlignment;
    final maxAmplitude = size.height * 0.42;

    // 1. Subtle Horizontal Horizon Baseline
    if (showBaseline) {
      final basePaint = Paint()
        ..color = activeColor.withOpacity(0.08)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        basePaint,
      );
    }

    final points = frame.wavePoints;
    if (points.isEmpty) {
      // Draw tranquil resting line
      final restingPaint = Paint()
        ..color = activeColor.withOpacity(0.2)
        ..strokeWidth = strokeWidth * 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        restingPaint,
      );
      return;
    }

    final path = Path();
    final pointCount = points.length;
    final stepX = size.width / (pointCount - 1);

    // Build smooth cubic Bézier spline through all wave offsets
    path.moveTo(0, centerY);

    final List<Offset> coords = List.generate(pointCount, (i) {
      final x = i * stepX;
      final y = centerY - (points[i] * maxAmplitude);
      return Offset(x, y);
    });

    for (int i = 0; i < pointCount - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;

      if (i == 0) {
        path.lineTo(p0.dx, p0.dy);
      }
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }
    path.lineTo(coords.last.dx, coords.last.dy);

    // 2. Outer Diffused Glow Layer
    if (isGlowEnabled && frame.amplitude > 0.01) {
      final bloomAlpha = (0.28 * frame.amplitude).clamp(0.05, 0.45);
      final glowPaint = Paint()
        ..color = activeColor.withOpacity(bloomAlpha)
        ..strokeWidth = strokeWidth * 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

      canvas.drawPath(path, glowPaint);
    }

    // 3. Crisp Luminous Core Beam Layer
    final coreAlpha = (0.35 + (frame.amplitude * 0.65)).clamp(0.2, 1.0);
    final coreColor = Color.lerp(Colors.white, activeColor, 0.3)!.withOpacity(coreAlpha);

    final corePaint = Paint()
      ..color = coreColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant _MinimalWaveformLinePainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.verticalAlignment != verticalAlignment;
  }
}
