import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/doodle_stroke.dart';
import '../services/doodle_controller.dart';
import 'doodle_canvas.dart';

class StoryViewerSheet extends StatefulWidget {
  final DoodleData story;
  final String senderName;
  final String senderUsername;
  final String senderEmoji;
  final Color senderColor;
  final String? senderPhoto;
  final VoidCallback? onReply;

  const StoryViewerSheet({
    super.key,
    required this.story,
    required this.senderName,
    required this.senderUsername,
    this.senderEmoji = '🦆',
    this.senderColor = const Color(0xFFFFC72C),
    this.senderPhoto,
    this.onReply,
  });

  static void show(
    BuildContext context, {
    required DoodleData story,
    required String senderName,
    required String senderUsername,
    String senderEmoji = '🦆',
    Color senderColor = const Color(0xFFFFC72C),
    String? senderPhoto,
    VoidCallback? onReply,
  }) {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DoodleUp',
      barrierColor: Colors.black.withValues(alpha: 0.9),
      pageBuilder: (ctx, anim1, anim2) {
        return StoryViewerSheet(
          story: story,
          senderName: senderName,
          senderUsername: senderUsername,
          senderEmoji: senderEmoji,
          senderColor: senderColor,
          senderPhoto: senderPhoto,
          onReply: onReply,
        );
      },
    );
  }

  @override
  State<StoryViewerSheet> createState() => _StoryViewerSheetState();
}

class _StoryViewerSheetState extends State<StoryViewerSheet> with SingleTickerProviderStateMixin {
  late final DoodleController _doodleCtrl;
  late final AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();
    _doodleCtrl = DoodleController();
    _doodleCtrl.load(widget.story, forErasing: false);
    _doodleCtrl.locked = true;

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..forward().then((_) {
        if (mounted) Navigator.maybePop(context);
      });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _doodleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Story Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AnimatedBuilder(
                animation: _progressCtrl,
                builder: (context, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _progressCtrl.value,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFC72C)),
                      minHeight: 3.5,
                    ),
                  );
                },
              ),
            ),

            // Top Header: Sender Profile + Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  // Story Ring Avatar
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFFFFC72C),
                          Color(0xFFFF4081),
                          Color(0xFF6C5CE7),
                          Color(0xFF00CEC9),
                          Color(0xFFFFC72C),
                        ],
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.senderColor,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: widget.senderPhoto != null && widget.senderPhoto!.isNotEmpty
                          ? Image.memory(
                              base64Decode(widget.senderPhoto!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(child: Text(widget.senderEmoji, style: const TextStyle(fontSize: 20))),
                            )
                          : Center(
                              child: Text(widget.senderEmoji, style: const TextStyle(fontSize: 20)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.senderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFC72C), Color(0xFFFF4081)],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'DoodleUp',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '@${widget.senderUsername} • DoodleUp',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Canvas Display with photo and doodle strokes
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161D),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: DoodleCanvas(controller: _doodleCtrl),
                ),
              ),
            ),

            // Bottom Bar: Compulsory Doodle Info & Reply
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Text('🎨', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pure hand-drawn DoodleUp status',
                              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onReply?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC72C),
                      foregroundColor: const Color(0xFF1E1E26),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.reply_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Reply',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
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
}
