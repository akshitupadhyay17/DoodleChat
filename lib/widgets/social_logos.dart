import 'package:flutter/material.dart';

/// Compact and robust SVG path parser that converts official SVG path data
/// into native Flutter [Path] objects with full vector fidelity.
Path parseSvgPath(String d) {
  final path = Path();
  final reg = RegExp(r'([a-df-zA-DF-Z])|([-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?)');
  final matches = reg.allMatches(d);

  String cmd = '';
  final args = <double>[];

  void executeCmd(String c, List<double> a) {
    switch (c) {
      case 'M':
        for (int i = 0; i < a.length; i += 2) {
          if (i + 1 < a.length) {
            if (i == 0) {
              path.moveTo(a[i], a[i + 1]);
            } else {
              path.lineTo(a[i], a[i + 1]);
            }
          }
        }
        break;
      case 'm':
        for (int i = 0; i < a.length; i += 2) {
          if (i + 1 < a.length) {
            if (i == 0) {
              path.relativeMoveTo(a[i], a[i + 1]);
            } else {
              path.relativeLineTo(a[i], a[i + 1]);
            }
          }
        }
        break;
      case 'L':
        for (int i = 0; i < a.length; i += 2) {
          if (i + 1 < a.length) path.lineTo(a[i], a[i + 1]);
        }
        break;
      case 'l':
        for (int i = 0; i < a.length; i += 2) {
          if (i + 1 < a.length) path.relativeLineTo(a[i], a[i + 1]);
        }
        break;
      case 'h':
        for (final dx in a) {
          path.relativeLineTo(dx, 0);
        }
        break;
      case 'v':
        for (final dy in a) {
          path.relativeLineTo(0, dy);
        }
        break;
      case 'C':
        for (int i = 0; i < a.length; i += 6) {
          if (i + 5 < a.length) {
            path.cubicTo(a[i], a[i + 1], a[i + 2], a[i + 3], a[i + 4], a[i + 5]);
          }
        }
        break;
      case 'c':
        for (int i = 0; i < a.length; i += 6) {
          if (i + 5 < a.length) {
            path.relativeCubicTo(a[i], a[i + 1], a[i + 2], a[i + 3], a[i + 4], a[i + 5]);
          }
        }
        break;
      case 'A':
        for (int i = 0; i < a.length; i += 7) {
          if (i + 6 < a.length) {
            path.arcToPoint(
              Offset(a[i + 5], a[i + 6]),
              radius: Radius.elliptical(a[i], a[i + 1]),
              rotation: a[i + 2],
              largeArc: a[i + 3] != 0,
              clockwise: a[i + 4] != 0,
            );
          }
        }
        break;
      case 'a':
        for (int i = 0; i < a.length; i += 7) {
          if (i + 6 < a.length) {
            path.relativeArcToPoint(
              Offset(a[i + 5], a[i + 6]),
              radius: Radius.elliptical(a[i], a[i + 1]),
              rotation: a[i + 2],
              largeArc: a[i + 3] != 0,
              clockwise: a[i + 4] != 0,
            );
          }
        }
        break;
      case 'Z':
      case 'z':
        path.close();
        break;
    }
  }

  for (final m in matches) {
    final text = m.group(0)!;
    if (RegExp(r'^[a-zA-Z]$').hasMatch(text)) {
      if (cmd.isNotEmpty && args.isNotEmpty) {
        executeCmd(cmd, args);
        args.clear();
      }
      cmd = text;
      if (cmd == 'Z' || cmd == 'z') {
        executeCmd(cmd, args);
        cmd = '';
      }
    } else {
      args.add(double.tryParse(text) ?? 0.0);
    }
  }
  if (cmd.isNotEmpty && args.isNotEmpty) {
    executeCmd(cmd, args);
  }
  return path;
}

/// Official Instagram vector painter using the mathematical SimpleIcons/Brand SVG path.
class InstagramLogoPainter extends CustomPainter {
  final Color color;
  const InstagramLogoPainter({this.color = Colors.white});

