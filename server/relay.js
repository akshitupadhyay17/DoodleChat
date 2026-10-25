const http = require('http');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { WebSocketServer } = require('ws');

const PORT = process.env.PORT || 8080;
const WEB_DIR = path.join(__dirname, '..', 'build', 'web');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};
const COMPRESSIBLE = new Set(['.html', '.js', '.mjs', '.css', '.json', '.wasm', '.svg', '.otf', '.ttf']);
const NO_CACHE = new Set([
  'index.html', 'flutter_bootstrap.js', 'main.dart.js', 'flutter_service_worker.js', 'version.json',
]);

// ───────────────────────── state ─────────────────────────
/** username -> profile */
const profiles = new Map();
/** username -> live WebSocket */
const sockets = new Map();
/** "from>to" -> { doodle } (a doodle that has not been erased yet) */
const pending = new Map();

/** Mutual friends: set of "userA<>userB" */
const friends = new Set();
/** Pending friend requests: set of "from>REQ>to" */
const friendRequests = new Set();

const key = (from, to) => `${from}>${to}`;
const pairKey = (a, b) => [norm(a), norm(b)].sort().join('<>');
const reqKey = (from, to) => `${norm(from)}>REQ>${norm(to)}`;
const norm = (u) => String(u || '').toLowerCase().trim().replace(/^@/, '').replace(/[^a-z0-9_.]/g, '');

function publicProfile(p) {
  return {
    username: p.username,
    name: p.name,
    avatarEmoji: p.avatarEmoji,
    avatarColor: p.avatarColor,
    avatarPhoto: p.avatarPhoto || null,
    bio: p.bio,
    online: sockets.has(p.username),
  };
}

function send(ws, obj) {
  if (ws && ws.readyState === 1) ws.send(JSON.stringify(obj));
}

function sendTo(username, obj) {
  send(sockets.get(username), obj);
}

function broadcastOnlineUsers() {
  const users = [...profiles.values()].filter((p) => sockets.has(p.username)).map(publicProfile);
  const msg = JSON.stringify({ type: 'online_users', users });
  for (const ws of sockets.values()) if (ws.readyState === 1) ws.send(msg);
}

function buildSync(username) {
  const u = norm(username);
  const incoming = [];
  const outgoing = [];
  for (const [k, v] of pending) {
    const [from, to] = k.split('>');
    if (to === u) incoming.push({ from, doodle: v.doodle });
    if (from === u) outgoing.push(to);
  }
  const incomingRequests = [];
  const outgoingRequests = [];
  for (const r of friendRequests) {
    const [from, to] = r.split('>REQ>');
    if (to === u) {
      const p = profiles.get(from);
      incomingRequests.push({ from, profile: p ? publicProfile(p) : { username: from, name: from } });
    }
    if (from === u) {
      outgoingRequests.push(to);
    }
  }
  const friendsList = [];
  for (const f of friends) {
    const [a, b] = f.split('<>');
    if (a === u) friendsList.push(b);
    else if (b === u) friendsList.push(a);
  }
  return {
    type: 'sync',
    incoming,
    outgoing,
    incomingRequests,
    outgoingRequests,
    friends: friendsList,
  };
}

