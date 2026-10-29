import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

/// All doodle geometry lives in a fixed "virtual canvas" that is
/// [kVirtualWidth] units wide, so a doodle looks identical on every phone.
const double kVirtualWidth = 1000.0;

enum DoodleElementType { stroke, text, emoji }

enum DoodleBrushType {
  pen,         // Regular smooth freehand pen
  marker,      // Chisel / bold semi-translucent marker
  neon,        // Glowing neon brush (Instagram signature!)
  highlighter, // Wide translucent layering
}

double _r(double v) => (v * 10).roundToDouble() / 10;

class DoodleStroke {
  List<Offset> points;
  final Color color;

  /// Brush diameter in virtual units.
  final double size;
  final bool isEraser;
  final DoodleBrushType brushType;

  Path? _path;
  double? _length;

  DoodleStroke({
    required this.points,
    required this.color,
    this.size = 10.0,
    this.isEraser = false,
    this.brushType = DoodleBrushType.pen,
  });

  /// Backwards compatible alias.
  double get strokeWidth => size;

  void invalidate() {
    _path = null;
    _length = null;
  }

  /// Cached, smoothed variable-width outline (perfect_freehand).
  Path get path => _path ??= buildFreehandPath(points, size, complete: true, brushType: brushType);

  double get length {
    if (_length != null) return _length!;
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    return _length = total;
  }

  DoodleStroke copyWith({List<Offset>? points, DoodleBrushType? brushType}) {
    return DoodleStroke(
      points: points ?? List.from(this.points),
      color: color,
      size: size,
      isEraser: isEraser,
      brushType: brushType ?? this.brushType,
    );
  }

  Map<String, dynamic> toJson() => {
        'p': [for (final p in points) ...[_r(p.dx), _r(p.dy)]],
        'c': color.toARGB32(),
        's': _r(size),
        if (brushType != DoodleBrushType.pen) 'b': brushType.index,
      };

  factory DoodleStroke.fromJson(Map<String, dynamic> json) {
    final flat = (json['p'] as List<dynamic>? ?? const []);
    final pts = <Offset>[];
    for (int i = 0; i + 1 < flat.length; i += 2) {
      pts.add(Offset((flat[i] as num).toDouble(), (flat[i + 1] as num).toDouble()));
    }
    final bIdx = (json['b'] as num?)?.toInt() ?? 0;
    final bType = (bIdx >= 0 && bIdx < DoodleBrushType.values.length)
        ? DoodleBrushType.values[bIdx]
        : DoodleBrushType.pen;
    return DoodleStroke(
      points: pts,
      color: Color((json['c'] as num?)?.toInt() ?? 0xFFFFC72C),
      size: (json['s'] as num?)?.toDouble() ?? 10.0,
      brushType: bType,
    );
  }
}

/// Smooth variable-width freehand path tailored for each brush type.
Path buildFreehandPath(
  List<Offset> pts,
  double size, {
  bool complete = false,
  DoodleBrushType brushType = DoodleBrushType.pen,
}) {
  final path = Path();
  if (pts.isEmpty) return path;

  double actualSize = size;
  double thinning = 0.0;
  double smoothing = 0.65;
  double streamline = 0.5;
  bool simulatePressure = false;

  switch (brushType) {
    case DoodleBrushType.pen:
      actualSize = size;
      thinning = 0.0;
      smoothing = 0.65;
      streamline = 0.5;
      simulatePressure = false;
      break;
    case DoodleBrushType.marker:
      // Real chisel marker: bold, broad, consistent width with no delicate thinning
      actualSize = size * 1.85;
      thinning = 0.0;
      smoothing = 0.5;
      streamline = 0.4;
      simulatePressure = false;
      break;
    case DoodleBrushType.neon:
      actualSize = size * 1.1;
      thinning = 0.0;
      smoothing = 0.6;
      streamline = 0.5;
      simulatePressure = false;
      break;
    case DoodleBrushType.highlighter:
      actualSize = size * 2.5;
      thinning = 0.0;
      smoothing = 0.5;
      streamline = 0.4;
      simulatePressure = false;
      break;
  }

  if (pts.length == 1) {
    path.addOval(Rect.fromCircle(center: pts.first, radius: actualSize / 2));
    return path;
  }
  final outline = getStroke(
    [for (final p in pts) PointVector(p.dx, p.dy)],
    options: StrokeOptions(
      size: actualSize,
      thinning: thinning,
      smoothing: smoothing,
      streamline: streamline,
      simulatePressure: simulatePressure,
      isComplete: complete,
    ),
  );
  if (outline.length < 2) {
    path.addOval(Rect.fromCircle(center: pts.first, radius: actualSize / 2));
    return path;
  }
  path.moveTo(outline.first.dx, outline.first.dy);
  for (int i = 1; i < outline.length - 1; i++) {
    final p0 = outline[i];
    final p1 = outline[i + 1];
    path.quadraticBezierTo(
      p0.dx,
      p0.dy,
      (p0.dx + p1.dx) / 2,
      (p0.dy + p1.dy) / 2,
    );
  }
  path.close();
  return path;
}

