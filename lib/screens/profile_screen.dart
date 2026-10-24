import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/chat_service.dart';
import '../widgets/doodle_avatar.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBackToChats;

  const ProfileScreen({super.key, this.onBackToChats});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _launchSocial(String url, {String? fallbackCopyText, String? feedbackMessage}) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (fallbackCopyText != null) {
      Clipboard.setData(ClipboardData(text: fallbackCopyText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(feedbackMessage ?? 'Link copied to clipboard! 📋'),
          backgroundColor: const Color(0xFF00B894),
        ));
      }
    }
  }

  void _showShareProfileDialog() {
    final user = ChatService().currentUser;
    final shareMsg = 'Add me on Doodle to exchange ephemeral doodles! 🎨 https://doodle.app/u/${user.username}';
    final shareUrl = 'https://doodle.app/u/${user.username}';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Doodle up',
                  style: GoogleFonts.gaegu(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Text('🦆', style: TextStyle(fontSize: 24)),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: user.qrData,
                    version: QrVersions.auto,
                    size: 180.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF1E1E26),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Color(0xFFFFB703),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '@${user.username}',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan to connect & exchange ephemeral doodles',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // Share options
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SHARE YOUR PROFILE',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // WhatsApp
                    Expanded(
                      child: _buildShareTile(
                        icon: Icons.chat_bubble_rounded,
                        label: 'WhatsApp',
                        color: const Color(0xFF25D366),
                        onTap: () {
                          Navigator.pop(ctx);
                          final waUrl = 'https://api.whatsapp.com/send?text=${Uri.encodeComponent(shareMsg)}';
                          _launchSocial(waUrl, fallbackCopyText: shareUrl, feedbackMessage: 'WhatsApp link copied! 💬');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Instagram Story
                    Expanded(
                      child: _buildShareTile(
                        icon: Icons.camera_alt_rounded,
                        label: 'Insta Story',
                        color: const Color(0xFFE1306C),
                        onTap: () {
                          Navigator.pop(ctx);
                          Clipboard.setData(ClipboardData(text: shareUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link copied! Open Instagram Story to paste sticker 📸'),
                              backgroundColor: Color(0xFFE1306C),
                            ),
                          );
                          _launchSocial('instagram://story-camera', fallbackCopyText: shareUrl);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Snapchat
                    Expanded(
                      child: _buildShareTile(
                        icon: Icons.flash_on_rounded,
                        label: 'Snapchat',
                        color: const Color(0xFFFFFC00),
                        textColor: const Color(0xFF1E1E26),
                        onTap: () {
                          Navigator.pop(ctx);
                          Clipboard.setData(ClipboardData(text: shareUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile link copied! Share to Snapchat 👻'),
                              backgroundColor: Color(0xFF1E1E26),
                            ),
                          );
                          _launchSocial('snapchat://', fallbackCopyText: shareUrl);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Copy Link
                    Expanded(
                      child: _buildShareTile(
                        icon: Icons.link_rounded,
                        label: 'Copy Link',
                        color: const Color(0xFF6C5CE7),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: shareUrl));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Profile link copied: $shareUrl 📋'),
                              backgroundColor: const Color(0xFF00B894),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareTile({
    required IconData icon,
    required String label,
    required Color color,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final user = ChatService().currentUser;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doodle Settings ⚙️',
                    style: GoogleFonts.gaegu(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Screenshot Alert Detection'),
                    subtitle: const Text('Notify when someone tries to capture canvas'),
                    value: user.screenshotAlertsEnabled,
                    activeColor: const Color(0xFFFFC72C),
                    onChanged: (val) {
                      setModalState(() => user.screenshotAlertsEnabled = val);
                      setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Haptic Drawing Feedback'),
                    subtitle: const Text('Feel pencil vibration on drawing and erasing'),
                    value: user.hapticEnabled,
                    activeColor: const Color(0xFFFFC72C),
                    onChanged: (val) {
                      setModalState(() => user.hapticEnabled = val);
                      setState(() {});
                    },
                  ),
                  ListTile(
                    title: const Text('Auto-Wipe Timer'),
                    subtitle: const Text('Unread doodles self-destruct after 24h'),
                    trailing: const Text('24 Hours', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFF00B894)),
              const SizedBox(width: 8),
              Text(
                'Privacy Policy 🔒',
                style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doodle Zero-Trace Guarantee:',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Ephemeral Doodles: Doodles are never stored on a server permanently. Once the receiver erases the doodle, it is wiped from memory forever.\n\n'
                  '2. Turn-Based Protocol: Only one doodle can exist in transit at any moment. The next doodle cannot be transmitted until the current one is erased.\n\n'
                  '3. Anti-Screenshot & Anti-Recording: On Android, FLAG_SECURE protects against screenshots and video recording. On iOS, screenshot notifications and secure-layer cloaking protect your creative sketches.\n\n'
                  '4. Zero Analytics on Doodles: We do not analyze, scan, or OCR your handwritten strokes.',
                  style: GoogleFonts.outfit(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC72C),
                foregroundColor: const Color(0xFF1E1E26),
              ),
              child: const Text('I Understand & Agree'),
            ),
          ],
        );
      },
    );
  }

  void _showSignOutDialog() {
    final user = ChatService().currentUser;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: Color(0xFFFF4081)),
              const SizedBox(width: 8),
              Text(
                'Sign Out?',
                style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to sign out from @${user.username}?',
            style: GoogleFonts.outfit(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                HapticFeedback.heavyImpact();
                await ChatService().signOut();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Signed out successfully 👋',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: const Color(0xFF1E1E26),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4081),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    try {
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final base64Str = base64Encode(bytes);
      final user = ChatService().currentUser;
      user.profilePicBase64 = base64Str;
      await ChatService().saveProfile();
      setState(() {});
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated! 📷'),
            backgroundColor: Color(0xFF00B894),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update photo: $e')),
        );
      }
    }
  }

  void _showAvatarEditorDialog() {
    final user = ChatService().currentUser;
    final emojis = ['🦆', '🐱', '🎨', '⚡️', '🌸', '🦊', '🐸', '🚀', '🐼', '👾', '🦄', '🍩'];
    final colors = [
      const Color(0xFFFFC72C),
      const Color(0xFFFF7675),
      const Color(0xFF74B9FF),
      const Color(0xFF55EFC4),
      const Color(0xFFA29BFE),
      const Color(0xFFFF6B81),
      const Color(0xFF00CEC9),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          Text('Edit Profile Picture', style: GoogleFonts.gaegu(fontSize: 26, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _pickProfilePhoto();
                              },
                              icon: const Icon(Icons.camera_alt_rounded, size: 18),
                              label: const Text('Upload Photo 📷'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC72C),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          if (user.profilePicBase64 != null) ...[
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                final nav = Navigator.of(ctx);
                                user.profilePicBase64 = null;
                                await ChatService().saveProfile();
                                setDlgState(() {});
                                setState(() {});
                                nav.pop();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Use Emoji'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text('CHOOSE EMOJI', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: emojis.map((em) {
                          final isSel = user.avatarEmoji == em && user.profilePicBase64 == null;
                          return GestureDetector(
                            onTap: () async {
                              user.avatarEmoji = em;
                              user.profilePicBase64 = null;
                              await ChatService().saveProfile();
                              setDlgState(() {});
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFFFFC72C).withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSel ? const Color(0xFFFFC72C) : Colors.transparent, width: 2),
                              ),
                              child: Text(em, style: const TextStyle(fontSize: 26)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      Text('CHOOSE THEME COLOR', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: colors.map((col) {
                          final isSel = user.avatarColor.value == col.value;
                          return GestureDetector(
                            onTap: () async {
                              user.avatarColor = col;
                              await ChatService().saveProfile();
                              setDlgState(() {});
                              setState(() {});
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: Border.all(color: isSel ? Colors.black : Colors.transparent, width: 3),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final user = chatService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Bar with back button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    onPressed: widget.onBackToChats ?? () => Navigator.pop(context),
                  ),
                  Text(
                    'Profile & Settings',
                    style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 40),
                ],
              ),

              const SizedBox(height: 20),

              // Profile Avatar Circle with Custom Photo & Story Ring
              GestureDetector(
                onTap: _showAvatarEditorDialog,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DoodleAvatar(
                      emoji: user.avatarEmoji,
                      color: user.avatarColor,
                      photoBase64: user.profilePicBase64,
                      activeStory: user.activeStory,
                      displayName: 'You',
                      username: user.username,
                      radius: 50,
                      onTap: _showAvatarEditorDialog,
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFC72C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _showAvatarEditorDialog,
                child: Text(
                  'Change Profile Picture 📷',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFFFC72C)),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                '@${user.username}',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.bio,
                textAlign: TextAlign.center,
                style: GoogleFonts.patrickHand(fontSize: 17, color: Colors.grey),
              ),

              const SizedBox(height: 20),

              // QR & Link Copy Quick Cards (From Sketch: "QR, link copy")
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _showShareProfileDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E26) : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_2_rounded, color: Color(0xFFFFB703), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Show QR',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: user.profileLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${user.profileLink} 📋'),
                            backgroundColor: const Color(0xFF00B894),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E26) : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.copy_rounded, color: Color(0xFF6C5CE7), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Copy Link',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Streak Highlights Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF7675).withValues(alpha: 0.18),
                      const Color(0xFFFFC72C).withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF7675).withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7675).withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🔥', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Doodle Streaks',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Exchange doodles daily with friends to keep the flame alive!',
                            style: GoogleFonts.patrickHand(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Settings List Menu (From Sketch):
              // - Theme (Dark, light)
              // - Settings
              // - Privacy Policy
              // - Sign Out
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Theme (Dark, light)
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC72C).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          user.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: const Color(0xFFE5A800),
                        ),
                      ),
                      title: Text(
                        'Theme',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.isDarkMode ? 'Dark' : 'Light',
                            style: GoogleFonts.outfit(color: Colors.grey),
                          ),
                          const SizedBox(width: 6),
                          Switch(
                            value: user.isDarkMode,
                            activeColor: const Color(0xFFFFC72C),
                            onChanged: (val) {
                              chatService.toggleTheme();
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 60),

                    // Settings
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.settings_rounded, color: Color(0xFF6C5CE7)),
                      ),
                      title: Text(
                        'Settings',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                      onTap: _showSettingsDialog,
                    ),
                    const Divider(height: 1, indent: 60),

                    // Privacy Policy
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B894).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.privacy_tip_rounded, color: Color(0xFF00B894)),
                      ),
                      title: Text(
                        'Privacy Policy',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                      onTap: _showPrivacyPolicyDialog,
                    ),
                    const Divider(height: 1, indent: 60),

                    // Sign Out
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4081).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout_rounded, color: Color(0xFFFF4081)),
                      ),
                      title: Text(
                        'Sign Out',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF4081),
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                      onTap: _showSignOutDialog,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Version & Duck Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🦆', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    'Doodle v1.0.0 • Pure Ephemeral Doodling',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
