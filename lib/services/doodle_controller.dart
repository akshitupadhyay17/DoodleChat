import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/doodle_stroke.dart';
import 'chat_service.dart';

/// Tiny notifier used to repaint a single canvas layer without rebuilding widgets.
class RepaintTick extends ChangeNotifier {
  void bump() => notifyListeners();
}

enum _DoodleHistoryKind { stroke, text, emoji, shape }

class _DoodleActionRecord {
  final _DoodleHistoryKind kind;
  final DoodleStroke? stroke;
  final DoodleTextItem? text;
  final DoodleEmojiItem? emoji;
  final DoodleShapeItem? shape;

  _DoodleActionRecord.stroke(this.stroke)
      : kind = _DoodleHistoryKind.stroke,
        text = null,
        emoji = null,
        shape = null;

  _DoodleActionRecord.text(this.text)
      : kind = _DoodleHistoryKind.text,
        stroke = null,
        emoji = null,
        shape = null;

  _DoodleActionRecord.emoji(this.emoji)
      : kind = _DoodleHistoryKind.emoji,
        stroke = null,
        text = null,
        shape = null;

  _DoodleActionRecord.shape(this.shape)
      : kind = _DoodleHistoryKind.shape,
        stroke = null,
        text = null,
        emoji = null;
}

enum SelectedElementType { text, emoji, shape }

class DoodleSelection {
  final SelectedElementType type;
  final DoodleTextItem? text;
  final DoodleEmojiItem? emoji;
  final DoodleShapeItem? shape;

  DoodleSelection.text(this.text)
      : type = SelectedElementType.text,
        emoji = null,
        shape = null;

  DoodleSelection.emoji(this.emoji)
      : type = SelectedElementType.emoji,
        text = null,
        shape = null;

  DoodleSelection.shape(this.shape)
      : type = SelectedElementType.shape,
        text = null,
        emoji = null;

  Rect get rect {
    switch (type) {
      case SelectedElementType.text:
        return text?.rect ?? Rect.zero;
      case SelectedElementType.emoji:
        return emoji?.rect ?? Rect.zero;
      case SelectedElementType.shape:
        return shape?.rect ?? Rect.zero;
    }
  }

  void moveBy(Offset delta) {
    switch (type) {
      case SelectedElementType.text:
        if (text != null) text!.position += delta;
        break;
      case SelectedElementType.emoji:
        if (emoji != null) emoji!.position += delta;
        break;
      case SelectedElementType.shape:
        if (shape != null) shape!.center += delta;
        break;
    }
  }

  void scaleBy(double factor) {
    switch (type) {
      case SelectedElementType.text:
        if (text != null) {
          final next = (text!.fontSize * factor).clamp(18.0, 360.0);
          text!.fontSize = next;
          text!.invalidate();
        }
        break;
      case SelectedElementType.emoji:
        if (emoji != null) {
          final next = (emoji!.size * factor).clamp(24.0, 480.0);
          emoji!.size = next;
          emoji!.invalidate();
        }
        break;
      case SelectedElementType.shape:
        if (shape != null) {
          final next = (shape!.radius * factor).clamp(20.0, 600.0);
          shape!.radius = next;
        }
        break;
    }
  }
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
  List<DoodleShapeItem> shapes = [];
  DoodleSelection? selection;
  String? backgroundPhoto;
  final List<_DoodleActionRecord> _undoStack = [];
  final List<_DoodleActionRecord> _redoStack = [];

  Color color = const Color(0xFFFFC72C);
  late DoodleBrushType brushType;

  DoodleController({DoodleBrushType? initialBrushType}) {
    if (initialBrushType != null) {
      brushType = initialBrushType;
    } else {
      bool isDark = false;
      try {
        isDark = ChatService().currentUser.isDarkMode;
      } catch (_) {}
      brushType = isDark ? DoodleBrushType.neon : DoodleBrushType.pen;
    }
  }

  /// Brush size in *screen* pixels (converted to virtual units on commit).
  double brushPx = 5.0;

