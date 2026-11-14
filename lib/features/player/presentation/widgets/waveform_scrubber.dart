import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/cinematic_colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/database/models/waveform_cache_model.dart';

class WaveformScrubber extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final WaveformCacheModel? waveform;
  final Color activeGlowColor;
  final ValueChanged<Duration> onSeek;

  const WaveformScrubber({
    super.key,
    required this.position,
    required this.duration,
    this.waveform,
    required this.activeGlowColor,
    required this.onSeek,
  });

  @override
  State<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends State<WaveformScrubber> {
  bool _isDragging = false;
  double _dragProgress = 0.0;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final currentMs = widget.position.inMilliseconds;
    final progress = totalMs > 0
        ? (_isDragging ? _dragProgress : (currentMs / totalMs).clamp(0.0, 1.0))
        : 0.0;

    final peaks = widget.waveform?.peaks ??
        List.generate(128, (i) => 0.2 + 0.6 * math.sin((i / 128.0) * math.pi));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onHorizontalDragStart: (details) {
            setState(() {
              _isDragging = true;
              _updateDrag(details.localPosition.dx, context.size?.width ?? 300);
            });
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _updateDrag(details.localPosition.dx, context.size?.width ?? 300);
            });
          },
          onHorizontalDragEnd: (details) {
            setState(() {
              _isDragging = false;
            });
            final seekMs = (_dragProgress * totalMs).round();
            widget.onSeek(Duration(milliseconds: seekMs));
          },
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            final width = box?.size.width ?? 300;
            final targetProgress = (details.localPosition.dx / width).clamp(0.0, 1.0);
            final seekMs = (targetProgress * totalMs).round();
            widget.onSeek(Duration(milliseconds: seekMs));
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: CustomPaint(
                painter: _WaveformPainter(
                  peaks: peaks,
                  progress: progress,
                  activeColor: widget.activeGlowColor,
                  inactiveColor: Colors.white.withOpacity(0.18),
                  isDragging: _isDragging,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_isDragging
                  ? Duration(milliseconds: (_dragProgress * totalMs).round())
                  : widget.position),
              style: CinematicTypography.timestamp,
            ),
            Text(
              _formatDuration(widget.duration),
              style: CinematicTypography.timestamp,
            ),
          ],
        ),
      ],
    );
  }

  void _updateDrag(double localX, double totalWidth) {
    if (totalWidth <= 0) return;
    _dragProgress = (localX / totalWidth).clamp(0.0, 1.0);
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> peaks;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDragging;

  _WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int count = peaks.length;
    final double step = size.width / count;
    final double barWidth = math.max(1.5, step * 0.65);
    final double centerY = size.height / 2;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = barWidth;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = barWidth;

    for (int i = 0; i < count; i++) {
      final double x = (i * step) + (barWidth / 2);
      final double peakHeight = (peaks[i] * (size.height * 0.85)).clamp(4.0, size.height);
      final double halfH = peakHeight / 2;

      final p1 = Offset(x, centerY - halfH);
      final p2 = Offset(x, centerY + halfH);

      final isPlayed = (i / count) <= progress;

      if (isPlayed) {
        canvas.drawLine(p1, p2, activePaint);
      } else {
        canvas.drawLine(p1, p2, inactivePaint);
      }
    }

    // Playhead glowing needle marker
    final double playheadX = size.width * progress;
    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(playheadX, 2),
      Offset(playheadX, size.height - 2),
      needlePaint,
    );

    // Playhead halo dot
    final dotPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(playheadX, centerY), isDragging ? 6.0 : 4.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => true;
}
