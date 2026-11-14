import 'package:flutter/material.dart';
import '../core/theme/cinematic_colors.dart';
import '../core/theme/glassmorphism.dart';
import '../core/theme/typography.dart';
import 'auth_service.dart';
import 'register_screen.dart';
import '../sync/sync_manager.dart';
import '../app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.login(
        email: _emailController.text,
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );

      // Trigger cloud sync to pull down all playlists, favorites, and history
      SyncManager.instance.syncAll();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception: ", "");
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinematicColors.obsidianBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text("Welcome Back", style: CinematicTypography.displayTitle),
                  const SizedBox(height: 8),
                  const Text(
                    "Log in to synchronize your playlists, favorites, and visualizer settings across your devices.",
                    style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 28),

                  // Error notification banner
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Glass Credentials Card
                  CinematicGlassCard(
                    padding: const EdgeInsets.all(22),
                    borderRadius: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email Field
                        const Text(
                          "EMAIL ADDRESS",
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "you@example.com",
                            hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                            prefixIcon: const Icon(Icons.mail_outline_rounded, color: Colors.white54, size: 20),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: CinematicColors.electricViolet, width: 1.5),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Email is required";
                            if (!val.contains('@')) return "Enter a valid email address";
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        const Text(
                          "PASSWORD",
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "••••••••",
                            hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: CinematicColors.electricViolet, width: 1.5),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Password is required";
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Remember Me Checkbox
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: CinematicColors.electricViolet,
                                checkColor: Colors.white,
                                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                onChanged: (val) => setState(() => _rememberMe = val ?? true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Remember session on this device",
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Login Button
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
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              "Log In",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Switch to Register
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? ", style: TextStyle(color: Colors.white60, fontSize: 13)),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: const Text(
                            "Create Account",
                            style: TextStyle(color: CinematicColors.electricViolet, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
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
    );
  }
}
