import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

/// All doodle geometry lives in a fixed "virtual canvas" that is
/// [kVirtualWidth] units wide, so a doodle looks identical on every phone.
const double kVirtualWidth = 1000.0;

enum DoodleElementType { stroke, text, emoji }

double _r(double v) => (v * 10).roundToDouble() / 10;

class DoodleStroke {
  List<Offset> points;
  final Color color;

  /// Brush diameter in virtual units.
  final double size;
  final bool isEraser;

  Path? _path;
  double? _length;

  DoodleStroke({
    required this.points,
    required this.color,
    this.size = 10.0,
    this.isEraser = false,
  });

  /// Backwards compatible alias.
  double get strokeWidth => size;

  void invalidate() {
    _path = null;
    _length = null;
  }

  /// Cached, smoothed variable-width outline (perfect_freehand).
  Path get path => _path ??= buildFreehandPath(points, size, complete: true);

  double get length {
    if (_length != null) return _length!;
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    return _length = total;
  }

  DoodleStroke copyWith({List<Offset>? points}) {
    return DoodleStroke(
      points: points ?? List.from(this.points),
      color: color,
      size: size,
      isEraser: isEraser,
    );
  }

  Map<String, dynamic> toJson() => {
        'p': [for (final p in points) ...[_r(p.dx), _r(p.dy)]],
        'c': color.toARGB32(),
        's': _r(size),
      };

  factory DoodleStroke.fromJson(Map<String, dynamic> json) {
    final flat = (json['p'] as List<dynamic>? ?? const []);
    final pts = <Offset>[];
    for (int i = 0; i + 1 < flat.length; i += 2) {
      pts.add(Offset((flat[i] as num).toDouble(), (flat[i + 1] as num).toDouble()));
    }
    return DoodleStroke(
      points: pts,
      color: Color((json['c'] as num?)?.toInt() ?? 0xFFFFC72C),
      size: (json['s'] as num?)?.toDouble() ?? 10.0,
    );
  }
}

/// Smooth variable-width freehand path for a list of points.
Path buildFreehandPath(List<Offset> pts, double size, {bool complete = false}) {
  final path = Path();
  if (pts.isEmpty) return path;
  if (pts.length == 1) {
    path.addOval(Rect.fromCircle(center: pts.first, radius: size / 2));
    return path;
  }
  final outline = getStroke(
    [for (final p in pts) PointVector(p.dx, p.dy)],
    options: StrokeOptions(
      size: size,
      thinning: 0.35,
      smoothing: 0.6,
      streamline: 0.5,
      simulatePressure: true,
      isComplete: complete,
    ),
  );
  if (outline.length < 2) {
    path.addOval(Rect.fromCircle(center: pts.first, radius: size / 2));
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
  switch (fontStyle) {
    case 'Gaegu':
      return GoogleFonts.gaegu(
          fontSize: fontSize, fontWeight: FontWeight.w700, color: color, shadows: shadows);
    case 'Caveat':
      return GoogleFonts.caveat(
          fontSize: fontSize, fontWeight: FontWeight.w700, color: color, shadows: shadows);
    default:
      return GoogleFonts.patrickHand(
          fontSize: fontSize, fontWeight: FontWeight.w700, color: color, shadows: shadows);
  }
}

class DoodleTextItem {
  final String text;
  final Offset position;
  final Color color;

  /// Font size in virtual units.
  final double fontSize;
  final String fontStyle; // 'PatrickHand', 'Caveat', 'Gaegu'

  TextPainter? _painter;

  DoodleTextItem({
    required this.text,
    required this.position,
    required this.color,
    this.fontSize = 64.0,
    this.fontStyle = 'PatrickHand',
  });

  /// Cached layout, so we never lay text out inside paint().
  TextPainter get painter {
    if (_painter != null) return _painter!;
    final tp = TextPainter(
      text: TextSpan(text: text, style: doodleTextStyle(fontStyle, fontSize, color)),
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
      };

  factory DoodleTextItem.fromJson(Map<String, dynamic> j) => DoodleTextItem(
        text: j['t']?.toString() ?? '',
        position: Offset((j['x'] as num? ?? 50).toDouble(), (j['y'] as num? ?? 400).toDouble()),
        color: Color((j['c'] as num?)?.toInt() ?? 0xFF00CEC9),
        fontSize: (j['f'] as num? ?? 64).toDouble(),
        fontStyle: j['k']?.toString() ?? 'PatrickHand',
      );
}

class DoodleEmojiItem {
  final String emoji;
  final Offset position;

  /// Emoji size in virtual units.
  final double size;

  TextPainter? _painter;

  DoodleEmojiItem({
    required this.emoji,
    required this.position,
    this.size = 96.0,
  });

  TextPainter get painter {
    if (_painter != null) return _painter!;
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    return _painter = tp;
  }

  Rect get rect => (position & painter.size).inflate(10);

  Map<String, dynamic> toJson() => {
        'e': emoji,
        'x': _r(position.dx),
        'y': _r(position.dy),
        's': _r(size),
      };

  factory DoodleEmojiItem.fromJson(Map<String, dynamic> j) => DoodleEmojiItem(
        emoji: j['e']?.toString() ?? '✨',
        position: Offset((j['x'] as num? ?? 300).toDouble(), (j['y'] as num? ?? 500).toDouble()),
        size: (j['s'] as num? ?? 96).toDouble(),
      );
}

class DoodleData {
  final String id;
  final List<DoodleStroke> strokes;
  final List<DoodleTextItem> textItems;
  final List<DoodleEmojiItem> emojiItems;
  final DateTime timestamp;
  final String senderId;

  DoodleData({
    String? id,
    required this.strokes,
    this.textItems = const [],
    this.emojiItems = const [],
    required this.timestamp,
    required this.senderId,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 31)}';

  bool get isEmpty => strokes.isEmpty && textItems.isEmpty && emojiItems.isEmpty;

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
            )
        ],
        emojiItems: [
          for (final e in emojiItems)
            DoodleEmojiItem(emoji: e.emoji, position: e.position, size: e.size)
        ],
        timestamp: timestamp,
        senderId: senderId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'strokes': [for (final s in strokes) s.toJson()],
        'texts': [for (final t in textItems) t.toJson()],
        'emojis': [for (final e in emojiItems) e.toJson()],
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
      timestamp: DateTime.now(),
      senderId: senderId,
    );
  }
}
