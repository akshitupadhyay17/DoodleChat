import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/doodle_stroke.dart';

/// Tiny notifier used to repaint a single canvas layer without rebuilding widgets.
class RepaintTick extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// Owns the doodle being drawn / erased. The UI never `setState`s while a
/// finger is moving: only the two canvas layers repaint through [committed]
/// and [live], which is what keeps drawing at a locked 60/120 fps.
class DoodleController extends ChangeNotifier {
  final RepaintTick committed = RepaintTick();
  final RepaintTick live = RepaintTick();

  /// 0..1 while erasing; listened to by the UI (cheap, isolated).
  final ValueNotifier<double> eraseProgress = ValueNotifier<double>(0);

  List<DoodleStroke> strokes = [];
  List<DoodleTextItem> texts = [];
  List<DoodleEmojiItem> emojis = [];

  Color color = const Color(0xFFFFC72C);

  /// Brush size in *screen* pixels (converted to virtual units on commit).
  double brushPx = 5.0;
  bool eraser = false;

  /// Read-only (e.g. waiting for the friend to erase my doodle).
  bool locked = false;

  /// When true, wiping everything fires [onErasedAll].
  bool mustErase = false;

  VoidCallback? onErasedAll;
  VoidCallback? onStrokeStart;
  ValueChanged<double>? onEraseProgress;
  VoidCallback? onEraseHit;

  double scale = 1.0;
  double viewWidth = 0, viewHeight = 0;

  final List<Offset> _live = [];
  Offset? eraserPos; // virtual units
  double _initialUnits = 0;
  bool _completed = false;

  static const double eraserScreenRadius = 26.0;
  static const double _itemUnits = 140.0;

  List<Offset> get livePoints => _live;
  bool get isEmpty => strokes.isEmpty && texts.isEmpty && emojis.isEmpty;
  bool get canUndo => strokes.isNotEmpty && !mustErase;

  void setViewport(double w, double h) {
    viewWidth = w;
    viewHeight = h;
    scale = w / kVirtualWidth;
  }

  double get viewHeightVirtual => scale == 0 ? 1400 : viewHeight / scale;

  // ───────────────────────── loading ─────────────────────────

  void load(DoodleData data, {required bool forErasing}) {
    final c = data.clone();
    for (final s in c.strokes) {
      s.points = densify(s.points);
      s.invalidate();
    }
    strokes = c.strokes;
    texts = c.textItems;
    emojis = c.emojiItems;
    _live.clear();
    eraserPos = null;
    _completed = false;
    mustErase = forErasing;
    eraser = forErasing;
    _initialUnits = _remainingUnits();
    eraseProgress.value = 0;
    committed.bump();
    live.bump();
    notifyListeners();
  }

  void clear({bool silent = false}) {
    strokes = [];
    texts = [];
    emojis = [];
    _live.clear();
    eraserPos = null;
    _initialUnits = 0;
    eraseProgress.value = 0;
    committed.bump();
    live.bump();
    if (!silent) notifyListeners();
  }

  DoodleData toData(String senderId) {
    final c = DoodleData(
      strokes: strokes,
      textItems: texts,
      emojiItems: emojis,
      timestamp: DateTime.now(),
      senderId: senderId,
    ).clone();
    return c;
  }

  // ───────────────────────── tool settings ─────────────────────────

  void setEraser(bool v) {
    eraser = v;
    eraserPos = null;
    live.bump();
    notifyListeners();
  }

  void setColor(Color c) {
    color = c;
    eraser = false;
    notifyListeners();
  }

  void setBrush(double px) {
    brushPx = px;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    strokes.removeLast();
    committed.bump();
    notifyListeners();
  }

  void addText(String text, String fontStyle) {
    if (text.trim().isEmpty) return;
    final rnd = math.Random();
    texts.add(DoodleTextItem(
      text: text.trim(),
      position: Offset(60 + rnd.nextDouble() * 220, viewHeightVirtual * (0.28 + rnd.nextDouble() * 0.4)),
      color: color,
      fontSize: 70,
      fontStyle: fontStyle,
    ));
    committed.bump();
    notifyListeners();
  }