/// Inserts points so spacing never exceeds [maxGap] (keeps eraser accurate).
List<Offset> densify(List<Offset> pts, {double maxGap = 8.0}) {
  if (pts.length < 2) return pts;
  final out = <Offset>[pts.first];
  for (int i = 1; i < pts.length; i++) {
    final a = pts[i - 1];
    final b = pts[i];
    final d = (b - a).distance;
    if (d > maxGap) {
      final steps = (d / maxGap).ceil();
      for (int s = 1; s < steps; s++) {
        out.add(Offset.lerp(a, b, s / steps)!);
      }
    }
    out.add(b);
  }
  return out;
}

TextStyle doodleTextStyle(String fontStyle, double fontSize, Color color) {
  final shadows = [
    Shadow(
      color: Colors.black.withValues(alpha: 0.25),
      offset: const Offset(2, 2),
      blurRadius: 1,
    ),
  ];
  const emojiFallbacks = [
    'Apple Color Emoji',
    'Noto Color Emoji',
    'Segoe UI Emoji',
    'Android Emoji',
    'EmojiSymbols',
    'sans-serif',
  ];
  switch (fontStyle) {
    case 'Gaegu':
      return GoogleFonts.gaegu(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        shadows: shadows,
      ).copyWith(fontFamilyFallback: emojiFallbacks);
    case 'Caveat':
      return GoogleFonts.caveat(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        shadows: shadows,
      ).copyWith(fontFamilyFallback: emojiFallbacks);
    case 'Outfit':
      return GoogleFonts.outfit(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: color,
        shadows: shadows,
      ).copyWith(fontFamilyFallback: emojiFallbacks);
    case 'PlusJakartaSans':
      return GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: color,
        shadows: shadows,
      ).copyWith(fontFamilyFallback: emojiFallbacks);
    case 'Neon':
      return GoogleFonts.outfit(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        shadows: [
          Shadow(color: color, blurRadius: 14),
          Shadow(color: color, blurRadius: 24),
          Shadow(color: color, blurRadius: 32),
        ],
      ).copyWith(fontFamilyFallback: emojiFallbacks);
    default:
      return GoogleFonts.patrickHand(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        shadows: shadows,
      ).copyWith(fontFamilyFallback: emojiFallbacks);
  }
}

class DoodleTextItem {
  String text;
  Offset position;
  Color color;

  /// Font size in virtual units.
  double fontSize;
  String fontStyle; // 'PatrickHand', 'Caveat', 'Gaegu', 'Outfit', 'PlusJakartaSans', 'Neon'
  bool hasBackground; // Instagram stories text pill style!

  TextPainter? _painter;

  DoodleTextItem({
    required this.text,
    required this.position,
    required this.color,
    this.fontSize = 64.0,
    this.fontStyle = 'PatrickHand',
    this.hasBackground = false,
  });

