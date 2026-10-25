import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'social_logos.dart';

/// Shows the "Doodle Pass" QR Code Dialog with QR scanner data and social share buttons.
void showDoodlePassDialog(BuildContext context) {
  final user = ChatService().currentUser;
  final shareMsg =
      'Add me on Doodle to exchange live ephemeral doodles! 🎨 https://doodle.app/u/${user.username}';
  final shareUrl = 'https://doodle.app/u/${user.username}';
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final messenger = ScaffoldMessenger.of(context);

  Future<void> launchSocial(
    String url, {
    String? fallbackCopyText,
    String? feedbackMessage,
  }) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (fallbackCopyText != null) {
      Clipboard.setData(ClipboardData(text: fallbackCopyText));
      messenger.showSnackBar(SnackBar(
        content: Text(feedbackMessage ?? 'Link copied to clipboard! ✨'),
        backgroundColor: AppTheme.acidLime,
      ));
    }
  }

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
                        final waUrl =
                            'https://api.whatsapp.com/send?text=${Uri.encodeComponent(shareMsg)}';
                        launchSocial(waUrl,
                            fallbackCopyText: shareUrl,
                            feedbackMessage: 'WhatsApp link copied! 💬');
                      },
                      isDark: isDark,
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
                        launchSocial(
                          'instagram://app',
                          fallbackCopyText: shareMsg,
                          feedbackMessage:
                              'Profile link copied! Share to Instagram Stories or DM 📸',
                        );
                      },
                      isDark: isDark,
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
                          border: Border.all(
                              color: AppTheme.cyberViolet.withOpacity(0.35), width: 1.5),
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
                      isDark: isDark,
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
  required bool isDark,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E202E) : const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        children: [
          iconWidget,
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF4A4E5C),
            ),
          ),
        ],
      ),
    ),
  );
}
