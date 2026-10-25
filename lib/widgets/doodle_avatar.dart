import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/doodle_stroke.dart';
import '../models/chat_contact.dart';
import '../services/chat_service.dart';
import '../screens/create_doodle_screen.dart';
import '../theme/app_theme.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget avatarInner = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? AppTheme.darkBackground : Colors.white,
          width: hasStory ? 1.5 : 2,
        ),
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
            onReply: onStoryReply ??
                () {
                  final chatService = ChatService();
                  ChatContact? target;
                  for (final c in chatService.contacts) {
                    if (c.username == username) {
                      target = c;
                      break;
                    }
                  }
                  target ??= ChatContact(
                    id: username,
                    username: username,
                    name: displayName.isNotEmpty ? displayName : '@$username',
                    avatarEmoji: emoji,
                    avatarColor: color,
                    avatarPhotoBase64: photoBase64,
                    activeStory: activeStory,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateDoodleScreen(
                        replyToContact: target,
                        replyToStory: activeStory,
                      ),
                    ),
                  );
                },
          );
        },
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                AppTheme.electricPink,
                AppTheme.cyberViolet,
                AppTheme.electricCyan,
                AppTheme.neonYellow,
                AppTheme.electricPink,
              ],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBackground : Colors.white,
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
      clipBehavior: Clip.none,
      children: [
        avatarWithRing,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.52,
            height: radius * 0.52,
            decoration: BoxDecoration(
              color: AppTheme.acidLime,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppTheme.darkBackground : Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
