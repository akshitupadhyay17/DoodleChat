import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/doodle_stroke.dart';

/// Renders emojis as vibrant hand-drawn cartoon doodles directly on the canvas,
/// completely background-less (transparent, with no white badge or backing).
class CartoonEmojiRenderer {
  CartoonEmojiRenderer._();

  /// Normalizes emoji string by removing zero-width joiners and variant selectors.
  static String normalize(String emoji) {
    return emoji.replaceAll('\uFE0F', '').replaceAll('\uFE0E', '').trim();
  }

  /// Returns true if this emoji has a dedicated hand-drawn cartoon vector illustration.
  static bool hasCustomCartoonVector(String emoji) {
    final n = normalize(emoji);
    switch (n) {
      case '⚡':
      case '🔥':
      case '💖':
      case '❤️':
      case '⭐':
      case '🌟':
      case '✨':
      case '😂':
      case '🤣':
      case '😆':
      case '😹':
      case '👑':
      case '🎉':
      case '💯':
      case '🌸':
      case '🖤':
      case '🚀':
        return true;
      default:
        return false;
    }
  }

  /// Paints the emoji on the canvas with cartoon styling (background-less).
  static void paint(Canvas canvas, DoodleEmojiItem item, {Color? brushColor}) {
    canvas.save();

    final cx = item.position.dx + item.size / 2;
    final cy = item.position.dy + item.size / 2;
    canvas.translate(cx, cy);

    // Apply hand-drawn organic tilt if specified
    if (item.rotation != 0) {
      canvas.rotate(item.rotation);
    }

    final s = item.size;
    final half = s / 2;
    final rect = Rect.fromLTWH(-half, -half, s, s);

    final norm = normalize(item.emoji);
    final isCustom = hasCustomCartoonVector(norm);

    if (isCustom) {
      _paintCustomCartoonVector(canvas, norm, rect, s);
    } else {
      _paintUniversalComicEmoji(canvas, item, rect, s);
    }

    canvas.restore();
  }

  // ──────────────────────── Custom Vector Cartoons (No White Backing) ────────────────────────