  void addEmoji(String emoji) {
    final rnd = math.Random();
    emojis.add(DoodleEmojiItem(
      emoji: emoji,
      position: Offset(120 + rnd.nextDouble() * 560, viewHeightVirtual * (0.22 + rnd.nextDouble() * 0.5)),
      size: 110,
    ));
    committed.bump();
    notifyListeners();
  }

  // ───────────────────────── pointer input (screen px) ─────────────────────────

  void pointerDown(Offset screen) {
    if (locked) return;
    final v = screen / scale;
    if (eraser) {
      eraserPos = v;
      _eraseAt(v);
      live.bump();
    } else {
      _live
        ..clear()
        ..add(v);
      onStrokeStart?.call();
      live.bump();
    }
  }

  void pointerMove(Offset screen) {
    if (locked) return;
    final v = screen / scale;
    if (eraser) {
      eraserPos = v;
      _eraseAt(v);
      live.bump();
    } else {
      if (_live.isEmpty || (v - _live.last).distance * scale >= 1.2) {
        _live.add(v);
        live.bump();
      }
    }
  }

  void pointerUp() {
    if (locked) return;
    if (eraser) {
      eraserPos = null;
      live.bump();
      return;
    }
    if (_live.isNotEmpty) {
      strokes.add(DoodleStroke(
        points: List<Offset>.from(_live),
        color: color,
        size: brushPx / scale,
      ));
      _live.clear();
      committed.bump();
      live.bump();
      notifyListeners();
    }
  }

  // ───────────────────────── erasing ─────────────────────────

  void _eraseAt(Offset c) {
    final r = eraserScreenRadius / scale;
    final r2 = r * r;
    bool modified = false;

    final next = <DoodleStroke>[];
    for (final s in strokes) {
      List<List<Offset>>? segs;
      List<Offset> cur = [];
      bool hit = false;
      for (final p in s.points) {
        final dx = p.dx - c.dx, dy = p.dy - c.dy;
        if (dx * dx + dy * dy <= r2) {
          hit = true;
          if (cur.isNotEmpty) {
            (segs ??= []).add(cur);
            cur = [];
          }
        } else {
          cur.add(p);
        }
      }
      if (!hit) {
        next.add(s);
        continue;
      }
      modified = true;
      if (cur.isNotEmpty) (segs ??= []).add(cur);
      for (final seg in segs ?? const <List<Offset>>[]) {
        if (seg.length >= 2) {
          next.add(DoodleStroke(points: seg, color: s.color, size: s.size));
        }
      }
    }
    if (modified) strokes = next;

    final tBefore = texts.length;
    texts.removeWhere((t) => t.rect.inflate(r).contains(c));
    final eBefore = emojis.length;
    emojis.removeWhere((e) => e.rect.inflate(r).contains(c));
    if (texts.length != tBefore || emojis.length != eBefore) modified = true;

    if (!modified) return;
    onEraseHit?.call();
    committed.bump();
    _updateProgress();
  }

  double _remainingUnits() {
    double total = (texts.length + emojis.length) * _itemUnits;
    for (final s in strokes) {
      total += s.length;
    }
    return total;
  }

  void _updateProgress() {
    if (_initialUnits <= 0) {
      eraseProgress.value = isEmpty ? 1 : 0;
    } else {
      final remaining = _remainingUnits();
      eraseProgress.value = (1 - remaining / _initialUnits).clamp(0.0, 1.0);
      // Auto-sweep leftover crumbs so nobody hunts for the last pixel.
      if (mustErase && remaining <= _initialUnits * 0.04 && !isEmpty) {
        strokes = [];
        texts = [];
        emojis = [];
        committed.bump();
      }
    }
    onEraseProgress?.call(eraseProgress.value);
    if (mustErase && isEmpty && !_completed) {
      _completed = true;
      eraseProgress.value = 1;
      onErasedAll?.call();
      notifyListeners();
    }
  }

  /// "Wipe all" shortcut button.
  void wipeAll() {
    if (!mustErase) {
      clear();
      return;
    }
    strokes = [];
    texts = [];
    emojis = [];
    committed.bump();
    _updateProgress();
  }

  @override
  void dispose() {
    committed.dispose();
    live.dispose();
    eraseProgress.dispose();
    super.dispose();
  }
}
