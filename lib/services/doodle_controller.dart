import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/doodle_stroke.dart';

/// Tiny notifier used to repaint a single canvas layer without rebuilding widgets.
class RepaintTick extends ChangeNotifier {
  void bump() => notifyListeners();
}

enum _DoodleHistoryKind { stroke, text, emoji }

class _DoodleActionRecord {
  final _DoodleHistoryKind kind;
  final DoodleStroke? stroke;
  final DoodleTextItem? text;
  final DoodleEmojiItem? emoji;

  _DoodleActionRecord.stroke(this.stroke)
      : kind = _DoodleHistoryKind.stroke,
        text = null,
        emoji = null;

  _DoodleActionRecord.text(this.text)
      : kind = _DoodleHistoryKind.text,
        stroke = null,
        emoji = null;

  _DoodleActionRecord.emoji(this.emoji)
      : kind = _DoodleHistoryKind.emoji,
        stroke = null,
        text = null;
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
  String? backgroundPhoto;
  final List<_DoodleActionRecord> _undoStack = [];
  final List<_DoodleActionRecord> _redoStack = [];

  Color color = const Color(0xFFFFC72C);
  DoodleBrushType brushType = DoodleBrushType.pen;

  /// Brush size in *screen* pixels (converted to virtual units on commit).
  double brushPx = 5.0;
  bool eraser = false;

  /// When non-null, tapping anywhere on the canvas stamps this emoji.
  String? stampEmoji;

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

  /// Dynamic eraser radius scaled by brush size pixel slider.
  double get eraserScreenRadius => (brushPx * 1.6).clamp(8.0, 75.0);
  static const double defaultEraserScreenRadius = 26.0;
  static const double _itemUnits = 140.0;

  List<Offset> get livePoints => _live;
  bool get isEmpty => strokes.isEmpty && texts.isEmpty && emojis.isEmpty && (backgroundPhoto == null || backgroundPhoto!.isEmpty);
  bool get canUndo => _undoStack.isNotEmpty && !mustErase;
  bool get canRedo => _redoStack.isNotEmpty && !mustErase;