  static void _paintCustomCartoonVector(Canvas canvas, String emoji, Rect r, double size) {
    final strokeW = (size * 0.055).clamp(2.5, 6.0);
    final inkPaint = Paint()
      ..color = const Color(0xFF16161E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final shadowOffset = Offset(size * 0.04, size * 0.05);

    switch (emoji) {
      case '⚡':
        _paintLightningBolt(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      case '💖':
      case '❤️':
        _paintCartoonHeart(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      case '🔥':
        _paintCartoonFlame(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      case '⭐':
      case '🌟':
        _paintCartoonStar(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      case '✨':
        _paintCartoonSparkles(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      case '😂':
      case '🤣':
      case '😆':
      case '😹':
        _paintCartoonLaugh(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      case '👑':
        _paintCartoonCrown(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      case '🎉':
        _paintCartoonPopper(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      case '💯':
        _paintCartoonHundred(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      case '🌸':
        _paintCartoonFlower(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      case '🖤':
        _paintCartoonBlackHeart(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      case '🚀':
        _paintCartoonRocket(canvas, r, size, inkPaint, shadowPaint, shadowOffset);
        break;
      default:
        break;
    }
  }

  // 1. ⚡ Cartoon Lightning Bolt (Pure transparent background)
  static void _paintLightningBolt(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    Offset p(double x, double y) => Offset(r.left + x * s, r.top + y * s);

    final path = Path()
      ..moveTo(p(0.55, 0.05).dx, p(0.55, 0.05).dy)
      ..lineTo(p(0.20, 0.52).dx, p(0.20, 0.52).dy)
      ..lineTo(p(0.48, 0.52).dx, p(0.48, 0.52).dy)
      ..lineTo(p(0.35, 0.95).dx, p(0.35, 0.95).dy)
      ..lineTo(p(0.82, 0.44).dx, p(0.82, 0.44).dy)
      ..lineTo(p(0.52, 0.44).dx, p(0.52, 0.44).dy)
      ..close();

    // Soft drop shadow
    canvas.drawPath(path.shift(shOff), shadow);

    // Bright electric yellow fill
    final yellowFill = Paint()
      ..color = const Color(0xFFFFD600)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, yellowFill);

    // Specular shine streak
    final shinePath = Path()
      ..moveTo(p(0.52, 0.15).dx, p(0.52, 0.15).dy)
      ..lineTo(p(0.28, 0.48).dx, p(0.28, 0.48).dy);
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(shinePath, shinePaint);

    // Bold comic ink outline
    canvas.drawPath(path, ink);

    // Sketched comic action sparks around it
    _drawSparkLines(canvas, [p(0.12, 0.38), p(0.88, 0.35), p(0.85, 0.65)], s * 0.12, ink);
  }

  // 2. 💖 Cute Cartoon Heart (No white backing)
  static void _paintCartoonHeart(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    final path = Path();
    final top = r.top + s * 0.15;
    final bottom = r.top + s * 0.88;
    final left = r.left + s * 0.08;
    final right = r.left + s * 0.92;
    final midX = r.left + s * 0.50;

    path.moveTo(midX, bottom);
    path.cubicTo(left, bottom - s * 0.35, left, top, midX, top + s * 0.22);
    path.cubicTo(right, top, right, bottom - s * 0.35, midX, bottom);
    path.close();

    // Soft drop shadow
    canvas.drawPath(path.shift(shOff), shadow);

    // Luscious candy hot pink fill
    canvas.drawPath(path, Paint()..color = const Color(0xFFFF2A6D));

    // Specular highlight crescent
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromLTWH(r.left + s * 0.18, r.top + s * 0.22, s * 0.18, s * 0.32),
      Paint()..color = Colors.white.withOpacity(0.65),
    );
    canvas.restore();

    // Comic ink outline
    canvas.drawPath(path, ink);

    // Cute sparkle doodle
    _drawDoodleSparkle(canvas, Offset(r.left + s * 0.82, r.top + s * 0.18), s * 0.12, ink);
  }

  // 3. 🔥 Cartoon Flame (No white backing)
  static void _paintCartoonFlame(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    Offset p(double x, double y) => Offset(r.left + x * s, r.top + y * s);

    final outer = Path()
      ..moveTo(p(0.50, 0.92).dx, p(0.50, 0.92).dy)
      ..cubicTo(p(0.15, 0.88).dx, p(0.15, 0.88).dy, p(0.12, 0.55).dx, p(0.12, 0.55).dy, p(0.35, 0.35).dx, p(0.35, 0.35).dy)
      ..cubicTo(p(0.30, 0.42).dx, p(0.30, 0.42).dy, p(0.32, 0.48).dx, p(0.32, 0.48).dy, p(0.40, 0.45).dx, p(0.40, 0.45).dy)
      ..cubicTo(p(0.38, 0.22).dx, p(0.38, 0.22).dy, p(0.48, 0.06).dx, p(0.48, 0.06).dy, p(0.52, 0.06).dx, p(0.52, 0.06).dy)
      ..cubicTo(p(0.60, 0.25).dx, p(0.60, 0.25).dy, p(0.68, 0.35).dx, p(0.68, 0.35).dy, p(0.62, 0.46).dx, p(0.62, 0.46).dy)
      ..cubicTo(p(0.72, 0.40).dx, p(0.72, 0.40).dy, p(0.88, 0.58).dx, p(0.88, 0.58).dy, p(0.85, 0.78).dx, p(0.85, 0.78).dy)
      ..cubicTo(p(0.80, 0.92).dx, p(0.80, 0.92).dy, p(0.55, 0.92).dx, p(0.55, 0.92).dy, p(0.50, 0.92).dx, p(0.50, 0.92).dy)
      ..close();

    final inner = Path()
      ..moveTo(p(0.50, 0.86).dx, p(0.50, 0.86).dy)
      ..cubicTo(p(0.32, 0.84).dx, p(0.32, 0.84).dy, p(0.32, 0.62).dx, p(0.32, 0.62).dy, p(0.50, 0.40).dx, p(0.50, 0.40).dy)
      ..cubicTo(p(0.68, 0.62).dx, p(0.68, 0.62).dy, p(0.68, 0.84).dx, p(0.68, 0.84).dy, p(0.50, 0.86).dx, p(0.50, 0.86).dy)
      ..close();

    // Soft drop shadow
    canvas.drawPath(outer.shift(shOff), shadow);

    // Outer flame fill (vivid red-orange)
    canvas.drawPath(outer, Paint()..color = const Color(0xFFFF4800));
    canvas.drawPath(outer, ink);

    // Inner flame fill (bright sunny gold)
    canvas.drawPath(inner, Paint()..color = const Color(0xFFFFD000));
    canvas.drawPath(inner, ink);

    // Flying cartoon sparks
    canvas.drawCircle(p(0.48, 0.02), s * 0.035, Paint()..color = const Color(0xFFFF8800));
    canvas.drawCircle(p(0.48, 0.02), s * 0.035, ink);
  }

  // 4. ⭐ Cartoon Star with smiling doodle face (No white backing)
  static void _paintCartoonStar(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    final cx = r.left + s * 0.5;
    final cy = r.top + s * 0.52;
    final rOuter = s * 0.44;
    final rInner = s * 0.22;
    const points = 5;

    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final rad = (i * math.pi / points) - math.pi / 2;
      final dist = (i % 2 == 0) ? rOuter : rInner;
      final pt = Offset(cx + math.cos(rad) * dist, cy + math.sin(rad) * dist);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();

    // Soft drop shadow
    canvas.drawPath(path.shift(shOff), shadow);

    // Golden yellow fill
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFC700));
    canvas.drawPath(path, ink);

    // Cute smiling face in the star!
    final eyePaint = Paint()
      ..color = const Color(0xFF14141E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - s * 0.11, cy - s * 0.02), s * 0.045, eyePaint);
    canvas.drawCircle(Offset(cx + s * 0.11, cy - s * 0.02), s * 0.045, eyePaint);

    // Specular eye catchlights
    canvas.drawCircle(Offset(cx - s * 0.12, cy - s * 0.035), s * 0.015, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + s * 0.10, cy - s * 0.035), s * 0.015, Paint()..color = Colors.white);

    // Happy open cartoon smile
    final mouthPath = Path()
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy + s * 0.02), radius: s * 0.08),
        0.2,
        math.pi - 0.4,
        false,
      );
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = const Color(0xFF14141E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.035
        ..strokeCap = StrokeCap.round,
    );

    // Rosy doodle blush circles
    final blushPaint = Paint()..color = const Color(0xFFFF6B81).withOpacity(0.5);
    canvas.drawCircle(Offset(cx - s * 0.18, cy + s * 0.05), s * 0.04, blushPaint);
    canvas.drawCircle(Offset(cx + s * 0.18, cy + s * 0.05), s * 0.04, blushPaint);
  }

  // 5. ✨ Cartoon Sparkle Diamonds (No white backing)
  static void _paintCartoonSparkles(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    void drawDiamond(Offset center, double radius, Color color) {
      final p = Path();
      p.moveTo(center.dx, center.dy - radius);
      p.quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy);
      p.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius);
      p.quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy);
      p.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius);
      p.close();

      canvas.drawPath(p.shift(shOff), shadow);
      canvas.drawPath(p, Paint()..color = color);
      canvas.drawPath(p, ink);
    }

