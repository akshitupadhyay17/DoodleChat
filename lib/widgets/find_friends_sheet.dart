import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/chat_contact.dart';
import '../screens/chat_screen.dart';
import '../services/chat_service.dart';

/// "Find & connect friends": live online list, @handle / link entry and a real QR scanner.
Future<void> showFindFriendsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _FindFriendsSheet(),
  );
}

String parseHandle(String raw) {
  var h = raw.trim();
  if (h.contains('doodlechat://user/')) {
    h = h.split('doodlechat://user/').last;
  } else if (h.contains('/u/')) {
    h = h.split('/u/').last;
  }
  return h.replaceAll('@', '').split(RegExp(r'[/?#\s]')).first.toLowerCase();
}

class _FindFriendsSheet extends StatefulWidget {
  const _FindFriendsSheet();

  @override
  State<_FindFriendsSheet> createState() => _FindFriendsSheetState();
}

class _FindFriendsSheetState extends State<_FindFriendsSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _connectHandle(String raw) async {
    final handle = parseHandle(raw);
    if (handle.isEmpty) return;
    final service = ChatService();
    if (handle == service.currentUser.username.toLowerCase()) {
      setState(() => _error = "That's you! 🦆 Share your QR with a friend instead.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    if (!service.isConnected) {
      service.resume();
      await Future.delayed(const Duration(milliseconds: 900));
    }
    final profile = await service.lookupUser(handle);
    if (!mounted) return;
    if (profile == null) {
      setState(() {
        _busy = false;
        _error = service.isConnected
            ? "Couldn't find @$handle. Ask them to open DoodleChat and sign up first."
            : 'Still connecting to the server… try again in a moment.';
      });
      return;
    }

    final existing = service.contacts.cast<ChatContact?>().firstWhere(
          (c) => c?.username == handle,
          orElse: () => null,
        );

    final nav = Navigator.of(context);
    if (existing != null && existing.friendshipStatus == FriendshipStatus.accepted) {
      nav.pop();
      nav.push(MaterialPageRoute(builder: (_) => ChatScreen(contact: existing)));
      return;
    }

    // Send doodle request
    await service.sendFriendRequest(handle, profile: profile);
    final contact = await service.ensureContact(handle, profile: profile, initialStatus: FriendshipStatus.requestSent);
    if (!mounted) return;
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => ChatScreen(contact: contact)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Doodle request sent to @$handle! ⏳'),
        backgroundColor: const Color(0xFFFFC72C),
      ),
    );
  }

  Future<void> _scan() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _QrScanPage()),
    );
    if (result != null && mounted) {
      _ctrl.text = parseHandle(result);
      _connectHandle(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final service = ChatService();

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final peers = service.onlinePeers;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Find & Connect Friends 🦆',
                      style: GoogleFonts.gaegu(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 8),

                // QR scanner
                InkWell(
                  onTap: _scan,
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFFC72C), Color(0xFFFF9F1C)]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF1E1E26)),
                        const SizedBox(width: 10),
                        Text(
                          'Scan a friend\'s QR code',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: const Color(0xFF1E1E26),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                Text(
                  'OR ENTER @USERNAME / LINK',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autocorrect: false,
                        textInputAction: TextInputAction.go,
                        onSubmitted: _connectHandle,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFFFFC72C)),
                          hintText: 'friend_handle',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1A1A22) : Colors.black.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _busy ? null : () => _connectHandle(_ctrl.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC72C),
                          foregroundColor: const Color(0xFF1E1E26),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF1E1E26)),
                              )
                            : const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: GoogleFonts.outfit(color: const Color(0xFFFF4081), fontWeight: FontWeight.w600),
                    ).animate().fadeIn().shakeX(hz: 4, amount: 4),
                  ),

                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: service.isConnected ? const Color(0xFF00B894) : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 0.7, end: 1.2, duration: 900.ms),
                    const SizedBox(width: 8),
                    Text(
                      service.isConnected
                          ? 'LIVE ONLINE NOW (${peers.length})'
                          : 'CONNECTING TO SERVER…',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (peers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Text('📱', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Nobody else is online yet. Ask your friend to open the link and pick a username — they\'ll pop up here instantly.',
                            style: GoogleFonts.patrickHand(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (int i = 0; i < peers.length; i++)
                    _PeerTile(peer: peers[i])
                        .animate()
                        .fadeIn(delay: (60 * i).ms, duration: 300.ms)
                        .slideX(begin: 0.1, curve: Curves.easeOutCubic),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  final Map<String, dynamic> peer;

  const _PeerTile({required this.peer});

  @override
  Widget build(BuildContext context) {
    final user = peer['username'].toString();
    final emoji = peer['avatarEmoji']?.toString() ?? '🎨';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC72C).withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        ),
        title: Text('@$user', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        subtitle: Text(
          peer['bio']?.toString() ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.patrickHand(fontSize: 15),
        ),
        trailing: Builder(
          builder: (context) {
            final service = ChatService();
            final existing = service.contacts.cast<ChatContact?>().firstWhere(
                  (c) => c?.username == user,
                  orElse: () => null,
                );
            final isAccepted = existing != null && existing.friendshipStatus == FriendshipStatus.accepted;
            final isPending = existing != null && existing.friendshipStatus == FriendshipStatus.requestSent;
            final isReceived = existing != null && existing.friendshipStatus == FriendshipStatus.requestReceived;

            String label = 'Request 🦆';
            Color bg = const Color(0xFFFFC72C);
            if (isAccepted) {
              label = 'Chat ➔';
            } else if (isReceived) {
              label = 'Accept 🦆';
              bg = const Color(0xFF00B894);
            } else if (isPending) {
              label = 'Pending ⏳';
              bg = const Color(0xFF6C5CE7);
            }

            return ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                if (isAccepted) {
                  nav.pop();
                  nav.push(MaterialPageRoute(builder: (_) => ChatScreen(contact: existing)));
                } else if (isReceived) {
                  service.respondFriendRequest(user, true);
                  nav.pop();
                  nav.push(MaterialPageRoute(builder: (_) => ChatScreen(contact: existing)));
                } else if (isPending) {
                  nav.pop();
                  nav.push(MaterialPageRoute(builder: (_) => ChatScreen(contact: existing)));
                } else {
                  await service.sendFriendRequest(user, profile: peer);
                  final contact = await service.ensureContact(
                    user,
                    profile: peer,
                    initialStatus: FriendshipStatus.requestSent,
                  );
                  nav.pop();
                  nav.push(MaterialPageRoute(builder: (_) => ChatScreen(contact: contact)));
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Doodle request sent to @$user! ⏳'),
                      backgroundColor: const Color(0xFFFFC72C),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: (isReceived || isPending) ? Colors.white : const Color(0xFF1E1E26),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          },
        ),
      ),
    );
  }
}

class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scan QR', style: GoogleFonts.gaegu(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final v = b.rawValue;
                if (v != null && v.contains('doodlechat://user/')) {
                  _done = true;
                  Navigator.of(context).pop(v);
                  return;
                }
              }
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Camera unavailable.\nAllow camera access (needs https), or type your friend\'s @username instead.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFFC72C), width: 4),
                borderRadius: BorderRadius.circular(28),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.96, end: 1.03, duration: 1100.ms, curve: Curves.easeInOut),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Text(
              'Point at your friend\'s DoodleChat QR 🦆',
              textAlign: TextAlign.center,
              style: GoogleFonts.patrickHand(color: Colors.white, fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }
}
