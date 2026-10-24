import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/chat_contact.dart';
import '../models/doodle_group.dart';
import '../models/doodle_stroke.dart';
import '../models/user_profile.dart';

enum ChatEventType {
  incomingDoodle,
  doodleErased,
  sendRejected,
  connectionLost,
  connectionRestored,
  registerError,
  incomingFriendRequest,
  friendRequestAccepted,
  friendRequestDeclined,
}

class ChatEvent {
  final ChatEventType type;
  final ChatContact? contact;
  final String? message;
  ChatEvent(this.type, {this.contact, this.message});
}

class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  ChatService._internal();

  final UserProfile currentUser = UserProfile();
  bool isOnboarded = false;
  bool isLoggedIn = false;

  final List<ChatContact> contacts = [];
  final List<DoodleGroup> groups = [];
  final List<Map<String, dynamic>> onlinePeers = [];

  /// Username of the chat screen currently open (null on Home etc.).
  String? activeChat;

  final StreamController<ChatEvent> _events = StreamController<ChatEvent>.broadcast();

  /// One-shot app events (incoming doodle, friend erased, connection changes…).
  Stream<ChatEvent> get events => _events.stream;

  SharedPreferences? _prefs;

  // ───────────────────────── persistence ─────────────────────────

  Future<void> init() async {
    final p = _prefs = await SharedPreferences.getInstance();
    currentUser.clientId = p.getString('clientId') ?? currentUser.clientId;
    await p.setString('clientId', currentUser.clientId);
    currentUser.username = p.getString('username') ?? '';
    currentUser.phoneOrEmail = p.getString('contact') ?? '';
    currentUser.bio = p.getString('bio') ?? currentUser.bio;
    currentUser.avatarEmoji = p.getString('emoji') ?? currentUser.avatarEmoji;
    currentUser.avatarColor = Color(p.getInt('color') ?? currentUser.avatarColor.toARGB32());
    currentUser.isDarkMode = p.getBool('dark') ?? false;
    currentUser.profilePicBase64 = p.getString('profilePic');
    if (currentUser.profilePicBase64 != null && currentUser.profilePicBase64!.isEmpty) {
      currentUser.profilePicBase64 = null;
    }
    isOnboarded = p.getBool('onboarded') ?? false;
    isLoggedIn = (p.getBool('loggedIn') ?? false) && currentUser.username.isNotEmpty;

    final raw = p.getString('contacts');
    if (raw != null) {
      try {
        for (final j in (jsonDecode(raw) as List<dynamic>)) {
          contacts.add(ChatContact.fromJson(Map<String, dynamic>.from(j as Map)));
        }
      } catch (_) {}
    }
    contacts.add(_buildDemoContact());

    final rawGroups = p.getString('groups');
    if (rawGroups != null) {
      try {
        for (final j in (jsonDecode(rawGroups) as List<dynamic>)) {
          groups.add(DoodleGroup.fromJson(Map<String, dynamic>.from(j as Map)));
        }
      } catch (_) {}
    }
    if (groups.isEmpty) {
      groups.add(_buildDemoGroup());
    }
  }

  Future<void> saveProfile() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString('username', currentUser.username);
    await p.setString('contact', currentUser.phoneOrEmail);
    await p.setString('bio', currentUser.bio);
    await p.setString('emoji', currentUser.avatarEmoji);
    await p.setInt('color', currentUser.avatarColor.toARGB32());
    await p.setBool('dark', currentUser.isDarkMode);
    if (currentUser.profilePicBase64 != null) {
      await p.setString('profilePic', currentUser.profilePicBase64!);
    } else {
      await p.remove('profilePic');
    }
    await p.setBool('onboarded', isOnboarded);
    await p.setBool('loggedIn', isLoggedIn);
  }

  Future<void> signOut() async {
    isLoggedIn = false;
    isOnboarded = false;
    currentUser.username = '';
    currentUser.phoneOrEmail = '';
    final p = _prefs;
    if (p != null) {
      await p.setBool('loggedIn', false);
      await p.setBool('onboarded', false);
      await p.remove('username');
      await p.remove('contact');
    }
    disconnect();
    notifyListeners();
  }

  void _saveContacts() {
    final p = _prefs;
    if (p == null) return;
    final list = contacts.where((c) => !c.isDemo).map((c) => c.toJson()).toList();
    p.setString('contacts', jsonEncode(list));
  }

  void _saveGroups() {
    final p = _prefs;
    if (p == null) return;
    p.setString('groups', jsonEncode(groups.map((g) => g.toJson()).toList()));
  }

  // ───────────────────────── connection ─────────────────────────

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  bool isConnected = false;
  bool _connecting = false;
  bool _gaveUp = false;
  bool _everConnected = false;
  int _retry = 0;
  DateTime _lastRx = DateTime.now();
  String? registerError;
  final Set<String> _queuedErases = {};

  String _wsUrl() {
    if (kIsWeb) {
      final uri = Uri.base;
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final host = uri.host.isNotEmpty ? uri.host : 'localhost';
      final port = (uri.hasPort && uri.port != 0) ? ':${uri.port}' : '';
      return '$scheme://$host$port';
    }
    return const String.fromEnvironment('DOODLE_SERVER', defaultValue: 'ws://192.168.1.26:8080');
  }

  /// Safe to call as often as you like.
  void connect() {
    if (!isLoggedIn || _channel != null || _connecting || _gaveUp) return;
    _connecting = true;
    _reconnectTimer?.cancel();
    try {
      final ch = WebSocketChannel.connect(Uri.parse(_wsUrl()));
      _channel = ch;
      ch.ready.then((_) {
        _connecting = false;
        _lastRx = DateTime.now();
        _register();
        _startHeartbeat();
      }).catchError((_) {
        _onClosed();
      });
      _sub = ch.stream.listen(_onMessage, onError: (_) => _onClosed(), onDone: _onClosed);
    } catch (e) {
      _connecting = false;
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _register() {
    _send({
      'type': 'register',
      'username': currentUser.username,
      'clientId': currentUser.clientId,
      'name': currentUser.username,
      'avatarEmoji': currentUser.avatarEmoji,
      'avatarColor': '#${currentUser.avatarColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'bio': currentUser.bio,
    });
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      if (DateTime.now().difference(_lastRx) > const Duration(seconds: 45)) {
        _forceReconnect();
      } else {
        _send({'type': 'ping'});
      }
    });
  }

  /// Call when the app returns to the foreground (iOS Safari silently kills sockets).
  void resume() {
    if (!isLoggedIn) return;
    if (_channel == null) {
      _gaveUp = false;
      connect();
    } else if (DateTime.now().difference(_lastRx) > const Duration(seconds: 20)) {
      _forceReconnect();
    } else {
      _send({'type': 'ping'});
    }
  }

  void disconnect() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _onClosed();
  }

  void _forceReconnect() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _onClosed();
  }

  void _onClosed() {
    _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _channel = null;
    _connecting = false;
    final was = isConnected;
    isConnected = false;
    for (final c in contacts) {
      if (!c.isDemo) c.isOnline = false;
      c.peerDrawing.value = false;
    }
    onlinePeers.clear();
    if (was) _events.add(ChatEvent(ChatEventType.connectionLost));
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!isLoggedIn || _gaveUp) return;
    _reconnectTimer?.cancel();
    final secs = (1 << _retry.clamp(0, 3)); // 1,2,4,8
    _retry++;
    _reconnectTimer = Timer(Duration(seconds: secs), connect);
  }

  void _send(Map<String, dynamic> msg) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  // ───────────────────────── incoming ─────────────────────────

  final Map<String, Completer<Map<String, dynamic>?>> _lookups = {};

  Future<void> _onMessage(dynamic raw) async {
    _lastRx = DateTime.now();
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(raw.toString()) as Map);
    } catch (_) {
      return;
    }

    switch (data['type']) {
      case 'registered_success':
        _retry = 0;
        final restored = _everConnected && !isConnected;
        isConnected = true;
        _everConnected = true;
        _updatePeers(data['users']);
        // Flush erases that happened while we were offline.
        for (final u in _queuedErases) {
          _send({'type': 'doodle_erased', 'to': u});
        }
        _queuedErases.clear();
        if (restored) _events.add(ChatEvent(ChatEventType.connectionRestored));
        notifyListeners();
        break;

      case 'register_error':
        _gaveUp = true;
        registerError = data['reason']?.toString();
        _events.add(ChatEvent(ChatEventType.registerError, message: registerError));
        break;

      case 'online_users':
        _updatePeers(data['users']);
        notifyListeners();
        break;

      case 'sync':
        _handleSync(data);
        break;

      case 'incoming_doodle':
        _handleIncoming(
          (data['from'] ?? '').toString(),
          Map<String, dynamic>.from(data['doodle'] as Map),
          announce: true,
        );
        break;

      case 'doodle_erased_ack':
        final c = _find((data['from'] ?? '').toString());
        if (c != null) {
          c.pendingDoodle = null;
          c.doodleStatus = DoodleChatStatus.idle;
          c.peerEraseProgress.value = 0;
          c.lastActive = 'Just now';
          _events.add(ChatEvent(ChatEventType.doodleErased, contact: c));
          notifyListeners();
        }
        break;

      case 'peer_erase_progress':
        final c = _find((data['from'] ?? '').toString());
        if (c != null) c.peerEraseProgress.value = (data['progress'] as num? ?? 0).toDouble();
        break;

      case 'peer_drawing':
        final c = _find((data['from'] ?? '').toString());
        if (c != null) c.peerDrawing.value = data['active'] == true;
        break;

      case 'incoming_friend_request': {
        final from = (data['from'] ?? '').toString();
        final prof = data['profile'] != null ? Map<String, dynamic>.from(data['profile'] as Map) : null;
        final c = await ensureContact(from, profile: prof, initialStatus: FriendshipStatus.requestReceived);
        c.friendshipStatus = FriendshipStatus.requestReceived;
        _saveContacts();
        _events.add(ChatEvent(ChatEventType.incomingFriendRequest, contact: c));
        notifyListeners();
        break;
      }

      case 'friend_request_accepted': {
        final from = (data['from'] ?? '').toString();
        final prof = data['profile'] != null ? Map<String, dynamic>.from(data['profile'] as Map) : null;
        final c = await ensureContact(from, profile: prof, initialStatus: FriendshipStatus.accepted);
        c.friendshipStatus = FriendshipStatus.accepted;
        _saveContacts();
        _events.add(ChatEvent(ChatEventType.friendRequestAccepted, contact: c));
        notifyListeners();
        break;
      }

      case 'friend_request_declined': {
        final from = (data['from'] ?? '').toString();
        final c = _find(from);
        if (c != null && c.friendshipStatus == FriendshipStatus.requestSent) {
          contacts.remove(c);
          _saveContacts();
          _events.add(ChatEvent(
            ChatEventType.friendRequestDeclined,
            contact: c,
            message: '@$from declined your doodle request.',
          ));
          notifyListeners();
        }
        break;
      }

      case 'send_rejected':
        final c = _find((data['to'] ?? '').toString());
        if (c != null && c.doodleStatus == DoodleChatStatus.sentWaitingForErase) {
          c.doodleStatus = DoodleChatStatus.idle;
          c.pendingDoodle = null;
        }
        final reason = data['reason']?.toString();
        String msg = 'Could not deliver that doodle.';
        if (reason == 'pending_doodle') {
          msg = 'A doodle is still waiting to be erased in this chat.';
        } else if (reason == 'not_friends') {
          msg = data['message']?.toString() ?? 'You must send a doodle request first!';
          if (c != null && c.friendshipStatus == FriendshipStatus.accepted) {
            c.friendshipStatus = FriendshipStatus.requestSent;
          }
        }
        _events.add(ChatEvent(
          ChatEventType.sendRejected,
          contact: c,
          message: msg,
        ));
        notifyListeners();
        break;

      case 'lookup_result':
        final comp = _lookups.remove(data['reqId']);
        comp?.complete(data['profile'] == null ? null : Map<String, dynamic>.from(data['profile'] as Map));
        break;

      case 'doodleup_story': {
        final from = (data['from'] ?? '').toString();
        final c = _find(from);
        if (c != null && data['doodle'] != null) {
          c.activeStory = DoodleData.fromJson(Map<String, dynamic>.from(data['doodle'] as Map), from);
          c.storyTimestamp = DateTime.now();
          notifyListeners();
        }
        break;
      }

      case 'group_doodle': {
        final gid = data['groupId']?.toString();
        final from = (data['from'] ?? '').toString();
        DoodleGroup? g;
        for (final grp in groups) {
          if (grp.id == gid) {
            g = grp;
            break;
          }
        }
        if (g == null && gid != null) {
          g = DoodleGroup(
            id: gid,
            name: data['groupName']?.toString() ?? 'Doodle Squad',
            memberUsernames: [from, currentUser.username],
          );
          groups.insert(0, g);
        }
        if (g != null && data['doodle'] != null) {
          g.latestDoodle = DoodleData.fromJson(Map<String, dynamic>.from(data['doodle'] as Map), from);
          g.lastActive = DateTime.now();
          g.streakCount++;
          _saveGroups();
          notifyListeners();
        }
        break;
      }
    }
  }

  void _updatePeers(dynamic users) {
    onlinePeers.clear();
    final me = currentUser.username.toLowerCase();
    final onlineNames = <String>{};
    for (final u in (users as List<dynamic>? ?? const [])) {
      final m = Map<String, dynamic>.from(u as Map);
      final name = (m['username'] ?? '').toString();
      onlineNames.add(name);
      if (name != me) onlinePeers.add(m);
    }
    for (final c in contacts) {
      if (!c.isDemo) {
        c.isOnline = onlineNames.contains(c.username);
        if (!c.isOnline) c.peerDrawing.value = false;
      }
    }
  }

  Future<void> _handleSync(Map<String, dynamic> data) async {
    final incoming = (data['incoming'] as List<dynamic>? ?? const []);
    final outgoing = ((data['outgoing'] as List<dynamic>? ?? const [])).map((e) => e.toString()).toSet();
    final incomingFrom = <String>{};

    for (final item in incoming) {
      final m = Map<String, dynamic>.from(item as Map);
      final from = m['from'].toString();
      incomingFrom.add(from);
      await _handleIncoming(from, Map<String, dynamic>.from(m['doodle'] as Map), announce: false);
    }

    final incReqs = (data['incomingRequests'] as List<dynamic>? ?? const []);
    for (final r in incReqs) {
      final rm = Map<String, dynamic>.from(r as Map);
      final from = rm['from'].toString();
      final prof = rm['profile'] != null ? Map<String, dynamic>.from(rm['profile'] as Map) : null;
      final c = await ensureContact(from, profile: prof, initialStatus: FriendshipStatus.requestReceived);
      c.friendshipStatus = FriendshipStatus.requestReceived;
    }

    final outReqs = ((data['outgoingRequests'] as List<dynamic>? ?? const [])).map((e) => e.toString()).toSet();
    for (final to in outReqs) {
      final c = await ensureContact(to, initialStatus: FriendshipStatus.requestSent);
      if (c.friendshipStatus != FriendshipStatus.accepted) {
        c.friendshipStatus = FriendshipStatus.requestSent;
      }
    }

    final mutualFriends = ((data['friends'] as List<dynamic>? ?? const [])).map((e) => e.toString()).toSet();
    for (final f in mutualFriends) {
      final c = _find(f);
      if (c != null) {
        c.friendshipStatus = FriendshipStatus.accepted;
      }
    }

    for (final c in contacts) {
      if (c.isDemo) continue;
      if (outgoing.contains(c.username)) {
        if (c.doodleStatus != DoodleChatStatus.sentWaitingForErase) {
          c.doodleStatus = DoodleChatStatus.sentWaitingForErase;
        }
      } else if (!incomingFrom.contains(c.username)) {
        // Server says nothing is pending with this friend.
        c.doodleStatus = DoodleChatStatus.idle;
        c.pendingDoodle = null;
      }
    }
    notifyListeners();
  }

  Future<void> _handleIncoming(String from, Map<String, dynamic> json, {required bool announce}) async {
    final c = await ensureContact(from);
    final doodle = DoodleData.fromJson(json, c.username);
    if (c.doodleStatus == DoodleChatStatus.receivedMustErase && c.pendingDoodle?.id == doodle.id) {
      return; // already have it (sync after reconnect)
    }
    c.pendingDoodle = doodle;
    c.doodleStatus = DoodleChatStatus.receivedMustErase;
    c.activeStory = doodle;
    c.storyTimestamp = DateTime.now();
    c.lastActive = 'Just now';
    c.peerDrawing.value = false;
    // Move the live conversation to the top.
    contacts.remove(c);
    contacts.insert(0, c);
    if (announce) {
      HapticFeedback.mediumImpact();
      _events.add(ChatEvent(ChatEventType.incomingDoodle, contact: c));
    }
    notifyListeners();
  }

  // ───────────────────────── contacts ─────────────────────────

  ChatContact? _find(String username) {
    final u = username.toLowerCase();
    for (final c in contacts) {
      if (c.username.toLowerCase() == u) return c;
    }
    return null;
  }

  Color _parseColor(dynamic v) {
    try {
      var s = v.toString().replaceAll('#', '');
      if (s.length == 6) s = 'ff$s';
      return Color(int.parse(s, radix: 16));
    } catch (_) {
      return const Color(0xFFFFC72C);
    }
  }

  /// Looks the user up on the server (null = not found / not connected).
  Future<Map<String, dynamic>?> lookupUser(String username) {
    final u = username.toLowerCase().replaceAll('@', '').trim();
    if (_channel == null || !isConnected) return Future.value(null);
    final reqId = '${DateTime.now().microsecondsSinceEpoch}';
    final comp = Completer<Map<String, dynamic>?>();
    _lookups[reqId] = comp;
    _send({'type': 'lookup', 'username': u, 'reqId': reqId});
    return comp.future.timeout(const Duration(seconds: 5), onTimeout: () {
      _lookups.remove(reqId);
      return null;
    });
  }

  /// Returns the existing contact or creates one from the server profile.
  Future<ChatContact> ensureContact(
    String username, {
    Map<String, dynamic>? profile,
    FriendshipStatus initialStatus = FriendshipStatus.accepted,
  }) async {
    final existing = _find(username);
    if (existing != null) return existing;

    final lower = username.toLowerCase().replaceAll('@', '').trim();
    Map<String, dynamic>? peer = profile;
    peer ??= onlinePeers.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p!['username'] == lower,
          orElse: () => null,
        );
    peer ??= await lookupUser(lower);

    // Another call may have created it while we awaited.
    final again = _find(lower);
    if (again != null) return again;

    final c = ChatContact(
      id: lower,
      name: peer?['name']?.toString() ?? lower,
      username: lower,
      avatarEmoji: peer?['avatarEmoji']?.toString() ?? '🎨',
      avatarColor: _parseColor(peer?['avatarColor']),
      statusBio: peer?['bio']?.toString() ?? 'Doodle buddy',
      isOnline: peer?['online'] == true,
      friendshipStatus: initialStatus,
      lastActive: 'Just now',
    );
    final demoIndex = contacts.indexWhere((x) => x.isDemo);
    contacts.insert(demoIndex == -1 ? contacts.length : 0, c);
    _saveContacts();
    notifyListeners();
    return c;
  }

  Future<void> sendFriendRequest(String username, {Map<String, dynamic>? profile}) async {
    final c = await ensureContact(username, profile: profile, initialStatus: FriendshipStatus.requestSent);
    c.friendshipStatus = FriendshipStatus.requestSent;
    _saveContacts();
    _send({'type': 'send_friend_request', 'to': c.username});
    notifyListeners();
  }

  void respondFriendRequest(String username, bool accept) {
    final c = _find(username);
    if (c != null) {
      if (accept) {
        c.friendshipStatus = FriendshipStatus.accepted;
      } else {
        contacts.remove(c);
      }
      _saveContacts();
    }
    _send({'type': 'respond_friend_request', 'to': username, 'accept': accept});
    notifyListeners();
  }

  // ───────────────────────── sending / erasing ─────────────────────────

  /// Returns false if it could not be sent (offline).
  bool sendDoodle(String contactId, DoodleData doodle) {
    final c = _find(contactId);
    if (c == null) return false;

    if (c.friendshipStatus != FriendshipStatus.accepted && !c.isDemo) {
      _events.add(ChatEvent(
        ChatEventType.sendRejected,
        contact: c,
        message: 'Waiting for @${c.username} to accept your doodle request first ⏳',
      ));
      return false;
    }

    if (c.isDemo) {
      c.pendingDoodle = doodle;
      c.doodleStatus = DoodleChatStatus.sentWaitingForErase;
      notifyListeners();
      _simulateDemoReply(c);
      return true;
    }
    if (!isConnected) return false;

    c.pendingDoodle = doodle;
    c.doodleStatus = DoodleChatStatus.sentWaitingForErase;
    c.streakCount++;
    c.lastActive = 'Just now';
    currentUser.activeStory = doodle;
    currentUser.storyTimestamp = DateTime.now();
    contacts.remove(c);
    contacts.insert(0, c);
    _saveContacts();
    _send({'type': 'send_doodle', 'to': c.username, 'doodle': doodle.toJson()});
    notifyListeners();
    return true;
  }

  void markDoodleErased(String contactId) {
    final c = _find(contactId);
    if (c == null) return;
    c.pendingDoodle = null;
    c.doodleStatus = DoodleChatStatus.idle;
    c.lastActive = 'Just now';
    if (!c.isDemo) {
      if (isConnected) {
        _send({'type': 'doodle_erased', 'to': c.username});
      } else {
        _queuedErases.add(c.username);
      }
    }
    notifyListeners();
  }

  void sendDrawingState(ChatContact c, bool active) {
    if (c.isDemo || !isConnected) return;
    _send({'type': 'drawing', 'to': c.username, 'active': active});
  }

  DateTime _lastProgressSent = DateTime.fromMillisecondsSinceEpoch(0);
  void sendEraseProgress(ChatContact c, double progress) {
    if (c.isDemo || !isConnected) return;
    final now = DateTime.now();
    if (progress < 1 && now.difference(_lastProgressSent) < const Duration(milliseconds: 120)) return;
    _lastProgressSent = now;
    _send({'type': 'erase_progress', 'to': c.username, 'progress': double.parse(progress.toStringAsFixed(3))});
  }

  void updateChatTheme(String contactId, String theme) {
    final c = _find(contactId);
    if (c != null) {
      c.chatTheme = theme;
      _saveContacts();
      notifyListeners();
    }
  }

  void toggleTheme() {
    currentUser.isDarkMode = !currentUser.isDarkMode;
    saveProfile();
    notifyListeners();
  }

  // ───────────────────────── offline demo friend ─────────────────────────

  List<Offset> _pts(List<List<double>> xy) => [for (final p in xy) Offset(p[0] * 2.5, p[1] * 2.5)];

  ChatContact _buildDemoContact() {
    final doodle = DoodleData(
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      senderId: 'mayadoodles',
      strokes: [
        // A cute heart outline
        DoodleStroke(
          points: _pts([
            [160, 220], [130, 180], [110, 150], [120, 120], [150, 110], [180, 130],
            [200, 160], [220, 130], [250, 110], [280, 120], [290, 150], [270, 180],
            [240, 220], [200, 260], [160, 220],
          ]),
          color: const Color(0xFFFF4081),
          size: 14,
        ),
        // Smile curve below
        DoodleStroke(
          points: _pts([[150, 310], [175, 335], [200, 340], [225, 335], [250, 310]]),
          color: const Color(0xFFFFC72C),
          size: 12,
        ),
      ],
      textItems: [
        DoodleTextItem(
          text: 'Hey! Wipe to reply 🪄',
          position: const Offset(225, 880),
          color: const Color(0xFF00CEC9),
          fontSize: 64,
          fontStyle: 'PatrickHand',
        ),
      ],
      emojiItems: [
        DoodleEmojiItem(emoji: '✨', position: const Offset(650, 420), size: 80),
        DoodleEmojiItem(emoji: '🐥', position: const Offset(300, 680), size: 90),
      ],
    );
    final demoStory = DoodleData(
      timestamp: DateTime.now(),
      senderId: 'mayadoodles',
      strokes: [
        DoodleStroke(
          points: _pts([[200, 300], [350, 180], [500, 300], [650, 180]]),
          color: const Color(0xFFFF4081),
          size: 16,
        ),
      ],
      textItems: [
        DoodleTextItem(
          text: 'Good morning from Maya! ✨🎨',
          position: const Offset(120, 600),
          color: const Color(0xFFFFC72C),
          fontSize: 64,
        ),
      ],
      emojiItems: [DoodleEmojiItem(emoji: '🌸', position: const Offset(450, 400), size: 110)],
    );

    return ChatContact(
      id: 'mayadoodles',
      name: 'Maya Lin (demo)',
      username: 'mayadoodles',
      avatarEmoji: '🌸',
      avatarColor: const Color(0xFFFF7675),
      statusBio: 'Sketching life in colors ✨',
      lastActive: 'Demo friend',
      doodleStatus: DoodleChatStatus.receivedMustErase,
      pendingDoodle: doodle,
      activeStory: demoStory,
      storyTimestamp: DateTime.now(),
      streakCount: 3,
      isDemo: true,
    );
  }

  DoodleGroup _buildDemoGroup() {
    return DoodleGroup(
      id: 'grp_doodle_squad',
      name: '🎨 Doodle Squad',
      avatarEmoji: '⚡️',
      color: const Color(0xFF6C5CE7),
      memberUsernames: ['mayadoodles', currentUser.username.isNotEmpty ? currentUser.username : 'me'],
      streakCount: 5,
      lastActive: DateTime.now(),
    );
  }

  DoodleGroup createGroup(String name, String emoji, List<String> memberUsernames) {
    final members = memberUsernames.toSet().toList();
    if (currentUser.username.isNotEmpty && !members.contains(currentUser.username)) {
      members.add(currentUser.username);
    }
    final g = DoodleGroup(
      id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      avatarEmoji: emoji.isNotEmpty ? emoji : '👥',
      memberUsernames: members,
      lastActive: DateTime.now(),
    );
    groups.insert(0, g);
    _saveGroups();
    notifyListeners();
    return g;
  }

  void addMemberToGroup(String groupId, String username) {
    for (final g in groups) {
      if (g.id == groupId) {
        if (!g.memberUsernames.contains(username)) {
          g.memberUsernames.add(username);
          _saveGroups();
          notifyListeners();
        }
        break;
      }
    }
  }

  bool sendGroupDoodle(String groupId, DoodleData doodle) {
    DoodleGroup? g;
    for (final grp in groups) {
      if (grp.id == groupId) {
        g = grp;
        break;
      }
    }
    if (g == null) return false;
    g.latestDoodle = doodle;
    g.lastActive = DateTime.now();
    g.streakCount++;
    currentUser.activeStory = doodle;
    currentUser.storyTimestamp = DateTime.now();
    if (isConnected) {
      for (final mem in g.memberUsernames) {
        if (mem.toLowerCase() != currentUser.username.toLowerCase()) {
          _send({
            'type': 'group_doodle',
            'groupId': groupId,
            'groupName': g.name,
            'to': mem,
            'doodle': doodle.toJson(),
          });
        }
      }
    }
    _saveGroups();
    notifyListeners();
    return true;
  }

  void postDoodleUpStory(DoodleData doodle) {
    currentUser.activeStory = doodle;
    currentUser.storyTimestamp = DateTime.now();
    if (isConnected) {
      for (final c in contacts) {
        if (!c.isDemo) {
          _send({
            'type': 'doodleup_story',
            'to': c.username,
            'doodle': doodle.toJson(),
          });
        }
      }
    }
    notifyListeners();
  }

  void _simulateDemoReply(ChatContact contact) {
    Future.delayed(const Duration(seconds: 7), () {
      if (contact.doodleStatus != DoodleChatStatus.sentWaitingForErase) return;
      contact.doodleStatus = DoodleChatStatus.receivedMustErase;
      final replyDoodle = DoodleData(
        timestamp: DateTime.now(),
        senderId: contact.id,
        strokes: [
          DoodleStroke(
            points: _pts([[150, 180], [150, 260], [250, 260]]),
            color: const Color(0xFF00B894),
            size: 14,
          ),
        ],
        textItems: [
          DoodleTextItem(
            text: 'Loved your doodle! Erase me now 😊',
            position: const Offset(150, 800),
            color: const Color(0xFFFFC72C),
            fontSize: 58,
          ),
        ],
        emojiItems: [DoodleEmojiItem(emoji: '🎉', position: const Offset(500, 420), size: 90)],
      );
      contact.pendingDoodle = replyDoodle;
      contact.activeStory = replyDoodle;
      contact.storyTimestamp = DateTime.now();
      _events.add(ChatEvent(ChatEventType.incomingDoodle, contact: contact));
      notifyListeners();
    });
  }
}
