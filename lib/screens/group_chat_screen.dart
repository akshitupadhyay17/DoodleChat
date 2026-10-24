import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/doodle_group.dart';
import '../services/chat_service.dart';
import '../services/doodle_controller.dart';
import '../widgets/doodle_canvas.dart';
import 'create_doodle_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final DoodleGroup group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final ChatService _service = ChatService();
  late final DoodleController _doodleCtrl;

  @override
  void initState() {
    super.initState();
    _doodleCtrl = DoodleController();
    if (widget.group.latestDoodle != null) {
      _doodleCtrl.load(widget.group.latestDoodle!, forErasing: false);
      _doodleCtrl.locked = true;
    }
    _service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    final current = _service.groups.firstWhere(
      (g) => g.id == widget.group.id,
      orElse: () => widget.group,
    );
    if (current.latestDoodle != null && current.latestDoodle?.id != _doodleCtrl.toData('x').id) {
      setState(() {
        _doodleCtrl.load(current.latestDoodle!, forErasing: false);
        _doodleCtrl.locked = true;
      });
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _doodleCtrl.dispose();
    super.dispose();
  }

  void _showAddMemberDialog() {
    final availableFriends = _service.contacts.where((c) => !widget.group.memberUsernames.contains(c.username)).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add to ${widget.group.name}', style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                if (availableFriends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('All your friends are already in this group!', style: GoogleFonts.outfit(color: Colors.grey)),
                    ),
                  )
                else
                  ...availableFriends.map((f) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: f.avatarColor,
                          child: Text(f.avatarEmoji),
                        ),
                        title: Text(f.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        subtitle: Text('@${f.username}'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            _service.addMemberToGroup(widget.group.id, f.username);
                            setState(() {});
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('@${f.username} added to ${widget.group.name}!')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC72C),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Add'),
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final group = widget.group;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF16161D) : const Color(0xFFF9F9FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E26) : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: group.color.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(color: group.color, width: 2),
              ),
              child: Center(child: Text(group.avatarEmoji, style: const TextStyle(fontSize: 20))),
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
                          group.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 10)),
                            Text(
                              '${group.streakCount}',
                              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFFF7675)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${group.memberUsernames.length} members: ${group.memberUsernames.map((u) => '@$u').join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Color(0xFFFFC72C)),
            tooltip: 'Add member',
            onPressed: _showAddMemberDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Canvas Display / Placeholder
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: group.latestDoodle == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(group.avatarEmoji, style: const TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                'Group Canvas is Empty',
                                style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Be the first to drop a doodle or DoodleUp in ${group.name}!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : DoodleCanvas(controller: _doodleCtrl),
              ),
            ),
          ),

          // Bottom Bar: Doodle Now
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateDoodleScreen(initialGroupId: group.id),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC72C),
                  foregroundColor: const Color(0xFF1E1E26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.brush_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Doodle in ${group.name} 🎨',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
