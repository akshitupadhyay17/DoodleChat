import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _step = 0; // 0 = Username only, 1 = Profile selection / auto-select

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _customEmojiController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedAvatar = '🦆';
  Color _selectedAvatarColor = const Color(0xFFFFC72C);
  String? _selectedPhotoBase64;

  final List<String> _givenAvatars = [
    '🦆', '🐱', '🎨', '⚡️', '🌸', '🦊',
    '🐸', '🚀', '🐼', '👾', '🦄', '🍩',
  ];

  final List<Color> _givenColors = [
    const Color(0xFFFFC72C), // Duck yellow
    const Color(0xFFFF7675), // Coral red
    const Color(0xFF74B9FF), // Sky blue
    const Color(0xFF55EFC4), // Mint
    const Color(0xFFA29BFE), // Lavender
    const Color(0xFFFF6B81), // Pink
    const Color(0xFF00CEC9), // Cyan
    const Color(0xFFFFA07A), // Peach
  ];

  String get _cleanedHandle => _usernameController.text
      .trim()
      .replaceAll('@', '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_.]'), '');

  bool get _isHandleValid => _cleanedHandle.length >= 3;

  Future<void> _pickProfilePhoto() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      setState(() {
        _selectedPhotoBase64 = base64Encode(bytes);
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick photo: $e')),
        );
      }
    }
  }

  void _onContinueUsername() {
    if (!_isHandleValid) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Username must be at least 3 characters (letters, numbers, _)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFFF4081),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _step = 1);
  }

  Future<void> _completeRegistration({bool autoSelect = false}) async {
    HapticFeedback.heavyImpact();
    final chatService = ChatService();

    String finalAvatar = _selectedAvatar;
    Color finalColor = _selectedAvatarColor;
    String? finalPhoto = _selectedPhotoBase64;

    if (autoSelect) {
      final rnd = Random();
      finalAvatar = _givenAvatars[rnd.nextInt(_givenAvatars.length)];
      finalColor = _givenColors[rnd.nextInt(_givenColors.length)];
      finalPhoto = null;
    }

    chatService.currentUser.username = _cleanedHandle;
    chatService.currentUser.avatarEmoji = finalAvatar;
    chatService.currentUser.avatarColor = finalColor;
    chatService.currentUser.profilePicBase64 = finalPhoto;
    chatService.currentUser.bio = 'Doodling away ✨';
    chatService.isLoggedIn = true;
    chatService.isOnboarded = true;

    await chatService.saveProfile();
    chatService.connect();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _customEmojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14141B) : const Color(0xFFFFFDF8),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: _step == 0 ? _buildUsernameStep(isDark) : _buildProfileStep(isDark),
        ),
      ),
    );
  }

  // ───────────────────────── STEP 1: ONLY USERNAME ─────────────────────────
  Widget _buildUsernameStep(bool isDark) {
    return Padding(
      key: const ValueKey('step-username'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Duck Icon & App Name
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
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
                        const Center(child: Text('🦆', style: TextStyle(fontSize: 24))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Doodle',
                style: GoogleFonts.gaegu(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E1E26),
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),

          Text(
            'Choose your @username',
            style: GoogleFonts.gaegu(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E1E26),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a unique handle. Friends will use this to find you and send doodle requests.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 32),

          // Username Input Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E26) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isHandleValid ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.3),
                width: _isHandleValid ? 2 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHandleValid
                      ? const Color(0xFFFFC72C).withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  '@',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFB703),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    autofocus: true,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'yourname',
                      hintStyle: GoogleFonts.outfit(fontSize: 20, color: Colors.grey.shade400),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_isHandleValid)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF00B894), size: 24),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Text(
            _isHandleValid
                ? '✨ Available as @$_cleanedHandle'
                : '• 3 or more characters (letters, numbers, _)',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _isHandleValid ? const Color(0xFF00B894) : Colors.grey,
            ),
          ),

          const Spacer(),

          // Uniform Action Button (Height 54px)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isHandleValid ? _onContinueUsername : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC72C),
                foregroundColor: const Color(0xFF1E1E26),
                disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                disabledForegroundColor: Colors.grey,
                elevation: _isHandleValid ? 2 : 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue ➜',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ───────────────────────── STEP 2: PROFILE CUSTOM / SELECT FROM GIVEN / AUTO SELECT ─────────────────────────
  Widget _buildProfileStep(bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey('step-profile'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation (Back button + Handle)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _step = 0),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC72C).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '@$_cleanedHandle',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE5A800),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            'Style Your Doodle Avatar 🎨',
            style: GoogleFonts.gaegu(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E1E26),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select from given avatars, type any custom emoji, or tap auto-select to start instantly!',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 24),

          // Big Interactive Live Avatar Preview with Custom Photo Support
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: _selectedAvatarColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedAvatarColor.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _selectedPhotoBase64 != null
                      ? Image.memory(
                          base64Decode(_selectedPhotoBase64!),
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Text(
                            _selectedAvatar,
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _pickProfilePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC72C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: _pickProfilePhoto,
                  icon: const Icon(Icons.photo_library_rounded, size: 16, color: Color(0xFFFFC72C)),
                  label: Text(
                    _selectedPhotoBase64 != null ? 'Change Photo' : 'Upload Profile Pic 📷',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFFFFC72C)),
                  ),
                ),
                if (_selectedPhotoBase64 != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _selectedPhotoBase64 = null),
                    child: Text('Use Emoji', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Select From Given: Avatars
          Text(
            'SELECT AVATAR',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _givenAvatars.map((emoji) {
              final isSelected = _selectedAvatar == emoji;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedAvatar = emoji);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFC72C).withValues(alpha: 0.25)
                        : (isDark ? const Color(0xFF1E1E26) : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFFC72C) : Colors.transparent,
                      width: 2.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFC72C).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFC72C),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 10, color: Color(0xFF1E1E26)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          // Select From Given: Colors
          Text(
            'SELECT COLOR',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _givenColors.map((col) {
              final isSelected = _selectedAvatarColor == col;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedAvatarColor = col);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: col.withValues(alpha: isSelected ? 0.6 : 0.2),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Center(
                          child: Icon(Icons.check, size: 18, color: Colors.white),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          // Custom Emoji Entry
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E26) : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_reaction_outlined, color: Color(0xFFFFB703), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _customEmojiController,
                    decoration: InputDecoration(
                      hintText: 'Or type custom emoji (e.g. 🦁, 🍕)',
                      hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    onChanged: (text) {
                      final val = text.trim();
                      if (val.isNotEmpty) {
                        setState(() => _selectedAvatar = val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Action Buttons: BOTH SAME SIZE (Height 54px)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => _completeRegistration(autoSelect: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC72C),
                foregroundColor: const Color(0xFF1E1E26),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'Enter Doodle 🎨',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Auto-Select to Proceed Without Selecting (Same Size: 54px)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () => _completeRegistration(autoSelect: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF1E1E26),
                side: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Auto-Select & Jump In',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
