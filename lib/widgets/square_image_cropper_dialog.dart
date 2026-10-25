import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Modal dialog that allows users to crop, zoom, pan, and rotate an image into a 1:1 square
/// before saving as their avatar profile picture.
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
      _resetFit();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load image: $e';
        _isLoading = false;
      });
    }
  }

  void _resetFit() {
    if (_rawImage == null) return;
    final w = _rawImage!.width.toDouble();
    final h = _rawImage!.height.toDouble();

    // Scale so the smaller dimension fills the crop box
    final baseScale = math.max(_kCropBoxSize / w, _kCropBoxSize / h);
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

  Future<void> _saveCrop() async {
    if (_rawImage == null) return;

    try {
      // Create a 512x512 canvas to render the exact cropped portion
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, _kOutputSize.toDouble(), _kOutputSize.toDouble()),
      );

      // Scale up from the 280px preview box to 512px output
      final outputScale = _kOutputSize / _kCropBoxSize;
      canvas.scale(outputScale, outputScale);

      // Apply the user's interactive pan/zoom transformation matrix
      canvas.transform(_transformCtrl.value.storage);

      // Apply 90° rotations if any around image center
      if (_rotationQuarterTurns != 0) {
        final imgCenterX = _rawImage!.width / 2.0;
        final imgCenterY = _rawImage!.height / 2.0;
        canvas.translate(imgCenterX, imgCenterY);
        canvas.rotate(_rotationQuarterTurns * math.pi / 2);
        canvas.translate(-imgCenterX, -imgCenterY);
      }

      // Draw the original raw image with high filter quality
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
          SnackBar(content: Text('Failed to crop photo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
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
                          'Crop Profile Picture',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF14141E),
                          ),
                        ),
                        Text(
                          'Pinch or drag to fit your avatar',
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
              color: Colors.black,
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
                            // Interactive pan/zoom area
                            SizedBox(
                              width: _kCropBoxSize,
                              height: _kCropBoxSize,
                              child: ClipRect(
                                child: InteractiveViewer(
                                  transformationController: _transformCtrl,
                                  minScale: 0.2,
                                  maxScale: 6.0,
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

                            // Circular & Square Avatar Cutout Guide Overlay
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
                                    // Rule-of-thirds grid
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

            // Adjustment Toolbar (Rotate, Zoom In, Zoom Out, Reset)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  _buildToolAction(
                    icon: Icons.center_focus_strong_rounded,
                    label: 'Center',
                    isDark: isDark,
                    onTap: _resetFit,
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // Bottom Actions (Cancel & Save)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF5D6275),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.electricPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _saveCrop,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        'Save Photo',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
