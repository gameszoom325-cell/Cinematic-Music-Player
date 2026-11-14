import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/visualizer_preset.dart';
import '../../../../core/theme/cinematic_colors.dart';

class AtmosphericParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;
  double phase;

  AtmosphericParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.phase,
  });
}

class AtmosphericParticlesOverlay extends StatefulWidget {
  final AtmosphereType type;
  final double bassImpulse;
  final Color accentColor;

  const AtmosphericParticlesOverlay({
    super.key,
    required this.type,
    this.bassImpulse = 0.0,
    this.accentColor = CinematicColors.electricViolet,
  });

  @override
  State<AtmosphericParticlesOverlay> createState() =>
      _AtmosphericParticlesOverlayState();
}

class _AtmosphericParticlesOverlayState extends State<AtmosphericParticlesOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  final List<AtmosphericParticle> _particles = [];
  final math.Random _random = math.Random();
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  void _ensureParticles(Size size) {
    if (size == Size.zero || widget.type == AtmosphereType.none) return;
    if (_particles.isEmpty || _lastSize != size) {
      _lastSize = size;
      _particles.clear();
      final count = widget.type == AtmosphereType.rain ? 90 : 60;
      for (int i = 0; i < count; i++) {
        _particles.add(_spawnParticle(size));
      }
    }
  }

  AtmosphericParticle _spawnParticle(Size size) {
    final x = _random.nextDouble() * size.width;
    final y = _random.nextDouble() * size.height;

    switch (widget.type) {
      case AtmosphereType.rain:
        return AtmosphericParticle(
          x: x,
          y: y,
          vx: -1.2,
          vy: 14.0 + _random.nextDouble() * 8.0,
          size: 1.5,
          opacity: 0.25 + _random.nextDouble() * 0.45,
          phase: 0.0,
        );
      case AtmosphereType.snow:
        return AtmosphericParticle(
          x: x,
          y: y,
          vx: 0.0,
          vy: 1.2 + _random.nextDouble() * 2.0,
          size: 2.0 + _random.nextDouble() * 3.5,
          opacity: 0.3 + _random.nextDouble() * 0.5,
          phase: _random.nextDouble() * math.pi * 2,
        );
      case AtmosphereType.dust:
        return AtmosphericParticle(
          x: x,
          y: y,
          vx: (_random.nextDouble() - 0.5) * 0.4,
          vy: -0.2 - _random.nextDouble() * 0.3,
          size: 1.2 + _random.nextDouble() * 2.0,
          opacity: 0.15 + _random.nextDouble() * 0.35,
          phase: _random.nextDouble() * math.pi * 2,
        );
      case AtmosphereType.fireflies:
        return AtmosphericParticle(
          x: x,
          y: y,
          vx: (_random.nextDouble() - 0.5) * 0.9,
          vy: (_random.nextDouble() - 0.5) * 0.9,
          size: 3.0 + _random.nextDouble() * 3.0,
          opacity: 0.2,
          phase: _random.nextDouble() * math.pi * 2,
        );
      case AtmosphereType.none:
        return AtmosphericParticle(x: 0, y: 0, vx: 0, vy: 0, size: 0, opacity: 0, phase: 0);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == AtmosphereType.none) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureParticles(size);

        return AnimatedBuilder(
          animation: _ticker,
          builder: (context, child) {
            _updatePhysics(size);
            return CustomPaint(
              size: size,
              painter: _AtmospherePainter(
                particles: _particles,
                type: widget.type,
                accentColor: widget.accentColor,
              ),
            );
          },
        );
      },
    );
  }

  void _updatePhysics(Size size) {
    const dt = 0.016;
    for (final p in _particles) {
      p.phase += dt * 2.0;

      switch (widget.type) {
        case AtmosphereType.rain:
          p.x += p.vx;
          p.y += p.vy + (widget.bassImpulse * 5.0);
          break;
        case AtmosphereType.snow:
          p.x += math.sin(p.phase) * 1.2;
          p.y += p.vy;
          break;
        case AtmosphereType.dust:
          p.x += p.vx + math.sin(p.phase) * 0.3;
          p.y += p.vy;
          break;
        case AtmosphereType.fireflies:
          p.x += p.vx + math.cos(p.phase) * 0.6;
          p.y += p.vy + math.sin(p.phase) * 0.6;
          p.opacity = 0.2 + 0.8 * (0.5 + 0.5 * math.sin(p.phase * 1.5));
          break;
        case AtmosphereType.none:
          break;
      }

      // Viewport wrapping
      if (p.y > size.height) {
        p.y = 0;
        p.x = _random.nextDouble() * size.width;
      }
      if (p.x < 0) p.x = size.width;
      if (p.x > size.width) p.x = 0;
    }
  }
}

class _AtmospherePainter extends CustomPainter {
  final List<AtmosphericParticle> particles;
  final AtmosphereType type;
  final Color accentColor;

  _AtmospherePainter({
    required this.particles,
    required this.type,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final p in particles) {
      if (type == AtmosphereType.rain) {
        paint.color = Colors.white.withOpacity(p.opacity * 0.65);
        paint.strokeWidth = p.size;
        paint.strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(p.x, p.y),
          Offset(p.x + p.vx * 2.2, p.y + p.vy * 0.8),
          paint,
        );
      } else if (type == AtmosphereType.snow) {
        paint.color = Colors.white.withOpacity(p.opacity * 0.8);
        canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
      } else if (type == AtmosphereType.dust) {
        paint.color = Color.lerp(Colors.white, accentColor, 0.4)!.withOpacity(p.opacity * 0.5);
        canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
      } else if (type == AtmosphereType.fireflies) {
        // Soft glowing firefly halo
        paint.color = accentColor.withOpacity(p.opacity * 0.3);
        canvas.drawCircle(Offset(p.x, p.y), p.size * 2.2, paint);
        paint.color = Colors.white.withOpacity(p.opacity);
        canvas.drawCircle(Offset(p.x, p.y), p.size * 0.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter old) => true;
}
