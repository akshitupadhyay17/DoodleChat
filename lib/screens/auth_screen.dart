import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';
import 'onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isEmail = true;
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  String _selectedAvatar = '🦆';
  Color _selectedAvatarColor = const Color(0xFFFFC72C);

  final List<String> _avatarEmojis = ['🦆', '🐱', '🎨', '⚡️', '🌸', '🦊', '🐸', '🚀'];
  final List<Color> _avatarColors = [
    const Color(0xFFFFC72C),
    const Color(0xFFFF7675),
    const Color(0xFF74B9FF),
    const Color(0xFF55EFC4),
    const Color(0xFFA29BFE),
    const Color(0xFFFFEAA7),
  ];

  Future<void> _submit({bool isSkippingOptional = false}) async {
    final chatService = ChatService();
    final handle = _usernameController.text
        .trim()
        .replaceAll('@', '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    if (handle.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pick a unique username (3+ letters, numbers or _) 🦆'),
      ));
      return;
    }
    chatService.currentUser.phoneOrEmail = _contactController.text.trim();
    chatService.currentUser.username = handle;
    if (_bioController.text.trim().isEmpty && !isSkippingOptional) {
      chatService.currentUser.bio = 'Doodling my thoughts away ✨';
    }

    if (!isSkippingOptional) {
      chatService.currentUser.avatarEmoji = _selectedAvatar;
      chatService.currentUser.avatarColor = _selectedAvatarColor;
      chatService.currentUser.bio = _bioController.text.trim();
    }

    chatService.isLoggedIn = true;
    await chatService.saveProfile();
    chatService.connect();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Header with Toy Duck & Title
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC72C),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Text('🦆', style: TextStyle(fontSize: 26))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Join DoodleChat',
                        style: GoogleFonts.gaegu(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E1E26),
                        ),
                      ),
                      Text(
                        'Create your unique doodle handle',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Email / Phone Switcher
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E26) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isEmail = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isEmail
                                ? const Color(0xFFFFC72C)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Email Login',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isEmail ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isEmail = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isEmail
                                ? const Color(0xFFFFC72C)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Phone Number',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !_isEmail ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Contact input
              Text(
                _isEmail ? 'Email Address' : 'Phone Number',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _contactController,
                keyboardType: _isEmail ? TextInputType.emailAddress : TextInputType.phone,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    _isEmail ? Icons.alternate_email_rounded : Icons.phone_rounded,
                    color: const Color(0xFFFFC72C),
                  ),
                  hintText: _isEmail ? 'hello@example.com' : '+1 555-0199',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Unique Username Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Unique Username',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF00B894)),
                      const SizedBox(width: 4),
                      Text(
                        'Available',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF00B894),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  prefixText: '@ ',
                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                  hintText: 'your_username',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Optional Section Banner with "Skip for now" bracket indicator
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC72C).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFC72C).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🎨', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text(
                              'Profile Photo & Bio',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => _submit(isSkippingOptional: true),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Skip for now ➔',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: const Color(0xFFFF6B35),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Avatar Selector
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _selectedAvatarColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(_selectedAvatar, style: const TextStyle(fontSize: 34)),
                        ),
                      ),
                    ),
                    // Avatar Color Picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _avatarColors.map((c) {
                        final isSelected = _selectedAvatarColor == c;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedAvatarColor = c),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.white,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Emoji Pickers
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _avatarEmojis.map((emoji) {
                          final isSelected = _selectedAvatar == emoji;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedAvatar = emoji),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? const Color(0xFFFFC72C)
                                    : (isDark ? Colors.black26 : Colors.white),
                                border: isSelected
                                    ? Border.all(color: Colors.black, width: 2)
                                    : null,
                              ),
                              child: Text(emoji, style: const TextStyle(fontSize: 20)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Bio Input
                    Text(
                      'Bio',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _bioController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Write a short doodle bio...',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => _submit(isSkippingOptional: false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC72C),
                    foregroundColor: const Color(0xFF1E1E26),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue to Onboarding',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
