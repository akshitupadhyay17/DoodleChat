import 'dart:async';
import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/chat_contact.dart';
import '../models/doodle_stroke.dart';
import '../services/chat_service.dart';
import '../services/doodle_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/doodle_avatar.dart';
import '../widgets/doodle_canvas.dart';
import '../widgets/privacy_watermark.dart';
import '../widgets/cartoon_emoji_renderer.dart';

class ChatScreen extends StatefulWidget {
  final ChatContact contact;

  /// When set, the chat opens as a reply to this friend's DoodleUp.
  final DoodleData? replyToStory;

  const ChatScreen({super.key, required this.contact, this.replyToStory});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _service = ChatService();
  final DoodleController _doodle = DoodleController();
  late final ConfettiController _confetti;
  final TextEditingController _textCtrl = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  StreamSubscription<ChatEvent>? _eventSub;

  String? _loadedDoodleId;
  bool _isRecordingVoice = false;
  bool _showReplyBanner = true;
  String _selectedDoodleFont = 'PatrickHand';

  Timer? _drawingTimer;
  bool _iAmDrawing = false;
  bool _isDraggingBrushSlider = false;
  bool? _lastThemeDark;

  String? _topToastMessage;
  Color _topToastColor = const Color(0xFF00B894);
  IconData? _topToastIcon;
  Timer? _topToastTimer;
  bool _topToastVisible = false;

  final List<Color> _colors = const [
    Colors.white,
    Colors.black,
    Color(0xFFFF2D55), // Hot Pink
    Color(0xFFFF4081), // Electric Pink
    Color(0xFF7928CA), // Cyber Violet
    Color(0xFF007AFF), // Royal Blue
    Color(0xFF00CEC9), // Sky Cyan
    Color(0xFFA3E635), // Acid Lime
    Color(0xFFFFC72C), // Bright Yellow
    Color(0xFFFF9500), // Neon Orange
    Color(0xFFFF3B30), // Ruby Red
    Color(0xFF00B894), // Mint
    Color(0xFFFFB8B8), // Pastel Peach
  ];

  final List<String> _emojiDoodles = [
    '⚡️', '🔥', '✨', '💖', '⭐', '🥰', '🌸', '🌈', '🎉', '💯'
  ];

  ChatContact get _contact => widget.contact;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _doodle.color = AppTheme.duckYellow;
    _doodle.onErasedAll = _onDoodleErasedSuccess;
    _doodle.onEraseProgress = (p) => _service.sendEraseProgress(_contact, p);
    _doodle.onStrokeStart = _markDrawing;

