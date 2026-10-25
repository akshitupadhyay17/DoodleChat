import 'dart:convert';
import 'package:flutter/material.dart';
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
  int? _pointer;

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
            if (_pointer != null) return;
            _pointer = e.pointer;
            c.pointerDown(e.localPosition);
          },
          onPointerMove: (e) {
            if (e.pointer != _pointer) return;
            c.pointerMove(e.localPosition);
          },
          onPointerUp: (e) {
            if (e.pointer != _pointer) return;
            _pointer = null;
            c.pointerUp();
          },
          onPointerCancel: (e) {
            if (e.pointer != _pointer) return;
            _pointer = null;
            c.pointerUp();
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
                    return Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    );
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
