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
import '../theme/app_theme.dart';
import '../models/doodle_stroke.dart';

/// Standalone doodle creator: DoodleUp!
/// Modeled after Instagram Draw & Canva tools with full creative control:
///  - Instagram Brush Modes: Pen, Marker, Neon Glow, Highlighter, Eraser
///  - Instagram Left Vertical Brush-Size Slider with live preview bubble
///  - Canva Creative Tools: Shapes (Star, Heart, Arrow, Bubble, Rect, Circle),
///    Instagram Story Text Studio with font choices and background pill highlight,
///    Categorized Stamps & Stickers, and Photo Background overlay.
///  - No concept of a story: everything is DoodleUp!
class CreateDoodleScreen extends StatefulWidget {
  final String? initialGroupId;

  const CreateDoodleScreen({super.key, this.initialGroupId});

  @override
  State<CreateDoodleScreen> createState() => _CreateDoodleScreenState();
}

class _CreateDoodleScreenState extends State<CreateDoodleScreen> {
  final DoodleController _doodle = DoodleController();
  final ChatService _service = ChatService();
  final ImagePicker _picker = ImagePicker();

  final List<Color> _colors = const [
    Colors.white,
    Colors.black,
    Color(0xFFFF2D55), // Hot Pink
    Color(0xFFFF4081), // Electric Pink
    Color(0xFF7928CA), // Cyber Violet
    Color(0xFF007AFF), // Royal Blue
    Color(0xFF00CEC9), // Sky Cyan
    Color(0xFFA3E635), // Acid Lime
    Color(0xFFFFC72C), // Bright Yellow
    Color(0xFFFF9500), // Neon Orange
    Color(0xFFFF3B30), // Ruby Red
    Color(0xFF00B894), // Mint
    Color(0xFFFFB8B8), // Pastel Peach
  ];

  final List<String> _quickEmojis = [
    '⚡️', '🔥', '✨', '💖', '🌸', '😂', '👑', '🎉',
    '👋', '🖤', '🚀', '💯', '😍', '🥳', '😎', '🤪',
    '🎨', '✏️', '🪄', '🌟', '🍭', '🍕', '🛸', '💎'
  ];

  bool _isDraggingBrushSlider = false;

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
              'Photo loaded! Doodle something fun on it before sending 🎨',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
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
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
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
            'Draw a doodle on the canvas before hitting DoodleUp! 🎨',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
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

