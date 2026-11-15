import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.45, curve: Curves.easeIn)),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.9, curve: Curves.easeInOut)),
    );

    _controller.forward();

    // Navigate to AuthGateway after entrance presentation
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthGateway(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinematicColors.obsidianBlack,
      body: Stack(
        children: [
          // Background ambient gradient orbs
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CinematicColors.electricViolet.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CinematicColors.cyberCyan.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Glowing Ring around App Icon
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer rotating glow ring
                            Transform.rotate(
                              angle: _controller.value * 2 * math.pi,
                              child: Container(
                                width: 146,
                                height: 146,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      CinematicColors.primary,
                                      CinematicColors.primary.withOpacity(0.3),
                                      CinematicColors.primary,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: CinematicColors.primary.withOpacity(_glowAnimation.value * 0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Inner dark mask
                            Container(
                              width: 140,
                              height: 140,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: CinematicColors.obsidianBlack,
                              ),
                            ),

                            // The Official Logo Image
                            ClipOval(
                              child: Image.asset(
                                'assets/icons/app_icon.png',
                                width: 132,
                                height: 132,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 132,
                                  height: 132,
                                  color: CinematicColors.electricViolet,
                                  child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 54),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),

                        // Title
                        const Text(
                          "CINEMATIC",
                          style: TextStyle(
                            color: CinematicColors.electricViolet,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Music Player",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Audio reactive mini bars animation
                        SizedBox(
                          width: 80,
                          height: 24,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(5, (index) {
                              final delay = index * 0.15;
                              final val = math.sin((_controller.value * 4 * math.pi) + (delay * math.pi)).abs();
                              final barHeight = 6.0 + (val * 18.0);

                              return Container(
                                width: 4,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: CinematicColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          "Initializing Audio Engine...",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
