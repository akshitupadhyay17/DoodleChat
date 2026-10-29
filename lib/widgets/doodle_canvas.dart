import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/doodle_stroke.dart';
import '../services/doodle_controller.dart';
import 'cartoon_emoji_renderer.dart';

/// High-performance doodle surface.
///  * Layer 1 (background): photo if user loaded one.
///  * Layer 2 (committed): finished strokes/text/emoji – repaints only when they change.
///  * Layer 3 (live): the stroke under your finger + eraser ring – repaints per touch event.
/// Both sit in their own RepaintBoundary (separate GPU layers) and repaint through
/// Listenables, so no widget is rebuilt while drawing.
class DoodleCanvas extends StatefulWidget {
  final DoodleController controller;

  const DoodleCanvas({super.key, required this.controller});

  @override
  State<DoodleCanvas> createState() => _DoodleCanvasState();
}

class _DoodleCanvasState extends State<DoodleCanvas> {
  int? _drawingPointer;
  final Map<int, Offset> _activePointers = {};
  double? _lastPinchDist;
  Offset? _lastFocalPoint;
  bool _isTwoFingerGesture = false;
  double _overlayScaleStart = 1.0;
  Offset? _singlePointerStart;
  bool _isEdgeSwipeBack = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return LayoutBuilder(
      builder: (context, box) {
        c.setViewport(box.maxWidth, box.maxHeight);
        final scale = c.scale;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            _activePointers[e.pointer] = e.localPosition;
            if (_activePointers.length >= 2) {
              // Two or more fingers detected -> activate 2-finger scale/pan mode!
              _isTwoFingerGesture = true;
              _drawingPointer = null;
              c.cancelLiveStroke();

              final pts = _activePointers.values.toList();
              final p1 = pts[0];
              final p2 = pts[1];
              _lastPinchDist = (p1 - p2).distance;
              _lastFocalPoint = (p1 + p2) / 2;

              if (c.selection == null) {
                final mid = _lastFocalPoint!;
                if (!c.hitTestSelect(mid / scale)) {
                  if (!c.hitTestSelect(p1 / scale)) {
                    c.hitTestSelect(p2 / scale);
                  }
                }
              }
            } else if (_activePointers.length == 1) {
              _isTwoFingerGesture = false;
              _drawingPointer = e.pointer;
              _singlePointerStart = e.localPosition;
              _isEdgeSwipeBack = false;
              c.pointerDown(e.localPosition);
            }
          },
          onPointerMove: (e) {
            _activePointers[e.pointer] = e.localPosition;
            if (_isTwoFingerGesture && _activePointers.length >= 2) {
              final pts = _activePointers.values.toList();
              final p1 = pts[0];
              final p2 = pts[1];
              final curDist = (p1 - p2).distance;
              final curFocal = (p1 + p2) / 2;

              if (_lastPinchDist != null && _lastPinchDist! > 1.0 && curDist > 1.0) {
                final factor = (curDist / _lastPinchDist!).clamp(0.65, 1.6);
                c.scaleSelected(factor);
              }
              if (_lastFocalPoint != null) {
                final delta = (curFocal - _lastFocalPoint!) / scale;
                c.moveSelected(delta);
              }
              _lastPinchDist = curDist;
              _lastFocalPoint = curFocal;
            } else if (!_isTwoFingerGesture && e.pointer == _drawingPointer) {
              // Edge swipe back detection: started within 34px of left edge/corner
              if (_singlePointerStart != null && _singlePointerStart!.dx <= 34.0 && !_isEdgeSwipeBack) {
                final dx = e.localPosition.dx - _singlePointerStart!.dx;
                final dy = (e.localPosition.dy - _singlePointerStart!.dy).abs();
                if (dx >= 42.0 && dx > dy * 1.25) {
                  _isEdgeSwipeBack = true;
                  _drawingPointer = null;
                  _singlePointerStart = null;
                  c.cancelLiveStroke();
                  HapticFeedback.lightImpact();
                  Navigator.maybePop(context);
                  return;
                }
              }
              if (!_isEdgeSwipeBack) {
                c.pointerMove(e.localPosition);
              }
            }
          },
          onPointerUp: (e) {
            _activePointers.remove(e.pointer);
            if (_activePointers.length < 2) {
              _isTwoFingerGesture = false;
              _lastPinchDist = null;
              _lastFocalPoint = null;
            }
            if (_activePointers.isEmpty) {
              _singlePointerStart = null;
              _isEdgeSwipeBack = false;
              if (_drawingPointer != null && e.pointer == _drawingPointer) {
                _drawingPointer = null;
                c.pointerUp();
              }
              _drawingPointer = null;
            }
          },
          onPointerCancel: (e) {
            _activePointers.remove(e.pointer);
            if (_activePointers.length < 2) {
              _isTwoFingerGesture = false;
              _lastPinchDist = null;
              _lastFocalPoint = null;
            }
            if (_activePointers.isEmpty) {
              _singlePointerStart = null;
              _isEdgeSwipeBack = false;
              if (_drawingPointer != null && e.pointer == _drawingPointer) {
                _drawingPointer = null;
                c.pointerUp();
              }
              _drawingPointer = null;
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Photo Layer (if selected)
              AnimatedBuilder(
                animation: c.committed,
                builder: (context, _) {
                  final photo = c.backgroundPhoto;
                  if (photo == null || photo.isEmpty) return const SizedBox.shrink();
                  try {
                    final bytes = base64Decode(photo);
                    Widget photoWidget = ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    );
                    if (c.mustErase) {
                      photoWidget = ValueListenableBuilder<double>(
                        valueListenable: c.eraseProgress,
                        builder: (_, p, child) => Opacity(
                          opacity: (1.0 - p * 0.95).clamp(0.0, 1.0),
                          child: child,
                        ),
                        child: photoWidget,
                      );
                    }
                    return Positioned.fill(child: photoWidget);
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                },
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: _CommittedPainter(c, scale),
                  isComplex: true,
                  child: const SizedBox.expand(),
                ),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: _LivePainter(c, scale),
                  child: const SizedBox.expand(),
                ),
              ),

              // Interactive Selection & Transformation Layer (Move anywhere, Resize, Delete)
              AnimatedBuilder(
                animation: c.committed,
                builder: (context, _) {
                  final sel = c.selection;
                  if (sel == null) return const SizedBox.shrink();
                  final r = sel.rect;
                  final left = r.left * scale;
                  final top = r.top * scale;
                  final width = r.width * scale;
                  final height = r.height * scale;

                  return Positioned(
                    left: left,
                    top: top,
                    width: width,
                    height: height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Move & Two-Finger Pinch Resize GestureDetector
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onScaleStart: (details) {
                              _overlayScaleStart = 1.0;
                            },
                            onScaleUpdate: (details) {
                              if (details.pointerCount > 1) {
                                // Two fingers inside selection -> scale resize!
                                if (_overlayScaleStart > 0) {
                                  final factor = (details.scale / _overlayScaleStart).clamp(0.65, 1.6);
                                  c.scaleSelected(factor);
                                }
                                _overlayScaleStart = details.scale;
                                c.moveSelected(details.focalPointDelta / scale);
                              } else {
                                // Single finger drag to move
                                c.moveSelected(details.focalPointDelta / scale);
                              }
                            },
                            onScaleEnd: (details) {
                              _overlayScaleStart = 1.0;
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF00E5FF), width: 2.0),
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFF00E5FF).withOpacity(0.06),
                              ),
                            ),
                          ),
                        ),

                        // Top Floating Action Pill (Delete & Done)
                        Positioned(
                          top: -38,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF181822),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => c.deleteSelected(),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF2A6D),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => c.clearSelection(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E5FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_rounded, size: 13, color: Colors.black),
                                          SizedBox(width: 2),
                                          Text(
                                            'Done',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Corner Scale/Resize Handle (Bottom-Right)
                        Positioned(
                          right: -14,
                          bottom: -14,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (details) {
                              final factor = 1.0 + (details.delta.dx + details.delta.dy) / (math.max(width, 40) * 0.85);
                              c.scaleSelected(factor);
                            },
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.open_in_full_rounded, size: 14, color: Colors.black),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommittedPainter extends CustomPainter {
  final DoodleController c;
  final double scale;
  final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  _CommittedPainter(this.c, this.scale) : super(repaint: c.committed);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);

    for (final s in c.strokes) {
      _paintStroke(canvas, s);
    }
    for (final sh in c.shapes) {
      _paintStroke(canvas, sh.toStroke());
    }
    for (final t in c.texts) {
      if (t.hasBackground) {
        final padH = 14.0;
        final padV = 6.0;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            t.position.dx - padH,
            t.position.dy - padV,
            t.painter.width + padH * 2,
            t.painter.height + padV * 2,
          ),
          const Radius.circular(14),
        );
        canvas.drawRRect(rrect, Paint()..color = t.color..isAntiAlias = true);
      }
      t.painter.paint(canvas, t.position);
    }
    for (final e in c.emojis) {
      CartoonEmojiRenderer.paint(canvas, e, brushColor: c.color);
    }
    canvas.restore();
  }

  void _paintStroke(Canvas canvas, DoodleStroke s) {
    switch (s.brushType) {
      case DoodleBrushType.neon:
        // Instagram Neon Brush: Outer glow pass + inner white core pass
        final glowRadius = (s.size * 0.75).clamp(8.0, 36.0);
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (s.size * 0.9).clamp(6.0, 42.0)
          ..color = s.color.withOpacity(0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius)
          ..isAntiAlias = true;
        canvas.drawPath(s.path, glowPaint);

        final corePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Color.lerp(s.color, Colors.white, 0.82)!
          ..isAntiAlias = true;
        canvas.drawPath(s.path, corePaint);
        break;

      case DoodleBrushType.marker:
        final markerPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = s.color.withOpacity(0.82)
          ..isAntiAlias = true;
        canvas.drawPath(s.path, markerPaint);
        break;

      case DoodleBrushType.highlighter:
        final hlPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = s.color.withOpacity(0.38)
          ..isAntiAlias = true;
        canvas.drawPath(s.path, hlPaint);
        break;

      case DoodleBrushType.pen:
        _fill.color = s.color;
        canvas.drawPath(s.path, _fill);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CommittedPainter old) => old.scale != scale || old.c != c;
}

