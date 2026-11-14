import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/cinematic_colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/database/models/waveform_cache_model.dart';

/// Tactile 52-bar Audio Waveform Scrubber from the "Acoustic Minimal" design system.
/// Displays live progress with played amber bars, glowing active cutoff, and unplayed cardstock bars.
class WaveformScrubber extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final WaveformCacheModel? waveform;
  final Color activeGlowColor;
  final String? technicalSpecs;
  final ValueChanged<Duration> onSeek;

  const WaveformScrubber({
    super.key,
    required this.position,
    required this.duration,
    this.waveform,
    required this.activeGlowColor,
    this.technicalSpecs,
    required this.onSeek,
  });

  @override
  State<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends State<WaveformScrubber> {
  bool _isDragging = false;
  double _dragProgress = 0.0;
  static const int barCount = 52;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatRemaining(Duration total, Duration current) {
    final remainingMs = total.inMilliseconds - current.inMilliseconds;
    if (remainingMs <= 0) return "-00:00";
    final d = Duration(milliseconds: remainingMs);
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '-$min:${sec.toString().padLeft(2, '0')}';
  }

  void _updateDrag(double localX, double width) {
    if (width <= 0) return;
    _dragProgress = (localX / width).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final currentMs = widget.position.inMilliseconds;
    final progress = totalMs > 0
        ? (_isDragging ? _dragProgress : (currentMs / totalMs).clamp(0.0, 1.0))
        : 0.0;

    final effectiveCurrent = _isDragging
        ? Duration(milliseconds: (_dragProgress * totalMs).round())
        : widget.position;

    // Resample waveform peaks down to exactly 52 bars
    final rawPeaks = widget.waveform?.peaks;
    final List<double> bars = List.generate(barCount, (i) {
      if (rawPeaks != null && rawPeaks.isNotEmpty) {
        final sampleIdx = ((i / barCount) * rawPeaks.length).floor().clamp(0, rawPeaks.length - 1);
        return rawPeaks[sampleIdx].clamp(0.12, 1.0);
      }
      // Gentle musical curve fallback
      return (0.25 + 0.65 * math.sin((i / barCount) * math.pi)).clamp(0.12, 1.0);
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CinematicColors.surfaceContainerLow.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Time header: Active elapsed & remaining duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: CinematicColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: CinematicColors.primary,
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(effectiveCurrent),
                    style: const TextStyle(
                      color: CinematicColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    " / ${_formatDuration(widget.duration)}",
                    style: const TextStyle(
                      color: CinematicColors.outline,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Remaining ",
                    style: TextStyle(color: CinematicColors.outline, fontSize: 11),
                  ),
                  Text(
                    _formatRemaining(widget.duration, effectiveCurrent),
                    style: const TextStyle(
                      color: CinematicColors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Tactile 52-bar waveform canvas
          GestureDetector(
            behavior: HitTestBehavior.opaque,
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
                  painter: _TactileWaveformPainter(
                    bars: bars,
                    progress: progress,
                    activeColor: CinematicColors.primary,
                    activeContainerColor: CinematicColors.primaryContainer,
                    unplayedColor: CinematicColors.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. Technical footer: Specs & Analog DAC status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.graphic_eq_rounded, size: 14, color: CinematicColors.primary),
                  SizedBox(width: 6),
                  Text(
                    "Acoustic Warmth • Direct DAC",
                    style: TextStyle(color: CinematicColors.outline, fontSize: 11, letterSpacing: 0.2),
                  ),
                ],
              ),
              Text(
                widget.technicalSpecs ?? "Bitperfect Lossless",
                style: const TextStyle(
                  color: CinematicColors.outline,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TactileWaveformPainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color activeContainerColor;
  final Color unplayedColor;

  _TactileWaveformPainter({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.activeContainerColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final count = bars.length;
    const gap = 3.0;
    final totalGaps = (count - 1) * gap;
    final barWidth = ((size.width - totalGaps) / count).clamp(1.5, 8.0);
    final activeIndex = (progress * count).floor().clamp(0, count - 1);

    final playedPaint = Paint()..color = activeContainerColor;
    final activeCutoffPaint = Paint()
      ..color = activeColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);
    final unplayedPaint = Paint()..color = unplayedColor;

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + gap);
      final normalizedHeight = bars[i].clamp(0.12, 1.0);
      final h = (normalizedHeight * size.height).clamp(4.0, size.height);
      final y = size.height - h;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        Radius.circular(barWidth / 2),
      );

      if (i < activeIndex) {
        canvas.drawRRect(rect, playedPaint);
      } else if (i == activeIndex && progress > 0.01) {
        canvas.drawRRect(rect, activeCutoffPaint);
      } else {
        canvas.drawRRect(rect, unplayedPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TactileWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bars != bars ||
        oldDelegate.activeColor != activeColor;
  }
}