  double get emojiSize {
    if (brushPx <= 3.0) return 72.0;
    if (brushPx <= 6.0) return 104.0;
    return 140.0;
  }

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
    backgroundPhoto = c.backgroundPhoto;
    _undoStack.clear();
    _redoStack.clear();
    for (final s in strokes) {
      _undoStack.add(_DoodleActionRecord.stroke(s));
    }
    for (final t in texts) {
      _undoStack.add(_DoodleActionRecord.text(t));
    }
    for (final e in emojis) {
      _undoStack.add(_DoodleActionRecord.emoji(e));
    }
    _live.clear();
    eraserPos = null;
    stampEmoji = null;
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
    backgroundPhoto = null;
    _undoStack.clear();
    _redoStack.clear();
    _live.clear();
    eraserPos = null;
    _initialUnits = 0;
    eraseProgress.value = 0;
    committed.bump();
    live.bump();
    if (!silent) notifyListeners();
  }

  void setBackgroundPhoto(String? base64) {
    backgroundPhoto = base64;
    committed.bump();
    notifyListeners();
  }

  DoodleData toData(String senderId) {
    final c = DoodleData(
      strokes: strokes,
      textItems: texts,
      emojiItems: emojis,
      backgroundPhoto: backgroundPhoto,
      timestamp: DateTime.now(),
      senderId: senderId,
    ).clone();
    return c;
  }

  // ───────────────────────── tool settings ─────────────────────────

  void setEraser(bool v) {
    eraser = v;
    if (v) stampEmoji = null;
    eraserPos = null;
    live.bump();
    notifyListeners();
  }

  void setColor(Color c) {
    color = c;
    eraser = false;
    stampEmoji = null;
    notifyListeners();
  }

  void setBrushType(DoodleBrushType type) {
    brushType = type;
    eraser = false;
    stampEmoji = null;
    notifyListeners();
  }

  void setStampEmoji(String? emoji) {
    stampEmoji = emoji;
    if (emoji != null) eraser = false;
    notifyListeners();
  }

  void setBrush(double px) {
    brushPx = px;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    final act = _undoStack.removeLast();
    _redoStack.add(act);
    switch (act.kind) {
      case _DoodleHistoryKind.stroke:
        if (act.stroke != null) strokes.remove(act.stroke);
        break;
      case _DoodleHistoryKind.text:
        if (act.text != null) texts.remove(act.text);
        break;
      case _DoodleHistoryKind.emoji:
        if (act.emoji != null) emojis.remove(act.emoji);
        break;
    }
    committed.bump();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final act = _redoStack.removeLast();
    _undoStack.add(act);
    switch (act.kind) {
      case _DoodleHistoryKind.stroke:
        if (act.stroke != null) strokes.add(act.stroke!);
        break;
      case _DoodleHistoryKind.text:
        if (act.text != null) texts.add(act.text!);
        break;
      case _DoodleHistoryKind.emoji:
        if (act.emoji != null) emojis.add(act.emoji!);
        break;
    }
    committed.bump();
    notifyListeners();
  }

  void addShape(String shapeType) {
    final center = Offset(kVirtualWidth / 2, viewHeightVirtual * 0.42);
    final pts = generateShapePoints(shapeType, center, 160.0);
    final s = DoodleStroke(
      points: pts,
      color: color,
      size: (brushPx / scale).clamp(8.0, 24.0),
      brushType: brushType,
    );
    strokes.add(s);
    _undoStack.add(_DoodleActionRecord.stroke(s));
    _redoStack.clear();
    committed.bump();
    notifyListeners();
  }

  void addText(String text, [String fontStyle = 'PatrickHand', bool hasBackground = false]) {
    if (text.trim().isEmpty) return;
    final rnd = math.Random();
    final item = DoodleTextItem(
      text: text.trim(),
      position: Offset(
        60 + rnd.nextDouble() * 220,
        viewHeightVirtual * (0.28 + rnd.nextDouble() * 0.4),
      ),
      color: color,
      fontSize: 70,
      fontStyle: fontStyle,
      hasBackground: hasBackground,
    );
    texts.add(item);
    _undoStack.add(_DoodleActionRecord.text(item));
    _redoStack.clear();
    committed.bump();
    notifyListeners();
  }

  bool _ignorePointerUntilUp = false;

  void addEmoji(String emoji, {Offset? virtualPos, double? customSize}) {
    final s = customSize ?? emojiSize;
    final pos = virtualPos ??
        Offset(
          (kVirtualWidth - s) / 2,
          (viewHeightVirtual - s) * 0.42,
        );
    final item = DoodleEmojiItem(
      emoji: emoji,
      position: pos,
      size: s,
    );
    emojis.add(item);
    _undoStack.add(_DoodleActionRecord.emoji(item));
    _redoStack.clear();
    committed.bump();
    onStrokeStart?.call();
    notifyListeners();
  }

  // ───────────────────────── pointer input (screen px) ─────────────────────────

  void pointerDown(Offset screen) {
    _ignorePointerUntilUp = false;
    if (locked) return;
    final v = screen / scale;
    if (eraser) {
      eraserPos = v;
      _eraseAt(v);
      live.bump();
    } else if (stampEmoji != null) {
      final s = emojiSize;
      final item = DoodleEmojiItem(
        emoji: stampEmoji!,
        position: Offset(v.dx - s / 2, v.dy - s / 2),
        size: s,
      );
      emojis.add(item);
      _undoStack.add(_DoodleActionRecord.emoji(item));
      _redoStack.clear();
      committed.bump();
      onStrokeStart?.call();
      notifyListeners();
    } else {
      _live
        ..clear()
        ..add(v);
      onStrokeStart?.call();
      live.bump();
    }
  }

  void pointerMove(Offset screen) {
    if (locked || _ignorePointerUntilUp) return;
    final v = screen / scale;
    if (eraser) {
      eraserPos = v;
      _eraseAt(v);
      live.bump();
    } else if (stampEmoji != null) {
      // Allow drag-stamping when moving at a spaced distance!
      final s = emojiSize;
      final lastPos = emojis.isNotEmpty ? emojis.last.position : null;
      final curPos = Offset(v.dx - s / 2, v.dy - s / 2);
      if (lastPos == null || (curPos - lastPos).distance >= s * 0.85) {
        final item = DoodleEmojiItem(
          emoji: stampEmoji!,
          position: curPos,
          size: s,
        );
        emojis.add(item);
        _undoStack.add(_DoodleActionRecord.emoji(item));
        _redoStack.clear();
        committed.bump();
        notifyListeners();
      }
    } else {
      if (_live.isEmpty || (v - _live.last).distance * scale >= 1.2) {
        _live.add(v);
        live.bump();
      }
    }
  }

  void pointerUp() {
    if (_ignorePointerUntilUp) {
      _ignorePointerUntilUp = false;
      _live.clear();
      eraserPos = null;
      live.bump();
      return;
    }
    if (locked) return;
    if (eraser) {
      eraserPos = null;
      live.bump();
      return;
    }
    if (stampEmoji != null) {
      return;
    }
    if (_live.isNotEmpty) {
      final s = DoodleStroke(
        points: List<Offset>.from(_live),
        color: color,
        size: brushPx / scale,
        brushType: brushType,
      );
      strokes.add(s);
      _undoStack.add(_DoodleActionRecord.stroke(s));
      _redoStack.clear();
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
      _ignorePointerUntilUp = true;
      _live.clear();
      eraserPos = null;
      live.bump();
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
