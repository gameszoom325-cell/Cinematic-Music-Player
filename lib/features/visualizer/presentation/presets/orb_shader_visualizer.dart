import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/audio_engine/fft_engine.dart';
import '../../../../core/theme/cinematic_colors.dart';

class OrbShaderVisualizer extends StatefulWidget {
  final AudioSpectrumFrame spectrum;
  final DynamicAlbumPalette palette;
  final double sensitivity;

  const OrbShaderVisualizer({
    super.key,
    required this.spectrum,
    required this.palette,
    this.sensitivity = 1.0,
  });

  @override
  State<OrbShaderVisualizer> createState() => _OrbShaderVisualizerState();
}

class _OrbShaderVisualizerState extends State<OrbShaderVisualizer>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  bool _shaderLoadFailed = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/orb_visualizer.frag');
      if (mounted) {
        setState(() {
          _shader = program.fragmentShader();
        });
      }
    } catch (e) {
      debugPrint("FragmentShader load error, using high-performance 3D Canvas fallback: $e");
      if (mounted) {
        setState(() {
          _shaderLoadFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final time = _controller.value * 20.0 * math.pi * 2;
        final bass = (widget.spectrum.bass * widget.sensitivity).clamp(0.0, 1.5);
        final mid = (widget.spectrum.mid * widget.sensitivity).clamp(0.0, 1.5);
        final treble = (widget.spectrum.treble * widget.sensitivity).clamp(0.0, 1.5);

        if (_shader != null && !_shaderLoadFailed) {
          return CustomPaint(
            painter: _OrbShaderPainter(
              shader: _shader!,
              time: time,
              bass: bass,
              mid: mid,
              treble: treble,
              primary: widget.palette.vibrant,
              secondary: widget.palette.muted,
              accent: widget.palette.lightVibrant,
            ),
            child: const SizedBox.expand(),
          );
        } else {
          // High-Performance 3D Geometric Spherical Fallback
          return CustomPaint(
            painter: _OrbGeometric3DPainter(
              time: time,
              bass: bass,
              mid: mid,
              treble: treble,
              palette: widget.palette,
              bands: widget.spectrum.bands,
            ),
            child: const SizedBox.expand(),
          );
        }
      },
    );
  }
}

class _OrbShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final double bass;
  final double mid;
  final double treble;
  final Color primary;
  final Color secondary;
  final Color accent;

  _OrbShaderPainter({
    required this.shader,
    required this.time,
    required this.bass,
    required this.mid,
    required this.treble,
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Pass uniforms to GLSL 460 fragment shader
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, bass);
    shader.setFloat(4, mid);
    shader.setFloat(5, treble);

    // Primary RGB
    shader.setFloat(6, primary.red / 255.0);
    shader.setFloat(7, primary.green / 255.0);
    shader.setFloat(8, primary.blue / 255.0);

    // Secondary RGB
    shader.setFloat(9, secondary.red / 255.0);
    shader.setFloat(10, secondary.green / 255.0);
    shader.setFloat(11, secondary.blue / 255.0);

    // Accent RGB
    shader.setFloat(12, accent.red / 255.0);
    shader.setFloat(13, accent.green / 255.0);
    shader.setFloat(14, accent.blue / 255.0);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbShaderPainter old) => true;
}

// 3D Fibonacci Sphere Lattice Geometry with Z-Sorting & Perspective Projection
class _OrbGeometric3DPainter extends CustomPainter {
  final double time;
  final double bass;
  final double mid;
  final double treble;
  final DynamicAlbumPalette palette;
  final List<double> bands;

  _OrbGeometric3DPainter({
    required this.time,
    required this.bass,
    required this.mid,
    required this.treble,
    required this.palette,
    required this.bands,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.28 * (1.0 + bass * 0.35);

    // Draw background ambient glow
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        baseRadius * 1.8,
        [
          palette.vibrant.withOpacity(0.4 + bass * 0.3),
          palette.muted.withOpacity(0.15),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(center, baseRadius * 1.8, glowPaint);

    // Generate 3D Spherical Points (Fibonacci Sphere Distribution)
    const int numPoints = 84;
    final List<_Projected3DPoint> projectedPoints = [];

    final double rotY = time * 0.4;
    final double rotX = math.sin(time * 0.2) * 0.3;

    for (int i = 0; i < numPoints; i++) {
      final double y = 1.0 - (i / (numPoints - 1.0)) * 2.0; // -1 to 1
      final double radiusAtY = math.sqrt(1.0 - y * y);
      final double theta = 2.39996323 * i + time * 0.3; // Golden angle

      double x = math.cos(theta) * radiusAtY;
      double z = math.sin(theta) * radiusAtY;

      // Deform by harmonic frequency bands
      final bandIndex = i % bands.length;
      final displacement = 1.0 + (bands[bandIndex] * 0.45 * (1.0 + mid * 0.5));
      x *= displacement * baseRadius;
      final double dy = y * displacement * baseRadius;
      z *= displacement * baseRadius;

      // Rotate 3D Euler angles
      final double x1 = x * math.cos(rotY) + z * math.sin(rotY);
      final double z1 = -x * math.sin(rotY) + z * math.cos(rotY);

      final double y2 = dy * math.cos(rotX) - z1 * math.sin(rotX);
      final double z2 = dy * math.sin(rotX) + z1 * math.cos(rotX);

      // Perspective projection
      const double fov = 400.0;
      final double scale = fov / (fov + z2 + 100.0);
      final double projX = center.dx + x1 * scale;
      final double projY = center.dy + y2 * scale;

      projectedPoints.add(
        _Projected3DPoint(
          offset: Offset(projX, projY),
          depth: z2,
          radius: math.max(2.0, (4.5 + treble * 3.0) * scale),
          color: Color.lerp(
            palette.vibrant,
            palette.lightVibrant,
            (y + 1.0) / 2.0,
          )!,
        ),
      );
    }

    // Depth sort (Z-sorting: back to front)
    projectedPoints.sort((a, b) => b.depth.compareTo(a.depth));

    final pointPaint = Paint()..style = PaintingStyle.fill;

    for (final pt in projectedPoints) {
      final alpha = ((pt.depth + 200.0) / 400.0).clamp(0.2, 1.0);
      pointPaint.color = pt.color.withOpacity(alpha);
      canvas.drawCircle(pt.offset, pt.radius, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbGeometric3DPainter old) => true;
}

class _Projected3DPoint {
  final Offset offset;
  final double depth;
  final double radius;
  final Color color;

  _Projected3DPoint({
    required this.offset,
    required this.depth,
    required this.radius,
    required this.color,
  });
}