  /// Dedicated eraser radius in *screen* pixels.
  /// Default is generously sized (36.0 px radius / 72.0 px diameter)
  /// for comfortable thumb erasing.
  double eraserPx = 36.0;
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

  /// Dynamic eraser radius in screen pixels (clamped between 10 and 80).
  double get eraserScreenRadius => eraserPx.clamp(10.0, 80.0);
  static const double defaultEraserScreenRadius = 36.0;
  static const double _itemUnits = 140.0;

  /// Current active tool size in screen pixels (eraser radius or brush thickness).
  double get activeToolPx => eraser ? eraserPx : brushPx;

  List<Offset> get livePoints => _live;
  bool get isEmpty => strokes.isEmpty && texts.isEmpty && emojis.isEmpty && shapes.isEmpty && (backgroundPhoto == null || backgroundPhoto!.isEmpty);
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
    if (forErasing && eraserPx < 30.0) {
      eraserPx = defaultEraserScreenRadius;
    }
    if (c.backgroundPhoto != null && c.backgroundPhoto!.isNotEmpty && forErasing) {
      _remainingPhotoUnits = _photoUnits;
    } else {
      _remainingPhotoUnits = 0;
    }
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
    shapes = [];
    selection = null;
    backgroundPhoto = null;
    _remainingPhotoUnits = 0;
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
    final allStrokes = [
      ...strokes,
      for (final s in shapes) s.toStroke(),
    ];
    final c = DoodleData(
      strokes: allStrokes,
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
    if (mustErase) {
      eraser = true;
      return;
    }
    eraser = v;
    if (v) {
      stampEmoji = null;
      if (eraserPx < 20.0) eraserPx = defaultEraserScreenRadius;
    }
    eraserPos = null;
    live.bump();
    notifyListeners();
  }

  void setColor(Color c) {
    if (mustErase) return;
    color = c;
    eraser = false;
    stampEmoji = null;
    notifyListeners();
  }

  void setBrushType(DoodleBrushType type) {
    if (mustErase) return;
    brushType = type;
    eraser = false;
    stampEmoji = null;
    notifyListeners();
  }

  void setStampEmoji(String? emoji) {
    if (mustErase) return;
    stampEmoji = emoji;
    if (emoji != null) eraser = false;
    notifyListeners();
  }