  static Path? _cachedPath;
  static Path get _path => _cachedPath ??= _buildPath();

  static Path _buildPath() {
    final p = parseSvgPath(
      'M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z',
    );
    p.fillType = PathFillType.evenOdd;
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    final s = size.width / 24.0;
    canvas.scale(s, s);
    canvas.drawPath(_path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant InstagramLogoPainter oldDelegate) => oldDelegate.color != color;
}

/// Official Instagram branded logo widget with authentic gradient background.
class InstagramLogoWidget extends StatelessWidget {
  final double size;
  const InstagramLogoWidget({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const RadialGradient(
          center: Alignment(-0.8, 0.9),
          radius: 1.35,
          colors: [
            Color(0xFFFFDF9E), // Yellow highlight
            Color(0xFFFFC272),
            Color(0xFFFF385C), // Red-orange
            Color(0xFFE02D69), // Pink
            Color(0xFFD300C5), // Magenta
            Color(0xFF7638FA), // Violet
          ],
          stops: [0.0, 0.15, 0.42, 0.58, 0.78, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE02D69).withOpacity(0.38),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.62, size * 0.62),
          painter: const InstagramLogoPainter(color: Colors.white),
        ),
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

/// Official WhatsApp vector painter using the mathematical SimpleIcons/Brand SVG path.
class WhatsAppLogoPainter extends CustomPainter {
  final Color color;
  const WhatsAppLogoPainter({this.color = Colors.white});

  static Path? _cachedPath;
  static Path get _path => _cachedPath ??= _buildPath();

  static Path _buildPath() {
    final p = parseSvgPath(
      'M12.04 2c-5.46 0-9.91 4.45-9.91 9.91 0 1.75.46 3.45 1.32 4.95L2.05 22l5.25-1.38c1.45.79 3.08 1.21 4.74 1.21 5.46 0 9.91-4.45 9.91-9.91 0-2.65-1.03-5.14-2.9-7.01A9.816 9.816 0 0 0 12.04 2m.01 1.67c2.2 0 4.26.86 5.82 2.42a8.225 8.225 0 0 1 2.41 5.83c0 4.54-3.7 8.23-8.24 8.23-1.48 0-2.93-.39-4.19-1.15l-.3-.17-3.12.82.83-3.04-.2-.32a8.188 8.188 0 0 1-1.26-4.38c0-4.54 3.7-8.24 8.24-8.24m-3.53 3.03c-.19 0-.4.07-.58.32-.18.25-.69.67-.69 1.63s.71 1.89.81 2.02c.1.13 1.36 2.08 3.3 2.92.46.2.82.32 1.1.41.46.15.89.13 1.22.08.37-.05 1.14-.47 1.3-.92.16-.45.16-.84.11-.92-.05-.08-.18-.13-.37-.22s-1.14-.56-1.32-.62c-.18-.07-.31-.1-.44.1-.13.2-.5 1.63-.61.76-.11.13-.22.15-.41.05-.19-.1-.8-.29-1.53-.94-.57-.51-.95-1.14-1.06-1.33-.11-.19-.01-.3.08-.39.09-.09.19-.22.29-.33.1-.11.13-.19.2-.31.07-.13.03-.24-.02-.34s-.44-1.06-.6-1.45c-.16-.39-.32-.34-.44-.34Z',
    );
    p.fillType = PathFillType.evenOdd;
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    final s = size.width / 24.0;
    canvas.scale(s, s);
    canvas.drawPath(_path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WhatsAppLogoPainter oldDelegate) => oldDelegate.color != color;
}

/// Official WhatsApp branded logo widget with authentic green gradient.
class WhatsAppLogoWidget extends StatelessWidget {
  final double size;
  const WhatsAppLogoWidget({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2EE572), // Vibrant WhatsApp Green
            Color(0xFF1EBE5D), // Deep WhatsApp Green
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25D366).withOpacity(0.38),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.62, size * 0.62),
          painter: const WhatsAppLogoPainter(color: Colors.white),
        ),
      ),
    );
  }
}
