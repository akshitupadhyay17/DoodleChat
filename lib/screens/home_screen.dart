import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_contact.dart';
import '../models/doodle_group.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/doodle_avatar.dart';
import '../widgets/find_friends_sheet.dart';
import '../widgets/story_viewer_sheet.dart';
import 'chat_screen.dart';
import 'create_doodle_screen.dart';
import 'group_chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  int _activeListTab = 0; // 0 = Chats, 1 = Groups
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final chatService = ChatService();
    chatService.addListener(_onServiceUpdate);
    chatService.connect();
  }

  @override
  void dispose() {
    ChatService().removeListener(_onServiceUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _showAddFriendDialog() {
    showFindFriendsSheet(context);
  }

  void _showCreateGroupDialog() {
    final nameCtrl = TextEditingController();
    String selectedEmoji = '👥';
    final chatService = ChatService();
    final friends = chatService.contacts
        .where((c) => c.friendshipStatus == FriendshipStatus.accepted)
        .toList();
    final selectedUsernames = <String>{};

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Text(selectedEmoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'New Doodle Group',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : const Color(0xFF0E1017),
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Group name (e.g. Doodle Squad)',
                        hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF8A90A6)),
                        filled: true,
                        fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF3F4F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'GROUP ICON',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: const Color(0xFF8A90A6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['👥', '🎨', '⚡️', '🔥', '👑', '💫'].map((em) {
                        final isSel = selectedEmoji == em;
                        return GestureDetector(
                          onTap: () => setDlgState(() => selectedEmoji = em),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppTheme.electricPink.withOpacity(0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? AppTheme.electricPink : Colors.transparent,
                                width: 1.8,
                              ),
                            ),
                            child: Text(em, style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ADD FRIENDS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: const Color(0xFF8A90A6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (friends.isEmpty)
                      Text(
                        'No friends yet. Add friends using their handle to invite them.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF8A90A6),
                        ),
                      )
                    else
                      ...friends.map((f) {
                        final isSelected = selectedUsernames.contains(f.username);
                        return CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          activeColor: AppTheme.electricPink,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            f.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '@${f.username}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF8A90A6),
                            ),
                          ),
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
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8A90A6)),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.electricPink, Color(0xFFFF3B30)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      chatService.createGroup(name, selectedEmoji, selectedUsernames.toList());
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Group "$name" created!',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: AppTheme.electricPink,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Create Group',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProfileTab = _currentTabIndex == 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatService = ChatService();
    final user = chatService.currentUser;

    final filteredContacts = chatService.contacts.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.username.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredGroups = chatService.groups.where((g) {
      if (_searchQuery.isEmpty) return true;
      return g.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: isProfileTab
            ? const ProfileScreen()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sleek Top App Bar (Instagram/Snapchat style)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.electricPink, AppTheme.cyberViolet],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.electricPink.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.gesture_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'doodle',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                    color: isDark ? Colors.white : const Color(0xFF0E1017),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Action Buttons: Find/Add Friends
                        GestureDetector(
                          onTap: _showAddFriendDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person_add_rounded,
                                  size: 15,
                                  color: AppTheme.electricPink,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Add Friends',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0E1017),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Spotlight iOS Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : const Color(0xFFF0F2F7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.transparent,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF8A90A6)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF8A90A6)),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          hintText: 'Search chats, doodles, groups...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: const Color(0xFF8A90A6),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  // Instagram / Snapchat Stories Bar
                  _buildStoriesBar(context, chatService, user, isDark),

                  // Filter Pills: All Chats vs Groups
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Row(
                      children: [
                        _buildFilterPill(
                          label: 'Chats',
                          count: filteredContacts.length,
                          isSelected: _activeListTab == 0,
                          onTap: () => setState(() => _activeListTab = 0),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          label: 'Groups',
                          count: filteredGroups.length,
                          isSelected: _activeListTab == 1,
                          onTap: () => setState(() => _activeListTab = 1),
                          isDark: isDark,
                        ),
                        const Spacer(),
                        if (_activeListTab == 1)
                          GestureDetector(
                            onTap: _showCreateGroupDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.cyberViolet.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_rounded, size: 14, color: AppTheme.cyberViolet),
                                  const SizedBox(width: 4),
                                  Text(
                                    'New Group',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.cyberViolet,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Main List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                      children: [
                        // You Card
                        _buildYouCard(user, isDark),
                        const SizedBox(height: 12),

                        // Incoming Friend Requests
                        if (_activeListTab == 0) ...[
                          _buildIncomingRequestsSection(context, chatService, isDark),
                        ],

                        // Chats or Groups List
                        if (_activeListTab == 0)
                          _buildChatsList(context, filteredContacts, isDark)
                        else
                          _buildGroupsList(context, filteredGroups, isDark),
                      ],
                    ),
                  ),
                ],
              ),
      ),

      // Premium Frosted Glass Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Chats Tab Icon
            IconButton(
              icon: Icon(
                Icons.chat_bubble_rounded,
                size: 26,
                color: _currentTabIndex == 0 ? AppTheme.electricPink : const Color(0xFF8A90A6),
              ),
              tooltip: 'Chats',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _currentTabIndex = 0);
              },
            ),

            // Middle: Floating Gradient DoodleUp Button
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateDoodleScreen()),
                );
              },
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.electricPink, Color(0xFFFF5E3A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.electricPink.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.brush_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),

            // Profile Tab Icon
            IconButton(
              icon: Icon(
                Icons.person_rounded,
                size: 26,
                color: _currentTabIndex == 1 ? AppTheme.electricPink : const Color(0xFF8A90A6),
              ),
              tooltip: 'Profile',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _currentTabIndex = 1);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF0E1017))
              : (isDark ? AppTheme.darkCard : const Color(0xFFF0F2F7)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : const Color(0xFF8A90A6),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.black12 : Colors.white24)
                    : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : const Color(0xFF8A90A6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesBar(BuildContext context, ChatService chatService, dynamic user, bool isDark) {
    final contactsWithStories = chatService.contacts.where((c) => c.hasActiveStory).toList();

    return Container(
      height: 98,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Your Story Bubble
          GestureDetector(
            onTap: () {
              if (user.hasActiveStory) {
                StoryViewerSheet.show(
                  context,
                  story: user.activeStory!,
                  senderName: 'You',
                  senderUsername: user.username,
                  senderEmoji: user.avatarEmoji,
                  senderColor: user.avatarColor,
                  senderPhoto: user.profilePicBase64,
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateDoodleScreen()),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      DoodleAvatar(
                        emoji: user.avatarEmoji,
                        color: user.avatarColor,
                        photoBase64: user.profilePicBase64,
                        activeStory: user.activeStory,
                        displayName: 'You',
                        username: user.username,
                        radius: 27,
                      ),
                      if (!user.hasActiveStory)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.electricPink, Color(0xFFFF5E3A)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppTheme.darkBackground : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.add, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your Story',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFA5ABC0) : const Color(0xFF5D6275),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Friends Stories
          ...contactsWithStories.map((contact) {
            return GestureDetector(
              onTap: () {
                StoryViewerSheet.show(
                  context,
                  story: contact.activeStory!,
                  senderName: contact.name,
                  senderUsername: contact.username,
                  senderEmoji: contact.avatarEmoji,
                  senderColor: contact.avatarColor,
                  senderPhoto: contact.avatarPhotoBase64,
                  onReply: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChatScreen(contact: contact)),
                    );
                  },
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DoodleAvatar(
                      emoji: contact.avatarEmoji,
                      color: contact.avatarColor,
                      photoBase64: contact.avatarPhotoBase64,
                      activeStory: contact.activeStory,
                      displayName: contact.name,
                      username: contact.username,
                      radius: 27,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 62,
                      child: Text(
                        contact.name.split(' ').first,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0E1017),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildYouCard(dynamic user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          DoodleAvatar(
            emoji: user.avatarEmoji,
            color: user.avatarColor,
            photoBase64: user.profilePicBase64,
            isOnline: true,
            activeStory: user.activeStory,
            displayName: 'You',
            username: user.username,
            radius: 24,
            onTap: () => setState(() => _currentTabIndex = 1),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'You',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0E1017),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.electricPink.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '@${user.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.electricPink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  user.bio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF8A90A6) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_rounded, color: AppTheme.electricPink, size: 22),
            tooltip: 'My QR Code',
            onPressed: () => setState(() => _currentTabIndex = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsSection(BuildContext context, ChatService chatService, bool isDark) {
    final pendingRequests = chatService.contacts
        .where((c) => c.friendshipStatus == FriendshipStatus.requestReceived)
        .toList();
    if (pendingRequests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.electricPink,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'INCOMING DOODLE REQUESTS (${pendingRequests.length})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppTheme.electricPink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...pendingRequests.map((req) => _buildRequestCard(context, req, isDark)),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildChatsList(BuildContext context, List<ChatContact> contacts, bool isDark) {
    final displayList = contacts
        .where((c) => c.friendshipStatus != FriendshipStatus.requestReceived)
        .toList();

    if (displayList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : const Color(0xFFF0F2F7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.brush_rounded, size: 28, color: Color(0xFF8A90A6)),
              ),
              const SizedBox(height: 14),
              Text(
                'No conversations yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0E1017),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap "Add Friends" to connect and exchange doodles!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF8A90A6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: displayList.map((contact) => _buildContactCard(context, contact, isDark)).toList(),
    );
  }

  Widget _buildGroupsList(BuildContext context, List<DoodleGroup> groups, bool isDark) {
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : const Color(0xFFF0F2F7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.groups_rounded, size: 28, color: Color(0xFF8A90A6)),
              ),
              const SizedBox(height: 14),
              Text(
                'No Groups Yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0E1017),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create a group to doodle with your close circle together!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF8A90A6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: groups.map((g) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: g.color.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: g.color, width: 2),
              ),
              child: Center(child: Text(g.avatarEmoji, style: const TextStyle(fontSize: 22))),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    g.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0E1017),
                    ),
                  ),
                ),
                if (g.streakCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.sunsetOrange.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 2),
                        Text(
                          '${g.streakCount}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.sunsetOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              '${g.memberUsernames.length} members • ${g.latestDoodle != null ? 'Active canvas 🎨' : 'Idle'}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF8A90A6),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8A90A6)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GroupChatScreen(group: g)),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRequestCard(BuildContext context, ChatContact contact, bool isDark) {
    final chatService = ChatService();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.electricPink.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          DoodleAvatar(
            emoji: contact.avatarEmoji,
            color: contact.avatarColor,
            photoBase64: contact.avatarPhotoBase64,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${contact.username}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0E1017),
                  ),
                ),
                Text(
                  contact.name,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF8A90A6)),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.electricPink, Color(0xFFFF3B30)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                chatService.respondFriendRequest(contact.username, true);
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Accepted @${contact.username}! Start doodling ✨'),
                    backgroundColor: AppTheme.acidLime,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Accept',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF8A90A6)),
            tooltip: 'Decline',
            onPressed: () {
              chatService.respondFriendRequest(contact.username, false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, ChatContact contact, bool isDark) {
    Color statusBgColor = Colors.transparent;
    Color statusTextColor = const Color(0xFF8A90A6);
    String statusLabel = 'Ready to doodle';
    IconData statusIcon = Icons.edit_note_rounded;

    if (contact.friendshipStatus == FriendshipStatus.requestSent) {
      statusBgColor = AppTheme.cyberViolet.withOpacity(0.15);
      statusTextColor = AppTheme.cyberViolet;
      statusLabel = 'Pending response';
      statusIcon = Icons.hourglass_top_rounded;
    } else if (contact.doodleStatus == DoodleChatStatus.receivedMustErase) {
      statusBgColor = AppTheme.electricPink.withOpacity(0.18);
      statusTextColor = AppTheme.electricPink;
      statusLabel = 'New Doodle • Erase to reply';
      statusIcon = Icons.auto_fix_high_rounded;
    } else if (contact.doodleStatus == DoodleChatStatus.sentWaitingForErase) {
      statusBgColor = AppTheme.cyberViolet.withOpacity(0.15);
      statusTextColor = AppTheme.cyberViolet;
      statusLabel = 'Delivered • Waiting to erase';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: DoodleAvatar(
          emoji: contact.avatarEmoji,
          color: contact.avatarColor,
          photoBase64: contact.avatarPhotoBase64,
          isOnline: contact.isOnline,
          activeStory: contact.activeStory,
          displayName: contact.name,
          username: contact.username,
          radius: 25,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(contact: contact)),
            );
          },
          onStoryReply: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(contact: contact)),
            );
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0E1017),
                      ),
                    ),
                  ),
                  if (contact.streakCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.sunsetOrange.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 2),
                          Text(
                            '${contact.streakCount}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.sunsetOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              contact.lastActive,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF8A90A6),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 13, color: statusTextColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8A90A6)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(contact: contact),
            ),
          );
        },
      ),
    );
  }
}