  void setBrush(double px) {
    if (eraser) {
      eraserPx = px;
    } else {
      brushPx = px;
    }
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
      case _DoodleHistoryKind.shape:
        if (act.shape != null) shapes.remove(act.shape);
        break;
    }
    clearSelection();
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
      case _DoodleHistoryKind.shape:
        if (act.shape != null) shapes.add(act.shape!);
        break;
    }
    clearSelection();
    committed.bump();
    notifyListeners();
  }

  void addShape(String shapeType) {
    final center = Offset(kVirtualWidth / 2, viewHeightVirtual * 0.42);
    final item = DoodleShapeItem(
      shapeType: shapeType,
      center: center,
      radius: 160.0,
      color: color,
      strokeWidth: (brushPx / scale).clamp(8.0, 24.0),
      brushType: brushType,
    );
    shapes.add(item);
    _undoStack.add(_DoodleActionRecord.shape(item));
    _redoStack.clear();
    selectShape(item);
    committed.bump();
    notifyListeners();
  }

  // ───────────────────────── direct manipulation & selection ─────────────────────────

  void selectText(DoodleTextItem item) {
    selection = DoodleSelection.text(item);
    committed.bump();
    notifyListeners();
  }

  void selectEmoji(DoodleEmojiItem item) {
    selection = DoodleSelection.emoji(item);
    committed.bump();
    notifyListeners();
  }

  void selectShape(DoodleShapeItem item) {
    selection = DoodleSelection.shape(item);
    committed.bump();
    notifyListeners();
  }

  void clearSelection() {
    if (selection == null) return;
    selection = null;
    committed.bump();
    notifyListeners();
  }

  void moveSelected(Offset delta) {
    if (selection == null) return;
    selection!.moveBy(delta);
    committed.bump();
    notifyListeners();
  }

  void scaleSelected(double factor) {
    if (selection == null) return;
    selection!.scaleBy(factor);
    committed.bump();
    notifyListeners();
  }

  void deleteSelected() {
    if (selection == null) return;
    if (selection!.text != null) {
      texts.remove(selection!.text);
    } else if (selection!.emoji != null) {
      emojis.remove(selection!.emoji);
    } else if (selection!.shape != null) {
      shapes.remove(selection!.shape);
    }
    selection = null;
    committed.bump();
    notifyListeners();
  }

  bool hitTestSelect(Offset v) {
    for (int i = shapes.length - 1; i >= 0; i--) {
      if (shapes[i].rect.inflate(24).contains(v)) {
        selectShape(shapes[i]);
        return true;
      }
    }
    for (int i = emojis.length - 1; i >= 0; i--) {
      if (emojis[i].rect.inflate(24).contains(v)) {
        selectEmoji(emojis[i]);
        return true;
      }
    }
    for (int i = texts.length - 1; i >= 0; i--) {
      if (texts[i].rect.inflate(24).contains(v)) {
        selectText(texts[i]);
        return true;
      }
    }
    return false;
  }

  /// Automatically calculates optimal font size based on text length and canvas dimensions.
  double computeAutoScaledFontSize(String text, String fontStyle) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 72.0;

    // Target width: ~80% of virtual width (800 virtual units)
    const targetW = kVirtualWidth * 0.80;

    final lines = trimmed.split('\n');
    String longestLine = lines.reduce((a, b) => a.length >= b.length ? a : b);
    if (longestLine.trim().isEmpty) return 72.0;

    // Quick calibration layout at 100pt
    final testPainter = TextPainter(
      text: TextSpan(
        text: longestLine,
        style: doodleTextStyle(fontStyle, 100.0, Colors.black),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final measuredW = testPainter.width;
    if (measuredW <= 0) return 72.0;

    double ideal = 100.0 * (targetW / measuredW);

    // Dynamic constraints based on line count and character length:
    if (lines.length > 3) {
      ideal = ideal.clamp(44.0, 70.0);
    } else if (lines.length > 1) {
      ideal = ideal.clamp(52.0, 96.0);
    } else {
      ideal = ideal.clamp(58.0, 134.0);
    }

    return ideal;
  }

  void addText(
    String text, [
    String fontStyle = 'PatrickHand',
    bool hasBackground = false,
    double? customFontSize,
  ]) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final fontSize = customFontSize ?? computeAutoScaledFontSize(trimmed, fontStyle);

    // Layout to calculate exact dimensions for perfect auto-centering
    final testPainter = TextPainter(
      text: TextSpan(
        text: trimmed,
        style: doodleTextStyle(fontStyle, fontSize, color),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(120, kVirtualWidth - 48));

    final textW = testPainter.width;
    final textH = testPainter.height;

    // Auto-center horizontally and place gracefully in upper-middle viewport
    final posX = ((kVirtualWidth - textW) / 2).clamp(24.0, math.max(24.0, kVirtualWidth - textW - 24.0)).toDouble();
    final posY = ((viewHeightVirtual - textH) * 0.38).clamp(60.0, math.max(60.0, viewHeightVirtual - textH - 60.0)).toDouble();

    final item = DoodleTextItem(
      text: trimmed,
      position: Offset(posX, posY),
      color: color,
      fontSize: fontSize,
      fontStyle: fontStyle,
      hasBackground: hasBackground,
    );
    texts.add(item);
    _undoStack.add(_DoodleActionRecord.text(item));
    _redoStack.clear();
    selectText(item);
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
    final rnd = math.Random();
    final rotation = (rnd.nextDouble() - 0.5) * 0.22; // ~ -6° to +6° organic hand tilt!
    final item = DoodleEmojiItem(
      emoji: emoji,
      position: pos,
      size: s,
      rotation: rotation,
    );
    emojis.add(item);
    _undoStack.add(_DoodleActionRecord.emoji(item));
    _redoStack.clear();
    selectEmoji(item);
    committed.bump();
    onStrokeStart?.call();
    notifyListeners();
  }

  // ───────────────────────── pointer input (screen px) ─────────────────────────

  void pointerDown(Offset screen) {
    _ignorePointerUntilUp = false;
    if (locked) return;
    final v = screen / scale;

    if (selection != null) {
      if (selection!.rect.inflate(20).contains(v)) {
        // Interacting with active selection overlay
        _ignorePointerUntilUp = true;
        return;
      } else {
        clearSelection();
      }
    }

    if (mustErase || eraser) {
      eraser = true;
      eraserPos = v;
      _eraseAt(v);
      live.bump();
    } else if (stampEmoji != null) {
      final s = emojiSize;
      final rnd = math.Random();
      final rotation = (rnd.nextDouble() - 0.5) * 0.24;
      final item = DoodleEmojiItem(
        emoji: stampEmoji!,
        position: Offset(v.dx - s / 2, v.dy - s / 2),
        size: s,
        rotation: rotation,
      );
      emojis.add(item);
      _undoStack.add(_DoodleActionRecord.emoji(item));
      _redoStack.clear();
      selectEmoji(item);
      committed.bump();
      onStrokeStart?.call();
      notifyListeners();
    } else {
      if (hitTestSelect(v)) {
        _ignorePointerUntilUp = true;
        return;
      }
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
    if (mustErase || eraser) {
      eraser = true;
      eraserPos = v;
      _eraseAt(v);
      live.bump();
    } else if (stampEmoji != null) {
      // Allow drag-stamping when moving at a spaced distance!
      final s = emojiSize;
      final lastPos = emojis.isNotEmpty ? emojis.last.position : null;
      final curPos = Offset(v.dx - s / 2, v.dy - s / 2);
      if (lastPos == null || (curPos - lastPos).distance >= s * 0.85) {
        final rnd = math.Random();
        final rotation = (rnd.nextDouble() - 0.5) * 0.24;
        final item = DoodleEmojiItem(
          emoji: stampEmoji!,
          position: curPos,
          size: s,
          rotation: rotation,
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

  void cancelLiveStroke() {
    _ignorePointerUntilUp = true;
    _live.clear();
    eraserPos = null;
    live.bump();
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
    if (mustErase || eraser) {
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
    final shBefore = shapes.length;
    shapes.removeWhere((sh) => sh.rect.inflate(r).contains(c));
    if (texts.length != tBefore || emojis.length != eBefore || shapes.length != shBefore) modified = true;

    if (backgroundPhoto != null && backgroundPhoto!.isNotEmpty && mustErase) {
      if (_remainingPhotoUnits > 0) {
        _remainingPhotoUnits = (_remainingPhotoUnits - (eraserPx * 4.0)).clamp(0.0, _photoUnits);
        modified = true;
      }
    }

    if (!modified) return;
    onEraseHit?.call();
    committed.bump();
    _updateProgress();
  }

  static const double _photoUnits = 1200.0;
  double _remainingPhotoUnits = 0;

  double _remainingUnits() {
    double total = (texts.length + emojis.length + shapes.length) * _itemUnits;
    for (final s in strokes) {
      total += s.length;
    }
    if (backgroundPhoto != null && backgroundPhoto!.isNotEmpty && mustErase) {
      total += _remainingPhotoUnits;
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
      if (mustErase && remaining <= _initialUnits * 0.05 && !isEmpty) {
        strokes = [];
        texts = [];
        emojis = [];
        shapes = [];
        _remainingPhotoUnits = 0;
        backgroundPhoto = null;
        committed.bump();
      }
    }
    onEraseProgress?.call(eraseProgress.value);
    if (mustErase && (isEmpty || eraseProgress.value >= 0.98) && !_completed) {
      _completed = true;
      _ignorePointerUntilUp = true;
      _live.clear();
      eraserPos = null;
      strokes = [];
      texts = [];
      emojis = [];
      shapes = [];
      _remainingPhotoUnits = 0;
      backgroundPhoto = null;
      live.bump();
      committed.bump();
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
    shapes = [];
    _remainingPhotoUnits = 0;
    backgroundPhoto = null;
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
