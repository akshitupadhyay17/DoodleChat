import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CatWhiskersHiAnimation extends StatefulWidget {
  final double size;
  final VoidCallback? onAnimationComplete;

  const CatWhiskersHiAnimation({
    super.key,
    this.size = 240,
    this.onAnimationComplete,
  });

  @override
  State<CatWhiskersHiAnimation> createState() => _CatWhiskersHiAnimationState();
}

class _CatWhiskersHiAnimationState extends State<CatWhiskersHiAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _whiskersAnimation;
  late Animation<double> _wiggleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.05),
        weight: 35,
      ),
    ]).animate(_controller);

    _whiskersAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    );

    _wiggleAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.elasticIn),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _wiggleAnimation.value,
            child: SizedBox(
              width: widget.size * 1.5,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Whiskers Custom Painter
                  CustomPaint(
                    size: Size(widget.size * 1.5, widget.size),
                    painter: CatWhiskersPainter(
                      progress: _whiskersAnimation.value,
                      whiskerColor: const Color(0xFF1E1E26),
                    ),
                  ),

                  // Center HI doodle text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cute cat ears above HI
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCatEar(isLeft: true),
                          const SizedBox(width: 45),
                          _buildCatEar(isLeft: false),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // HI Text in Cartoon Doodle Font
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFFFB703),
                            Color(0xFFFFC72C),
                            Color(0xFFFF6B35),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          'HI',
                          style: GoogleFonts.gaegu(
                            fontSize: widget.size * 0.42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.0,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(3, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Little cat nose & mouth doodle
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B81),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'ω',
                        style: GoogleFonts.patrickHand(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E26),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCatEar({required bool isLeft}) {
    return Transform.rotate(
      angle: isLeft ? -0.25 : 0.25,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFFFFC72C),
          border: Border.all(color: const Color(0xFF1E1E26), width: 2.5),
          borderRadius: BorderRadius.only(
            topLeft: isLeft ? const Radius.circular(16) : const Radius.circular(4),
            topRight: !isLeft ? const Radius.circular(16) : const Radius.circular(4),
            bottomLeft: const Radius.circular(4),
            bottomRight: const Radius.circular(4),
          ),
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFFF7675),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

class CatWhiskersPainter extends CustomPainter {
  final double progress;
  final Color whiskerColor;

  CatWhiskersPainter({
    required this.progress,
    required this.whiskerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = whiskerColor
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2 + 10;

    // 3 Left Whiskers (cat moustaches)
    final leftOrigin = Offset(centerX - 65, centerY);
    _drawWhisker(canvas, paint, leftOrigin, -55 * progress, -18);
    _drawWhisker(canvas, paint, leftOrigin, -62 * progress, 0);
    _drawWhisker(canvas, paint, leftOrigin, -55 * progress, 18);

    // 3 Right Whiskers (cat moustaches)
    final rightOrigin = Offset(centerX + 65, centerY);
    _drawWhisker(canvas, paint, rightOrigin, 55 * progress, -18);
    _drawWhisker(canvas, paint, rightOrigin, 62 * progress, 0);
    _drawWhisker(canvas, paint, rightOrigin, 55 * progress, 18);
  }

  void _drawWhisker(
    Canvas canvas,
    Paint paint,
    Offset start,
    double dx,
    double dy,
  ) {
    final path = Path();
    path.moveTo(start.dx, start.dy);
    // Slight organic curve for doodle aesthetic
    final controlPoint = Offset(start.dx + dx * 0.5, start.dy + dy * 0.7);
    final endPoint = Offset(start.dx + dx, start.dy + dy);
    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      endPoint.dx,
      endPoint.dy,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CatWhiskersPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
