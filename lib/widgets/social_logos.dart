import 'package:flutter/material.dart';

/// Accurate vector painter for official Instagram camera logo.
class InstagramLogoPainter extends CustomPainter {
  final Color color;
  const InstagramLogoPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.088
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final r = size.width * 0.27;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.8, size.height * 0.8),
      Radius.circular(size.width * 0.24),
    );

    // Outer rounded square body
    canvas.drawRRect(rect, strokePaint);
    // Center camera lens
    canvas.drawCircle(center, r, strokePaint);
    // Flash dot
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.28),
      size.width * 0.052,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant InstagramLogoPainter oldDelegate) => oldDelegate.color != color;
}

/// Official Instagram branded logo widget with authentic gradient background.
class InstagramLogoWidget extends StatelessWidget {
  final double size;
  const InstagramLogoWidget({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const RadialGradient(
          center: Alignment(-0.8, 0.9),
          radius: 1.25,
          colors: [
            Color(0xFFFFDF9E), // Yellow highlight
            Color(0xFFFFC272),
            Color(0xFFFF385C), // Red-orange
            Color(0xFFE02D69), // Pink
            Color(0xFFD300C5), // Magenta
            Color(0xFF7638FA), // Violet
          ],
          stops: [0.0, 0.15, 0.45, 0.6, 0.78, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE02D69).withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.65, size * 0.65),
          painter: const InstagramLogoPainter(color: Colors.white),
        ),
      ),
    );
  }
}

/// Accurate vector painter for official X (formerly Twitter) logo.
/// Uses the exact mathematical vector path from X brand guidelines.
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

    // Viewbox 24x24 scale factors
    final sx = w / 24.0;
    final sy = h / 24.0;

    // Outer polygon
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

    // Inner cutout polygon
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
