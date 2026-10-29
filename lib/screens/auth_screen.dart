import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/square_image_cropper_dialog.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _step = 0; // 0 = Username, 1 = Profile avatar

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _customEmojiController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedAvatar = '⚡️';
  Color _selectedAvatarColor = AppTheme.electricPink;
  String? _selectedPhotoBase64;

  Timer? _handleCheckTimer;
  bool _isCheckingHandle = false;
  bool? _isHandleAvailable;
  String? _handleError;
  bool _isSubmitting = false;

  final List<String> _givenAvatars = [
    '⚡️', '🔥', '✨', '🪐', '👾', '🌸',
    '🖤', '🎧', '🛹', '🎨', '🕶️', '💎',
  ];

  final List<Color> _givenColors = [
    AppTheme.electricPink,
    AppTheme.cyberViolet,
    AppTheme.neonYellow,
    AppTheme.sunsetOrange,
    AppTheme.electricCyan,
    AppTheme.acidLime,
    const Color(0xFF007AFF),
    const Color(0xFF1E202E),
  ];

  String get _cleanedHandle => _usernameController.text
      .trim()
      .replaceAll('@', '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_.]'), '');

  bool get _isHandleValid => _cleanedHandle.length >= 3 && _isHandleAvailable != false;

  void _onHandleTextChanged(String _) {
    _handleCheckTimer?.cancel();
    final handle = _cleanedHandle;
    if (handle.length < 3) {
      setState(() {
        _isCheckingHandle = false;
        _isHandleAvailable = null;
        _handleError = null;
      });
      return;
    }
    setState(() {
      _isCheckingHandle = true;
      _isHandleAvailable = null;
      _handleError = null;
    });
    _handleCheckTimer = Timer(const Duration(milliseconds: 350), () async {
      final available = await ChatService().checkUsernameAvailable(handle);
      if (!mounted || _cleanedHandle != handle) return;
      setState(() {
        _isCheckingHandle = false;
        _isHandleAvailable = available;
        _handleError = available
            ? null
            : '@$handle is already taken. No two users can have the same ID!';
      });
    });
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final xfile = await _picker.pickImage(
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
      setState(() {
        _selectedPhotoBase64 = croppedBase64;
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

  Future<void> _onContinueUsername() async {
    final handle = _cleanedHandle;
    if (handle.length < 3) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Username must be at least 3 characters',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppTheme.electricPink,
        ),
      );
      return;
    }
    if (_isCheckingHandle || _isSubmitting) return;

    setState(() {
      _isCheckingHandle = true;
      _handleError = null;
    });
    final available = await ChatService().checkUsernameAvailable(handle);
    if (!mounted) return;
    setState(() {
      _isCheckingHandle = false;
      _isHandleAvailable = available;
    });
    if (!available) {
      HapticFeedback.vibrate();
      setState(() {
        _handleError = '@$handle is already taken. No two users can have the same ID!';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '@$handle is already taken! Pick a unique ID.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppTheme.electricPink,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _step = 1);
  }

  Future<void> _completeRegistration({bool autoSelect = false}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();
    final chatService = ChatService();

    // Re-check uniqueness before completing registration
    final available = await chatService.checkUsernameAvailable(_cleanedHandle);
    if (!mounted) return;
    if (!available) {
      setState(() {
        _isSubmitting = false;
        _step = 0;
        _isHandleAvailable = false;
        _handleError = '@$_cleanedHandle is already taken. No two users can have the same ID!';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '@$_cleanedHandle is already taken! Please choose another ID.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppTheme.electricPink,
        ),
      );
      return;
    }

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
    chatService.currentUser.bio = 'Doodling in real-time ✨';
    chatService.isLoggedIn = true;
    chatService.isOnboarded = true;

    final err = await chatService.registerAndVerify();
    if (!mounted) return;
    if (err != null) {
      chatService.isLoggedIn = false;
      chatService.isOnboarded = false;
      chatService.currentUser.username = '';
      setState(() {
        _isSubmitting = false;
        _step = 0;
        _isHandleAvailable = false;
        _handleError = err;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppTheme.electricPink,
        ),
      );
      return;
    }

    await chatService.saveProfile();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _handleCheckTimer?.cancel();
    _usernameController.dispose();
    _customEmojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _step == 0 ? _buildUsernameStep(isDark) : _buildProfileStep(isDark),
        ),
      ),
    );
  }

  Widget _buildUsernameStep(bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey('step-username'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.electricPink, AppTheme.cyberViolet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.gesture_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'doodle',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: isDark ? Colors.white : const Color(0xFF0E1017),
                ),
              ),
            ],
          ),

          const SizedBox(height: 48),

          Text(
            'Claim your\n@handle',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -1.0,
              color: isDark ? Colors.white : const Color(0xFF0E1017),
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 10),

          Text(
            'Friends will use your handle to send ephemeral doodles and find your canvas.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.45,
              color: isDark ? const Color(0xFFA5ABC0) : const Color(0xFF5D6275),
            ),
          ),

          const SizedBox(height: 36),

          // Modern iOS-style Input Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHandleValid
                    ? AppTheme.electricPink
                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
                width: _isHandleValid ? 2 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHandleValid
                      ? AppTheme.electricPink.withOpacity(0.2)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  '@',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _isHandleValid ? AppTheme.electricPink : const Color(0xFF8A90A6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    autofocus: true,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0E1017),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                    ],
                    onChanged: _onHandleTextChanged,
                    decoration: InputDecoration(
                      hintText: 'username',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_isCheckingHandle)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppTheme.electricPink,
                    ),
                  )
                else if (_cleanedHandle.length >= 3 && _isHandleAvailable == false)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.electricPink,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ).animate().shakeX(hz: 4, amount: 3)
                else if (_isHandleValid)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.acidLime,
                    ),
                    child: const Icon(Icons.check, color: Colors.black, size: 16),
                  ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Text(
            _handleError != null
                ? '⚠️ $_handleError'
                : _isCheckingHandle
                    ? 'Checking if @$_cleanedHandle is available…'
                    : _isHandleValid
                        ? '✨ @$_cleanedHandle is unique & ready'
                        : 'Letters, numbers, and underscores (min 3 chars)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _handleError != null
                  ? AppTheme.electricPink
                  : (_isHandleValid ? AppTheme.acidLime : const Color(0xFF8A90A6)),
            ),
          ),

          const SizedBox(height: 36),

          // CTA Continue Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: _isHandleValid
                  ? const LinearGradient(
                      colors: [AppTheme.electricPink, Color(0xFFFF3B30)],
                    )
                  : null,
              color: _isHandleValid ? null : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isHandleValid
                  ? [
                      BoxShadow(
                        color: AppTheme.electricPink.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isHandleValid ? _onContinueUsername : null,
                borderRadius: BorderRadius.circular(20),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _isHandleValid ? Colors.white : const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: _isHandleValid ? Colors.white : const Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── STEP 2: PROFILE SETUP ─────────────────────────
  Widget _buildProfileStep(bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey('step-profile'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => setState(() => _step = 0),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.electricPink.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '@$_cleanedHandle',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.electricPink,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            'Your Persona',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: isDark ? Colors.white : const Color(0xFF0E1017),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose your signature avatar and accent color, or upload a photo.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark ? const Color(0xFFA5ABC0) : const Color(0xFF5D6275),
            ),
          ),

          const SizedBox(height: 28),

          // Avatar Preview with Camera Overlay
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: _selectedAvatarColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedAvatarColor.withOpacity(0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
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
                  bottom: 2,
                  child: GestureDetector(
                    onTap: _pickProfilePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Color(0xFF0E1017),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: _pickProfilePhoto,
                  icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.electricPink),
                  label: Text(
                    _selectedPhotoBase64 != null ? 'Change Photo' : 'Upload Photo',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.electricPink,
                    ),
                  ),
                ),
                if (_selectedPhotoBase64 != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _selectedPhotoBase64 = null),
                    child: Text(
                      'Use Symbol',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF8A90A6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'CHOOSE SYMBOL',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: const Color(0xFF8A90A6),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _givenAvatars.map((emoji) {
                  final isSelected = _selectedAvatar == emoji && _selectedPhotoBase64 == null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedAvatar = emoji;
                          _selectedPhotoBase64 = null;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.electricPink.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppTheme.electricPink : Colors.transparent,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'ACCENT COLOR',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: const Color(0xFF8A90A6),
            ),
          ),
          const SizedBox(height: 12),

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
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: col.withOpacity(isSelected ? 0.6 : 0.2),
                        blurRadius: isSelected ? 10 : 4,
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

          const SizedBox(height: 32),

          // Primary Enter Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.electricPink, Color(0xFFFF3B30)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.electricPink.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _completeRegistration(autoSelect: false),
                borderRadius: BorderRadius.circular(20),
                child: Center(
                  child: Text(
                    'Enter Doodle',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Auto-select shortcut
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () => _completeRegistration(autoSelect: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF0E1017),
                side: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(
                'Auto-Select & Jump In',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
