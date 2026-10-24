import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/chat_contact.dart';
import '../services/chat_service.dart';
import '../services/doodle_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/doodle_canvas.dart';
import '../widgets/privacy_watermark.dart';

class ChatScreen extends StatefulWidget {
  final ChatContact contact;

  const ChatScreen({super.key, required this.contact});

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
  String _selectedDoodleFont = 'PatrickHand';

  Timer? _drawingTimer;
  bool _iAmDrawing = false;

  final List<String> _emojiDoodles = [
    '🐥', '🦆', '💖', '🔥', '✨', '⭐', '🥰', '🐾', '🌈', '🎉'
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
  void dispose() {
    _service.activeChat = null;
    _service.removeListener(_syncFromService);
    _eventSub?.cancel();
    _drawingTimer?.cancel();
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

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ───────────────────────── actions ─────────────────────────

  void _onDoodleErasedSuccess() {
    _confetti.play();
    HapticFeedback.heavyImpact();
    _service.markDoodleErased(_contact.id);
    _doodle.setEraser(false);
    _toast('Doodle erased! Canvas unlocked — you can reply 🪄', const Color(0xFF00B894));
  }

  void _sendDoodle() {
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
      '🦆 Duck & Pals': ['🐥', '🦆', '🐤', '🐱', '🐶', '🐰', '🦊', '🐻', '🐼', '🐸', '🦄', '🐾', '🐝', '🐙', '🦋'],
      '✨ Sparks & Magic': ['✨', '⭐', '🌟', '💫', '🔥', '💥', '⚡️', '🌈', '☀️', '🌙', '🪐', '☁️', '❄️', '🌸', '🍀'],
      '💖 Hearts & Moods': ['🥰', '😍', '💖', '❤️', '💕', '💘', '💛', '😎', '🤪', '🥳', '🤩', '🥺', '😂', '🤤', '😇'],
      '🎨 Creative & Fun': ['🎨', '🖌️', '✏️', '🖍️', '💌', '🎈', '🎉', '🪄', '🎯', '🚀', '💎', '🍕', '🍦', '🍩', '☕'],
      '👍 Hands & Vibes': ['✌️', '👍', '👏', '🙌', '🤝', '👋', '🤘', '🤙', '👀', '💯', '💬', '💭', '💡', '🎵', '👑'],
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
                              'Doodle Emoji Stamps',
                              style: GoogleFonts.gaegu(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
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
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                hintText: 'Type or paste ANY emoji here...',
                                hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
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
                                _doodle.setStampEmoji(text);
                                _doodle.addEmoji(text);
                                _markDrawing();
                                HapticFeedback.mediumImpact();
                                Navigator.pop(ctx);
                                _toast('Stamp selected! Tap canvas to stamp more ✨', const Color(0xFFFFC72C));
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
                                    color: Colors.grey,
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
                                      _doodle.setStampEmoji(e);
                                      _doodle.addEmoji(e);
                                      _markDrawing();
                                      HapticFeedback.selectionClick();
                                      Navigator.pop(ctx);
                                      _toast('Stamped "$e"! Tap canvas to stamp more 🎨', const Color(0xFFFFC72C));
                                    },
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(e, style: const TextStyle(fontSize: 22)),
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

                  // Status / Mechanic Banner (animated in/out)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: isMustErase
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

                          // Empty canvas hint when idle
                          ListenableBuilder(
                            listenable: _doodle,
                            builder: (context, _) {
                              final show = !isMustErase && !isSentWaiting && _doodle.isEmpty;
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

                          // Active Stamp Mode floating indicator
                          ListenableBuilder(
                            listenable: _doodle,
                            builder: (context, _) {
                              final stamp = _doodle.stampEmoji;
                              if (stamp == null || isSentWaiting || isMustErase) {
                                return const SizedBox.shrink();
                              }
                              return Positioned(
                                top: 12,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E26).withValues(alpha: 0.88),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFFFC72C), width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(stamp, style: const TextStyle(fontSize: 18)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Stamp mode: tap canvas to place',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: () {
                                            _doodle.setStampEmoji(null);
                                            HapticFeedback.selectionClick();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.white24,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Floating Toolbar (Colors, Brush size, Eraser, Clear)
                  if (!isSentWaiting && !isMustErase) _buildDrawingToolbar(isDark),

                  // Bottom Input Bar (write text, mic, send) - From Sketch
                  if (!isSentWaiting && !isMustErase) _buildBottomInputBar(isDark),
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
          // Profile Avatar with Status
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _contact.avatarColor.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: _contact.avatarColor, width: 2),
                ),
                child: Center(child: Text(_contact.avatarEmoji, style: const TextStyle(fontSize: 22))),
              ),
              if (_contact.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B894),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
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
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF4081),
                  ),
                ),
                Text(
                  'Erase it completely with your finger to reply 🪄',
                  style: GoogleFonts.patrickHand(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 5),
                ValueListenableBuilder<double>(
                  valueListenable: _doodle.eraseProgress,
                  builder: (context, p, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: p),
                      duration: const Duration(milliseconds: 160),
                      builder: (_, v, __) => LinearProgressIndicator(
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
                      style: GoogleFonts.patrickHand(fontSize: 14),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E26) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji Doodles Quick Stamp Row (From Sketch: "emoji doodle")
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Draw / Pen mode button
                    _Pressable(
                      onTap: () {
                        _doodle.setStampEmoji(null);
                        _doodle.setEraser(false);
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (!_doodle.eraser && _doodle.stampEmoji == null)
                              ? const Color(0xFFFFC72C)
                              : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: (!_doodle.eraser && _doodle.stampEmoji == null)
                                  ? const Color(0xFF1E1E26)
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Draw',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (!_doodle.eraser && _doodle.stampEmoji == null)
                                    ? const Color(0xFF1E1E26)
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // More Emojis Picker Button
                    _Pressable(
                      onTap: () => _showEmojiPickerSheet(context),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC72C).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFFC72C).withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_rounded, size: 14, color: Color(0xFFE5A800)),
                            SizedBox(width: 2),
                            Text(
                              'More 😊',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE5A800)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),

                    // Quick Stamps list
                    ..._emojiDoodles.map(
                      (emoji) {
                        final isStampActive = _doodle.stampEmoji == emoji;
                        return _Pressable(
                          onTap: () {
                            if (isStampActive) {
                              _doodle.setStampEmoji(null);
                            } else {
                              _doodle.setStampEmoji(emoji);
                              _doodle.addEmoji(emoji);
                              _markDrawing();
                            }
                            HapticFeedback.selectionClick();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isStampActive
                                  ? const Color(0xFFFFC72C).withValues(alpha: 0.3)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isStampActive ? const Color(0xFFFFC72C) : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 18)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // Eraser Toggle Button
                  _Pressable(
                    onTap: () {
                      _doodle.setEraser(!_doodle.eraser);
                      HapticFeedback.selectionClick();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _doodle.eraser
                            ? const Color(0xFFFF4081)
                            : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cleaning_services_rounded,
                            size: 18,
                            color: _doodle.eraser ? Colors.white : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Eraser',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _doodle.eraser ? Colors.white : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Stroke Width Button
                  _Pressable(
                    onTap: () {
                      final b = _doodle.brushPx;
                      _doodle.setBrush(b == 2.5 ? 5.0 : (b == 5.0 ? 9.0 : 2.5));
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: _doodle.brushPx + 4,
                            height: _doodle.brushPx + 4,
                            decoration: BoxDecoration(color: _doodle.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _doodle.brushPx <= 3.0 ? 'Fine' : (_doodle.brushPx <= 6.0 ? 'Med' : 'Bold'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Color Palette
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: AppTheme.doodleColors.map((color) {
                          final isSelected = !_doodle.eraser && _doodle.color == color;
                          return _Pressable(
                            onTap: () {
                              _doodle.setColor(color);
                              HapticFeedback.selectionClick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isSelected ? 32 : 28,
                              height: isSelected ? 32 : 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF1E1E26) : Colors.white,
                                  width: isSelected ? 3 : 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)]
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Undo
                  IconButton(
                    icon: const Icon(Icons.undo_rounded, size: 20),
                    tooltip: 'Undo',
                    onPressed: _doodle.canUndo
                        ? () {
                            _doodle.undo();
                            HapticFeedback.lightImpact();
                          }
                        : null,
                  ),

                  // Clear All
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, size: 22, color: Colors.redAccent),
                    tooltip: 'Clear Canvas',
                    onPressed: () {
                      _doodle.clear();
                      HapticFeedback.mediumImpact();
                    },
                  ),
                ],
              ),
            ],
          ),
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
