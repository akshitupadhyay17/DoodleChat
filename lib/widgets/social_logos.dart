import 'package:flutter/material.dart';

/// Official Instagram glyph painter (crisp rounded camera outline, center lens, and flash dot).
/// Rendered with mathematical accuracy using native Canvas primitives to guarantee 100% vector fidelity.
class InstagramLogoPainter extends CustomPainter {
  final Color color;
  const InstagramLogoPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.10;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Camera rounded rect outline
    final outerRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width - strokeWidth,
      height: size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(outerRect, Radius.circular(size.width * 0.28));
    canvas.drawRRect(rrect, strokePaint);

    // 2. Center lens circle
    final center = Offset(size.width / 2, size.height / 2);
    final lensRadius = size.width * 0.23;
    canvas.drawCircle(center, lensRadius, strokePaint);

    // 3. Top-right flash dot
    final dotCenter = Offset(size.width * 0.74, size.height * 0.26);
    final dotRadius = size.width * 0.055;
    canvas.drawCircle(dotCenter, dotRadius, fillPaint);
  }

  @override
  bool shouldRepaint(covariant InstagramLogoPainter oldDelegate) => oldDelegate.color != color;
}

/// Official Instagram branded logo widget with authentic gradient background and glow.
class InstagramLogoWidget extends StatelessWidget {
  final double size;
  const InstagramLogoWidget({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const RadialGradient(
          center: Alignment(-0.85, 0.95),
          radius: 1.35,
          colors: [
            Color(0xFFFFDF9E), // Light yellow highlight
            Color(0xFFFFC272), // Amber
            Color(0xFFFF385C), // Red-coral
            Color(0xFFE02D69), // Pink
            Color(0xFFD300C5), // Magenta
            Color(0xFF7638FA), // Deep Violet
          ],
          stops: [0.0, 0.15, 0.42, 0.58, 0.78, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE02D69).withOpacity(0.38),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.60, size * 0.60),
          painter: const InstagramLogoPainter(color: Colors.white),
        ),
      ),
    );
  }
}

/// Official WhatsApp brand vector painter.
/// Draws the authentic WhatsApp speech bubble with its pointer tail at bottom-left
/// and the crisp, perfectly proportioned telephone handset inside.
class WhatsAppLogoPainter extends CustomPainter {
  final Color bubbleColor;
  final Color handsetColor;

  const WhatsAppLogoPainter({
    this.bubbleColor = const Color(0xFF25D366),
    this.handsetColor = Colors.white,
  });

  static Path? _cachedBubblePath;
  static Path? _cachedHandsetPath;

  static Path get _bubblePath => _cachedBubblePath ??= _buildBubblePath();
  static Path get _handsetPath => _cachedHandsetPath ??= _buildHandsetPath();

  static Path _buildBubblePath() {
    final p = Path();
    p.moveTo(307.546, 52.566);
    p.cubicTo(273.709, 18.684, 228.706, 0.017, 180.756, 0);
    p.cubicTo(81.951, 0, 1.538, 80.404, 1.504, 179.235);
    p.cubicTo(1.487, 210.829, 9.746, 241.667, 25.432, 268.844);
    p.lineTo(0, 361.736);
    p.lineTo(95.024, 336.811);
    p.cubicTo(121.203, 351.096, 150.683, 358.616, 180.679, 358.625);
    p.lineTo(180.756, 358.625);
    p.cubicTo(279.544, 358.625, 359.966, 278.212, 360.0, 179.381);
    p.cubicTo(360.017, 131.483, 341.392, 86.455, 307.546, 52.566);
    p.close();
    return p;
  }

