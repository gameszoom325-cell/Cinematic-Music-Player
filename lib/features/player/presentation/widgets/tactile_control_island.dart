import 'package:flutter/material.dart';
import '../../../../core/theme/cinematic_colors.dart';

/// Tactile Centerpiece Audio Control Island matching the Acoustic Minimal aesthetic.
/// Houses the ambient rain slider, analog-feel transport controls (shuffle, prev,
/// 56px amber play/pause spring button, next, repeat), and master volume gain slider.
class TactileControlIsland extends StatefulWidget {
  final bool isPlaying;
  final bool isLoading;
  final bool isShuffle;
  final int repeatMode; // 0 = off, 1 = one, 2 = all
  final double volume; // 0.0 to 1.0
  final double ambientLevel; // 0.0 to 1.0
  final Color activeColor;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onAmbientChanged;
  final VoidCallback? onToggleMute;

  const TactileControlIsland({
    super.key,
    required this.isPlaying,
    this.isLoading = false,
    required this.isShuffle,
    required this.repeatMode,
    this.volume = 1.0,
    this.ambientLevel = 0.35,
    this.activeColor = CinematicColors.primary,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
    required this.onVolumeChanged,
    required this.onAmbientChanged,
    this.onToggleMute,
  });

  @override
  State<TactileControlIsland> createState() => _TactileControlIslandState();
}

class _TactileControlIslandState extends State<TactileControlIsland> {
  bool _playPressed = false;
  bool _playHovered = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: CinematicColors.surfaceContainerLow.withOpacity(0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isNarrow ? _buildNarrowLayout() : _buildWideLayout(),
        );
      },
    );
  }

  Widget _buildWideLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Ambient Rain Sound Generator Slider
        _buildAmbientSlider(width: 180),

        // Center: Analog Audio Transport
        _buildTransportControls(),

        // Right: Direct DAC & Master Volume Gain
        _buildVolumeControls(width: 180),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTransportControls(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildAmbientSlider(width: 140)),
            const SizedBox(width: 16),
            Expanded(child: _buildVolumeControls(width: 140)),
          ],
        ),
      ],
    );
  }

  Widget _buildAmbientSlider({required double width}) {
    final pct = (widget.ambientLevel * 100).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: CinematicColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.water_drop_rounded,
            size: 18,
            color: widget.ambientLevel > 0
                ? widget.activeColor
                : Colors.white38,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Rain Ambience",
                    style: TextStyle(
                      color: CinematicColors.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "$pct%",
                    style: TextStyle(
                      color: widget.activeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              GestureDetector(
                onHorizontalDragUpdate: (details) {
                  final delta = details.delta.dx / width;
                  widget.onAmbientChanged((widget.ambientLevel + delta).clamp(0.0, 1.0));
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 5,
                    color: CinematicColors.surfaceContainerHighest,
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: widget.ambientLevel.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.activeColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransportControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shuffle Mode Button
        _buildSubtleButton(
          icon: Icons.shuffle_rounded,
          isSelected: widget.isShuffle,
          tooltip: "Shuffle",
          onPressed: widget.onToggleShuffle,
        ),
        const SizedBox(width: 8),

        // Skip Previous
        _buildSubtleButton(
          icon: Icons.skip_previous_rounded,
          tooltip: "Previous Track",
          size: 40,
          iconSize: 22,
          onPressed: widget.onPrevious,
        ),
        const SizedBox(width: 12),

        // Main Tactile Play/Pause Spring Button
        _buildMainPlayPauseButton(),

        const SizedBox(width: 12),

        // Skip Next
        _buildSubtleButton(
          icon: Icons.skip_next_rounded,
          tooltip: "Next Track",
          size: 40,
          iconSize: 22,
          onPressed: widget.onNext,
        ),
        const SizedBox(width: 8),

        // Repeat Mode Button
        _buildSubtleButton(
          icon: widget.repeatMode == 1
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          isSelected: widget.repeatMode > 0,
          tooltip: "Repeat Mode",
          onPressed: widget.onCycleRepeat,
        ),
      ],
    );
  }

  Widget _buildMainPlayPauseButton() {
    final scale = _playPressed ? 0.90 : (_playHovered ? 1.06 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _playHovered = true),
      onExit: (_) => setState(() => _playHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _playPressed = true),
        onTapUp: (_) => setState(() => _playPressed = false),
        onTapCancel: () => setState(() => _playPressed = false),
        onTap: widget.isLoading ? null : widget.onPlayPause,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.activeColor,
              boxShadow: [
                BoxShadow(
                  color: widget.activeColor.withOpacity(widget.isPlaying ? 0.5 : 0.25),
                  blurRadius: widget.isPlaying ? 20 : 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                      ),
                    )
                  : Icon(
                      widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 30,
                      color: Colors.black87,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtleButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    bool isSelected = false,
    double size = 36,
    double iconSize = 19,
  }) {
    return Tooltip(
      message: tooltip ?? "",
      child: Material(
        color: isSelected
            ? widget.activeColor.withOpacity(0.18)
            : CinematicColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: widget.activeColor.withOpacity(0.5), width: 1.0)
                  : null,
            ),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: isSelected ? widget.activeColor : CinematicColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeControls({required double width}) {
    final pct = (widget.volume * 100).round();
    final isMuted = widget.volume == 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Direct DAC Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: CinematicColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speaker_rounded, size: 13, color: widget.activeColor),
              const SizedBox(width: 4),
              const Text(
                "Direct DAC",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Volume Icon & Slider
        GestureDetector(
          onTap: widget.onToggleMute,
          child: Icon(
            isMuted
                ? Icons.volume_off_rounded
                : (widget.volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
            size: 18,
            color: isMuted ? Colors.redAccent : CinematicColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),

        SizedBox(
          width: width * 0.55,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              final delta = details.delta.dx / (width * 0.55);
              widget.onVolumeChanged((widget.volume + delta).clamp(0.0, 1.0));
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 5,
                color: CinematicColors.surfaceContainerHighest,
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: widget.volume.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.activeColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: Text(
            "$pct%",
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