class _LivePainter extends CustomPainter {
  final DoodleController c;
  final double scale;
  final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  _LivePainter(this.c, this.scale) : super(repaint: c.live);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = c.livePoints;
    if (pts.isNotEmpty) {
      canvas.save();
      canvas.scale(scale);
      final virtSize = c.brushPx / scale;
      final path = buildFreehandPath(pts, virtSize, brushType: c.brushType);

      switch (c.brushType) {
        case DoodleBrushType.neon:
          final glowRadius = (virtSize * 0.75).clamp(8.0, 36.0);
          final glowPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (virtSize * 0.9).clamp(6.0, 42.0)
            ..color = c.color.withOpacity(0.85)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius)
            ..isAntiAlias = true;
          canvas.drawPath(path, glowPaint);

          final corePaint = Paint()
            ..style = PaintingStyle.fill
            ..color = Color.lerp(c.color, Colors.white, 0.82)!
            ..isAntiAlias = true;
          canvas.drawPath(path, corePaint);
          break;

        case DoodleBrushType.marker:
          final markerPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = c.color.withOpacity(0.82)
            ..isAntiAlias = true;
          canvas.drawPath(path, markerPaint);
          break;

        case DoodleBrushType.highlighter:
          final hlPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = c.color.withOpacity(0.38)
            ..isAntiAlias = true;
          canvas.drawPath(path, hlPaint);
          break;

        case DoodleBrushType.pen:
          _fill.color = c.color;
          canvas.drawPath(path, _fill);
          break;
      }
      canvas.restore();
    }

    final pos = c.eraserPos;
    if (pos != null) {
      final center = pos * scale;
      final rad = c.eraserScreenRadius;
      canvas.drawCircle(
        center,
        rad + 3,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        center,
        rad,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
      canvas.drawCircle(
        center,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFFFC72C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LivePainter old) => old.scale != scale || old.c != c;
}
