import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'doodle_stroke.dart';

class UserProfile {
  String username;
  String phoneOrEmail;
  String bio;
  String avatarEmoji;
  Color avatarColor;
  String? profilePicBase64;
  DoodleData? activeStory;
  DateTime? storyTimestamp;
  bool isDarkMode;
  bool screenshotAlertsEnabled;
  bool hapticEnabled;

  /// Stable device identity so a refresh/reconnect can reclaim the same @username.
  String clientId;

  UserProfile({
    this.username = '',
    this.phoneOrEmail = '',
    this.bio = 'Doodling my thoughts away ✨',
    this.avatarEmoji = '🦆',
    this.avatarColor = const Color(0xFFFFC72C),
    this.profilePicBase64,
    this.activeStory,
    this.storyTimestamp,
    this.isDarkMode = false,
    this.screenshotAlertsEnabled = true,
    this.hapticEnabled = true,
    String? clientId,
  }) : clientId = clientId ?? _newId();

  static String _newId() {
    final r = math.Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  bool get hasActiveStory => activeStory != null;

  String get profileLink => 'https://doodle.app/u/$username';
  String get qrData => 'doodle://user/$username';
}
