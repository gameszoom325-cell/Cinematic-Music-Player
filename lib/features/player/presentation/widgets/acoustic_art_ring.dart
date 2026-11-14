import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/cinematic_colors.dart';

/// Perimeter Acoustic Soundwave Ring around the album artwork.
/// Features a dashed circular track, animated progress arc, and
/// 8 radial acoustic tick spikes that pulse to real audio frequencies.
class AcousticArtRing extends StatelessWidget {
  final Widget child;
  final double size;
  final double progress; // 0.0 to 1.0
  final double bassEnergy; // 0.0 to 1.0
  final double midEnergy;  // 0.0 to 1.0
  final Color activeColor;

  const AcousticArtRing({
    super.key,
    required this.child,
    this.size = 320.0,
    this.progress = 0.0,
    this.bassEnergy = 0.0,
    this.midEnergy = 0.0,
    this.activeColor = CinematicColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Audio-reactive outer soundwave perimeter
          Positioned.fill(
            child: CustomPaint(
              painter: _AcousticRingPainter(
                progress: progress.clamp(0.0, 1.0),
                bass: bassEnergy.clamp(0.0, 1.0),
                mid: midEnergy.clamp(0.0, 1.0),
                activeColor: activeColor,
              ),
            ),
          ),

          // Central Album Artwork Container with inner padding
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AcousticRingPainter extends CustomPainter {
  final double progress;
  final double bass;
  final double mid;
  final Color activeColor;

  _AcousticRingPainter({
    required this.progress,
    required this.bass,
    required this.mid,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10.0;

    // 1. Background dashed perimeter track ring
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const dashCount = 64;
    const dashLength = (2 * math.pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashLength;
      final sweepAngle = dashLength * 0.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        bgPaint,
      );
    }

    // 2. Active playback progress arc (starts at 12 o'clock / -pi/2)
    if (progress > 0.005) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        activePaint,
      );
    }

    // 3. 8 Radial Acoustic Tick Spikes that pulse to real audio frequencies
    final tickPaint = Paint()
      ..color = activeColor.withOpacity((0.35 + bass * 0.65).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final pulseExtension = (bass * 8.0) + (mid * 4.0);

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - (math.pi / 2);
      final isMajor = i % 2 == 0;
      final baseTickLength = isMajor ? 5.0 : 3.0;
      final currentTickLength = baseTickLength + (isMajor ? pulseExtension : pulseExtension * 0.6);

      final r1 = radius + 2.0;
      final r2 = radius + 2.0 + currentTickLength;

      final p1 = Offset(
        center.dx + r1 * math.cos(angle),
        center.dy + r1 * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + r2 * math.cos(angle),
        center.dy + r2 * math.sin(angle),
      );

      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AcousticRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bass != bass ||
        oldDelegate.mid != mid ||
        oldDelegate.activeColor != activeColor;
  }
}
