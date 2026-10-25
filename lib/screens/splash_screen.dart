import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      final chatService = ChatService();
      if (chatService.isLoggedIn) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient background glow orbs
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.electricPink.withOpacity(0.18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.electricPink.withOpacity(0.3),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyberViolet.withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyberViolet.withOpacity(0.3),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Sleek Brand Emblem (Glowing squircle with ribbon doodle mark)
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E202E),
                          Color(0xFF12131C),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.electricPink.withOpacity(0.25),
                          blurRadius: 36,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: AppTheme.cyberViolet.withOpacity(0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(64, 64),
                          painter: _DoodleRibbonPainter(),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .scale(
                        duration: 800.ms,
                        curve: Curves.easeOutBack,
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1, 1),
                      )
                      .fade(duration: 600.ms),

                  const SizedBox(height: 32),

                  // Brand Title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFF0F3FF),
                        Color(0xFFFFD6E0),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      'doodle',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        color: Colors.white,
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    'handwritten • ephemeral • real-time',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: const Color(0xFF8A90A6),
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                  const Spacer(),

                  // Anti-Screenshot / Privacy Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.acidLime,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.acidLime,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Zero Digital Footprint • Anti-Screenshot',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: const Color(0xFFA5ABC0),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the modern gradient doodle ribbon logo
class _DoodleRibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = const LinearGradient(
      colors: [
        AppTheme.electricPink,
        AppTheme.cyberViolet,
        AppTheme.neonYellow,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);

    final paint = Paint()
      ..shader = gradient
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Flowing elegant infinity doodle loop
    path.moveTo(size.width * 0.22, size.height * 0.65);
    path.cubicTo(
      size.width * 0.05,
      size.height * 0.35,
      size.width * 0.45,
      size.height * 0.15,
      size.width * 0.50,
      size.height * 0.50,
    );
    path.cubicTo(
      size.width * 0.55,
      size.height * 0.85,
      size.width * 0.95,
      size.height * 0.65,
      size.width * 0.78,
      size.height * 0.32,
    );
    path.cubicTo(
      size.width * 0.65,
      size.height * 0.12,
      size.width * 0.40,
      size.height * 0.30,
      size.width * 0.38,
      size.height * 0.48,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
