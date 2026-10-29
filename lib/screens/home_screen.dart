import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_contact.dart';
import '../models/doodle_group.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/doodle_avatar.dart';
import '../widgets/find_friends_sheet.dart' show parseHandle;
import '../widgets/story_viewer_sheet.dart';
import 'chat_screen.dart';
import 'create_doodle_screen.dart';
import 'group_chat_screen.dart';
import 'profile_screen.dart';
import '../widgets/doodle_pass_dialog.dart';

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
  Timer? _searchDebounce;
  bool _isSearchingPeople = false;
  List<Map<String, dynamic>> _searchedPeople = [];

  @override
  void initState() {
    super.initState();
    final chatService = ChatService();
    chatService.addListener(_onServiceUpdate);
    chatService.connect();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    ChatService().removeListener(_onServiceUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
    });
    _searchDebounce?.cancel();
    final q = val.trim();
    if (q.isEmpty) {
      setState(() {
        _isSearchingPeople = false;
        _searchedPeople = [];
      });
      return;
    }
    setState(() => _isSearchingPeople = true);
    _searchDebounce = Timer(const Duration(milliseconds: 220), () async {
      final results = await ChatService().searchUsers(q);
      if (!mounted || _searchQuery.trim() != q) return;
      setState(() {
        _searchedPeople = results;
        _isSearchingPeople = false;
      });
    });
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
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! < -260 && _currentTabIndex == 0) {
              HapticFeedback.lightImpact();
              setState(() => _currentTabIndex = 1);
            } else if (details.primaryVelocity! > 260 && _currentTabIndex == 1) {
              HapticFeedback.lightImpact();
              setState(() => _currentTabIndex = 0);
            }
          },
          child: isProfileTab
              ? ProfileScreen(onBackToChats: () => setState(() => _currentTabIndex = 0))
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sleek Top App Bar (Instagram style — no separate Add Friends popup button)
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
                      ],
                    ),
                  ),

                  // Instagram-style Top Search Bar (search people, @usernames, chats, groups directly)
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
                        onChanged: _onSearchChanged,
                        autocorrect: false,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF8A90A6)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF8A90A6)),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          hintText: 'Search people, @username, chats...',
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
                  if (_searchQuery.trim().isEmpty)
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
                        if (_searchQuery.trim().isEmpty) ...[
                          // You Card
                          _buildYouCard(user, isDark),
                          const SizedBox(height: 12),
                        ],

                        // Direct Instagram-style People Search Results when typing in top search bar
                        if (_searchQuery.trim().isNotEmpty)
                          _buildDirectPeopleSearchSection(context, chatService, isDark),

                        // Incoming Friend Requests
                        if (_activeListTab == 0 && _searchQuery.trim().isEmpty) ...[
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
                chatService.markStorySeen(user.activeStory);
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
                        isOnline: chatService.isConnected,
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
                    'DoodleUp',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
                chatService.markStorySeen(contact.activeStory);
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
                      MaterialPageRoute(
                        builder: (_) => CreateDoodleScreen(
                          replyToContact: contact,
                          replyToStory: contact.activeStory,
                        ),
                      ),
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
                      isOnline: contact.isOnline,
                      activeStory: contact.activeStory,
                      displayName: contact.name,
                      username: contact.username,
                      radius: 27,
                      onStoryReply: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateDoodleScreen(
                              replyToContact: contact,
                              replyToStory: contact.activeStory,
                            ),
                          ),
                        );
                      },
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
            isOnline: ChatService().isConnected,
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
            onPressed: () => showDoodlePassDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectPeopleSearchSection(BuildContext context, ChatService chatService, bool isDark) {
    final cleanHandle = parseHandle(_searchQuery);
    final rawLower = _searchQuery.trim().toLowerCase().replaceAll('@', '');
    final myUsername = chatService.currentUser.username.toLowerCase();

    // Merge onlinePeers that match query + _searchedPeople (deduplicated by username)
    final peopleByUsername = <String, Map<String, dynamic>>{};
    for (final p in chatService.onlinePeers) {
      final u = (p['username'] ?? '').toString().toLowerCase().trim();
      final n = (p['name'] ?? '').toString().toLowerCase();
      if (u.isEmpty || u == myUsername) continue;
      if ((cleanHandle.isNotEmpty && u.contains(cleanHandle)) ||
          (rawLower.isNotEmpty && n.contains(rawLower))) {
        peopleByUsername[u] = p;
      }
    }
    for (final p in _searchedPeople) {
      final u = (p['username'] ?? '').toString().toLowerCase().trim();
      if (u.isEmpty || u == myUsername) continue;
      peopleByUsername[u] = p;
    }

    final matchedPeople = peopleByUsername.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          child: Row(
            children: [
              Text(
                'PEOPLE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: const Color(0xFF8A90A6),
                ),
              ),
              if (_isSearchingPeople) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.electricPink,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (matchedPeople.isEmpty && _isSearchingPeople && cleanHandle.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: AppTheme.electricPink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Searching for @$cleanHandle…',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8A90A6),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (matchedPeople.isEmpty && !_isSearchingPeople && cleanHandle.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_search_rounded, size: 20, color: Color(0xFF8A90A6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cleanHandle == myUsername
                        ? "That's your handle (@$cleanHandle)"
                        : 'No user found for @$cleanHandle',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8A90A6),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...matchedPeople.map((peer) {
            final username = (peer['username'] ?? '').toString().toLowerCase().trim();
            final displayName = (peer['name'] ?? username).toString();
            final emoji = peer['avatarEmoji']?.toString() ?? '✨';
            final photo = peer['avatarPhoto']?.toString();
            final bio = peer['bio']?.toString() ?? 'Doodle user';
            final isOnline = peer['online'] == true;

            final existing = chatService.contacts.cast<ChatContact?>().firstWhere(
                  (c) => c?.username.toLowerCase() == username,
                  orElse: () => null,
                );
            final isAccepted = existing != null && existing.friendshipStatus == FriendshipStatus.accepted;
            final isPending = existing != null && existing.friendshipStatus == FriendshipStatus.requestSent;
            final isReceived = existing != null && existing.friendshipStatus == FriendshipStatus.requestReceived;

            String actionLabel = 'Add';
            Color actionBg = AppTheme.electricPink;
            if (isAccepted) {
              actionLabel = 'Chat';
            } else if (isReceived) {
              actionLabel = 'Accept';
              actionBg = AppTheme.acidLime;
            } else if (isPending) {
              actionLabel = 'Requested';
              actionBg = AppTheme.cyberViolet;
            }

            Future<void> handleTap() async {
              HapticFeedback.lightImpact();
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              if (isAccepted) {
                nav.push(MaterialPageRoute(builder: (_) => ChatScreen(contact: existing)));
              } else if (isReceived) {
                chatService.respondFriendRequest(username, true);
                nav.push(MaterialPageRoute(builder: (_) => ChatScreen(contact: existing)));
              } else if (isPending) {
                nav.push(MaterialPageRoute(builder: (_) => ChatScreen(contact: existing)));
              } else {
                await chatService.sendFriendRequest(username, profile: peer);
                final contact = await chatService.ensureContact(
                  username,
                  profile: peer,
                  initialStatus: FriendshipStatus.requestSent,
                );
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Doodle request sent to @$username!',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: AppTheme.electricPink,
                  ),
                );
                nav.push(MaterialPageRoute(builder: (_) => ChatScreen(contact: contact)));
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                ),
              ),
              child: ListTile(
                onTap: handleTap,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: DoodleAvatar(
                  emoji: emoji,
                  color: AppTheme.electricPink.withOpacity(0.18),
                  photoBase64: photo,
                  isOnline: isOnline,
                  displayName: displayName,
                  username: username,
                  radius: 22,
                ),
                title: Text(
                  '@$username',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0E1017),
                  ),
                ),
                subtitle: Text(
                  bio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF8A90A6)),
                ),
                trailing: SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: handleTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionBg,
                      foregroundColor: isReceived ? Colors.black : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      actionLabel,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
      ],
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

    // Sort with latest interacted contact at the top
    displayList.sort((a, b) {
      final timeA = a.lastInteractionTimestamp;
      final timeB = b.lastInteractionTimestamp;
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      return timeB.compareTo(timeA);
    });

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
                'Search for a @username above to connect and exchange doodles!',
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
            isOnline: contact.isOnline,
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
              MaterialPageRoute(
                builder: (_) => CreateDoodleScreen(
                  replyToContact: contact,
                  replyToStory: contact.activeStory,
                ),
              ),
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
              '@${contact.username}',
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
