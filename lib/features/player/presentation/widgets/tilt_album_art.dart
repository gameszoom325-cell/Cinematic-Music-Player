import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/database/models/song_model.dart';
import '../../../../core/theme/cinematic_colors.dart';

class TiltAlbumArtwork extends StatefulWidget {
  final SongModel? song;
  final double size;
  final double borderRadius;
  final Color glowColor;

  const TiltAlbumArtwork({
    super.key,
    required this.song,
    this.size = 280.0,
    this.borderRadius = 24.0,
    this.glowColor = CinematicColors.electricViolet,
  });

  @override
  State<TiltAlbumArtwork> createState() => _TiltAlbumArtworkState();
}

class _TiltAlbumArtworkState extends State<TiltAlbumArtwork> {
  double _rotateX = 0.0;
  double _rotateY = 0.0;
  Offset _sheenPosition = const Offset(0.5, 0.5);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final center = Offset(box.size.width / 2, box.size.height / 2);
        final delta = event.localPosition - center;

        setState(() {
          // Max rotation: ~14 degrees (0.24 rad)
          _rotateX = (-delta.dy / center.dy).clamp(-1.0, 1.0) * 0.24;
          _rotateY = (delta.dx / center.dx).clamp(-1.0, 1.0) * 0.24;
          _sheenPosition = Offset(
            (event.localPosition.dx / box.size.width).clamp(0.0, 1.0),
            (event.localPosition.dy / box.size.height).clamp(0.0, 1.0),
          );
        });
      },
      onExit: (_) {
        setState(() {
          _rotateX = 0.0;
          _rotateY = 0.0;
          _sheenPosition = const Offset(0.5, 0.5);
        });
      },
      child: TweenAnimationBuilder<Matrix4>(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        tween: Matrix4Tween(
          begin: Matrix4.identity(),
          end: Matrix4.identity()
            ..setEntry(3, 2, 0.0015) // 3D Perspective division
            ..rotateX(_rotateX)
            ..rotateY(_rotateY),
        ),
        builder: (context, matrix, child) {
          return Transform(
            transform: matrix,
            alignment: FractionalOffset.center,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: widget.glowColor.withOpacity(0.45),
                    blurRadius: 40.0,
                    spreadRadius: -4.0,
                    offset: Offset(_rotateY * 40, -_rotateX * 40 + 16),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 28.0,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Artwork image or procedural gradient fallback
                    _buildArtworkContent(),

                    // Dynamic Specular Sheen Highlight
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(
                            (_sheenPosition.dx * 2) - 1,
                            (_sheenPosition.dy * 2) - 1,
                          ),
                          radius: 0.85,
                          colors: [
                            Colors.white.withOpacity(0.28),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),

                    // Specular Border Stroke
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                        border: Border.all(
                          width: 1.5,
                          color: Colors.white.withOpacity(0.25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtworkContent() {
    if (widget.song?.artworkPath != null) {
      final file = File(widget.song!.artworkPath!);
      if (file.existsSync() && file.lengthSync() > 0) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    // Procedural glowing album art tile
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.glowColor.withOpacity(0.8),
            CinematicColors.obsidianDark,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: widget.size * 0.32,
              color: Colors.white.withOpacity(0.85),
            ),
            const SizedBox(height: 8),
            Text(
              widget.song?.format ?? "CINEMATIC",
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