    _service.activeChat = _contact.username;
    _service.addListener(_syncFromService);
    _eventSub = _service.events.listen(_onEvent);
    _textCtrl.addListener(() => setState(() {}));
    _syncFromService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark || _service.currentUser.isDarkMode;
    if (_lastThemeDark != isDark) {
      _lastThemeDark = isDark;
      if (!_doodle.mustErase) {
        if (isDark) {
          _doodle.setBrushType(DoodleBrushType.neon);
        } else {
          _doodle.setBrushType(DoodleBrushType.pen);
        }
      }
    }
  }

  @override
  void dispose() {
    _service.activeChat = null;
    _service.removeListener(_syncFromService);
    _eventSub?.cancel();
    _drawingTimer?.cancel();
    _topToastTimer?.cancel();
    if (_iAmDrawing) _service.sendDrawingState(_contact, false);
    _speech.cancel();
    _confetti.dispose();
    _textCtrl.dispose();
    _doodle.dispose();
    super.dispose();
  }

  // ───────────────────────── real-time sync ─────────────────────────

  /// Mirrors the service state (incoming doodle, friend erased mine, …) onto the canvas.
  void _syncFromService() {
    final status = _contact.doodleStatus;
    final d = _contact.pendingDoodle;

    switch (status) {
      case DoodleChatStatus.receivedMustErase:
        if (d != null && _loadedDoodleId != d.id) {
          _loadedDoodleId = d.id;
          _doodle.locked = false;
          _doodle.load(d, forErasing: true);
        }
        _doodle.mustErase = true;
        _doodle.eraser = true;
        break;
      case DoodleChatStatus.sentWaitingForErase:
        if (d != null && _loadedDoodleId != d.id) {
          _loadedDoodleId = d.id;
          _doodle.mustErase = false;
          _doodle.load(d, forErasing: false);
        }
        _doodle.locked = true;
        break;
      case DoodleChatStatus.idle:
        _doodle.locked = false;
        _doodle.mustErase = false;
        if (_loadedDoodleId != null) {
          _loadedDoodleId = null;
          _doodle.setEraser(false);
          _doodle.clear();
        }
        break;
    }
    if (mounted) setState(() {});
  }

  void _onEvent(ChatEvent e) {
    if (!mounted || e.contact != _contact) return;
    if (e.type == ChatEventType.doodleErased) {
      _confetti.play();
      HapticFeedback.heavyImpact();
      _toast('${_contact.name} erased your doodle! Your turn ✏️', const Color(0xFF00B894));
    } else if (e.type == ChatEventType.sendRejected) {
      _toast(e.message ?? 'Could not send.', const Color(0xFFFF4081));
    } else if (e.type == ChatEventType.incomingDoodle) {
      HapticFeedback.mediumImpact();
    } else if (e.type == ChatEventType.friendRequestAccepted) {
      HapticFeedback.heavyImpact();
      _confetti.play();
      _doodle.locked = false;
      _toast('${_contact.name} accepted your doodle request! Canvas unlocked 🎨', const Color(0xFF00B894));
      setState(() {});
    } else if (e.type == ChatEventType.friendRequestDeclined) {
      _toast('${_contact.name} declined the request.', Colors.grey);
      setState(() {});
    }
  }

  void _markDrawing() {
    if (!_iAmDrawing) {
      _iAmDrawing = true;
      _service.sendDrawingState(_contact, true);
    }
    _drawingTimer?.cancel();
    _drawingTimer = Timer(const Duration(milliseconds: 2500), () {
      _iAmDrawing = false;
      _service.sendDrawingState(_contact, false);
    });
  }

  void _showTopNotification(String msg, Color color, {IconData? icon}) {
    if (!mounted) return;
    _topToastTimer?.cancel();
    setState(() {
      _topToastMessage = msg;
      _topToastColor = color;
      _topToastIcon = icon ?? Icons.info_outline_rounded;
      _topToastVisible = true;
    });
    _topToastTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        setState(() => _topToastVisible = false);
      }
    });
  }

  void _toast(String msg, Color color, {IconData? icon}) {
    _showTopNotification(msg, color, icon: icon);
  }

  // ───────────────────────── actions ─────────────────────────

  void _onDoodleErasedSuccess() {
    _confetti.play();
    HapticFeedback.heavyImpact();
    _service.markDoodleErased(_contact.id);
    _doodle.setEraser(false);
    _toast('Doodle erased! Canvas unlocked — you can reply 🪄', const Color(0xFF00B894), icon: Icons.celebration_rounded);
  }

  Future<void> _pickPhoto() async {
    try {
      final xfile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        imageQuality: 80,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final base64Str = base64Encode(bytes);
      setState(() {
        _doodle.setBackgroundPhoto(base64Str);
      });
      _toast('Photo loaded! Compulsory to draw a doodle on it 🎨', const Color(0xFFFF4081));
    } catch (e) {
      _toast('Could not open photo: $e', Colors.black87);
    }
  }

  void _sendDoodle() {
    final hasPhoto = _doodle.backgroundPhoto != null && _doodle.backgroundPhoto!.isNotEmpty;
    final hasDoodle = _doodle.strokes.isNotEmpty || _doodle.texts.isNotEmpty || _doodle.emojis.isNotEmpty;

    if (hasPhoto && !hasDoodle) {
      _toast('Compulsory: Draw a doodle on your photo before sending! 🎨', const Color(0xFFFF4081));
      return;
    }

    if (_doodle.isEmpty) {
      _toast('Please draw something on the canvas first! 🎨', Colors.black87);
      return;
    }
    final data = _doodle.toData(_service.currentUser.username);
    _loadedDoodleId = data.id; // so the sync doesn't reload my own canvas
    final ok = _service.sendDoodle(_contact.id, data);
    if (!ok) {
      _loadedDoodleId = null;
      _service.resume();
      _toast('You are offline — reconnecting. Try again in a second.', Colors.orange);
      return;
    }
    _drawingTimer?.cancel();
    if (_iAmDrawing) {
      _iAmDrawing = false;
      _service.sendDrawingState(_contact, false);
    }
    HapticFeedback.mediumImpact();
    _toast('Doodle delivered! Waiting for ${_contact.name} to erase it.', const Color(0xFF6C5CE7));
  }

  void _addText(String text) {
    if (text.trim().isEmpty) return;
    _doodle.color = _doodle.eraser ? AppTheme.duckYellow : _doodle.color;
    _doodle.addText(text, _selectedDoodleFont);
    _textCtrl.clear();
    _markDrawing();
    HapticFeedback.lightImpact();
  }

  Future<void> _toggleVoice() async {
    if (_isRecordingVoice) {
      await _speech.stop();
      setState(() => _isRecordingVoice = false);
      return;
    }
    final ok = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isRecordingVoice = false);
      },
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) {
          setState(() => _isRecordingVoice = false);
        }
      },
    );
    if (!ok) {
      _toast('Voice input isn\'t available here (needs mic permission + https).', Colors.orange);
      return;
    }
    setState(() => _isRecordingVoice = true);
    _speech.listen(
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      onResult: (r) {
        _textCtrl.text = r.recognizedWords;
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          _addText(r.recognizedWords);
          _toast('Voice ➔ handwritten doodle ✍️', const Color(0xFFFFC72C));
        }
      },
    );
  }

  void _showEmojiPickerSheet(BuildContext context) {
    final customCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = <String, List<String>>{
      '⚡️ Vibes & Energy': ['⚡️', '🔥', '✨', '⭐', '🌟', '💫', '💥', '🌈', '☀️', '🌙', '🪐', '☁️', '❄️', '🌸', '🍀'],
      '💖 Moods & Reactions': ['🥰', '😍', '💖', '❤️', '💕', '💘', '💛', '😎', '🤪', '🥳', '🤩', '🥺', '😂', '🤤', '😇'],
      '🎨 Creative & Play': ['🎨', '🖌️', '✏️', '🖍️', '💌', '🎈', '🎉', '🪄', '🎯', '🚀', '💎', '🍕', '🍦', '🍩', '☕'],
      '👍 Gestures & Signs': ['✌️', '👍', '👏', '🙌', '🤝', '👋', '🤘', '🤙', '👀', '💯', '💬', '💭', '💡', '🎵', '👑'],
      '🐾 Creatures': ['🐱', '🐶', '🐰', '🦊', '🐻', '🐼', '🐸', '🦄', '🐾', '🐝', '🐙', '🦋', '🐥', '🦁', '🐯'],
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E26) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar & Title
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🎨', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Text(
                              'Stickers & Stamps',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : const Color(0xFF14141E),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Custom Emoji Input Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF14141B) : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFC72C).withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_emotions_outlined, color: Color(0xFFFFC72C), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: customCtrl,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white : const Color(0xFF14141E),
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFFFFC72C),
                              decoration: InputDecoration(
                                hintText: 'Type or paste ANY emoji here...',
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF9094A6) : const Color(0xFF8A90A6),
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              final text = customCtrl.text.trim();
                              if (text.isNotEmpty) {
                                if (!_emojiDoodles.contains(text)) {
                                  setState(() => _emojiDoodles.insert(0, text));
                                }
                                _doodle.addEmoji(text);
                                _markDrawing();
                                HapticFeedback.mediumImpact();
                                Navigator.pop(ctx);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC72C),
                              foregroundColor: const Color(0xFF1E1E26),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Stamp', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Categories & Grids
                    Expanded(
                      child: ListView(
                        children: categories.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  entry.key,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFFB0B5C6) : const Color(0xFF6B7280),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: entry.value.map((e) {
                                  return _Pressable(
                                    onTap: () {
                                      if (!_emojiDoodles.contains(e)) {
                                        setState(() => _emojiDoodles.insert(0, e));
                                      }
                                      _doodle.addEmoji(e);
                                      _markDrawing();
                                      HapticFeedback.selectionClick();
                                      Navigator.pop(ctx);
                                    },
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: CartoonEmojiWidget(emoji: e, size: 28),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChatThemeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final themes = ['Default', 'Neon Glow', 'Sunset Glow', 'Midnight Duck', 'Mint Matcha'];
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Chat Theme',
                style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...themes.map((t) {
                final isSelected = _contact.chatTheme == t;
                return ListTile(
                  leading: const Icon(Icons.palette_outlined, color: Color(0xFFFFC72C)),
                  title: Text(t, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF00B894)) : null,
                  onTap: () {
                    _service.updateChatTheme(_contact.id, t);
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showThreeDotsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.palette_rounded, color: Color(0xFFFFC72C)),
                title: Text('Chat Theme', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                subtitle: Text('Current: ${_contact.chatTheme}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChatThemeSelector();
                },
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined, color: Color(0xFF00B894)),
                title: Text('Privacy Shield & Anti-Screenshot', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                subtitle: const Text('Active • Screenshots and recordings blocked'),
                onTap: () {
                  Navigator.pop(ctx);
                  _toast('Privacy Shield: Active! Ephemeral canvas wipes on delete.', const Color(0xFF00B894));
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.orange),
                title: Text('Block @${_contact.username}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _toast('Blocked @${_contact.username}', Colors.black87);
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_problem_rounded, color: Colors.red),
                title: Text('Report User', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _toast('Report submitted. We take privacy seriously.', Colors.black87);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getCanvasBackgroundColor(bool isDark) {
    switch (_contact.chatTheme) {
      case 'Neon Glow':
        return const Color(0xFF0D0221);
      case 'Sunset Glow':
        return isDark ? const Color(0xFF261118) : const Color(0xFFFFF0ED);
      case 'Midnight Duck':
        return const Color(0xFF090A0F);
      case 'Mint Matcha':
        return isDark ? const Color(0xFF0F231D) : const Color(0xFFEDFAF5);
      default:
        return isDark ? const Color(0xFF15151C) : const Color(0xFFFAFAF7);
    }
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _contact.doodleStatus;
    final isMustErase = status == DoodleChatStatus.receivedMustErase;
    final isSentWaiting = status == DoodleChatStatus.sentWaitingForErase;
    final isRequestSent = _contact.friendshipStatus == FriendshipStatus.requestSent;
    final isRequestReceived = _contact.friendshipStatus == FriendshipStatus.requestReceived;
    final isBlocked = isRequestSent || isRequestReceived;

    if (isBlocked && !_doodle.locked) {
      _doodle.locked = true;
    }

    return Scaffold(
      backgroundColor: _getCanvasBackgroundColor(isDark),
      body: PrivacyShieldOverlay(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top Bar (From Sketch: Profile at top left, three dots at right)
                  _buildTopBar(context, isDark),

                  // Replying-to-DoodleUp banner
                  if (widget.replyToStory != null && _showReplyBanner && !isBlocked && !isMustErase)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      decoration: BoxDecoration(
                        color: AppTheme.electricPink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border(
                          left: BorderSide(color: AppTheme.electricPink, width: 4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.reply_rounded, size: 18, color: AppTheme.electricPink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Replying to ${_contact.name}\'s DoodleUp 🎨 — draw your reply below',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0E1017),
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _showReplyBanner = false),
                          ),
                        ],
                      ),
                    ),

                  // Status / Mechanic Banner (animated in/out)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: isRequestReceived
                          ? _buildRequestReceivedBanner()
                          : isRequestSent
                              ? _buildRequestSentBanner()
                              : isMustErase
                                  ? _buildMustEraseBanner()
                                  : isSentWaiting
                                      ? _buildSentWaitingBanner()
                                      : const SizedBox(width: double.infinity, key: ValueKey('none')),
                    ),
                  ),

                  // Drawing Canvas Area ("draw" in sketch)
                  Expanded(
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          isSentWaiting
                              ? ValueListenableBuilder<double>(
                                  valueListenable: _contact.peerEraseProgress,
                                  builder: (_, p, child) => Opacity(
                                    opacity: (1 - p * 0.9).clamp(0.08, 1.0),
                                    child: child,
                                  ),
                                  child: DoodleCanvas(controller: _doodle),
                                )
                              : DoodleCanvas(controller: _doodle),

                          // Instagram Left Vertical Brush-Size & Eraser Slider
                          if (!isSentWaiting && !isBlocked)
                            Positioned(
                              left: 12,
                              top: 20,
                              bottom: 20,
                              child: _buildInstagramVerticalBrushSlider(isDark),
                            ),

                          // Lock overlay when waiting for request approval
                          if (isBlocked)
                            IgnorePointer(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: isRequestReceived
                                              ? const Color(0xFFFFC72C).withValues(alpha: 0.2)
                                              : const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isRequestReceived ? Icons.mail_outline_rounded : Icons.lock_outline_rounded,
                                            size: 36,
                                            color: isRequestReceived ? const Color(0xFFE5A800) : const Color(0xFF6C5CE7),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        isRequestReceived
                                            ? 'Doodle Request Received 💌'
                                            : 'Doodle Request Pending ⏳',
                                        style: GoogleFonts.gaegu(fontSize: 26, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        isRequestReceived
                                            ? 'Accept ${_contact.name}\'s request above to unlock the canvas!'
                                            : 'Waiting for @${_contact.username} to accept your doodle request.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.patrickHand(fontSize: 16, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Empty canvas hint when idle
                          ListenableBuilder(
                            listenable: _doodle,
                            builder: (context, _) {
                              final show = !isMustErase && !isSentWaiting && !isBlocked && _doodle.isEmpty;
                              return IgnorePointer(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 250),
                                  opacity: show ? 0.28 : 0,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.gesture_rounded, size: 60),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Draw your doodle here ✨',
                                          style: GoogleFonts.gaegu(fontSize: 26, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Touch & sketch with finger or write below',
                                          style: GoogleFonts.patrickHand(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),

                  // Floating Toolbar (Colors, Brush size, Eraser, Clear)
                  if (!isSentWaiting && !isMustErase && !isBlocked) _buildDrawingToolbar(isDark),

                  // Bottom Input Bar (write text, mic, send) - From Sketch
                  if (!isSentWaiting && !isMustErase && !isBlocked) _buildBottomInputBar(isDark),
                ],
              ),

              // Confetti Overlay for Erase celebration
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  colors: const [
                    Color(0xFFFFC72C),
                    Color(0xFFFF4081),
                    Color(0xFF00CEC9),
                    Color(0xFF00B894),
                    Color(0xFF6C5CE7),
                  ],
                  numberOfParticles: 30,
                  gravity: 0.3,
                ),
              ),

              // Top-Floating Notification Pill (Dynamic Island style - never covers bottom tools or text)
              Positioned(
                top: 64,
                left: 16,
                right: 16,
                child: Center(
                  child: AnimatedSlide(
                    offset: _topToastVisible ? Offset.zero : const Offset(0, -0.6),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _topToastVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: IgnorePointer(
                        ignoring: !_topToastVisible,
                        child: GestureDetector(
                          onTap: () {
                            if (mounted) setState(() => _topToastVisible = false);
                          },
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 420),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _topToastColor.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: _topToastColor.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_topToastIcon != null) ...[
                                  Icon(_topToastIcon, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    _topToastMessage ?? '',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          DoodleAvatar(
            emoji: _contact.avatarEmoji,
            color: _contact.avatarColor,
            photoBase64: _contact.avatarPhotoBase64,
            isOnline: _contact.isOnline,
            activeStory: _contact.activeStory,
            displayName: _contact.name,
            username: _contact.username,
            radius: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_contact.streakCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7675).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF7675).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 2),
                            Text(
                              '${_contact.streakCount}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
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
                ValueListenableBuilder<bool>(
                  valueListenable: _contact.peerDrawing,
                  builder: (context, drawing, _) {
                    if (drawing) {
                      return Text(
                        '✏️ doodling right now…',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF6B35),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.45, end: 1, duration: 600.ms);
                    }
                    return Text(
                      _contact.isOnline ? 'Online • Ephemeral mode' : _contact.lastActive,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: _contact.isOnline ? const Color(0xFF00B894) : Colors.grey,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Three Dots Menu (From Sketch: Chat theme, Block, Report)
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: _showThreeDotsMenu),
        ],
      ),
    );
  }

  Widget _buildRequestReceivedBanner() {
    return Container(
      key: const ValueKey('request-received'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC72C).withValues(alpha: 0.22),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFFFC72C), width: 1.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.electricPink.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.person_pin_circle_rounded, color: AppTheme.electricPink, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_contact.name} sent a Doodle Request!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Accept to unlock peer-to-peer doodle exchange.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF8A90A6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              _service.respondFriendRequest(_contact.username, false);
              HapticFeedback.lightImpact();
              _toast('Request declined', Colors.grey);
              Navigator.of(context).maybePop();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(60, 34),
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Decline', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade700)),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: () {
              _service.respondFriendRequest(_contact.username, true);
              HapticFeedback.heavyImpact();
              _confetti.play();
              _doodle.locked = false;
              _toast('Request accepted! Canvas unlocked ✨', AppTheme.acidLime);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.electricPink,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(70, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Accept', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSentBanner() {
    return Container(
      key: const ValueKey('request-sent'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7).withValues(alpha: 0.16),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF6C5CE7), width: 1.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.hourglass_top_rounded, color: Color(0xFF6C5CE7), size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doodle Request Sent ⏳',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6C5CE7),
                  ),
                ),
                Text(
                  'Waiting for @${_contact.username} to accept before sending doodles.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF8A90A6)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Pending',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6C5CE7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMustEraseBanner() {
    return Container(
      key: const ValueKey('must-erase'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFF4081).withValues(alpha: 0.18),
      child: Row(
        children: [
          const Icon(Icons.cleaning_services_rounded, color: Color(0xFFFF4081), size: 22)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .rotate(begin: -0.06, end: 0.06, duration: 500.ms),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_contact.name} sent a doodle!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF4081),
                  ),
                ),
                Text(
                  'Erase it completely with your finger to reply ✨',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF8A90A6)),
                ),
                const SizedBox(height: 5),
                ValueListenableBuilder<double>(
                  valueListenable: _doodle.eraseProgress,
                  builder: (context, p, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: p),
                      duration: const Duration(milliseconds: 160),
                      builder: (_, v, child) => LinearProgressIndicator(
                        value: v,
                        backgroundColor: Colors.white38,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4081)),
                        minHeight: 5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _doodle.wipeAll,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFF4081),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Wipe All ✨', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSentWaitingBanner() {
    return Container(
      key: const ValueKey('sent-waiting'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFC72C).withValues(alpha: 0.2),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded, color: Color(0xFFE5A800), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: _contact.peerEraseProgress,
              builder: (context, p, _) {
                final erasing = p > 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      erasing
                          ? '${_contact.name} is erasing… ${(p * 100).round()}%'
                          : 'Doodle Delivered & Locked 🔒',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE5A800),
                      ),
                    ),
                    Text(
                      erasing
                          ? 'Watch it vanish live 👀'
                          : 'Waiting for ${_contact.name} to view & erase before you can send another.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF8A90A6)),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingToolbar(bool isDark) {
    return ListenableBuilder(
      listenable: _doodle,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Brush Modes + Undo / Redo (Thumb Accessible)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildThumbHistoryButton(
                      icon: Icons.undo_rounded,
                      enabled: _doodle.canUndo,
                      tooltip: 'Undo',
                      isDark: isDark,
                      onTap: () {
                        _doodle.undo();
                        HapticFeedback.lightImpact();
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildThumbHistoryButton(
                      icon: Icons.redo_rounded,
                      enabled: _doodle.canRedo,
                      tooltip: 'Redo',
                      isDark: isDark,
                      onTap: () {
                        _doodle.redo();
                        HapticFeedback.lightImpact();
                      },
                    ),

                    Container(
                      width: 1,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),

                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildBrushModePill(
                              label: 'Pen',
                              icon: Icons.edit_rounded,
                              isActive: !_doodle.eraser && _doodle.brushType == DoodleBrushType.pen,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _doodle.setBrushType(DoodleBrushType.pen));
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildBrushModePill(
                              label: 'Marker',
                              icon: Icons.brush_rounded,
                              isActive: !_doodle.eraser && _doodle.brushType == DoodleBrushType.marker,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _doodle.setBrushType(DoodleBrushType.marker));
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildBrushModePill(
                              label: 'Neon',
                              icon: Icons.auto_awesome_rounded,
                              isActive: !_doodle.eraser && _doodle.brushType == DoodleBrushType.neon,
                              isSpecialGlow: true,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _doodle.setBrushType(DoodleBrushType.neon));
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildBrushModePill(
                              label: 'Highlighter',
                              icon: Icons.highlight_rounded,
                              isActive: !_doodle.eraser && _doodle.brushType == DoodleBrushType.highlighter,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _doodle.setBrushType(DoodleBrushType.highlighter));
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildBrushModePill(
                              label: 'Eraser',
                              icon: Icons.cleaning_services_rounded,
                              isActive: _doodle.eraser,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _doodle.setEraser(!_doodle.eraser));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 5),

              // Row 2: Color Palette Strip + Palette Wheel
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _colors.map((c) {
                            final isSelected = _doodle.color == c && !_doodle.eraser;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _doodle.setEraser(false);
                                  _doodle.setColor(c);
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: isSelected ? 28 : 22,
                                height: isSelected ? 28 : 22,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.3),
                                    width: isSelected ? 2.5 : 1.2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: c.withValues(alpha: 0.55),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.palette_rounded, size: 20, color: AppTheme.electricPink),
                      tooltip: 'More colors',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: _showColorPickerModal,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 5),

              // Row 3: Canva Studio Creative Elements (Photo, Text, Shapes, Stickers, Clear)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildBottomActionButton(
                        icon: Icons.add_photo_alternate_rounded,
                        label: 'Photo',
                        color: const Color(0xFFFF7675),
                        onTap: _pickPhoto,
                      ),
                    ),
                    Expanded(
                      child: _buildBottomActionButton(
                        icon: Icons.text_fields_rounded,
                        label: 'Text',
                        color: const Color(0xFF00CEC9),
                        onTap: _showTextStudio,
                      ),
                    ),
                    Expanded(
                      child: _buildBottomActionButton(
                        icon: Icons.interests_rounded,
                        label: 'Shapes',
                        color: const Color(0xFF6C5CE7),
                        onTap: _showShapesSheet,
                      ),
                    ),
                    Expanded(
                      child: _buildBottomActionButton(
                        icon: Icons.emoji_emotions_rounded,
                        label: 'Stickers',
                        color: const Color(0xFFFFC72C),
                        onTap: () => _showEmojiPickerSheet(context),
                      ),
                    ),
                    Expanded(
                      child: _buildBottomActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Clear',
                        color: const Color(0xFF8A90A6),
                        onTap: _showClearConfirm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbHistoryButton({
    required IconData icon,
    required bool enabled,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled
              ? (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: enabled
                ? (isDark ? Colors.white : const Color(0xFF0E1017))
                : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }

  Widget _buildBrushModePill({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    bool isSpecialGlow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? (isSpecialGlow
                  ? const Color(0xFFFF4081)
                  : const Color(0xFFFFC72C))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: (isSpecialGlow ? const Color(0xFFFF4081) : const Color(0xFFFFC72C)).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.black : Colors.grey,
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstagramVerticalBrushSlider(bool isDark) {
    final isEraser = _doodle.eraser;
    final minSize = isEraser ? 12.0 : 2.0;
    final maxSize = isEraser ? 75.0 : 38.0;
    final currentPx = _doodle.activeToolPx;
    final fraction = ((currentPx - minSize) / (maxSize - minSize)).clamp(0.0, 1.0);
    final activeColor = isEraser ? const Color(0xFFFFC72C) : _doodle.color;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = (constraints.maxHeight * 0.55).clamp(120.0, 200.0);

        return Center(
          child: SizedBox(
            width: 70,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                GestureDetector(
                  onVerticalDragStart: (_) => setState(() => _isDraggingBrushSlider = true),
                  onVerticalDragEnd: (_) => setState(() => _isDraggingBrushSlider = false),
                  onVerticalDragCancel: () => setState(() => _isDraggingBrushSlider = false),
                  onVerticalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final local = box.globalToLocal(details.globalPosition);
                    final rawFraction = 1.0 - (local.dy / totalHeight);
                    final clamped = rawFraction.clamp(0.0, 1.0);
                    final newSize = minSize + clamped * (maxSize - minSize);
                    setState(() {
                      _doodle.setBrush(newSize);
                    });
                  },
                  child: Container(
                    width: 26,
                    height: totalHeight,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          width: 5,
                          height: totalHeight * fraction,
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Positioned(
                          bottom: (totalHeight - 22) * fraction,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: activeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isDraggingBrushSlider)
                  Positioned(
                    left: 36,
                    bottom: (totalHeight - 48) * fraction,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(2, 2),
                          ),
                        ],
                        border: Border.all(
                          color: activeColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: (isEraser ? _doodle.eraserScreenRadius * 0.75 : _doodle.brushPx).clamp(4.0, 36.0),
                          height: (isEraser ? _doodle.eraserScreenRadius * 0.75 : _doodle.brushPx).clamp(4.0, 36.0),
                          decoration: BoxDecoration(
                            color: isEraser ? Colors.white.withOpacity(0.6) : _doodle.color,
                            shape: BoxShape.circle,
                            border: isEraser
                                ? Border.all(color: const Color(0xFFFFC72C), width: 1.5)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showColorPickerModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E26) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Color Palette', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ..._colors,
                    const Color(0xFF6C5CE7),
                    const Color(0xFF0984E3),
                    const Color(0xFF00CEC9),
                    const Color(0xFF00B894),
                    const Color(0xFFE17055),
                    const Color(0xFFD63031),
                    const Color(0xFFE84393),
                    const Color(0xFF2D3436),
                    const Color(0xFFFDCB6E),
                    const Color(0xFF55EFC4),
                  ].map((c) {
                    final isSel = _doodle.color == c;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _doodle.setColor(c);
                        });
                        Navigator.pop(ctx);
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? const Color(0xFFFFC72C) : Colors.grey.withValues(alpha: 0.3),
                            width: isSel ? 3.5 : 1,
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showShapesSheet() {
    final shapes = [
      {'id': 'star', 'name': 'Star', 'icon': '⭐'},
      {'id': 'heart', 'name': 'Heart', 'icon': '💖'},
      {'id': 'circle', 'name': 'Circle', 'icon': '⭕'},
      {'id': 'rect', 'name': 'Box', 'icon': '🔲'},
      {'id': 'arrow', 'name': 'Arrow', 'icon': '➔'},
      {'id': 'bubble', 'name': 'Bubble', 'icon': '💬'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🔷', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          'Canva Shapes',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF14141E),
                          ),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap any shape to add directly onto your canvas',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9EA3B5) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: shapes.map((s) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _doodle.addShape(s['id']!);
                        _markDrawing();
                        HapticFeedback.mediumImpact();
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _doodle.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(s['icon']!, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s['name']!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTextStudio() {
    final textCtrl = TextEditingController();
    String selectedFont = 'PatrickHand';
    bool hasBackground = false;
    Color textColor = _doodle.color;

    final fonts = [
      {'id': 'PatrickHand', 'label': 'Doodle'},
      {'id': 'Outfit', 'label': 'Clean Sans'},
      {'id': 'PlusJakartaSans', 'label': 'Bold'},
      {'id': 'Caveat', 'label': 'Script'},
      {'id': 'Gaegu', 'label': 'Playful'},
      {'id': 'Neon', 'label': 'Neon Glow'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🔤', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              'Canva Text Studio',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF14141E),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Toggle text background pill',
                          icon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasBackground ? textColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: textColor, width: 1.5),
                            ),
                            child: Text(
                              'A',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: hasBackground
                                    ? (textColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                                    : textColor,
                              ),
                            ),
                          ),
                          onPressed: () {
                            setDlgState(() => hasBackground = !hasBackground);
                            HapticFeedback.selectionClick();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textCtrl,
                      autofocus: true,
                      onChanged: (val) => setDlgState(() {}),
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white : const Color(0xFF14141E),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: AppTheme.electricPink,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: isDark ? const Color(0xFF9094A6) : const Color(0xFF8A90A6),
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF22222E) : const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: fonts.map((f) {
                          final isSel = selectedFont == f['id'];
                          return GestureDetector(
                            onTap: () {
                              setDlgState(() => selectedFont = f['id']!);
                              HapticFeedback.selectionClick();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? textColor : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                f['label']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isSel
                                      ? (textColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                                      : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: textCtrl.text.trim().isEmpty
                            ? null
                            : () {
                                final txt = textCtrl.text.trim();
                                _doodle.addText(txt, selectedFont, hasBackground);
                                _markDrawing();
                                Navigator.pop(ctx);
                                HapticFeedback.mediumImpact();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.electricPink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Add Text to Canvas ✨',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showClearConfirm() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Clear Canvas?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: const Text('This will erase all strokes, texts, shapes and stickers from this doodle.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _doodle.clear();
                Navigator.pop(ctx);
                HapticFeedback.heavyImpact();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4081),
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Text Input (From Sketch: "write text")
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14141B) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  _Pressable(
                    onTap: () {
                      setState(() {
                        _selectedDoodleFont = _selectedDoodleFont == 'PatrickHand'
                            ? 'Gaegu'
                            : (_selectedDoodleFont == 'Gaegu' ? 'Caveat' : 'PatrickHand');
                      });
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC72C).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedDoodleFont == 'PatrickHand'
                            ? 'Comic'
                            : (_selectedDoodleFont == 'Gaegu' ? 'Chubby' : 'Cursive'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE5A800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      style: GoogleFonts.patrickHand(fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Write text ➔ doodle...',
                        hintStyle: GoogleFonts.patrickHand(fontSize: 16),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _addText,
                    ),
                  ),
                  if (_textCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.check, size: 18, color: Color(0xFF00B894)),
                      onPressed: () => _addText(_textCtrl.text),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Mic Button (From Sketch: "mic" speech-to-doodle)
          _Pressable(
            onTap: _toggleVoice,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isRecordingVoice
                    ? const Color(0xFFFF4081)
                    : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isRecordingVoice ? Icons.mic : Icons.mic_none_rounded,
                color: _isRecordingVoice ? Colors.white : const Color(0xFFFF6B35),
                size: 22,
              ),
            ),
          )
              .animate(target: _isRecordingVoice ? 1 : 0)
              .scaleXY(end: 1.12, duration: 300.ms, curve: Curves.easeOut),

          const SizedBox(width: 8),

          // Send Button (From Sketch: ">" send)
          _Pressable(
            onTap: _sendDoodle,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFC72C), Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0xFFFFC72C), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: const Center(
                child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny press-scale micro-interaction used across the app.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Pressable({required this.child, this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
