import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/audio_engine/fft_engine.dart';
import '../../../../core/theme/cinematic_colors.dart';

class AuroraMeshVisualizer extends StatefulWidget {
  final AudioSpectrumFrame spectrum;
  final DynamicAlbumPalette palette;
  final double sensitivity;

  const AuroraMeshVisualizer({
    super.key,
    required this.spectrum,
    required this.palette,
    this.sensitivity = 1.0,
  });

  @override
  State<AuroraMeshVisualizer> createState() => _AuroraMeshVisualizerState();
}

class _AuroraMeshVisualizerState extends State<AuroraMeshVisualizer>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  bool _shaderLoadFailed = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/aurora_mesh.frag');
      if (mounted) {
        setState(() {
          _shader = program.fragmentShader();
        });
      }
    } catch (e) {
      debugPrint("Aurora FragmentShader load fallback: $e");
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
        final time = _controller.value * 30.0;
        final energy = (widget.spectrum.overallRms * widget.sensitivity).clamp(0.0, 1.5);
        final bass = (widget.spectrum.bass * widget.sensitivity).clamp(0.0, 1.5);

        if (_shader != null && !_shaderLoadFailed) {
          return CustomPaint(
            painter: _AuroraShaderPainter(
              shader: _shader!,
              time: time,
              energy: energy,
              bass: bass,
              palette: widget.palette,
            ),
            child: const SizedBox.expand(),
          );
        } else {
          // Smooth Lava-Lamp Procedural Fallback
          return CustomPaint(
            painter: _AuroraProceduralPainter(
              time: time,
              energy: energy,
              bass: bass,
              palette: widget.palette,
            ),
            child: const SizedBox.expand(),
          );
        }
      },
    );
  }
}

class _AuroraShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final double energy;
  final double bass;
  final DynamicAlbumPalette palette;

  _AuroraShaderPainter({
    required this.shader,
    required this.time,
    required this.energy,
    required this.bass,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, energy);
    shader.setFloat(4, bass);

    // Color 1: Vibrant
    shader.setFloat(5, palette.vibrant.red / 255.0);
    shader.setFloat(6, palette.vibrant.green / 255.0);
    shader.setFloat(7, palette.vibrant.blue / 255.0);

    // Color 2: Muted
    shader.setFloat(8, palette.muted.red / 255.0);
    shader.setFloat(9, palette.muted.green / 255.0);
    shader.setFloat(10, palette.muted.blue / 255.0);

    // Color 3: Light Vibrant
    shader.setFloat(11, palette.lightVibrant.red / 255.0);
    shader.setFloat(12, palette.lightVibrant.green / 255.0);
    shader.setFloat(13, palette.lightVibrant.blue / 255.0);

    // Color BG: Dark Muted
    shader.setFloat(14, palette.darkMuted.red / 255.0);
    shader.setFloat(15, palette.darkMuted.green / 255.0);
    shader.setFloat(16, palette.darkMuted.blue / 255.0);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraShaderPainter old) => true;
}

class _AuroraProceduralPainter extends CustomPainter {
  final double time;
  final double energy;
  final double bass;
  final DynamicAlbumPalette palette;

  _AuroraProceduralPainter({
    required this.time,
    required this.energy,
    required this.bass,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill base deep dark obsidian
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = palette.darkMuted.withOpacity(0.95),
    );

    final t = time * (0.3 + energy * 0.4);

    // 4 Morphing Lava-lamp gradient blobs
    final blob1Center = Offset(
      size.width * (0.35 + 0.25 * math.sin(t * 0.8)),
      size.height * (0.4 + 0.25 * math.cos(t * 0.7)),
    );
    final blob1Radius = size.width * (0.45 + bass * 0.2);

    final blob2Center = Offset(
      size.width * (0.7 + 0.2 * math.cos(t * 0.6)),
      size.height * (0.65 + 0.2 * math.sin(t * 0.9)),
    );
    final blob2Radius = size.width * (0.5 + energy * 0.15);

    final blob3Center = Offset(
      size.width * (0.5 + 0.3 * math.sin(t * 1.1)),
      size.height * (0.2 + 0.15 * math.cos(t * 1.2)),
    );
    final blob3Radius = size.width * 0.35;

    // Draw Blob 1 (Vibrant)
    canvas.drawCircle(
      blob1Center,
      blob1Radius,
      Paint()
        ..shader = ui.Gradient.radial(
          blob1Center,
          blob1Radius,
          [
            palette.vibrant.withOpacity(0.45 + bass * 0.3),
            palette.vibrant.withOpacity(0.0),
          ],
        ),
    );

    // Draw Blob 2 (Muted)
    canvas.drawCircle(
      blob2Center,
      blob2Radius,
      Paint()
        ..shader = ui.Gradient.radial(
          blob2Center,
          blob2Radius,
          [
            palette.muted.withOpacity(0.4 + energy * 0.25),
            palette.muted.withOpacity(0.0),
          ],
        ),
    );

    // Draw Blob 3 (Light Vibrant highlight)
    canvas.drawCircle(
      blob3Center,
      blob3Radius,
      Paint()
        ..shader = ui.Gradient.radial(
          blob3Center,
          blob3Radius,
          [
            palette.lightVibrant.withOpacity(0.35 + energy * 0.3),
            palette.lightVibrant.withOpacity(0.0),
          ],
        ),
    );

    // Vignette overlay
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height / 2),
          size.width * 0.7,
          [
            Colors.transparent,
            CinematicColors.obsidianBlack.withOpacity(0.75),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraProceduralPainter old) => true;
}
