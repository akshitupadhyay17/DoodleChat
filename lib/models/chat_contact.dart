import 'package:flutter/material.dart';
import 'doodle_stroke.dart';

enum DoodleChatStatus {
  idle, // Ready to draw and send
  sentWaitingForErase, // You sent one, friend must erase it before next
  receivedMustErase, // Friend sent one, you MUST erase it before replying
}

enum FriendshipStatus {
  accepted, // Mutual doodle friends! Can doodle back and forth.
  requestSent, // You sent a request to them, waiting for them to accept.
  requestReceived, // They sent a request to you, waiting for your approval.
}

class ChatContact {
  final String id;
  final String name;
  final String username;
  final String avatarEmoji;
  final Color avatarColor;
  bool isOnline;
  final String statusBio;
  String lastActive;
  DoodleChatStatus doodleStatus;
  FriendshipStatus friendshipStatus;
  DoodleData? pendingDoodle;
  String chatTheme;

  /// Offline demo contact (not networked).
  final bool isDemo;

  /// Live presence from the friend (real-time), isolated notifiers.
  final ValueNotifier<bool> peerDrawing = ValueNotifier<bool>(false);
  final ValueNotifier<double> peerEraseProgress = ValueNotifier<double>(0);

  ChatContact({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarEmoji,
    required this.avatarColor,
    this.isOnline = true,
    this.statusBio = "Doodling something cool 🎨",
    this.lastActive = "Just now",
    this.doodleStatus = DoodleChatStatus.idle,
    this.friendshipStatus = FriendshipStatus.accepted,
    this.pendingDoodle,
    this.chatTheme = 'Default',
    this.isDemo = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'emoji': avatarEmoji,
        'color': avatarColor.toARGB32(),
        'bio': statusBio,
        'theme': chatTheme,
        'friendship': friendshipStatus.name,
      };

  factory ChatContact.fromJson(Map<String, dynamic> j) => ChatContact(
        id: j['id'] as String,
        name: j['name'] as String,
        username: j['username'] as String,
        avatarEmoji: j['emoji'] as String? ?? '🦆',
        avatarColor: Color((j['color'] as num?)?.toInt() ?? 0xFFFFC72C),
        statusBio: j['bio'] as String? ?? '',
        chatTheme: j['theme'] as String? ?? 'Default',
        friendshipStatus: FriendshipStatus.values.firstWhere(
          (e) => e.name == j['friendship'],
          orElse: () => FriendshipStatus.accepted,
        ),
        isOnline: false,
        lastActive: 'Saved',
      );
}
