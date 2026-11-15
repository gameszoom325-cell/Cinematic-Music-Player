import 'dart:ui';
import 'package:flutter/material.dart';
import 'cinematic_colors.dart';

class CinematicGlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final Color tintColor;
  final double tintOpacity;
  final double borderOpacity;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;

  const CinematicGlassCard({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.borderRadius = 8.0,
    this.tintColor = Colors.white,
    this.tintOpacity = 0.04,
    this.borderOpacity = 0.08,
    this.borderColor,
    this.padding,
    this.margin,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16.0,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                width: 1.2,
                color: borderColor ?? Colors.white.withOpacity(borderOpacity),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tintColor.withOpacity(tintOpacity.clamp(0.0, 1.0)),
                  tintColor.withOpacity((tintOpacity * 0.4).clamp(0.0, 1.0)),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final Color? glowColor;
  final String? tooltip;
  final bool isSelected;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 46.0,
    this.iconSize = 22.0,
    this.glowColor,
    this.tooltip,
    this.isSelected = false,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final activeGlow = widget.glowColor ?? CinematicColors.electricViolet;
    final scale = _isPressed ? 0.92 : (_isHovered ? 1.08 : 1.0);

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
            duration: const Duration(milliseconds: 200),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isSelected
                  ? activeGlow.withOpacity(0.3)
                  : (_isHovered
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.06)),
              border: Border.all(
                color: widget.isSelected
                    ? activeGlow.withOpacity(0.8)
                    : (_isHovered
                        ? Colors.white.withOpacity(0.35)
                        : Colors.white.withOpacity(0.14)),
                width: 1.2,
              ),
              boxShadow: [
                if (widget.isSelected || _isHovered)
                  BoxShadow(
                    color: activeGlow.withOpacity(0.4),
                    blurRadius: 18.0,
                    spreadRadius: 1.0,
                  ),
              ],
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: widget.isSelected
                    ? Colors.white
                    : (_isHovered ? Colors.white : Colors.white.withOpacity(0.85)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
