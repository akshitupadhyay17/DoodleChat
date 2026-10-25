import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'services/chat_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await ChatService().init();
  // Preload fonts so first paint never janks; never block startup for long.
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.plusJakartaSans(),
      GoogleFonts.outfit(),
      GoogleFonts.caveat(),
    ]).timeout(const Duration(seconds: 3));
  } catch (_) {}
  runApp(const DoodleChatApp());
}

class DoodleChatApp extends StatefulWidget {
  const DoodleChatApp({super.key});

  @override
  State<DoodleChatApp> createState() => _DoodleChatAppState();
}

class _DoodleChatAppState extends State<DoodleChatApp> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  StreamSubscription<ChatEvent>? _events;
  late bool _dark = _chatService.currentUser.isDarkMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatService.addListener(_onServiceUpdate);
    _events = _chatService.events.listen(_onEvent);
    if (_chatService.isLoggedIn) _chatService.connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatService.removeListener(_onServiceUpdate);
    _events?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _chatService.isLoggedIn) {
      _chatService.resume();
    }
  }

  // Only rebuild the whole app when the theme actually flips.
  void _onServiceUpdate() {
    final d = _chatService.currentUser.isDarkMode;
    if (d != _dark && mounted) setState(() => _dark = d);
  }

  void _toast(String text, {Color color = const Color(0xFF1E1E26)}) {
    final m = messengerKey.currentState;
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(text, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 3),
    ));
    HapticFeedback.lightImpact();
  }

  void _onEvent(ChatEvent e) {
    switch (e.type) {
      case ChatEventType.incomingDoodle:
        // Notification removed per user request: latest interacted contact is placed at the top of the chat list
        break;
      case ChatEventType.doodleErased:
        if (e.contact != null && _chatService.activeChat != e.contact!.username) {
          _toast('🧽 @${e.contact!.username} erased your doodle — your turn!',
              color: const Color(0xFF00B894));
        }
        break;
      case ChatEventType.sendRejected:
        _toast(e.message ?? 'Erase the pending doodle first', color: const Color(0xFFFF4081));
        break;
      case ChatEventType.connectionLost:
        _toast('Reconnecting…', color: const Color(0xFF636E72));
        break;
      case ChatEventType.connectionRestored:
        _toast('Back online ✨', color: const Color(0xFF00B894));
        break;
      case ChatEventType.registerError:
        _toast(e.message ?? 'That username is taken — pick another',
            color: const Color(0xFFFF4081));
        break;
      case ChatEventType.incomingFriendRequest:
        _toast('💌 @${e.contact?.username ?? ''} sent you a doodle request!',
            color: const Color(0xFFFFC72C));
        break;
      case ChatEventType.friendRequestAccepted:
        _toast('🎉 @${e.contact?.username ?? ''} accepted your request! Start doodling!',
            color: const Color(0xFF00B894));
        break;
      case ChatEventType.friendRequestDeclined:
        _toast(e.message ?? 'Doodle request was declined',
            color: const Color(0xFF636E72));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const transitions = PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
    });
    return MaterialApp(
      title: 'Doodle',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      theme: AppTheme.lightTheme.copyWith(pageTransitionsTheme: transitions),
      darkTheme: AppTheme.darkTheme.copyWith(pageTransitionsTheme: transitions),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 350),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.stylus},
      ),
      home: const SplashScreen(),
    );
  }
}