  static Path _buildHandsetPath() {
    final p = Path();
    p.moveTo(262.475, 224.211);
    p.relativeCubicTo(-4.478, -2.243, -26.497, -13.073, -30.606, -14.568);
    p.relativeCubicTo(-4.108, -1.496, -7.09, -2.243, -10.073, 2.243);
    p.relativeCubicTo(-2.982, 4.487, -11.568, 14.577, -14.181, 17.559);
    p.relativeCubicTo(-2.613, 2.991, -5.226, 3.361, -9.704, 1.117);
    p.relativeCubicTo(-4.477, -2.243, -18.908, -6.97, -36.02, -22.226);
    p.relativeCubicTo(-13.313, -11.878, -22.304, -26.54, -24.916, -31.027);
    p.relativeCubicTo(-2.613, -4.486, -0.275, -6.91, 1.959, -9.136);
    p.relativeCubicTo(2.011, -2.011, 4.478, -5.234, 6.721, -7.847);
    p.relativeCubicTo(2.244, -2.613, 2.983, -4.486, 4.478, -7.469);
    p.relativeCubicTo(1.496, -2.991, 0.748, -5.603, -0.369, -7.847);
    p.relativeCubicTo(-1.118, -2.243, -10.073, -24.289, -13.812, -33.253);
    p.relativeCubicTo(-3.636, -8.732, -7.331, -7.546, -10.073, -7.692);
    p.relativeCubicTo(-2.613, -0.13, -5.595, -0.155, -8.586, -0.155);
    p.relativeCubicTo(-2.991, 0, -7.839, 1.118, -11.947, 5.604);
    p.relativeCubicTo(-4.108, 4.486, -15.677, 15.324, -15.677, 37.361);
    // Smooth continuation computed explicitly as standard relative cubic
    p.relativeCubicTo(0, 22.037, 16.047, 43.344, 18.29, 46.335);
    p.relativeCubicTo(2.243, 2.991, 31.585, 48.225, 76.51, 67.632);
    p.relativeCubicTo(10.684, 4.615, 19.029, 7.374, 25.535, 9.437);
    p.relativeCubicTo(10.727, 3.412, 20.49, 2.931, 28.208, 1.779);
    p.relativeCubicTo(8.604, -1.289, 26.498, -10.838, 30.228, -21.298);
    p.relativeCubicTo(3.73, -10.46, 3.73, -19.433, 2.613, -21.298);
    p.relativeCubicTo(-1.117, -1.865, -4.108, -2.991, -8.586, -5.234);
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Scale from 360x362 viewBox into current size
    final scale = size.width / 360.0;
    canvas.scale(scale, scale);

    // 1. Draw speech bubble with smooth gradient or solid color
    final bubblePaint = Paint()
      ..color = bubbleColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(_bubblePath, bubblePaint);

    // 2. Draw white telephone handset inside
    final handsetPaint = Paint()
      ..color = handsetColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(_handsetPath, handsetPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WhatsAppLogoPainter oldDelegate) =>
      oldDelegate.bubbleColor != bubbleColor || oldDelegate.handsetColor != handsetColor;
}

/// Official WhatsApp branded logo widget.
class WhatsAppLogoWidget extends StatelessWidget {
  final double size;
  const WhatsAppLogoWidget({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle glow shadow behind bubble
          Container(
            width: size * 0.88,
            height: size * 0.88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25D366).withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: Size(size, size * (362 / 360)),
            painter: const WhatsAppLogoPainter(
              bubbleColor: Color(0xFF25D366),
              handsetColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Official X (Twitter) vector painter using official brand coordinates.
class XLogoPainter extends CustomPainter {
  final Color color;
  const XLogoPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    final sx = w / 24.0;
    final sy = h / 24.0;

    final path = Path();
    path.moveTo(18.244 * sx, 2.25 * sy);
    path.lineTo(21.552 * sx, 2.25 * sy);
    path.lineTo(14.325 * sx, 10.51 * sy);
    path.lineTo(22.827 * sx, 21.75 * sy);
    path.lineTo(16.17 * sx, 21.75 * sy);
    path.lineTo(10.956 * sx, 14.933 * sy);
    path.lineTo(4.99 * sx, 21.75 * sy);
    path.lineTo(1.68 * sx, 21.75 * sy);
    path.lineTo(9.41 * sx, 12.915 * sy);
    path.lineTo(1.254 * sx, 2.25 * sy);
    path.lineTo(8.08 * sx, 2.25 * sy);
    path.lineTo(12.793 * sx, 8.481 * sy);
    path.close();

    final cutout = Path();
    cutout.moveTo(17.083 * sx, 19.77 * sy);
    cutout.lineTo(18.916 * sx, 19.77 * sy);
    cutout.lineTo(7.084 * sx, 4.126 * sy);
    cutout.lineTo(5.117 * sx, 4.126 * sy);
    cutout.close();

    final finalPath = Path.combine(PathOperation.difference, path, cutout);
    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant XLogoPainter oldDelegate) => oldDelegate.color != color;
}

/// Official X branded logo widget.
class XLogoWidget extends StatelessWidget {
  final double size;
  final bool isDark;
  const XLogoWidget({super.key, this.size = 28, this.isDark = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181C) : Colors.black,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.52, size * 0.52),
          painter: const XLogoPainter(color: Colors.white),
        ),
      ),
    );
  }
}