// ───────────────────────── HTTP (static app + tiny API) ─────────────────────────
const gzCache = new Map();

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');

  if (url.pathname === '/api/check') {
    const u = norm(url.searchParams.get('u'));
    const cid = url.searchParams.get('cid') || '';
    const p = profiles.get(u);
    const taken = !!p && p.clientId !== cid && sockets.has(u);
    res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
    res.end(JSON.stringify({ username: u, available: !!u && u.length >= 3 && !taken }));
    return;
  }

  let reqPath = decodeURIComponent(url.pathname);
  if (reqPath === '/' || reqPath === '') reqPath = '/index.html';
  let filePath = path.normalize(path.join(WEB_DIR, reqPath));
  if (!filePath.startsWith(WEB_DIR)) {
    res.writeHead(403);
    res.end();
    return;
  }
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(WEB_DIR, 'index.html');
  }

  const ext = path.extname(filePath).toLowerCase();
  const base = path.basename(filePath);
  const headers = {
    'Content-Type': MIME_TYPES[ext] || 'application/octet-stream',
    'Access-Control-Allow-Origin': '*',
    // Always revalidate: tree-shaken icon fonts change per build and stale copies hide new icons.
    'Cache-Control': 'no-cache',
  };

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(500);
      res.end('Error loading ' + reqPath);
      return;
    }
    const wantsGzip = /\bgzip\b/.test(req.headers['accept-encoding'] || '');
    if (wantsGzip && COMPRESSIBLE.has(ext) && content.length > 1024) {
      const mtime = fs.statSync(filePath).mtimeMs;
      const ck = filePath + ':' + mtime;
      let gz = gzCache.get(ck);
      if (!gz) {
        gz = zlib.gzipSync(content, { level: 6 });
        gzCache.set(ck, gz);
      }
      headers['Content-Encoding'] = 'gzip';
      headers['Vary'] = 'Accept-Encoding';
      res.writeHead(200, headers);
      res.end(gz);
    } else {
      res.writeHead(200, headers);
      res.end(content);
    }
  });
});

// ───────────────────────── WebSocket realtime ─────────────────────────
const wss = new WebSocketServer({ server, maxPayload: 8 * 1024 * 1024 });

