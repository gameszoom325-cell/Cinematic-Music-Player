import 'package:flutter/material.dart';
import '../core/theme/cinematic_colors.dart';
import '../core/theme/glassmorphism.dart';
import '../core/theme/typography.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'auth_service.dart';
import '../app_shell.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  bool _isLoadingGuest = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleContinueWithoutAccount() async {
    setState(() => _isLoadingGuest = true);
    try {
      await AuthService.instance.continueWithoutAccount();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingGuest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinematicColors.obsidianBlack,
      body: Stack(
        children: [
          // Ambient Background Glow Circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CinematicColors.electricViolet.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CinematicColors.cyberCyan.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Cinematic Icon Badge
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [CinematicColors.electricViolet, CinematicColors.deepPlum],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: CinematicColors.electricViolet.withOpacity(0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Title & Subtitle
                        Text(
                          "CINEMATIC",
                          style: TextStyle(
                            color: CinematicColors.electricViolet,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Your Music, Everywhere",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Log in on Windows Desktop and Android Mobile to access the same playlists, favorites, and visualizer experience on all your devices.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Cross-Device Capabilities Card
                        CinematicGlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          borderRadius: 20,
                          child: Column(
                            children: [
                              _buildFeatureRow(
                                Icons.cloud_sync_rounded,
                                "Cross-Platform Sync",
                                "Playlists, favorites, and history synchronized seamlessly.",
                              ),
                              const Divider(color: Colors.white12, height: 20),
                              _buildFeatureRow(
                                Icons.devices_rounded,
                                "Multi-Device Freedom",
                                "Instant access across Windows desktop & Android phone.",
                              ),
                              const Divider(color: Colors.white12, height: 20),
                              _buildFeatureRow(
                                Icons.lock_outline_rounded,
                                "Private Local Vault",
                                "Zero public streaming or scraping. 100% private library.",
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Action 1: Create Account
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CinematicColors.electricViolet,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              shadowColor: CinematicColors.electricViolet.withOpacity(0.5),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add_alt_1_rounded, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  "Create Account",
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Action 2: Login
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.2)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  "Log In",
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action 3: Continue without account
                        TextButton(
                          onPressed: _isLoadingGuest ? null : _handleContinueWithoutAccount,
                          child: _isLoadingGuest
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Continue without account",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.65),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: Colors.white.withOpacity(0.65),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: CinematicColors.electricViolet.withOpacity(0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: CinematicColors.electricViolet, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
