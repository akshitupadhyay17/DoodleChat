import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_contact.dart';
import '../services/chat_service.dart';
import '../services/doodle_controller.dart';
import '../widgets/doodle_canvas.dart';
import 'chat_screen.dart';

/// Standalone doodle creator: draw freely, then hit send to pick a friend from the list!
class CreateDoodleScreen extends StatefulWidget {
  const CreateDoodleScreen({super.key});

  @override
  State<CreateDoodleScreen> createState() => _CreateDoodleScreenState();
}

class _CreateDoodleScreenState extends State<CreateDoodleScreen> {
  final DoodleController _doodle = DoodleController();
  final ChatService _service = ChatService();
  final TextEditingController _textCtrl = TextEditingController();

  final List<Color> _colors = const [
    Color(0xFFFFC72C), // Duck yellow
    Color(0xFFFF4081), // Pink
    Color(0xFF00CEC9), // Cyan
    Color(0xFF55EFC4), // Mint
    Color(0xFF6C5CE7), // Lavender
    Color(0xFFFF7675), // Coral
    Color(0xFFFFFFFF), // White
    Color(0xFF2D3436), // Charcoal
  ];

  final List<String> _quickEmojis = ['🦆', '❤️', '🔥', '✨', '🌸', '⚡️', '😂', '👑', '🎉', '👋'];

  @override
  void dispose() {
    _doodle.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _onSendTapped() {
    if (_doodle.isEmpty) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Draw a doodle on the canvas before sending! 🎨',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFFF4081),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    _showSelectFriendSheet();
  }

  void _showSelectFriendSheet() {
    final friends = _service.contacts
        .where((c) => c.friendshipStatus == FriendshipStatus.accepted)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🦆', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Text(
                              'Send Doodle To',
                              style: GoogleFonts.gaegu(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a friend to receive your handwritten sketch:',
                      style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    if (friends.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Column(
                            children: [
                              const Text('🎨', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 8),
                              Text(
                                'No approved friends yet!',
                                style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Send a friend request first or practice with Maya (demo)',
                                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: friends.length,
                          separatorBuilder: (_, child) => const Divider(height: 1, indent: 64),
                          itemBuilder: (ctx, i) {
                            final friend = friends[i];
                            final isWaitingErase =
                                friend.doodleStatus == DoodleChatStatus.sentWaitingForErase;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                              leading: Stack(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: friend.avatarColor.withValues(alpha: 0.25),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: friend.avatarColor, width: 2),
                                    ),
                                    child: Center(
                                      child: Text(friend.avatarEmoji,
                                          style: const TextStyle(fontSize: 24)),
                                    ),
                                  ),
                                  if (friend.isOnline)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00B894),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    friend.name,
                                    style: GoogleFonts.outfit(
                                        fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFFF7675).withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('🔥', style: TextStyle(fontSize: 11)),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${friend.streakCount}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFFF7675),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '@${friend.username}',
                                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                              ),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  final data = _doodle.toData('me');
                                  final ok = _service.sendDoodle(friend.id, data);
                                  Navigator.pop(ctx); // pop sheet
                                  if (ok) {
                                    HapticFeedback.heavyImpact();
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(contact: friend),
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Doodle sent to @${friend.username}! 🔥 Streak: ${friend.streakCount}',
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                        ),
                                        backgroundColor: const Color(0xFF00B894),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isWaitingErase
                                              ? '@${friend.username} hasn\'t erased your last doodle yet! 🧽'
                                              : 'Could not deliver doodle right now.',
                                        ),
                                        backgroundColor: const Color(0xFFFF4081),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isWaitingErase
                                      ? Colors.grey.shade400
                                      : const Color(0xFFFFC72C),
                                  foregroundColor: const Color(0xFF1E1E26),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  isWaitingErase ? 'Waiting ⏳' : 'Send 🚀',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEmojiSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stamp Emojis', style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _quickEmojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      _doodle.addEmoji(emoji);
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTextToDoodleDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Handwritten Text ✨', style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _textCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type words to convert into doodle...',
              hintStyle: GoogleFonts.outfit(fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = _textCtrl.text.trim();
                if (text.isNotEmpty) {
                  _doodle.addText(text, 'PatrickHand');
                  _textCtrl.clear();
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC72C)),
              child: const Text('Place ✍️', style: TextStyle(color: Color(0xFF1E1E26), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14141B) : const Color(0xFFFFFDF8),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Close, Title, Clear, Send 🚀
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Quick Doodle',
                    style: GoogleFonts.gaegu(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E1E26),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                    tooltip: 'Clear canvas',
                    onPressed: () {
                      _doodle.clear();
                      HapticFeedback.lightImpact();
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _onSendTapped,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC72C),
                      foregroundColor: const Color(0xFF1E1E26),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Send 🚀', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Canvas Surface
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: DoodleCanvas(controller: _doodle),
                ),
              ),
            ),

            // Bottom Toolbars: Colors & Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  // Color Palette Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _colors.map((c) {
                      final isSelected = _doodle.color == c && !_doodle.eraser;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _doodle.setEraser(false);
                            _doodle.setColor(c);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: isSelected ? 34 : 28,
                          height: isSelected ? 34 : 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.3),
                              width: isSelected ? 3 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: c.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Actions: Brush Size, Eraser, Emoji Stamp, Text-to-doodle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Brush Size Toggle
                      IconButton(
                        icon: const Icon(Icons.line_weight_rounded),
                        tooltip: 'Brush size',
                        onPressed: () {
                          final current = _doodle.brushPx;
                          final next = current <= 4.0 ? 8.0 : (current <= 10.0 ? 18.0 : 4.0);
                          setState(() => _doodle.brushPx = next);
                          HapticFeedback.selectionClick();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Brush size: ${next <= 4 ? 'Fine' : (next <= 10 ? 'Medium' : 'Thick')} 🖌️'),
                              duration: const Duration(milliseconds: 900),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      // Eraser Toggle
                      IconButton(
                        icon: Icon(
                          Icons.cleaning_services_rounded,
                          color: _doodle.eraser ? const Color(0xFFFF4081) : Colors.grey,
                        ),
                        tooltip: 'Eraser',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _doodle.setEraser(!_doodle.eraser));
                        },
                      ),
                      // Emoji Stamp
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFFFFC72C)),
                        tooltip: 'Add emoji stamp',
                        onPressed: _showEmojiSheet,
                      ),
                      // Handwriting Text
                      IconButton(
                        icon: const Icon(Icons.text_fields_rounded, color: Color(0xFF00CEC9)),
                        tooltip: 'Add text',
                        onPressed: _showTextToDoodleDialog,
                      ),
                    ],
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
