import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Modal dialog that gives users full control to crop, resize, zoom, and frame their profile picture.
/// Does NOT auto-crop upon opening: the photo is initially presented in its full aspect ratio as chosen,
/// and the user sizes and crops it as intended.
class SquareImageCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const SquareImageCropperDialog({super.key, required this.imageBytes});

  @override
  State<SquareImageCropperDialog> createState() => _SquareImageCropperDialogState();
}

class _SquareImageCropperDialogState extends State<SquareImageCropperDialog> {
  ui.Image? _rawImage;
  bool _isLoading = true;
  String? _error;

  final GlobalKey _previewKey = GlobalKey();
  final TransformationController _transformCtrl = TransformationController();
  int _rotationQuarterTurns = 0; // 0, 1, 2, 3 (each is 90°)

  static const double _kCropBoxSize = 280.0;
  static const int _kOutputSize = 512;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _decodeImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _rawImage = frame.image;
        _isLoading = false;
      });
      // Do NOT auto-crop: fit the entire original photo uncropped
      _resetFit(fill: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load image: $e';
        _isLoading = false;
      });
    }
  }

  /// Centers the image in the crop box.
  /// When [fill] is false (default): fits the ENTIRE photo with zero pre-cropping (BoxFit.contain).
  /// When [fill] is true: scales up to fill the square box (BoxFit.cover).
  void _resetFit({bool fill = false}) {
    if (_rawImage == null) return;
    final isRotated = _rotationQuarterTurns % 2 == 1;
    final w = (isRotated ? _rawImage!.height : _rawImage!.width).toDouble();
    final h = (isRotated ? _rawImage!.width : _rawImage!.height).toDouble();

    final baseScale = fill
        ? math.max(_kCropBoxSize / w, _kCropBoxSize / h)
        : math.min(_kCropBoxSize / w, _kCropBoxSize / h);

    final dx = (_kCropBoxSize - w * baseScale) / 2;
    final dy = (_kCropBoxSize - h * baseScale) / 2;

    final matrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(baseScale);

    _transformCtrl.value = matrix;
    setState(() {});
  }

  void _rotate90() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
    // Re-adjust fit for the rotated aspect ratio without auto-cropping
    _resetFit(fill: false);
  }

  void _zoom(double factor) {
    final current = _transformCtrl.value;
    final center = const Offset(_kCropBoxSize / 2, _kCropBoxSize / 2);

    final matrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(factor)
      ..translate(-center.dx, -center.dy)
      ..multiply(current);

    _transformCtrl.value = matrix;
    setState(() {});
  }

  /// Exports the exact crop as sized and positioned by the user.
  Future<void> _saveCrop() async {
    if (_rawImage == null) return;

    try {
      // 1. First attempt: pixel-perfect RepaintBoundary snapshot of the user's framed preview
      try {
        final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final pixelRatio = _kOutputSize / _kCropBoxSize;
          final img = await boundary.toImage(pixelRatio: pixelRatio);
          final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final base64Result = base64Encode(byteData.buffer.asUint8List());
            if (mounted) {
              Navigator.of(context).pop(base64Result);
              return;
            }
          }
        }
      } catch (_) {
        // Fall back to Canvas recording
      }

      // 2. Direct Canvas recording fallback
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, _kOutputSize.toDouble(), _kOutputSize.toDouble()),
      );

      // Clean dark background for letterboxed areas
      canvas.drawRect(
        Rect.fromLTWH(0, 0, _kOutputSize.toDouble(), _kOutputSize.toDouble()),
        Paint()..color = const Color(0xFF14141E),
      );

      final outputScale = _kOutputSize / _kCropBoxSize;
      canvas.scale(outputScale, outputScale);
      canvas.transform(_transformCtrl.value.storage);

      // Apply rotation matching RotatedBox layout
      switch (_rotationQuarterTurns) {
        case 1:
          canvas.translate(_rawImage!.height.toDouble(), 0);
          canvas.rotate(math.pi / 2);
          break;
        case 2:
          canvas.translate(_rawImage!.width.toDouble(), _rawImage!.height.toDouble());
          canvas.rotate(math.pi);
          break;
        case 3:
          canvas.translate(0, _rawImage!.width.toDouble());
          canvas.rotate(3 * math.pi / 2);
          break;
      }

      final paint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      canvas.drawImage(_rawImage!, Offset.zero, paint);

      final picture = recorder.endRecording();
      final croppedImg = await picture.toImage(_kOutputSize, _kOutputSize);
      final byteData = await croppedImg.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) throw Exception('Image encoding failed');
      final base64Result = base64Encode(byteData.buffer.asUint8List());

      if (mounted) {
        Navigator.of(context).pop(base64Result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save photo: $e')),
        );
      }
    }
  }

  /// Directly saves the original chosen photo without any square cropping.
  void _useOriginal() {
    final base64Result = base64Encode(widget.imageBytes);
    Navigator.of(context).pop(base64Result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14141E) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.electricPink.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.crop_rounded, color: AppTheme.electricPink, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Size & Crop Photo',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF14141E),
                          ),
                        ),
                        Text(
                          'Pinch, zoom, or drag to size your avatar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF8A90A6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // Viewport & Cropper Frame
            Container(
              height: 320,
              width: double.infinity,
              color: const Color(0xFF0C0D14),
              alignment: Alignment.center,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.electricPink))
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            // Interactive pan/zoom area (Captured without overlay borders)
                            SizedBox(
                              width: _kCropBoxSize,
                              height: _kCropBoxSize,
                              child: RepaintBoundary(
                                key: _previewKey,
                                child: ClipRect(
                                  child: Container(
                                    color: const Color(0xFF14141E),
                                    child: InteractiveViewer(
                                      transformationController: _transformCtrl,
                                      minScale: 0.1,
                                      maxScale: 8.0,
                                      boundaryMargin: const EdgeInsets.all(400),
                                      child: RotatedBox(
                                        quarterTurns: _rotationQuarterTurns,
                                        child: RawImage(
                                          image: _rawImage,
                                          fit: BoxFit.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Guide Overlay (Cyan border, circular avatar boundary, and rule-of-thirds grid)
                            IgnorePointer(
                              child: Container(
                                width: _kCropBoxSize,
                                height: _kCropBoxSize,
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Stack(
                                  children: [
                                    // Circular avatar guide
                                    Center(
                                      child: Container(
                                        width: _kCropBoxSize - 16,
                                        height: _kCropBoxSize - 16,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.4),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Rule-of-thirds grid lines
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Divider(color: Colors.white.withOpacity(0.18), height: 1),
                                        Divider(color: Colors.white.withOpacity(0.18), height: 1),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        VerticalDivider(color: Colors.white.withOpacity(0.18), width: 1),
                                        VerticalDivider(color: Colors.white.withOpacity(0.18), width: 1),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
            ),

            // Adjustment Toolbar (Rotate, Fit Whole, Fill Square, Zoom -, Zoom +)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildToolAction(
                    icon: Icons.rotate_right_rounded,
                    label: 'Rotate',
                    isDark: isDark,
                    onTap: _rotate90,
                  ),
                  _buildToolAction(
                    icon: Icons.aspect_ratio_rounded,
                    label: 'Fit Whole',
                    isDark: isDark,
                    onTap: () => _resetFit(fill: false),
                  ),
                  _buildToolAction(
                    icon: Icons.crop_square_rounded,
                    label: 'Fill Square',
                    isDark: isDark,
                    onTap: () => _resetFit(fill: true),
                  ),
                  _buildToolAction(
                    icon: Icons.zoom_out_rounded,
                    label: 'Zoom -',
                    isDark: isDark,
                    onTap: () => _zoom(0.85),
                  ),
                  _buildToolAction(
                    icon: Icons.zoom_in_rounded,
                    label: 'Zoom +',
                    isDark: isDark,
                    onTap: () => _zoom(1.15),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // Bottom Actions (Cancel, Use Full Photo, Save Crop)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : const Color(0xFF5D6275),
                      ),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    onPressed: _useOriginal,
                    child: Text(
                      'Use Full Photo',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: isDark ? Colors.white : const Color(0xFF14141E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.electricPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _saveCrop,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      'Save Crop',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolAction({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white70 : const Color(0xFF333344)),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF9094A6) : const Color(0xFF5D6275),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