    // Main diamond
    drawDiamond(Offset(r.left + s * 0.42, r.top + s * 0.48), s * 0.36, const Color(0xFFFFD600));
    // Top right secondary diamond
    drawDiamond(Offset(r.left + s * 0.78, r.top + s * 0.22), s * 0.18, const Color(0xFF00E5FF));
    // Small sparkle dot
    canvas.drawCircle(Offset(r.left + s * 0.76, r.top + s * 0.78), s * 0.05, Paint()..color = const Color(0xFFFF4081));
    canvas.drawCircle(Offset(r.left + s * 0.76, r.top + s * 0.78), s * 0.05, ink);
  }

  // 6. 😂 / 🤣 Custom Cartoon Laughing Emoji Face (No white background)
  static void _paintCartoonLaugh(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    final cx = r.left + s * 0.5;
    final cy = r.top + s * 0.5;
    final radius = s * 0.42;

    // Soft drop shadow
    canvas.drawCircle(Offset(cx + shOff.dx, cy + shOff.dy), radius, shadow);

    // Vibrant round yellow head fill
    canvas.drawCircle(Offset(cx, cy), radius, Paint()..color = const Color(0xFFFFD200));
    canvas.drawCircle(Offset(cx, cy), radius, ink);

    // Arched laughing closed squint eyes (^ ^)
    final eyePaint = Paint()
      ..color = const Color(0xFF14141E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round;

    final leftEye = Path()
      ..arcTo(
        Rect.fromCircle(center: Offset(cx - s * 0.16, cy - s * 0.05), radius: s * 0.09),
        math.pi + 0.3,
        math.pi - 0.6,
        false,
      );
    final rightEye = Path()
      ..arcTo(
        Rect.fromCircle(center: Offset(cx + s * 0.16, cy - s * 0.05), radius: s * 0.09),
        math.pi + 0.3,
        math.pi - 0.6,
        false,
      );
    canvas.drawPath(leftEye, eyePaint);
    canvas.drawPath(rightEye, eyePaint);

    // Eyebrows raised in laughing joy
    final browPaint = Paint()
      ..color = const Color(0xFF14141E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.04
      ..strokeCap = StrokeCap.round;
    final leftBrow = Path()
      ..moveTo(cx - s * 0.24, cy - s * 0.16)
      ..quadraticBezierTo(cx - s * 0.16, cy - s * 0.22, cx - s * 0.08, cy - s * 0.18);
    final rightBrow = Path()
      ..moveTo(cx + s * 0.08, cy - s * 0.18)
      ..quadraticBezierTo(cx + s * 0.16, cy - s * 0.22, cx + s * 0.24, cy - s * 0.16);
    canvas.drawPath(leftBrow, browPaint);
    canvas.drawPath(rightBrow, browPaint);

    // Big laughing open mouth
    final mouth = Path()
      ..moveTo(cx - s * 0.24, cy + s * 0.06)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy + s * 0.06), radius: s * 0.24),
        0.05,
        math.pi - 0.1,
        false,
      )
      ..close();
    canvas.drawPath(mouth, Paint()..color = const Color(0xFF6B1212));

    // Pink tongue and upper teeth inside mouth
    canvas.save();
    canvas.clipPath(mouth);
    // Upper teeth strip
    canvas.drawRect(Rect.fromLTWH(cx - s * 0.20, cy + s * 0.06, s * 0.40, s * 0.06), Paint()..color = Colors.white);
    // Cute pink tongue
    canvas.drawCircle(Offset(cx, cy + s * 0.24), s * 0.13, Paint()..color = const Color(0xFFFF5252));
    canvas.restore();

    canvas.drawPath(mouth, ink);

    // Blue comic tears splashing sideways!
    void drawTear(Offset pos, double angle) {
      final tPath = Path();
      tPath.moveTo(pos.dx, pos.dy - s * 0.09);
      tPath.quadraticBezierTo(pos.dx - s * 0.07, pos.dy, pos.dx, pos.dy + s * 0.07);
      tPath.quadraticBezierTo(pos.dx + s * 0.07, pos.dy, pos.dx, pos.dy - s * 0.09);
      tPath.close();

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      canvas.translate(-pos.dx, -pos.dy);
      canvas.drawPath(tPath, Paint()..color = const Color(0xFF00B0FF));
      canvas.drawPath(tPath, ink);
      // Tear reflection
      canvas.drawCircle(Offset(pos.dx - s * 0.02, pos.dy), s * 0.015, Paint()..color = Colors.white);
      canvas.restore();
    }

    drawTear(Offset(cx - s * 0.38, cy + s * 0.02), -0.7);
    drawTear(Offset(cx + s * 0.38, cy + s * 0.02), 0.7);
  }

  // 7. 👑 Cartoon Gold Crown (No white backing)
  static void _paintCartoonCrown(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    Offset p(double x, double y) => Offset(r.left + x * s, r.top + y * s);

    final path = Path()
      ..moveTo(p(0.12, 0.78).dx, p(0.12, 0.78).dy)
      ..lineTo(p(0.10, 0.36).dx, p(0.10, 0.36).dy)
      ..lineTo(p(0.32, 0.54).dx, p(0.32, 0.54).dy)
      ..lineTo(p(0.50, 0.22).dx, p(0.50, 0.22).dy)
      ..lineTo(p(0.68, 0.54).dx, p(0.68, 0.54).dy)
      ..lineTo(p(0.90, 0.36).dx, p(0.90, 0.36).dy)
      ..lineTo(p(0.88, 0.78).dx, p(0.88, 0.78).dy)
      ..close();

    // Soft drop shadow
    canvas.drawPath(path.shift(shOff), shadow);

    // Gold fill
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFB300));
    canvas.drawPath(path, ink);

    // Pearls on crown points
    final pearlPaint = Paint()..color = Colors.white;
    canvas.drawCircle(p(0.10, 0.35), s * 0.05, pearlPaint);
    canvas.drawCircle(p(0.10, 0.35), s * 0.05, ink);

    canvas.drawCircle(p(0.50, 0.20), s * 0.065, Paint()..color = const Color(0xFFFF1744));
    canvas.drawCircle(p(0.50, 0.20), s * 0.065, ink);

    canvas.drawCircle(p(0.90, 0.35), s * 0.05, pearlPaint);
    canvas.drawCircle(p(0.90, 0.35), s * 0.05, ink);

    // Jewel band along bottom
    canvas.drawCircle(p(0.32, 0.70), s * 0.04, Paint()..color = const Color(0xFF00E5FF));
    canvas.drawCircle(p(0.32, 0.70), s * 0.04, ink);

    canvas.drawCircle(p(0.50, 0.70), s * 0.045, Paint()..color = const Color(0xFFFF1744));
    canvas.drawCircle(p(0.50, 0.70), s * 0.045, ink);

    canvas.drawCircle(p(0.68, 0.70), s * 0.04, Paint()..color = const Color(0xFF00E676));
    canvas.drawCircle(p(0.68, 0.70), s * 0.04, ink);
  }

  // 8. 🎉 Cartoon Party Popper (No white backing)
  static void _paintCartoonPopper(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    Offset p(double x, double y) => Offset(r.left + x * s, r.top + y * s);

    // Popper cone tilted from bottom-left to center
    final cone = Path()
      ..moveTo(p(0.20, 0.88).dx, p(0.20, 0.88).dy)
      ..lineTo(p(0.18, 0.62).dx, p(0.18, 0.62).dy)
      ..lineTo(p(0.48, 0.45).dx, p(0.48, 0.45).dy)
      ..lineTo(p(0.58, 0.75).dx, p(0.58, 0.75).dy)
      ..close();

    canvas.drawPath(cone.shift(shOff), shadow);

    // Cone stripes fill
    canvas.drawPath(cone, Paint()..color = const Color(0xFF7C4DFF));
    canvas.drawPath(cone, ink);

    // Burst streamers & confetti
    void drawStreamer(Path path, Color col) {
      canvas.drawPath(
        path,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.045
          ..strokeCap = StrokeCap.round,
      );
    }

    final ribbon1 = Path()
      ..moveTo(p(0.52, 0.52).dx, p(0.52, 0.52).dy)
      ..cubicTo(p(0.65, 0.35).dx, p(0.65, 0.35).dy, p(0.60, 0.18).dx, p(0.60, 0.18).dy, p(0.75, 0.10).dx, p(0.75, 0.10).dy);
    drawStreamer(ribbon1, const Color(0xFFFF007F));

    final ribbon2 = Path()
      ..moveTo(p(0.48, 0.46).dx, p(0.48, 0.46).dy)
      ..cubicTo(p(0.70, 0.48).dx, p(0.70, 0.48).dy, p(0.80, 0.35).dx, p(0.80, 0.35).dy, p(0.92, 0.38).dx, p(0.92, 0.38).dy);
    drawStreamer(ribbon2, const Color(0xFF00E5FF));

    // Confetti dots & stars
    canvas.drawCircle(p(0.58, 0.32), s * 0.035, Paint()..color = const Color(0xFFFFD600));
    canvas.drawCircle(p(0.85, 0.22), s * 0.04, Paint()..color = const Color(0xFFFF1744));
    canvas.drawCircle(p(0.70, 0.60), s * 0.03, Paint()..color = const Color(0xFF00E676));
    _drawDoodleSparkle(canvas, p(0.82, 0.52), s * 0.08, ink);
  }

  // 9. 💯 Cartoon 100 with double comic underline (Transparent background)
  static void _paintCartoonHundred(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    final tp = TextPainter(
      text: TextSpan(
        text: '100',
        style: TextStyle(
          fontSize: s * 0.62,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFE50914),
          fontStyle: FontStyle.italic,
          letterSpacing: -2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textPos = Offset(r.left + (s - tp.width) / 2, r.top + s * 0.08);

    tp.paint(canvas, textPos);

    // Double comic red underline
    final under1 = Path()
      ..moveTo(r.left + s * 0.08, r.top + s * 0.72)
      ..lineTo(r.left + s * 0.92, r.top + s * 0.72);
    final under2 = Path()
      ..moveTo(r.left + s * 0.14, r.top + s * 0.82)
      ..lineTo(r.left + s * 0.86, r.top + s * 0.82);

    final linePaint = Paint()
      ..color = const Color(0xFFE50914)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(under1, linePaint);
    canvas.drawPath(under2, linePaint);
  }

  // 10. 🌸 Cartoon Blossom Flower (No white backing)
  static void _paintCartoonFlower(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    final cx = r.left + s * 0.5;
    final cy = r.top + s * 0.5;
    const petals = 5;
    final petalDist = s * 0.22;
    final petalRad = s * 0.18;

    final flowerPath = Path();
    for (int i = 0; i < petals; i++) {
      final a = (i * 2 * math.pi / petals) - math.pi / 2;
      flowerPath.addOval(Rect.fromCircle(center: Offset(cx + math.cos(a) * petalDist, cy + math.sin(a) * petalDist), radius: petalRad));
    }
    flowerPath.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: s * 0.18));

    // Soft drop shadow
    canvas.drawPath(flowerPath.shift(shOff), shadow);

    // Pink petals
    for (int i = 0; i < petals; i++) {
      final a = (i * 2 * math.pi / petals) - math.pi / 2;
      final center = Offset(cx + math.cos(a) * petalDist, cy + math.sin(a) * petalDist);
      canvas.drawCircle(center, petalRad, Paint()..color = const Color(0xFFFF80AB));
      canvas.drawCircle(center, petalRad, ink);
    }

    // Yellow center core
    canvas.drawCircle(Offset(cx, cy), s * 0.15, Paint()..color = const Color(0xFFFFD600));
    canvas.drawCircle(Offset(cx, cy), s * 0.15, ink);
  }

  // 11. 🖤 Cartoon Black Heart (No white backing)
  static void _paintCartoonBlackHeart(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    final path = Path();
    final top = r.top + s * 0.15;
    final bottom = r.top + s * 0.88;
    final left = r.left + s * 0.08;
    final right = r.left + s * 0.92;
    final midX = r.left + s * 0.50;

    path.moveTo(midX, bottom);
    path.cubicTo(left, bottom - s * 0.35, left, top, midX, top + s * 0.22);
    path.cubicTo(right, top, right, bottom - s * 0.35, midX, bottom);
    path.close();

    // Soft drop shadow
    canvas.drawPath(path.shift(shOff), shadow);

    // Charcoal black fill
    canvas.drawPath(path, Paint()..color = const Color(0xFF1E1E24));
    canvas.drawPath(path, ink);

    // White gloss reflection mark
    final hlPath = Path()
      ..moveTo(r.left + s * 0.22, r.top + s * 0.30)
      ..cubicTo(r.left + s * 0.18, r.top + s * 0.45, r.left + s * 0.24, r.top + s * 0.55, r.left + s * 0.28, r.top + s * 0.60);
    canvas.drawPath(
      hlPath,
      Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  // 12. 🚀 Cartoon Retro Rocket (No white backing)
  static void _paintCartoonRocket(Canvas canvas, Rect r, double s, Paint ink, Paint shadow, Offset shOff) {
    Offset p(double x, double y) => Offset(r.left + x * s, r.top + y * s);

    // Exhaust jet flame
    final flame = Path()
      ..moveTo(p(0.35, 0.65).dx, p(0.35, 0.65).dy)
      ..lineTo(p(0.12, 0.92).dx, p(0.12, 0.92).dy)
      ..lineTo(p(0.42, 0.78).dx, p(0.42, 0.78).dy)
      ..lineTo(p(0.25, 0.96).dx, p(0.25, 0.96).dy)
      ..lineTo(p(0.60, 0.72).dx, p(0.60, 0.72).dy)
      ..close();
    canvas.drawPath(flame, Paint()..color = const Color(0xFFFF5722));
    canvas.drawPath(flame, ink);

    // Fuselage
    final body = Path()
      ..moveTo(p(0.85, 0.15).dx, p(0.85, 0.15).dy)
      ..quadraticBezierTo(p(0.70, 0.50).dx, p(0.70, 0.50).dy, p(0.55, 0.75).dx, p(0.55, 0.75).dy)
      ..lineTo(p(0.38, 0.58).dx, p(0.38, 0.58).dy)
      ..quadraticBezierTo(p(0.50, 0.30).dx, p(0.50, 0.30).dy, p(0.85, 0.15).dx, p(0.85, 0.15).dy)
      ..close();

    canvas.drawPath(body.shift(shOff), shadow);
    canvas.drawPath(body, Paint()..color = const Color(0xFFF0F4F8));
    canvas.drawPath(body, ink);

    // Porthole window
    canvas.drawCircle(p(0.62, 0.38), s * 0.08, Paint()..color = const Color(0xFF00E5FF));
    canvas.drawCircle(p(0.62, 0.38), s * 0.08, ink);

    // Red nosecone tip
    final nose = Path()
      ..moveTo(p(0.85, 0.15).dx, p(0.85, 0.15).dy)
      ..lineTo(p(0.74, 0.22).dx, p(0.74, 0.22).dy)
      ..lineTo(p(0.78, 0.32).dx, p(0.78, 0.32).dy)
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFFFF1744));
    canvas.drawPath(nose, ink);
  }

  // ──────────────────────── Universal Comic Emoji (No White Background) ────────────────────────

  /// Renders any emoji cleanly without any white box or badge.
  static void _paintUniversalComicEmoji(Canvas canvas, DoodleEmojiItem item, Rect r, double size) {
    final tp = item.painter;
    final w = tp.width;
    final h = tp.height;

    // Center coordinates for emoji
    final ex = -w / 2;
    final ey = -h / 2;

    // 1. Crisp emoji painted directly on canvas (transparent background)
    tp.paint(canvas, Offset(ex, ey));

    // 2. Sketched comic action accents on corner
    final ink = Paint()
      ..color = const Color(0xFF16161E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size * 0.04).clamp(2.0, 4.5)
      ..strokeCap = StrokeCap.round;

    final corner = Offset(ex + w + size * 0.02, ey - size * 0.02);
    _drawDoodleSparkle(canvas, corner, size * 0.10, ink);
  }

  // ──────────────────────── Sketched Accent Helpers ────────────────────────

  static void _drawDoodleSparkle(Canvas canvas, Offset c, double radius, Paint paint) {
    canvas.drawLine(Offset(c.dx, c.dy - radius), Offset(c.dx, c.dy + radius), paint);
    canvas.drawLine(Offset(c.dx - radius, c.dy), Offset(c.dx + radius, c.dy), paint);
    final mini = radius * 0.55;
    canvas.drawLine(Offset(c.dx - mini, c.dy - mini), Offset(c.dx + mini, c.dy + mini), paint);
    canvas.drawLine(Offset(c.dx + mini, c.dy - mini), Offset(c.dx - mini, c.dy + mini), paint);
  }

  static void _drawSparkLines(Canvas canvas, List<Offset> points, double length, Paint paint) {
    for (final pt in points) {
      canvas.drawLine(pt, pt + Offset(length * 0.6, -length * 0.6), paint);
    }
  }
}

/// A standalone widget to display an emoji as a hand-drawn cartoon sticker.
class CartoonEmojiWidget extends StatelessWidget {
  final String emoji;
  final double size;

  const CartoonEmojiWidget({
    super.key,
    required this.emoji,
    this.size = 36.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CartoonEmojiWidgetPainter(emoji: emoji, size: size),
      ),
    );
  }
}

class _CartoonEmojiWidgetPainter extends CustomPainter {
  final String emoji;
  final double size;

  _CartoonEmojiWidgetPainter({required this.emoji, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final item = DoodleEmojiItem(
      emoji: emoji,
      position: Offset.zero,
      size: size,
      rotation: 0.0,
    );
    CartoonEmojiRenderer.paint(canvas, item);
  }

  @override
  bool shouldRepaint(covariant _CartoonEmojiWidgetPainter oldDelegate) {
    return oldDelegate.emoji != emoji || oldDelegate.size != size;
  }
}
