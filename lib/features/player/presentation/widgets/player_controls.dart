import 'package:flutter/material.dart';
import '../../../../core/theme/cinematic_colors.dart';
import '../../../../core/theme/glassmorphism.dart';

class PlayerControls extends StatelessWidget {
  final bool isPlaying;
  final bool isShuffle;
  final int repeatMode; // 0=off, 1=one, 2=all
  final bool isFavorite;
  final Color activeGlow;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;
  final VoidCallback onToggleFavorite;

  const PlayerControls({
    super.key,
    required this.isPlaying,
    required this.isShuffle,
    required this.repeatMode,
    required this.isFavorite,
    required this.activeGlow,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shuffle Button
        GlassIconButton(
          icon: Icons.shuffle_rounded,
          onPressed: onToggleShuffle,
          size: 42,
          iconSize: 20,
          isSelected: isShuffle,
          glowColor: activeGlow,
          tooltip: "Shuffle",
        ),
        const SizedBox(width: 16),

        // Skip Previous
        GlassIconButton(
          icon: Icons.skip_previous_rounded,
          onPressed: onPrevious,
          size: 52,
          iconSize: 28,
          glowColor: activeGlow,
          tooltip: "Previous Track",
        ),
        const SizedBox(width: 20),

        // Hero Play / Pause Button with Pulsing Glow
        _HeroPlayPauseButton(
          isPlaying: isPlaying,
          glowColor: activeGlow,
          onPressed: onPlayPause,
        ),
        const SizedBox(width: 20),

        // Skip Next
        GlassIconButton(
          icon: Icons.skip_next_rounded,
          onPressed: onNext,
          size: 52,
          iconSize: 28,
          glowColor: activeGlow,
          tooltip: "Next Track",
        ),
        const SizedBox(width: 16),

        // Repeat Button
        GlassIconButton(
          icon: repeatMode == 1
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          onPressed: onCycleRepeat,
          size: 42,
          iconSize: 20,
          isSelected: repeatMode > 0,
          glowColor: activeGlow,
          tooltip: "Repeat Mode",
        ),
      ],
    );
  }
}

class _HeroPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final Color glowColor;
  final VoidCallback onPressed;

  const _HeroPlayPauseButton({
    required this.isPlaying,
    required this.glowColor,
    required this.onPressed,
  });

  @override
  State<_HeroPlayPauseButton> createState() => _HeroPlayPauseButtonState();
}

class _HeroPlayPauseButtonState extends State<_HeroPlayPauseButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.90 : (_isHovered ? 1.08 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.glowColor,
                  widget.glowColor.withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withOpacity(widget.isPlaying ? 0.6 : 0.35),
                  blurRadius: widget.isPlaying ? 30.0 : 18.0,
                  spreadRadius: widget.isPlaying ? 2.0 : 0.0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 16.0,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(widget.isPlaying),
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