wss.on('connection', (ws) => {
  let me = null;
  ws.isAlive = true;
  ws.on('pong', () => (ws.isAlive = true));

  ws.on('message', (raw) => {
    let data;
    try {
      data = JSON.parse(raw.toString());
    } catch (e) {
      return;
    }
    ws.isAlive = true;

    switch (data.type) {
      case 'ping':
        send(ws, { type: 'pong' });
        break;

      case 'register': {
        const username = norm(data.username);
        if (username.length < 3) {
          send(ws, { type: 'register_error', reason: 'Username must be at least 3 characters.' });
          return;
        }
        const existing = profiles.get(username);
        const clientId = String(data.clientId || '');
        if (existing && existing.clientId !== clientId && sockets.has(username)) {
          send(ws, { type: 'register_error', reason: `@${username} is already taken. Pick another!` });
          return;
        }
        // Replace an old socket of the same owner (page refresh / reconnect).
        const old = sockets.get(username);
        if (old && old !== ws) {
          old.replaced = true;
          try { old.close(); } catch (e) {}
        }
        me = username;
        profiles.set(username, {
          username,
          clientId,
          name: data.name || username,
          avatarEmoji: data.avatarEmoji || '🦆',
          avatarColor: data.avatarColor || '#FFC72C',
          avatarPhoto: data.avatarPhoto || null,
          bio: data.bio || 'Doodling away ✨',
        });
        sockets.set(username, ws);
        send(ws, {
          type: 'registered_success',
          username,
          users: [...profiles.values()].filter((p) => sockets.has(p.username)).map(publicProfile),
        });
        send(ws, buildSync(username));
        broadcastOnlineUsers();
        console.log(`+ @${username} online (${sockets.size} connected)`);
        break;
      }

      case 'lookup': {
        const p = profiles.get(norm(data.username));
        send(ws, { type: 'lookup_result', reqId: data.reqId, profile: p ? publicProfile(p) : null });
        break;
      }

      case 'profile_update': {
        if (!me) return;
        const p = profiles.get(me) || { username: me, clientId: '' };
        if (data.name) p.name = data.name;
        if (data.avatarEmoji) p.avatarEmoji = data.avatarEmoji;
        if (data.avatarColor) p.avatarColor = data.avatarColor;
        if (data.avatarPhoto !== undefined) p.avatarPhoto = data.avatarPhoto;
        if (data.bio) p.bio = data.bio;
        profiles.set(me, p);
        broadcastOnlineUsers();
        for (const f of friends) {
          const [a, b] = f.split('<>');
          const other = (a === me) ? b : (b === me ? a : null);
          if (other) {
            sendTo(other, { type: 'peer_profile_updated', from: me, profile: publicProfile(p) });
          }
        }
        break;
      }

      case 'send_friend_request': {
        if (!me) return;
        const to = norm(data.to);
        if (!to || to === me) return;
        if (friends.has(pairKey(me, to))) {
          const p = profiles.get(to);
          send(ws, {
            type: 'friend_request_accepted',
            from: to,
            profile: p ? publicProfile(p) : { username: to, name: to },
          });
          return;
        }
        friendRequests.add(reqKey(me, to));
        send(ws, { type: 'friend_request_sent', to });
        const senderProfile = publicProfile(profiles.get(me) || { username: me, name: me });
        sendTo(to, { type: 'incoming_friend_request', from: me, profile: senderProfile });
        console.log(`🤝 @${me} sent doodle request to @${to}`);
        break;
      }

      case 'respond_friend_request': {
        if (!me) return;
        const from = norm(data.to); // the requester
        if (!from) return;
        const accept = data.accept === true;
        friendRequests.delete(reqKey(from, me));
        if (accept) {
          friends.add(pairKey(from, me));
          const myProfile = publicProfile(profiles.get(me) || { username: me, name: me });
          const theirProfile = publicProfile(profiles.get(from) || { username: from, name: from });
          sendTo(from, { type: 'friend_request_accepted', from: me, profile: myProfile });
          send(ws, { type: 'friend_request_accepted', from, profile: theirProfile });
          console.log(`🎉 @${me} accepted @${from}'s doodle request!`);
        } else {
          sendTo(from, { type: 'friend_request_declined', from: me });
          send(ws, { type: 'friend_request_declined', from });
          console.log(`✕ @${me} declined @${from}'s doodle request`);
        }
        break;
      }

      case 'send_doodle': {
        if (!me) return;
        const to = norm(data.to);
        if (!profiles.has(to) || to === me) {
          send(ws, { type: 'send_rejected', to, reason: 'unknown_user' });
          return;
        }
        // Must be friends before sending doodles!
        if (!friends.has(pairKey(me, to))) {
          send(ws, {
            type: 'send_rejected',
            to,
            reason: 'not_friends',
            message: 'You must send a doodle request first and wait for approval!',
          });
          return;
        }
        // One doodle at a time between a pair, in either direction.
        if (pending.has(key(me, to)) || pending.has(key(to, me))) {
          send(ws, { type: 'send_rejected', to, reason: 'pending_doodle' });
          return;
        }
        pending.set(key(me, to), { doodle: data.doodle, at: Date.now() });
        sendTo(to, { type: 'incoming_doodle', from: me, doodle: data.doodle });
        send(ws, { type: 'doodle_delivered', to, online: sockets.has(to) });
        console.log(`✎ @${me} → @${to} (${sockets.has(to) ? 'live' : 'queued'})`);
        break;
      }

      case 'doodle_erased': {
        if (!me) return;
        const from = norm(data.to); // the original sender
        if (pending.delete(key(from, me))) {
          sendTo(from, { type: 'doodle_erased_ack', from: me });
          console.log(`✓ @${me} erased @${from}'s doodle`);
        }
        break;
      }

      case 'erase_progress':
        if (me) sendTo(norm(data.to), { type: 'peer_erase_progress', from: me, progress: data.progress });
        break;

      case 'drawing':
        if (me) sendTo(norm(data.to), { type: 'peer_drawing', from: me, active: !!data.active });
        break;

      case 'doodleup_story':
        if (me) sendTo(norm(data.to), { type: 'doodleup_story', from: me, doodle: data.doodle });
        break;

      case 'group_doodle':
        if (me) sendTo(norm(data.to), {
          type: 'group_doodle',
          from: me,
          groupId: data.groupId,
          groupName: data.groupName,
          doodle: data.doodle,
        });
        break;
    }
  });

  ws.on('close', () => {
    if (me && sockets.get(me) === ws) {
      sockets.delete(me);
      broadcastOnlineUsers();
      console.log(`- @${me} offline (${sockets.size} connected)`);
    }
  });
});

// Keep connections alive through proxies/tunnels and drop dead ones.
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) {
      ws.terminate();
      continue;
    }
    ws.isAlive = false;
    try { ws.ping(); } catch (e) {}
  }
}, 25000);

server.listen(PORT, '0.0.0.0', () => {
  console.log(`DoodleChat HTTP + WebSocket server running on http://0.0.0.0:${PORT}`);
});
