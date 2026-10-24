import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/doodle_stroke.dart';
import 'story_viewer_sheet.dart';

class DoodleAvatar extends StatelessWidget {
  final String emoji;
  final Color color;
  final String? photoBase64;
  final double radius;
  final bool isOnline;
  final DoodleData? activeStory;
  final String displayName;
  final String username;
  final VoidCallback? onTap;
  final VoidCallback? onStoryReply;

  const DoodleAvatar({
    super.key,
    required this.emoji,
    required this.color,
    this.photoBase64,
    this.radius = 24,
    this.isOnline = false,
    this.activeStory,
    this.displayName = '',
    this.username = '',
    this.onTap,
    this.onStoryReply,
  });

  bool get hasStory => activeStory != null;

  @override
  Widget build(BuildContext context) {
    final avatarSize = radius * 2;

    Widget avatarInner = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: hasStory ? 1.5 : 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoBase64 != null && photoBase64!.isNotEmpty
          ? Image.memory(
              base64Decode(photoBase64!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(emoji, style: TextStyle(fontSize: radius * 0.95)),
              ),
            )
          : Center(
              child: Text(emoji, style: TextStyle(fontSize: radius * 0.95)),
            ),
    );

    Widget avatarWithRing;
    if (hasStory) {
      avatarWithRing = GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          StoryViewerSheet.show(
            context,
            story: activeStory!,
            senderName: displayName.isNotEmpty ? displayName : '@$username',
            senderUsername: username,
            senderEmoji: emoji,
            senderColor: color,
            senderPhoto: photoBase64,
            onReply: onStoryReply,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(3.0),
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
            padding: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: avatarInner,
          ),
        ),
      );
    } else {
      avatarWithRing = GestureDetector(
        onTap: onTap,
        child: avatarInner,
      );
    }

    if (!isOnline) return avatarWithRing;

    return Stack(
      children: [
        avatarWithRing,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.55,
            height: radius * 0.55,
            decoration: BoxDecoration(
              color: const Color(0xFF00B894),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
