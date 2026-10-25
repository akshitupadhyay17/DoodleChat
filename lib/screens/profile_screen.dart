import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/doodle_avatar.dart';
import '../widgets/social_logos.dart';
import '../widgets/square_image_cropper_dialog.dart';
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
          content: Text(feedbackMessage ?? 'Link copied to clipboard! ✨'),
          backgroundColor: AppTheme.acidLime,
        ));
      }
    }
  }

  void _showShareProfileDialog() {
    final user = ChatService().currentUser;
    final shareMsg = 'Add me on Doodle to exchange live ephemeral doodles! 🎨 https://doodle.app/u/${user.username}';
    final shareUrl = 'https://doodle.app/u/${user.username}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.electricPink, AppTheme.cyberViolet],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.gesture_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'Doodle Pass',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : const Color(0xFF0E1017),
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: user.qrData,
                    version: QrVersions.auto,
                    size: 180.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0E1017),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: AppTheme.electricPink,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '@${user.username}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0E1017),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan to connect and exchange ephemeral doodles',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF8A90A6)),
                ),
                const SizedBox(height: 20),

                // Share options
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SHARE TO APPS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: const Color(0xFF8A90A6),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // WhatsApp (Official Logo)
                    Expanded(
                      child: _buildShareTile(
                        iconWidget: const WhatsAppLogoWidget(size: 36),
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

                    // Instagram (Official Logo)
                    Expanded(
                      child: _buildShareTile(
                        iconWidget: const InstagramLogoWidget(size: 36),
                        label: 'Instagram',
                        color: const Color(0xFFE1306C),
                        onTap: () {
                          Navigator.pop(ctx);
                          Clipboard.setData(ClipboardData(text: shareMsg));
                          _launchSocial(
                            'instagram://app',
                            fallbackCopyText: shareMsg,
                            feedbackMessage: 'Profile link copied! Share to Instagram Stories or DM 📸',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Copy Link
                    Expanded(
                      child: _buildShareTile(
                        iconWidget: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.cyberViolet.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.cyberViolet.withOpacity(0.35), width: 1.5),
                          ),
                          child: const Center(
                            child: Icon(Icons.link_rounded, color: AppTheme.cyberViolet, size: 21),
                          ),
                        ),
                        label: 'Copy Link',
                        color: AppTheme.cyberViolet,
                        onTap: () {
                          Navigator.pop(ctx);
                          Clipboard.setData(ClipboardData(text: shareUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Copied profile link! 📋',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: AppTheme.acidLime,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Done',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.electricPink,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShareTile({
    required Widget iconWidget,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.24), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final user = ChatService().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    'Preferences',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : const Color(0xFF0E1017),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      'Screenshot Alert Detection',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Notify when someone tries to capture canvas',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF8A90A6)),
                    ),
                    value: user.screenshotAlertsEnabled,
                    activeColor: AppTheme.electricPink,
                    onChanged: (val) {
                      setModalState(() => user.screenshotAlertsEnabled = val);
                      setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      'Haptic Drawing Feedback',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Tactile vibration on drawing and erasing strokes',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF8A90A6)),
                    ),
                    value: user.hapticEnabled,
                    activeColor: AppTheme.electricPink,
                    onChanged: (val) {
                      setModalState(() => user.hapticEnabled = val);
                      setState(() {});
                    },
                  ),
                  ListTile(
                    title: Text(
                      'Auto-Wipe Timer',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Unread doodles self-destruct after 24h',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF8A90A6)),
                    ),
                    trailing: Text(
                      '24 Hours',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.electricPink),
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.shield_rounded, color: AppTheme.acidLime),
              const SizedBox(width: 8),
              Text(
                'Privacy Architecture',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0E1017),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zero-Trace Ephemeral Promise:',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Ephemeral Strokes: Messages are never stored permanently on our database. Once erased by your peer, they vanish from memory forever.\n\n'
                  '2. Turn-Based Exchange: Only one active doodle can exist between peers at any time. The next doodle cannot be sent until the current one is completely erased.\n\n'
                  '3. Anti-Screenshot Protection: Real-time screenshot alerts and canvas cloaking protect your visual privacy.\n\n'
                  '4. Zero Tracking: No analytics or machine learning models are trained on your strokes.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45, color: const Color(0xFF8A90A6)),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.electricPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Understood', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _showSignOutDialog() {
    final user = ChatService().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: AppTheme.electricPink),
              const SizedBox(width: 8),
              Text(
                'Sign Out?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0E1017),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to sign out from @${user.username}?',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF8A90A6)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8A90A6)),
              ),
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.electricPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Sign Out',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
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
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      if (!mounted) return;
      final croppedBase64 = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SquareImageCropperDialog(imageBytes: bytes),
      );
      if (croppedBase64 == null) return;
      final user = ChatService().currentUser;
      user.profilePicBase64 = croppedBase64;
      await ChatService().saveProfile();
      setState(() {});
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile picture updated!',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.acidLime,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatars = ['⚡️', '🔥', '✨', '🪐', '👾', '🌸', '🖤', '🎧', '🛹', '🎨', '🕶️', '💎'];
    final colors = [
      AppTheme.electricPink,
      AppTheme.cyberViolet,
      AppTheme.neonYellow,
      AppTheme.sunsetOrange,
      AppTheme.electricCyan,
      AppTheme.acidLime,
      const Color(0xFF007AFF),
      const Color(0xFF1E202E),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Persona',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF0E1017),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pick photo row
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _pickProfilePhoto();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.electricPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.camera_alt_rounded, color: AppTheme.electricPink),
                          const SizedBox(width: 12),
                          Text(
                            'Upload Photo from Gallery',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.electricPink,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'CHOOSE SYMBOL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: const Color(0xFF8A90A6),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: avatars.map((em) {
                      final isSel = user.avatarEmoji == em && user.profilePicBase64 == null;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setDlgState(() {
                            user.avatarEmoji = em;
                            user.profilePicBase64 = null;
                          });
                          setState(() {});
                          ChatService().saveProfile();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppTheme.electricPink.withOpacity(0.2)
                                : (isDark ? AppTheme.darkSurface : const Color(0xFFF3F4F8)),
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

                  const SizedBox(height: 20),

                  Text(
                    'ACCENT COLOR',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: const Color(0xFF8A90A6),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: colors.map((col) {
                      final isSel = user.avatarColor == col;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setDlgState(() => user.avatarColor = col);
                          setState(() {});
                          ChatService().saveProfile();
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: col.withOpacity(isSel ? 0.6 : 0.2),
                                blurRadius: isSel ? 8 : 4,
                              ),
                            ],
                          ),
                          child: isSel
                              ? const Center(
                                  child: Icon(Icons.check, size: 16, color: Colors.white),
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
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
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    onPressed: widget.onBackToChats ?? () => Navigator.pop(context),
                  ),
                  Text(
                    'Profile',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : const Color(0xFF0E1017),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),

              const SizedBox(height: 20),

              // Avatar with camera badge
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
                      radius: 52,
                      onTap: _showAvatarEditorDialog,
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: AppTheme.electricPink),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Text(
                '@${user.username}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0E1017),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.bio,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF8A90A6)),
              ),

              const SizedBox(height: 24),

              // Quick Action Cards (QR & Copy Link)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _showShareProfileDialog,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_2_rounded, color: AppTheme.electricPink, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Doodle Pass',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : const Color(0xFF0E1017),
                                ),
                              ),
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
                            content: Text(
                              'Profile link copied! ✨',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: AppTheme.acidLime,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.copy_rounded, color: AppTheme.cyberViolet, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Copy Link',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : const Color(0xFF0E1017),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Grouped iOS Settings Container
              Material(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                    // Theme Switch
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.neonYellow.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          user.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: AppTheme.neonYellow,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Appearance',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.isDarkMode ? 'Dark' : 'Light',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF8A90A6)),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: user.isDarkMode,
                            activeColor: AppTheme.electricPink,
                            onChanged: (val) {
                              chatService.toggleTheme();
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),

                    // Settings Preferences
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.cyberViolet.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.tune_rounded, color: AppTheme.cyberViolet, size: 20),
                      ),
                      title: Text(
                        'Canvas & Haptics',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8A90A6)),
                      onTap: _showSettingsDialog,
                    ),
                    Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),

                    // Privacy Architecture
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.acidLime.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield_rounded, color: AppTheme.acidLime, size: 20),
                      ),
                      title: Text(
                        'Privacy & Security',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8A90A6)),
                      onTap: _showPrivacyPolicyDialog,
                    ),
                    Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),

                    // Sign Out
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.electricPink.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.logout_rounded, color: AppTheme.electricPink, size: 20),
                      ),
                      title: Text(
                        'Sign Out',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.electricPink,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8A90A6)),
                      onTap: _showSignOutDialog,
                    ),
                  ],
                ),
              ),
            ),

              const SizedBox(height: 28),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.acidLime,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'doodle • ephemeral by design',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8A90A6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
