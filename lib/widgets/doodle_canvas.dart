import 'package:flutter/material.dart';
import '../models/doodle_stroke.dart';
import '../services/doodle_controller.dart';

/// High-performance doodle surface.
///  * Layer 1 (committed): finished strokes/text/emoji – repaints only when they change.
///  * Layer 2 (live): the stroke under your finger + eraser ring – repaints per touch event.
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
      _fill.color = s.color;
      canvas.drawPath(s.path, _fill);
    }
    for (final t in c.texts) {
      t.painter.paint(canvas, t.position);
    }
    for (final e in c.emojis) {
      e.painter.paint(canvas, e.position);
    }
    canvas.restore();
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
      _fill.color = c.color;
      canvas.drawPath(buildFreehandPath(pts, c.brushPx / scale), _fill);
      canvas.restore();
    }

    final pos = c.eraserPos;
    if (pos != null) {
      final center = pos * scale;
      canvas.drawCircle(
        center,
        DoodleController.eraserScreenRadius + 3,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        center,
        DoodleController.eraserScreenRadius,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
      canvas.drawCircle(
        center,
        DoodleController.eraserScreenRadius,
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
