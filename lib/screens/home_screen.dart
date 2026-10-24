import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_contact.dart';
import '../services/chat_service.dart';
import '../widgets/find_friends_sheet.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
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

  @override
  Widget build(BuildContext context) {
    if (_currentTabIndex == 2) {
      return ProfileScreen(
        onBackToChats: () => setState(() => _currentTabIndex = 0),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatService = ChatService();
    final user = chatService.currentUser;

    final filteredContacts = chatService.contacts.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.username.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Logo & Branding
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
                        'DoodleChat',
                        style: GoogleFonts.gaegu(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E1E26),
                        ),
                      ),
                    ],
                  ),
                  // Live Friends / Privacy Pill
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _showAddFriendDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: chatService.onlinePeers.isNotEmpty
                                ? const Color(0xFF00B894).withOpacity(0.18)
                                : const Color(0xFFFFC72C).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: chatService.onlinePeers.isNotEmpty
                                  ? const Color(0xFF00B894)
                                  : const Color(0xFFFFC72C),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: chatService.onlinePeers.isNotEmpty
                                      ? const Color(0xFF00B894)
                                      : const Color(0xFFFFC72C),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                chatService.onlinePeers.isNotEmpty
                                    ? '${chatService.onlinePeers.length} Live'
                                    : 'Connect',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: chatService.onlinePeers.isNotEmpty
                                      ? const Color(0xFF00B894)
                                      : const Color(0xFFE5A800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B894).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield, size: 14, color: Color(0xFF00B894)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar (From Sketch: "Search" at top)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A22) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFFFC72C)),
                    hintText: 'Search chats, doodles, friends...',
                    hintStyle: GoogleFonts.outfit(fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                children: [
                  // "You" Status Card (From Sketch: "You" with status)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFC72C).withOpacity(0.2),
                          const Color(0xFFFFB703).withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFC72C).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Avatar with Status Dot
                        Stack(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: user.avatarColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text(user.avatarEmoji, style: const TextStyle(fontSize: 26)),
                              ),
                            ),
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
                          onPressed: () => setState(() => _currentTabIndex = 2),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // "+ others (Add) / invite" Row (From Sketch)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DOODLE CONVERSATIONS',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showAddFriendDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC72C).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFC72C), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add_rounded, size: 16, color: Color(0xFFE5A800)),
                              const SizedBox(width: 4),
                              Text(
                                '+ others (Add)',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFE5A800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Chat Cards List
                  if (filteredContacts.isEmpty)
                    Center(
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
                              'Tap "+ others" to start a live doodle chat!',
                              style: GoogleFonts.outfit(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filteredContacts.map((contact) => _buildContactCard(context, contact, isDark)),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar with 3 tabs matching the Sketch:
      // Left: Chats, Middle: Quick Doodle Draw, Right: Profile
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16161D) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Left: Chats Tab
            IconButton(
              icon: Icon(
                Icons.chat_bubble_rounded,
                size: 28,
                color: _currentTabIndex == 0 ? const Color(0xFFFFC72C) : Colors.grey,
              ),
              onPressed: () => setState(() => _currentTabIndex = 0),
            ),

            // Middle: Floating Quick Draw Doodle Button
            GestureDetector(
              onTap: () {
                // Open doodle chat with first contact or prompt
                if (chatService.contacts.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(contact: chatService.contacts.first),
                    ),
                  );
                } else {
                  _showAddFriendDialog();
                }
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC72C), Color(0xFFFF6B35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC72C).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),

            // Right: Profile Tab
            IconButton(
              icon: Icon(
                Icons.person_rounded,
                size: 28,
                color: _currentTabIndex == 2 ? const Color(0xFFFFC72C) : Colors.grey,
              ),
              onPressed: () => setState(() => _currentTabIndex = 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, ChatContact contact, bool isDark) {
    Color statusBgColor = Colors.transparent;
    Color statusTextColor = Colors.grey;
    String statusLabel = 'Ready to doodle';
    IconData statusIcon = Icons.edit_note_rounded;

    if (contact.doodleStatus == DoodleChatStatus.receivedMustErase) {
      statusBgColor = const Color(0xFFFF4081).withOpacity(0.15);
      statusTextColor = const Color(0xFFFF4081);
      statusLabel = 'Doodle received • Must erase!';
      statusIcon = Icons.cleaning_services_rounded;
    } else if (contact.doodleStatus == DoodleChatStatus.sentWaitingForErase) {
      statusBgColor = const Color(0xFFFFC72C).withOpacity(0.15);
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: contact.avatarColor.withOpacity(0.25),
                shape: BoxShape.circle,
                border: Border.all(color: contact.avatarColor, width: 2),
              ),
              child: Center(
                child: Text(contact.avatarEmoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            if (contact.isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF1E1E26) : Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              contact.name,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