  /// Cached layout, so we never lay text out inside paint().
  TextPainter get painter {
    if (_painter != null) return _painter!;
    final textColor = hasBackground
        ? (color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
        : color;
    final tp = TextPainter(
      text: TextSpan(text: text, style: doodleTextStyle(fontStyle, fontSize, textColor)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(120, kVirtualWidth - position.dx - 24));
    return _painter = tp;
  }

  /// Re-lay out once fonts finish loading.
  void invalidate() => _painter = null;

  Rect get rect => (position & painter.size).inflate(14);

  Map<String, dynamic> toJson() => {
        't': text,
        'x': _r(position.dx),
        'y': _r(position.dy),
        'c': color.toARGB32(),
        'f': _r(fontSize),
        'k': fontStyle,
        if (hasBackground) 'bg': 1,
      };

  factory DoodleTextItem.fromJson(Map<String, dynamic> j) => DoodleTextItem(
        text: j['t']?.toString() ?? '',
        position: Offset((j['x'] as num? ?? 50).toDouble(), (j['y'] as num? ?? 400).toDouble()),
        color: Color((j['c'] as num?)?.toInt() ?? 0xFF00CEC9),
        fontSize: (j['f'] as num? ?? 64).toDouble(),
        fontStyle: j['k']?.toString() ?? 'PatrickHand',
        hasBackground: (j['bg'] as num?) == 1,
      );
}

/// Generates smooth geometric outline points for Canva shapes!
List<Offset> generateShapePoints(String shape, Offset center, double radius) {
  final pts = <Offset>[];
  switch (shape.toLowerCase()) {
    case 'circle':
      const count = 36;
      for (int i = 0; i <= count; i++) {
        final a = (i / count) * 2 * math.pi;
        pts.add(center + Offset(math.cos(a) * radius, math.sin(a) * radius));
      }
      break;
    case 'star':
      const points = 5;
      const totalPts = points * 2;
      final innerRadius = radius * 0.44;
      for (int i = 0; i <= totalPts; i++) {
        final r = (i % 2 == 0) ? radius : innerRadius;
        final a = (i / totalPts) * 2 * math.pi - math.pi / 2;
        pts.add(center + Offset(math.cos(a) * r, math.sin(a) * r));
      }
      break;
    case 'heart':
      const count = 48;
      final scale = radius / 16.0;
      for (int i = 0; i <= count; i++) {
        final t = (i / count) * 2 * math.pi;
        final x = 16 * math.pow(math.sin(t), 3);
        final y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t));
        pts.add(center + Offset(x * scale, y * scale + radius * 0.15));
      }
      break;
    case 'rect':
    case 'square':
      final r = radius * 0.9;
      pts.add(center + Offset(-r, -r));
      pts.add(center + Offset(r, -r));
      pts.add(center + Offset(r, r));
      pts.add(center + Offset(-r, r));
      pts.add(center + Offset(-r, -r));
      break;
    case 'arrow':
      final r = radius;
      pts.add(center + Offset(-r, 0));
      pts.add(center + Offset(r, 0));
      pts.add(center + Offset(r * 0.5, -r * 0.4));
      pts.add(center + Offset(r, 0));
      pts.add(center + Offset(r * 0.5, r * 0.4));
      break;
    case 'bubble':
      final r = radius * 0.85;
      pts.add(center + Offset(-r, -r * 0.7));
      pts.add(center + Offset(r, -r * 0.7));
      pts.add(center + Offset(r, r * 0.6));
      pts.add(center + Offset(-r * 0.2, r * 0.6));
      pts.add(center + Offset(-r * 0.6, r * 1.05));
      pts.add(center + Offset(-r * 0.5, r * 0.6));
      pts.add(center + Offset(-r, r * 0.6));
      pts.add(center + Offset(-r, -r * 0.7));
      break;
    default:
      // Fallback circle
      const count = 28;
      for (int i = 0; i <= count; i++) {
        final a = (i / count) * 2 * math.pi;
        pts.add(center + Offset(math.cos(a) * radius, math.sin(a) * radius));
      }
      break;
  }
  return densify(pts, maxGap: 8.0);
}

class DoodleShapeItem {
  final String shapeType; // 'star', 'heart', 'circle', 'rect', 'arrow', 'bubble'
  Offset center;
  double radius;
  final Color color;
  double strokeWidth;
  final DoodleBrushType brushType;

  DoodleShapeItem({
    required this.shapeType,
    required this.center,
    this.radius = 160.0,
    required this.color,
    this.strokeWidth = 14.0,
    this.brushType = DoodleBrushType.pen,
  });

  Rect get rect => Rect.fromCircle(center: center, radius: radius).inflate(16);

