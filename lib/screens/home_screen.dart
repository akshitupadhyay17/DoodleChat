import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_contact.dart';
import '../models/doodle_group.dart';
import '../services/chat_service.dart';
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
    final friends = chatService.contacts.where((c) => c.friendshipStatus == FriendshipStatus.accepted).toList();
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
                      children: ['👥', '🎨', '⚡️', '🐥', '🔥', '👑'].map((em) {
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
                    chatService.createGroup(name, selectedEmoji, selectedUsernames.toList());
                    Navigator.pop(ctx);
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
      backgroundColor: isDark ? const Color(0xFF14141B) : const Color(0xFFFFFDF8),
      body: SafeArea(
        child: isProfileTab
            ? const ProfileScreen()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar with Logo & Name "Doodle"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC72C),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(child: Text('🦆', style: TextStyle(fontSize: 20))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Doodle',
                              style: GoogleFonts.gaegu(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E1E26),
                              ),
                            ),
                          ],
                        ),
                        // Invite others shortcut
                        TextButton.icon(
                          onPressed: _showAddFriendDialog,
                          icon: const Icon(Icons.person_add_rounded, size: 18, color: Color(0xFFE5A800)),
                          label: Text(
                            'Invite others',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: const Color(0xFFE5A800),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC72C).withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A22) : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFFFC72C)),
                          hintText: 'Search chats, doodles, groups...',
                          hintStyle: GoogleFonts.outfit(fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),

                  // DoodleUp Stories Row (Horizontal Bar)
                  _buildStoriesBar(context, chatService, user, isDark),

                  // Tab Selector: Chats vs Groups
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                    child: Row(
                      children: [
                        _buildFilterPill(
                          label: 'Chats',
                          count: filteredContacts.length,
                          isSelected: _activeListTab == 0,
                          onTap: () => setState(() => _activeListTab = 0),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          label: 'Groups',
                          count: filteredGroups.length,
                          isSelected: _activeListTab == 1,
                          onTap: () => setState(() => _activeListTab = 1),
                        ),
                        const Spacer(),
                        if (_activeListTab == 1)
                          GestureDetector(
                            onTap: _showCreateGroupDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_rounded, size: 14, color: Color(0xFF6C5CE7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Create Group',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
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

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                      children: [
                        // "You" Status Card
                        _buildYouCard(user, isDark),
                        const SizedBox(height: 12),

                        // Incoming Friend Requests (only on chats tab)
                        if (_activeListTab == 0) ...[
                          _buildIncomingRequestsSection(context, chatService, isDark),
                        ],

                        // Content List: Chats or Groups
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

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16161D) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Chats Tab
            IconButton(
              icon: Icon(
                Icons.chat_bubble_rounded,
                size: 28,
                color: _currentTabIndex == 0 ? const Color(0xFFFFC72C) : Colors.grey,
              ),
              tooltip: 'Chats',
              onPressed: () => setState(() => _currentTabIndex = 0),
            ),

            // Middle: Floating Quick Draw DoodleUp Button
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateDoodleScreen()),
                );
              },
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC72C), Color(0xFFFF6B35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC72C).withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),

            // Right: Settings / Profile Tab
            IconButton(
              icon: Icon(
                Icons.settings_rounded,
                size: 28,
                color: _currentTabIndex == 1 ? const Color(0xFFFFC72C) : Colors.grey,
              ),
              tooltip: 'Settings',
              onPressed: () => setState(() => _currentTabIndex = 1),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : Colors.grey,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : Colors.grey,
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
      height: 94,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Your Story
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
                        radius: 26,
                      ),
                      if (!user.hasActiveStory)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC72C),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.add, size: 12, color: Colors.black),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your Story',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
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
                      radius: 26,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: Text(
                        contact.name.split(' ').first,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
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
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFC72C).withValues(alpha: 0.2),
            const Color(0xFFFFB703).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFC72C).withValues(alpha: 0.4),
          width: 1.5,
        ),
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
            radius: 26,
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
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E1E26),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC72C),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '@${user.username}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.bio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.patrickHand(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_rounded, color: Color(0xFFFFB703)),
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
            const Text('👋', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              'INCOMING DOODLE REQUESTS (${pendingRequests.length})',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: const Color(0xFFFF4081),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
              const Text('🎨', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'No chats found',
                style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap "Invite others" to send a doodle request!',
                style: GoogleFonts.outfit(color: Colors.grey),
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
              const Text('👥', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'No Doodle Groups Yet',
                style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Create a group and doodle with multiple friends together!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: groups.map((g) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E26) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: g.color.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(color: g.color, width: 2),
              ),
              child: Center(child: Text(g.avatarEmoji, style: const TextStyle(fontSize: 24))),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    g.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 2),
                      Text(
                        '${g.streakCount}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
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
              '${g.memberUsernames.length} members • ${g.latestDoodle != null ? 'Active doodle 🎨' : 'Idle'}',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
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
        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF4081).withValues(alpha: 0.3)),
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
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  contact.name,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              chatService.respondFriendRequest(contact.username, true);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Accepted @${contact.username}! Start doodling 🎨'),
                  backgroundColor: const Color(0xFF00B894),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC72C),
              foregroundColor: const Color(0xFF1E1E26),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Accept 🦆', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
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
    Color statusTextColor = Colors.grey;
    String statusLabel = 'Ready to doodle';
    IconData statusIcon = Icons.edit_note_rounded;

    if (contact.friendshipStatus == FriendshipStatus.requestSent) {
      statusBgColor = const Color(0xFF6C5CE7).withValues(alpha: 0.15);
      statusTextColor = const Color(0xFF6C5CE7);
      statusLabel = 'Request sent • Waiting for approval ⏳';
      statusIcon = Icons.hourglass_top_rounded;
    } else if (contact.doodleStatus == DoodleChatStatus.receivedMustErase) {
      statusBgColor = const Color(0xFFFF4081).withValues(alpha: 0.15);
      statusTextColor = const Color(0xFFFF4081);
      statusLabel = 'Doodle received • Must erase!';
      statusIcon = Icons.cleaning_services_rounded;
    } else if (contact.doodleStatus == DoodleChatStatus.sentWaitingForErase) {
      statusBgColor = const Color(0xFFFFC72C).withValues(alpha: 0.15);
      statusTextColor = const Color(0xFFE5A800);
      statusLabel = 'Sent • Waiting for wipe ⏳';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
            Row(
              children: [
                Text(
                  contact.name,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (contact.streakCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFF7675).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 2),
                        Text(
                          '${contact.streakCount}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF7675),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            Text(
              contact.lastActive,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusTextColor),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
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