  void _showClearConfirm() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Clear Canvas?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          content: Text(
            'This will clear all strokes, texts, shapes, and photo from your DoodleUp.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF8A90A6)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _doodle.clear();
                Navigator.pop(ctx);
                HapticFeedback.lightImpact();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Clear All',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
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
                  Text(selectedEmoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text('New Doodle Group', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
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
                    Text('Select Emoji Icon:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    Text('Add Friends:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (friends.isEmpty)
                      Text('No friends to add yet. You will be the first member!', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey))
                    else
                      ...friends.map((f) {
                        final isSelected = selectedUsernames.contains(f.username);
                        return CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(f.name, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
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
    bool postToDoodleUp = false;
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

            final totalRecipients = selectedContactIds.length + selectedGroupIds.length + (postToDoodleUp ? 1 : 0);

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
                                    'DoodleUp Recipients',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF1E1E26),
                                    ),
                                  ),
                                  Text(
                                    'Broadcast to DoodleUp or send directly to friends',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
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
                          color: isDark ? const Color(0xFF282834) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (val) => setSheetState(() => searchQuery = val),
                          style: GoogleFonts.plusJakartaSans(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search friends or groups...',
                            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
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

                    // Quick Select Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      child: Row(
                        children: [
                          if (filteredFriends.isNotEmpty)
                            InkWell(
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
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: allFilteredSelected
                                      ? const Color(0xFFFFC72C).withValues(alpha: 0.2)
                                      : Colors.grey.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: allFilteredSelected ? const Color(0xFFFFC72C) : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  allFilteredSelected ? 'Deselect All Friends' : 'Select All Friends',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: allFilteredSelected ? const Color(0xFFFFC72C) : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          InkWell(
                            onTap: () => _showCreateGroupDialog(ctx),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 14, color: Color(0xFF6C5CE7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'New Group',
                                    style: GoogleFonts.plusJakartaSans(
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

                    const SizedBox(height: 6),

                    // Scrollable List: DoodleUp Broadcast, Contacts, Groups
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        children: [
                          // 1. DoodleUp Broadcast Card (No story!)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setSheetState(() => postToDoodleUp = !postToDoodleUp);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: postToDoodleUp
                                      ? [
                                          const Color(0xFFFFC72C).withValues(alpha: 0.25),
                                          const Color(0xFFFF4081).withValues(alpha: 0.18),
                                        ]
                                      : [
                                          isDark ? const Color(0xFF282834) : const Color(0xFFF7F8FA),
                                          isDark ? const Color(0xFF282834) : const Color(0xFFF7F8FA),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: postToDoodleUp ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.25),
                                  width: postToDoodleUp ? 2 : 1,
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
                                    child: const Center(child: Text('🚀', style: TextStyle(fontSize: 18))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'DoodleUp Feed',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF0E1017),
                                          ),
                                        ),
                                        Text(
                                          'Broadcast to all friends on DoodleUp',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF8A90A6)),
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
                                      color: postToDoodleUp ? const Color(0xFFFFC72C) : Colors.transparent,
                                      border: Border.all(
                                        color: postToDoodleUp ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.5),
                                        width: 2,
                                      ),
                                    ),
                                    child: postToDoodleUp
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
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: Colors.grey,
                                ),
                              ),
                              if (selectedContactIds.isNotEmpty)
                                Text(
                                  '${selectedContactIds.length} selected',
                                  style: GoogleFonts.plusJakartaSans(
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
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            )
                          else if (filteredFriends.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'No friends match "$searchQuery"',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ...filteredFriends.map((friend) {
                              final isSelected = selectedContactIds.contains(friend.id);

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
                                      DoodleAvatar(
                                        emoji: friend.avatarEmoji,
                                        color: friend.avatarColor,
                                        photoBase64: friend.avatarPhotoBase64,
                                        radius: 20,
                                        displayName: friend.name,
                                        username: friend.username,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              friend.name,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white : const Color(0xFF1E1E26),
                                              ),
                                            ),
                                            Text(
                                              '@${friend.username}',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 160),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? const Color(0xFFFFC72C) : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.4),
                                            width: 1.8,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                          const SizedBox(height: 16),

                          // 3. GROUPS SECTION
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'GROUPS (${filteredGroups.length})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: Colors.grey,
                                ),
                              ),
                              if (selectedGroupIds.isNotEmpty)
                                Text(
                                  '${selectedGroupIds.length} selected',
                                  style: GoogleFonts.plusJakartaSans(
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'No groups yet. Tap "+ New Group" above to start one!',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            )
                          else if (filteredGroups.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'No groups match "$searchQuery"',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ...filteredGroups.map((group) {
                              final isSelected = selectedGroupIds.contains(group.id);

                              return InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() {
                                    if (isSelected) {
                                      selectedGroupIds.remove(group.id);
                                    } else {
                                      selectedGroupIds.add(group.id);
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
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(group.avatarEmoji, style: const TextStyle(fontSize: 20)),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group.name,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white : const Color(0xFF1E1E26),
                                              ),
                                            ),
                                            Text(
                                              '${group.memberUsernames.length} members',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 160),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? const Color(0xFF6C5CE7) : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey.withValues(alpha: 0.4),
                                            width: 1.8,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                            : null,
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

                                  // Broadcast to DoodleUp if chosen
                                  if (postToDoodleUp) {
                                    _service.postDoodleUp(data);
                                  }

                                  HapticFeedback.heavyImpact();
                                  Navigator.pop(ctx); // Close recipients sheet
                                  Navigator.pop(context); // Close DoodleUp back to home

                                  final message = StringBuffer();
                                  if (sentCount > 0 && postToDoodleUp) {
                                    message.write('Sent to $sentCount contact${sentCount == 1 ? '' : 's'} & posted to DoodleUp! 🚀');
                                  } else if (postToDoodleUp) {
                                    message.write('Posted to DoodleUp! 🚀');
                                  } else {
                                    message.write('Doodle sent to $sentCount recipient${sentCount == 1 ? '' : 's'}! 🚀');
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        message.toString(),
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
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
                                Icons.rocket_launch_rounded,
                                size: 18,
                                color: totalRecipients > 0 ? const Color(0xFF1E1E26) : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                totalRecipients == 0
                                    ? 'Select contacts or DoodleUp'
                                    : (postToDoodleUp && selectedContactIds.isEmpty && selectedGroupIds.isEmpty)
                                        ? 'Post to DoodleUp 🚀'
                                        : 'DoodleUp ($totalRecipients recipient${totalRecipients > 1 ? 's' : ''}) 🚀',
                                style: GoogleFonts.plusJakartaSans(
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

  // ───────────────────────── Canva & Instagram Tool Sheets ─────────────────────────

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
                    Text('Stickers & Emojis', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _quickEmojis.map((e) {
                    return GestureDetector(
                      onTap: () {
                        _doodle.addEmoji(e);
                        Navigator.pop(ctx);
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 28)),
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

  void _showShapesSheet() {
    final shapes = [
      {'id': 'star', 'name': 'Star', 'icon': '⭐'},
      {'id': 'heart', 'name': 'Heart', 'icon': '💖'},
      {'id': 'circle', 'name': 'Circle', 'icon': '⭕'},
      {'id': 'rect', 'name': 'Box', 'icon': '🔲'},
      {'id': 'arrow', 'name': 'Arrow', 'icon': '➔'},
      {'id': 'bubble', 'name': 'Bubble', 'icon': '💬'},
    ];

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
                    Row(
                      children: [
                        const Text('🔷', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          'Canva Shapes',
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap any shape to stamp onto your canvas in active brush style',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: shapes.map((s) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _doodle.addShape(s['id']!);
                        HapticFeedback.mediumImpact();
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _doodle.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _doodle.color.withOpacity(0.4)),
                            ),
                            child: Center(
                              child: Text(s['icon']!, style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s['name']!,
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTextStudio() {
    final textCtrl = TextEditingController();
    String selectedFont = 'PatrickHand';
    bool hasBackground = false;
    Color textColor = _doodle.color;

    final fonts = [
      {'id': 'PatrickHand', 'label': 'Doodle'},
      {'id': 'Outfit', 'label': 'Clean Sans'},
      {'id': 'PlusJakartaSans', 'label': 'Bold'},
      {'id': 'Caveat', 'label': 'Script'},
      {'id': 'Gaegu', 'label': 'Playful'},
      {'id': 'Neon', 'label': 'Neon Glow'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🔤', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              'Canva Text Studio',
                              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        // Instagram Text Highlight Pill Toggle ([A])
                        IconButton(
                          tooltip: 'Toggle text background pill',
                          icon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasBackground ? textColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: textColor, width: 1.5),
                            ),
                            child: Text(
                              'A',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: hasBackground
                                    ? (textColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                                    : textColor,
                              ),
                            ),
                          ),
                          onPressed: () {
                            setDlgState(() => hasBackground = !hasBackground);
                            HapticFeedback.selectionClick();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Input TextField
                    TextField(
                      controller: textCtrl,
                      autofocus: true,
                      onChanged: (val) => setDlgState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF282834) : const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Live Preview Container
                    if (textCtrl.text.isNotEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: hasBackground ? textColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            textCtrl.text,
                            style: doodleTextStyle(
                              selectedFont,
                              24,
                              hasBackground
                                  ? (textColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                                  : textColor,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 14),

                    // Font Switcher Chips
                    Text(
                      'FONTS',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: fonts.map((f) {
                          final isSelected = selectedFont == f['id'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                f['label']!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFFFFC72C),
                              backgroundColor: isDark ? const Color(0xFF282834) : const Color(0xFFF0F0F2),
                              onSelected: (_) {
                                setDlgState(() => selectedFont = f['id']!);
                                HapticFeedback.selectionClick();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Color Picker Row for Text
                    Text(
                      'COLOR',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _colors.map((c) {
                          final isSel = textColor == c;
                          return GestureDetector(
                            onTap: () {
                              setDlgState(() => textColor = c);
                              setState(() => _doodle.setColor(c));
                              HapticFeedback.selectionClick();
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? const Color(0xFFFFC72C) : Colors.grey.withOpacity(0.3),
                                  width: isSel ? 3 : 1,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Add Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: textCtrl.text.trim().isEmpty
                            ? null
                            : () {
                                final txt = textCtrl.text.trim();
                                _doodle.addText(txt, selectedFont, hasBackground);
                                Navigator.pop(ctx);
                                HapticFeedback.mediumImpact();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.electricPink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Add Text to Canvas ✨',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
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

  void _showColorPickerModal() {
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
                    Text('Color Palette', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ..._colors,
                    const Color(0xFF6C5CE7),
                    const Color(0xFF0984E3),
                    const Color(0xFF00CEC9),
                    const Color(0xFF00B894),
                    const Color(0xFFE17055),
                    const Color(0xFFD63031),
                    const Color(0xFFE84393),
                    const Color(0xFF2D3436),
                    const Color(0xFFFDCB6E),
                    const Color(0xFF55EFC4),
                  ].map((c) {
                    final isSel = _doodle.color == c;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _doodle.setColor(c);
                        });
                        Navigator.pop(ctx);
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? const Color(0xFFFFC72C) : Colors.grey.withOpacity(0.3),
                            width: isSel ? 3.5 : 1,
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: c.withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
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

  // ───────────────────────── Main Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto = _doodle.backgroundPhoto != null && _doodle.backgroundPhoto!.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101015) : const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            // Top Minimal Navigation Header (Distraction-free & Clean)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  // Back Button with subtle frosted bubble
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B24) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(18),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: isDark ? Colors.white : const Color(0xFF0E1017),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Title Pill: DoodleUp Studio
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B24) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.electricPink, AppTheme.cyberViolet],
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.initialGroupId != null ? 'Group Doodle' : 'DoodleUp',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0E1017),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Clear Canvas Button (Clean Trash Icon)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B24) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: _showClearConfirm,
                      borderRadius: BorderRadius.circular(18),
                      child: const Center(
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFF8A90A6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // If photo loaded, show compulsory badge
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
                          'Photo loaded! Doodle on it before sending 🎨',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFF4081),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _doodle.setBackgroundPhoto(null));
                          HapticFeedback.lightImpact();
                        },
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFFF4081)),
                      ),
                    ],
                  ),
                ),
              ),

            // Canvas Surface with Instagram Left Vertical Brush Slider
            Expanded(
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
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

                  // Instagram Left Vertical Brush-Size Slider
                  Positioned(
                    left: 24,
                    top: 30,
                    bottom: 30,
                    child: _buildInstagramVerticalBrushSlider(isDark),
                  ),
                ],
              ),
            ),

            // ════════════════════════════════════════════════════════════════════
            // Ergonomic Bottom Thumb Deck (Everything Easily Reachable With Thumbs)
            // ════════════════════════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Brush Modes + Undo / Redo (Thumb Accessible)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B24) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Undo Thumb Button
                        _buildThumbHistoryButton(
                          icon: Icons.undo_rounded,
                          enabled: _doodle.canUndo,
                          tooltip: 'Undo',
                          isDark: isDark,
                          onTap: () {
                            _doodle.undo();
                            HapticFeedback.lightImpact();
                          },
                        ),
                        const SizedBox(width: 4),
                        // Redo Thumb Button
                        _buildThumbHistoryButton(
                          icon: Icons.redo_rounded,
                          enabled: _doodle.canRedo,
                          tooltip: 'Redo',
                          isDark: isDark,
                          onTap: () {
                            _doodle.redo();
                            HapticFeedback.lightImpact();
                          },
                        ),

                        // Subtle Divider
                        Container(
                          width: 1,
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),

                        // Horizontally scrollable brush pills
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children: [
                                _buildBrushModePill(
                                  label: 'Pen',
                                  icon: Icons.edit_rounded,
                                  isActive: !_doodle.eraser && _doodle.brushType == DoodleBrushType.pen,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _doodle.setBrushType(DoodleBrushType.pen));
                                  },
                                ),
                                const SizedBox(width: 4),
                                _buildBrushModePill(
                                  label: 'Marker',
                                  icon: Icons.brush_rounded,
                                  isActive: !_doodle.eraser && _doodle.brushType == DoodleBrushType.marker,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _doodle.setBrushType(DoodleBrushType.marker));
                                  },
                                ),
                                const SizedBox(width: 4),
                                _buildBrushModePill(
                                  label: 'Neon',
                                  icon: Icons.auto_awesome_rounded,
                                  isActive: !_doodle.eraser && _doodle.brushType == DoodleBrushType.neon,
                                  isSpecialGlow: true,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _doodle.setBrushType(DoodleBrushType.neon));
                                  },
                                ),
                                const SizedBox(width: 4),
                                _buildBrushModePill(
                                  label: 'Highlighter',
                                  icon: Icons.highlight_rounded,
                                  isActive: !_doodle.eraser && _doodle.brushType == DoodleBrushType.highlighter,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _doodle.setBrushType(DoodleBrushType.highlighter));
                                  },
                                ),
                                const SizedBox(width: 4),
                                _buildBrushModePill(
                                  label: 'Eraser',
                                  icon: Icons.cleaning_services_rounded,
                                  isActive: _doodle.eraser,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _doodle.setEraser(!_doodle.eraser));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Row 2: Color Palette + Custom HSV Picker
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B24) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
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
                                    width: isSelected ? 30 : 24,
                                    height: isSelected ? 30 : 24,
                                    margin: const EdgeInsets.only(right: 7),
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.3),
                                        width: isSelected ? 2.5 : 1.2,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: c.withValues(alpha: 0.55),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.palette_rounded, size: 20, color: AppTheme.electricPink),
                          tooltip: 'More colors',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: _showColorPickerModal,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Row 3: Canva Studio Creative Elements + Primary Thumb Action CTA
                  Row(
                    children: [
                      // Canva Creative Elements Dock
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B1B24) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildBottomActionButton(
                                  icon: Icons.add_photo_alternate_rounded,
                                  label: 'Photo',
                                  color: const Color(0xFFFF7675),
                                  onTap: _pickPhoto,
                                ),
                              ),
                              Expanded(
                                child: _buildBottomActionButton(
                                  icon: Icons.text_fields_rounded,
                                  label: 'Text',
                                  color: const Color(0xFF00CEC9),
                                  onTap: _showTextStudio,
                                ),
                              ),
                              Expanded(
                                child: _buildBottomActionButton(
                                  icon: Icons.interests_rounded,
                                  label: 'Shapes',
                                  color: const Color(0xFF6C5CE7),
                                  onTap: _showShapesSheet,
                                ),
                              ),
                              Expanded(
                                child: _buildBottomActionButton(
                                  icon: Icons.emoji_emotions_rounded,
                                  label: 'Stickers',
                                  color: const Color(0xFFFFC72C),
                                  onTap: _showEmojiSheet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Primary "Post DoodleUp" Thumb Action Button
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.electricPink, AppTheme.cyberViolet],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.electricPink.withValues(alpha: 0.38),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _onSendTapped,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.rocket_launch_rounded, size: 16, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    'DoodleUp',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildThumbHistoryButton({
    required IconData icon,
    required bool enabled,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled
              ? (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: enabled
                ? (isDark ? Colors.white : const Color(0xFF0E1017))
                : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Helper Widgets ─────────────────────────

  Widget _buildBrushModePill({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    bool isSpecialGlow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (isSpecialGlow
                  ? const Color(0xFFFF4081)
                  : const Color(0xFFFFC72C))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: (isSpecialGlow ? const Color(0xFFFF4081) : const Color(0xFFFFC72C)).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.black : Colors.grey,
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstagramVerticalBrushSlider(bool isDark) {
    // 2.0 to 38.0 range
    final minSize = 2.0;
    final maxSize = 38.0;
    final fraction = ((_doodle.brushPx - minSize) / (maxSize - minSize)).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = (constraints.maxHeight * 0.55).clamp(140.0, 220.0);

        return Center(
          child: SizedBox(
            width: 80,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Slider Track Capsule
                GestureDetector(
                  onVerticalDragStart: (_) => setState(() => _isDraggingBrushSlider = true),
                  onVerticalDragEnd: (_) => setState(() => _isDraggingBrushSlider = false),
                  onVerticalDragCancel: () => setState(() => _isDraggingBrushSlider = false),
                  onVerticalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final local = box.globalToLocal(details.globalPosition);
                    // dragging up increases size
                    final rawFraction = 1.0 - (local.dy / totalHeight);
                    final clamped = rawFraction.clamp(0.0, 1.0);
                    final newSize = minSize + clamped * (maxSize - minSize);
                    setState(() {
                      _doodle.setBrush(newSize);
                    });
                  },
                  child: Container(
                    width: 28,
                    height: totalHeight,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.45) : Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Inner fill
                        Container(
                          width: 6,
                          height: totalHeight * fraction,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: _doodle.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // Slider Thumb
                        Positioned(
                          bottom: (totalHeight - 24) * fraction,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _doodle.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Live Preview Bubble (Pops out to the right when dragging)
                if (_isDraggingBrushSlider)
                  Positioned(
                    left: 36,
                    bottom: (totalHeight - 34) * fraction - 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B1B24) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Exact brush preview circle
                          Container(
                            width: _doodle.brushPx.clamp(6.0, 32.0),
                            height: _doodle.brushPx.clamp(6.0, 32.0),
                            decoration: BoxDecoration(
                              color: _doodle.color,
                              shape: BoxShape.circle,
                              boxShadow: _doodle.brushType == DoodleBrushType.neon
                                  ? [
                                      BoxShadow(
                                        color: _doodle.color.withOpacity(0.8),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_doodle.brushPx.round()}px',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
