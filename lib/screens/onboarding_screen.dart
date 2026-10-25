import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

/// Clean, high-end Gen-Z onboarding screen designed with iOS native aesthetics.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _getStarted(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient lighting
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.electricPink.withOpacity(isDark ? 0.15 : 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.electricPink.withOpacity(isDark ? 0.25 : 0.12),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyberViolet.withOpacity(isDark ? 0.14 : 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyberViolet.withOpacity(isDark ? 0.22 : 0.1),
                    blurRadius: 120,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),

                  // Minimalist Brand Ribbon Header
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.electricPink, AppTheme.cyberViolet],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.gesture_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'doodle',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          color: isDark ? Colors.white : const Color(0xFF0E1017),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),

                  const Spacer(flex: 1),

                  // Hero visual illustration card (Simulating an active ephemeral canvas exchange)
                  Center(
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Top bar inside card
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppTheme.electricPink.withOpacity(0.2),
                                    child: const Text('✨', style: TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '@alex • drawing now',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.electricPink,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.acidLime.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Ephemeral',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.acidLime,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Simulated neon doodle stroke in card
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [
                                      AppTheme.electricPink,
                                      AppTheme.cyberViolet,
                                      AppTheme.neonYellow,
                                    ],
                                  ).createShader(bounds),
                                  child: Text(
                                    'Meet up tonight? ⚡️',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Erase completely to unlock your reply canvas',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF7A8098) : const Color(0xFF8C92A4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().scale(delay: 150.ms, duration: 500.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 32),

                  // Headline
                  Text(
                    'Talk in strokes,\nnot keyboards.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                      letterSpacing: -1.0,
                      color: isDark ? Colors.white : const Color(0xFF0E1017),
                    ),
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 10),

                  Text(
                    'Express yourself with real-time handwritten doodles, stamps, and photos. No archives. No screenshots.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      height: 1.45,
                      color: isDark ? const Color(0xFFA5ABC0) : const Color(0xFF5D6275),
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  const Spacer(flex: 2),

                  // Feature Pills
                  _buildFeatureRow(
                    isDark: isDark,
                    icon: Icons.brush_rounded,
                    accentColor: AppTheme.electricPink,
                    title: 'Live Canvas Chat',
                    subtitle: 'Spontaneous fingerstrokes, stickers, and sketches.',
                  ).animate().fadeIn(delay: 450.ms).slideX(begin: 0.1, end: 0),

                  const SizedBox(height: 14),

                  _buildFeatureRow(
                    isDark: isDark,
                    icon: Icons.auto_fix_high_rounded,
                    accentColor: AppTheme.cyberViolet,
                    title: 'Erase to Reply',
                    subtitle: 'Your friend rubs out your doodle before drawing back.',
                  ).animate().fadeIn(delay: 550.ms).slideX(begin: 0.1, end: 0),

                  const Spacer(flex: 2),

                  // Bottom CTA Button — iOS 18-styled frosted gradient capsule
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.electricPink,
                          Color(0xFFFF3B30),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.electricPink.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _getStarted(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 16),
                        ],
                      ),
                    ),
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

  Widget _buildFeatureRow({
    required bool isDark,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(isDark ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF0E1017),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF8A90A6) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
