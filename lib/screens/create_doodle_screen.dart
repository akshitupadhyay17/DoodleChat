import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_contact.dart';
import '../services/chat_service.dart';
import '../services/doodle_controller.dart';
import '../widgets/doodle_canvas.dart';
import '../widgets/doodle_avatar.dart';

/// Standalone doodle creator: DoodleUp!
/// Draw freely, load a photo (compulsory to doodle on it!), then hit "Select ➜"
/// to choose friends, groups, or post to your DoodleUp Story!
class CreateDoodleScreen extends StatefulWidget {
  final String? initialGroupId;

  const CreateDoodleScreen({super.key, this.initialGroupId});

  @override
  State<CreateDoodleScreen> createState() => _CreateDoodleScreenState();
}

class _CreateDoodleScreenState extends State<CreateDoodleScreen> {
  final DoodleController _doodle = DoodleController();
  final ChatService _service = ChatService();
  final TextEditingController _textCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

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
  void initState() {
    super.initState();
    _doodle.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _doodle.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        imageQuality: 80,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final base64Str = base64Encode(bytes);
      setState(() {
        _doodle.setBackgroundPhoto(base64Str);
      });
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo loaded! It\'s compulsory to draw a doodle on it before sending 🎨',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFFF4081),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open photo: $e')),
        );
      }
    }
  }

  void _onSendTapped() {
    final hasPhoto = _doodle.backgroundPhoto != null && _doodle.backgroundPhoto!.isNotEmpty;
    final hasDoodle = _doodle.strokes.isNotEmpty || _doodle.texts.isNotEmpty || _doodle.emojis.isNotEmpty;

    // Compulsory check: if photo is added, doodling is compulsory!
    if (hasPhoto && !hasDoodle) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Compulsory: Draw a doodle on your photo before sending! 🎨',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFFF4081),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_doodle.isEmpty) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Draw a doodle on the canvas before hitting Send! 🎨',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFFF4081),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    _showSelectRecipientsSheet();
  }

  void _showCreateGroupDialog(BuildContext sheetCtx) {
    final nameCtrl = TextEditingController();
    String selectedEmoji = '🎨';
    final friends = _service.contacts.where((c) => c.friendshipStatus == FriendshipStatus.accepted).toList();
    final selectedUsernames = <String>{};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Text(selectedEmoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 8),
                  Text('New Doodle Group', style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Group name (e.g. Doodle Squad)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Select Emoji Icon:', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['🎨', '⚡️', '🐥', '🔥', '👑', '🚀'].map((em) {
                        return GestureDetector(
                          onTap: () => setDlgState(() => selectedEmoji = em),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: selectedEmoji == em ? const Color(0xFFFFC72C).withValues(alpha: 0.3) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedEmoji == em ? const Color(0xFFFFC72C) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Text(em, style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Text('Add Friends:', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (friends.isEmpty)
                      Text('No friends to add yet. You will be the first member!', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey))
                    else
                      ...friends.map((f) {
                        final isSelected = selectedUsernames.contains(f.username);
                        return CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(f.name, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('@${f.username}', style: const TextStyle(fontSize: 11)),
                          onChanged: (val) {
                            setDlgState(() {
                              if (val == true) {
                                selectedUsernames.add(f.username);
                              } else {
                                selectedUsernames.remove(f.username);
                              }
                            });
                          },
                        );
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    _service.createGroup(name, selectedEmoji, selectedUsernames.toList());
                    Navigator.pop(ctx);
                    Navigator.pop(sheetCtx); // re-open sheet
                    _showSelectRecipientsSheet();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Group "$name" created! 👥')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC72C),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Create Group'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSelectRecipientsSheet() {
    final allFriends = _service.contacts.where((c) => c.friendshipStatus == FriendshipStatus.accepted).toList();
    final allGroups = _service.groups;

    final selectedContactIds = <String>{};
    final selectedGroupIds = <String>{};
    if (widget.initialGroupId != null && allGroups.any((g) => g.id == widget.initialGroupId)) {
      selectedGroupIds.add(widget.initialGroupId!);
    }
    bool postToStory = false;
    String searchQuery = '';
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchQuery.trim().toLowerCase();
            final filteredFriends = allFriends.where((f) {
              if (query.isEmpty) return true;
              return f.name.toLowerCase().contains(query) || f.username.toLowerCase().contains(query);
            }).toList();

            final filteredGroups = allGroups.where((g) {
              if (query.isEmpty) return true;
              return g.name.toLowerCase().contains(query);
            }).toList();

            final totalRecipients = selectedContactIds.length + selectedGroupIds.length + (postToStory ? 1 : 0);

            final allFilteredSelected = filteredFriends.isNotEmpty &&
                filteredFriends.every((f) => selectedContactIds.contains(f.id));

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Handle bar
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),

                    // Top Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC72C).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text('👥', style: TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Contacts',
                                    style: GoogleFonts.gaegu(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1E1E26),
                                    ),
                                  ),
                                  Text(
                                    'Select friends or groups to send your DoodleUp',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Search Field
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF282834) : const Color(0xFFF1F2F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (val) {
                            setSheetState(() => searchQuery = val);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search contacts or @username...',
                            hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                            prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      setSheetState(() => searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ),

                    // Quick Actions Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      child: Row(
                        children: [
                          // Select All Friends Chip
                          if (filteredFriends.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setSheetState(() {
                                  if (allFilteredSelected) {
                                    for (final f in filteredFriends) {
                                      selectedContactIds.remove(f.id);
                                    }
                                  } else {
                                    for (final f in filteredFriends) {
                                      selectedContactIds.add(f.id);
                                    }
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: allFilteredSelected
                                      ? const Color(0xFFFFC72C).withValues(alpha: 0.25)
                                      : (isDark ? const Color(0xFF282834) : const Color(0xFFF1F2F6)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: allFilteredSelected ? const Color(0xFFFFC72C) : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      allFilteredSelected ? Icons.check_circle_rounded : Icons.checklist_rounded,
                                      size: 15,
                                      color: allFilteredSelected ? const Color(0xFFFFC72C) : Colors.grey,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      allFilteredSelected ? 'Deselect All Contacts' : 'Select All Contacts',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: allFilteredSelected
                                            ? (isDark ? Colors.white : const Color(0xFF1E1E26))
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const Spacer(),
                          // Create Group button
                          GestureDetector(
                            onTap: () => _showCreateGroupDialog(ctx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.group_add_rounded, size: 14, color: Color(0xFF6C5CE7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+ New Group',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6C5CE7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 16),

                    // Scrollable List of Recipients
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        children: [
                          // 1. DoodleUp Story Toggle Card
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setSheetState(() => postToStory = !postToStory);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: postToStory
                                      ? [
                                          const Color(0xFFFFC72C).withValues(alpha: 0.25),
                                          const Color(0xFFFF4081).withValues(alpha: 0.15),
                                        ]
                                      : [
                                          isDark ? const Color(0xFF282834) : const Color(0xFFF7F8FA),
                                          isDark ? const Color(0xFF282834) : const Color(0xFFF7F8FA),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: postToStory ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.25),
                                  width: postToStory ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
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
                                    child: const Center(child: Text('🌟', style: TextStyle(fontSize: 18))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'My DoodleUp Story',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF1E1E26),
                                          ),
                                        ),
                                        Text(
                                          'Appears as a status ring around your avatar ⭕️',
                                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: postToStory ? const Color(0xFFFFC72C) : Colors.transparent,
                                      border: Border.all(
                                        color: postToStory ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.5),
                                        width: 2,
                                      ),
                                    ),
                                    child: postToStory
                                        ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 2. CONTACTS SECTION
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'CONTACTS (${filteredFriends.length})',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: Colors.grey,
                                ),
                              ),
                              if (selectedContactIds.isNotEmpty)
                                Text(
                                  '${selectedContactIds.length} selected',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFFC72C),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          if (allFriends.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'No approved friends yet. Add friends first!',
                                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            )
                          else if (filteredFriends.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'No friends match "$searchQuery"',
                                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ...filteredFriends.map((friend) {
                              final isSelected = selectedContactIds.contains(friend.id);
                              final hasPending = friend.doodleStatus == DoodleChatStatus.sentWaitingForErase;

                              return InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() {
                                    if (isSelected) {
                                      selectedContactIds.remove(friend.id);
                                    } else {
                                      selectedContactIds.add(friend.id);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFFC72C).withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFFFC72C).withValues(alpha: 0.4) : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Checkbox
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 160),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? const Color(0xFFFFC72C) : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.45),
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),

                                      // Avatar
                                      DoodleAvatar(
                                        emoji: friend.avatarEmoji,
                                        color: friend.avatarColor,
                                        radius: 20,
                                        displayName: friend.name,
                                        username: friend.username,
                                      ),
                                      const SizedBox(width: 12),

                                      // Name & username
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    friend.name,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : const Color(0xFF1E1E26),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text('🔥 ${friend.streakCount}', style: const TextStyle(fontSize: 11, color: Color(0xFFFF7675))),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Text('@${friend.username}', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                                                if (hasPending) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '⏳ Pending erase',
                                                      style: GoogleFonts.outfit(fontSize: 9, color: Colors.amber.shade700, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                          const SizedBox(height: 18),

                          // 3. GROUPS SECTION
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'GROUPS (${filteredGroups.length})',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: Colors.grey,
                                ),
                              ),
                              if (selectedGroupIds.isNotEmpty)
                                Text(
                                  '${selectedGroupIds.length} selected',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF6C5CE7),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          if (allGroups.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No groups yet. Tap "+ New Group" above to create one!',
                                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                              ),
                            )
                          else if (filteredGroups.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No groups match "$searchQuery"',
                                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                              ),
                            )
                          else
                            ...filteredGroups.map((grp) {
                              final isSelected = selectedGroupIds.contains(grp.id);

                              return InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() {
                                    if (isSelected) {
                                      selectedGroupIds.remove(grp.id);
                                    } else {
                                      selectedGroupIds.add(grp.id);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF6C5CE7).withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF6C5CE7).withValues(alpha: 0.4) : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Checkbox
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 160),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? const Color(0xFF6C5CE7) : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey.withValues(alpha: 0.45),
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),

                                      // Avatar
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: grp.color.withValues(alpha: 0.25),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: grp.color, width: 2),
                                        ),
                                        child: Center(child: Text(grp.avatarEmoji, style: const TextStyle(fontSize: 18))),
                                      ),
                                      const SizedBox(width: 12),

                                      // Name & details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    grp.name,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : const Color(0xFF1E1E26),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text('🔥 ${grp.streakCount}', style: const TextStyle(fontSize: 11, color: Color(0xFFFF7675))),
                                              ],
                                            ),
                                            Text(
                                              '${grp.memberUsernames.length} members',
                                              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),

                    // Sticky Bottom Send Action Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: totalRecipients == 0
                              ? null
                              : () {
                                  final data = _doodle.toData(_service.currentUser.username);
                                  int sentCount = 0;

                                  // Send to selected contacts
                                  for (final contactId in selectedContactIds) {
                                    if (_service.sendDoodle(contactId, data)) {
                                      sentCount++;
                                    }
                                  }

                                  // Send to selected groups
                                  for (final groupId in selectedGroupIds) {
                                    if (_service.sendGroupDoodle(groupId, data)) {
                                      sentCount++;
                                    }
                                  }

                                  // Post to story if chosen
                                  if (postToStory) {
                                    _service.postDoodleUpStory(data);
                                  }

                                  HapticFeedback.heavyImpact();
                                  Navigator.pop(ctx); // Close recipients sheet
                                  Navigator.pop(context); // Close DoodleUp back to home

                                  final message = StringBuffer('DoodleUp sent to $sentCount recipient${sentCount == 1 ? '' : 's'}');
                                  if (postToStory) {
                                    message.write(' & posted to your Story 🌟');
                                  } else {
                                    message.write('! 🚀');
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        message.toString(),
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                      ),
                                      backgroundColor: const Color(0xFF00B894),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC72C),
                            foregroundColor: const Color(0xFF1E1E26),
                            disabledBackgroundColor: isDark ? const Color(0xFF282834) : Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey,
                            elevation: totalRecipients > 0 ? 3 : 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.send_rounded,
                                size: 18,
                                color: totalRecipients > 0 ? const Color(0xFF1E1E26) : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                totalRecipients == 0
                                    ? 'Select contacts to send'
                                    : 'Send to $totalRecipients recipient${totalRecipients > 1 ? 's' : ''} 🚀',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: totalRecipients > 0 ? const Color(0xFF1E1E26) : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                    Text('Choose Emoji Stamp', style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _quickEmojis.map((e) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => _doodle.stampEmoji = e);
                        Navigator.pop(ctx);
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tap anywhere on the canvas to stamp $e!'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 32)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTextToDoodleDialog() {
    _textCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Text Doodle', style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _textCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type your message...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final txt = _textCtrl.text.trim();
                if (txt.isNotEmpty) {
                  _doodle.addText(txt);
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC72C),
                foregroundColor: Colors.black,
              ),
              child: const Text('Add Text'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto = _doodle.backgroundPhoto != null && _doodle.backgroundPhoto!.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF16161D) : const Color(0xFFF9F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back, Title "DoodleUp", Clear, and "Select ➜"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF1E1E26)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFFC72C), Color(0xFFFF6B35)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DoodleUp',
                          style: GoogleFonts.gaegu(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
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
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: _onSendTapped,
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      'Send',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC72C),
                      foregroundColor: const Color(0xFF1E1E26),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),

            // If a photo background is loaded, show compulsory badge
            if (hasPhoto)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4081).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF4081).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Text('📷', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Photo loaded! Compulsory to doodle on it before sending 🎨',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF4081),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _doodle.setBackgroundPhoto(null);
                          });
                          HapticFeedback.lightImpact();
                        },
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFFF4081)),
                      ),
                    ],
                  ),
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

                  // Actions: Photo Picker, Brush Size, Eraser, Emoji Stamp, Text-to-doodle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Photo Background Picker
                      IconButton(
                        icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFFF7675), size: 26),
                        tooltip: 'Add photo background',
                        onPressed: _pickPhoto,
                      ),

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
