import 'package:flutter/material.dart';
import 'doodle_stroke.dart';

class DoodleGroup {
  final String id;
  String name;
  String avatarEmoji;
  Color color;
  List<String> memberUsernames;
  DoodleData? latestDoodle;
  DateTime? lastActive;
  int streakCount;

  DoodleGroup({
    required this.id,
    required this.name,
    this.avatarEmoji = '👥',
    this.color = const Color(0xFF6C5CE7),
    required this.memberUsernames,
    this.latestDoodle,
    this.lastActive,
    this.streakCount = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': avatarEmoji,
        'color': color.toARGB32(),
        'members': memberUsernames,
        'streak': streakCount,
      };

  factory DoodleGroup.fromJson(Map<String, dynamic> j) => DoodleGroup(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarEmoji: j['emoji'] as String? ?? '👥',
        color: Color((j['color'] as num?)?.toInt() ?? 0xFF6C5CE7),
        memberUsernames: (j['members'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        streakCount: (j['streak'] as num?)?.toInt() ?? 1,
        lastActive: DateTime.now(),
      );
}