  DoodleStroke toStroke() => DoodleStroke(
        points: generateShapePoints(shapeType, center, radius),
        color: color,
        size: strokeWidth,
        brushType: brushType,
      );
}

class DoodleEmojiItem {
  final String emoji;
  Offset position;

  /// Emoji size in virtual units.
  double size;

  /// Optional rotation in radians for organic hand-drawn tilt.
  double rotation;

  TextPainter? _painter;

  DoodleEmojiItem({
    required this.emoji,
    required this.position,
    this.size = 96.0,
    this.rotation = 0.0,
  });

  TextPainter get painter {
    if (_painter != null) return _painter!;
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: size,
          fontFamilyFallback: const [
            'Apple Color Emoji',
            'Noto Color Emoji',
            'Segoe UI Emoji',
            'Android Emoji',
            'EmojiSymbols',
            'sans-serif',
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return _painter = tp;
  }

  void invalidate() => _painter = null;

  Rect get rect => Rect.fromLTWH(position.dx, position.dy, size, size).inflate(14);

  Map<String, dynamic> toJson() => {
        'e': emoji,
        'x': _r(position.dx),
        'y': _r(position.dy),
        's': _r(size),
        if (rotation != 0) 'r': _r(rotation),
      };

  factory DoodleEmojiItem.fromJson(Map<String, dynamic> j) => DoodleEmojiItem(
        emoji: j['e']?.toString() ?? '✨',
        position: Offset((j['x'] as num? ?? 300).toDouble(), (j['y'] as num? ?? 500).toDouble()),
        size: (j['s'] as num? ?? 96).toDouble(),
        rotation: (j['r'] as num? ?? 0.0).toDouble(),
      );
}

class DoodleData {
  final String id;
  final List<DoodleStroke> strokes;
  final List<DoodleTextItem> textItems;
  final List<DoodleEmojiItem> emojiItems;
  final String? backgroundPhoto;
  final DateTime timestamp;
  final String senderId;

  DoodleData({
    String? id,
    required this.strokes,
    this.textItems = const [],
    this.emojiItems = const [],
    this.backgroundPhoto,
    required this.timestamp,
    required this.senderId,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 31)}';

  bool get isEmpty => strokes.isEmpty && textItems.isEmpty && emojiItems.isEmpty && (backgroundPhoto == null || backgroundPhoto!.isEmpty);

  int get totalPointsCount {
    int count = 0;
    for (var s in strokes) {
      count += s.points.length;
    }
    return count;
  }

  /// Deep copy (so erasing the received copy never mutates the stored one).
  DoodleData clone() => DoodleData(
        id: id,
        strokes: [for (final s in strokes) s.copyWith()],
        textItems: [
          for (final t in textItems)
            DoodleTextItem(
              text: t.text,
              position: t.position,
              color: t.color,
              fontSize: t.fontSize,
              fontStyle: t.fontStyle,
              hasBackground: t.hasBackground,
            )
        ],
        emojiItems: [
          for (final e in emojiItems)
            DoodleEmojiItem(emoji: e.emoji, position: e.position, size: e.size)
        ],
        backgroundPhoto: backgroundPhoto,
        timestamp: timestamp,
        senderId: senderId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'strokes': [for (final s in strokes) s.toJson()],
        'texts': [for (final t in textItems) t.toJson()],
        'emojis': [for (final e in emojiItems) e.toJson()],
        if (backgroundPhoto != null) 'photo': backgroundPhoto,
      };

  factory DoodleData.fromJson(Map<String, dynamic> json, String senderId) {
    return DoodleData(
      id: json['id']?.toString(),
      strokes: [
        for (final s in (json['strokes'] as List<dynamic>? ?? const []))
          DoodleStroke.fromJson(Map<String, dynamic>.from(s as Map))
      ],
      textItems: [
        for (final t in (json['texts'] as List<dynamic>? ?? const []))
          DoodleTextItem.fromJson(Map<String, dynamic>.from(t as Map))
      ],
      emojiItems: [
        for (final e in (json['emojis'] as List<dynamic>? ?? const []))
          DoodleEmojiItem.fromJson(Map<String, dynamic>.from(e as Map))
      ],
      backgroundPhoto: json['photo']?.toString(),
      timestamp: DateTime.now(),
      senderId: senderId,
    );
  }
}
