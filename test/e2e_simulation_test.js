// Comprehensive End-to-End WebSocket Relay & Turn-Based Golden Rule Test
const { spawn } = require('child_process');
const path = require('path');
const WebSocket = require('ws');

const TEST_PORT = 8999;
const SERVER_PATH = path.join(__dirname, '..', 'server', 'relay.js');

let serverProc;

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function startServer() {
  return new Promise((resolve, reject) => {
    serverProc = spawn('node', [SERVER_PATH], {
      env: { ...process.env, PORT: TEST_PORT },
      stdio: 'pipe',
    });

    serverProc.stdout.on('data', (data) => {
      const msg = data.toString();
      if (msg.includes('DoodleChat HTTP + WebSocket server running')) {
        resolve();
      }
    });

    serverProc.stderr.on('data', (err) => {
      console.error('Server err:', err.toString());
    });

    serverProc.on('error', reject);
  });
}

function createClient(username) {
  return new Promise((resolve) => {
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}`);
    const events = [];

    ws.on('open', () => {
      ws.send(
        JSON.stringify({
          type: 'register',
          username,
          clientId: `cid_${username}`,
          name: `${username.toUpperCase()} Test`,
          avatarEmoji: '🦆',
          avatarColor: '#FFC72C',
          bio: 'Automated tester',
        })
      );
    });

    ws.on('message', (raw) => {
      try {
        const msg = JSON.parse(raw);
        events.push(msg);
      } catch (e) {}
    });

    // Wait until registered
    const check = setInterval(() => {
      if (events.some((e) => e.type === 'registered_success')) {
        clearInterval(check);
        resolve({ ws, events });
      }
    }, 50);
  });
}

async function runE2ETest() {
  console.log('--- STARTING DOODLECHAT E2E TEST ---');
  console.log('1. Launching local relay server on port', TEST_PORT);
  await startServer();
  console.log('✓ Relay server online');

  try {
    // 2. Connect Alice and Bob
    console.log('2. Connecting @alice and @bob...');
    const alice = await createClient('alice');
    const bob = await createClient('bob');
    console.log('✓ Both @alice and @bob connected and registered');

    // 3. Friend Request Flow
    console.log('3. Testing Friend Request flow...');
    alice.ws.send(JSON.stringify({ type: 'send_friend_request', to: 'bob' }));
    await sleep(200);

    const bobGotReq = bob.events.some(
      (e) => e.type === 'incoming_friend_request' && e.from === 'alice'
    );
    if (!bobGotReq) throw new Error('Bob did not receive incoming friend request from Alice');
    console.log('✓ Bob received friend request from Alice');

    // Bob accepts friend request
    bob.ws.send(
      JSON.stringify({
        type: 'respond_friend_request',
        to: 'alice',
        accept: true,
      })
    );
    await sleep(200);

    const aliceAccepted = alice.events.some(
      (e) => e.type === 'friend_request_accepted' && e.from === 'bob'
    );
    if (!aliceAccepted) throw new Error('Alice did not receive friend_request_accepted from Bob');
    console.log('✓ Mutual friendship established!');

    // 4. Real-time Drawing Indicator
    console.log('4. Testing Real-time Drawing Presence indicator...');
    alice.ws.send(JSON.stringify({ type: 'drawing', to: 'bob', active: true }));
    await sleep(150);

    const bobSawDrawing = bob.events.some(
      (e) => e.type === 'peer_drawing' && e.from === 'alice' && e.active === true
    );
    if (!bobSawDrawing) throw new Error('Bob did not see Alice drawing presence');
    console.log('✓ Realtime "pencil drawing" presence verified');

    // 5. Doodle Delivery & Golden Turn Rule
    console.log('5. Testing Doodle Delivery & The Golden Turn Rule...');
    const mockDoodle = {
      version: 1,
      strokes: [
        {
          color: 0xFFFF0000,
          strokeWidth: 4.0,
          points: [
            { x: 100, y: 100 },
            { x: 200, y: 200 },
          ],
        },
      ],
    };

    alice.ws.send(
      JSON.stringify({
        type: 'send_doodle',
        to: 'bob',
        doodle: mockDoodle,
      })
    );
    await sleep(200);

    const bobGotDoodle = bob.events.some(
      (e) => e.type === 'incoming_doodle' && e.from === 'alice'
    );
    if (!bobGotDoodle) throw new Error('Bob did not receive doodle from Alice');
    console.log('✓ Doodle received by Bob');

    // Golden Turn Rule: Alice tries to send another doodle before Bob erases
    alice.ws.send(
      JSON.stringify({
        type: 'send_doodle',
        to: 'bob',
        doodle: mockDoodle,
      })
    );
    await sleep(200);

    const rejected = alice.events.some(
      (e) => e.type === 'send_rejected' && e.reason === 'pending_doodle'
    );
    if (!rejected) throw new Error('Golden Turn Rule violation: Second doodle was not rejected!');
    console.log('✓ Golden Turn Rule verified: 2nd doodle blocked while 1st is pending');

    // 6. Erase Progress & Sweep Ack
    console.log('6. Testing Erase Progress & Erase Ack...');
    bob.ws.send(
      JSON.stringify({
        type: 'erase_progress',
        to: 'alice',
        progress: 0.55,
      })
    );
    await sleep(150);

    const aliceSawEraseProgress = alice.events.some(
      (e) => e.type === 'peer_erase_progress' && e.from === 'bob' && e.progress === 0.55
    );
    if (!aliceSawEraseProgress) throw new Error('Alice did not receive erase progress');
    console.log('✓ Real-time erase progress indicator verified (55%)');

    // Bob completes erase
    bob.ws.send(
      JSON.stringify({
        type: 'doodle_erased',
        to: 'alice',
      })
    );
    await sleep(200);

    const aliceErasedAck = alice.events.some(
      (e) => e.type === 'doodle_erased_ack' && e.from === 'bob'
    );
    if (!aliceErasedAck) throw new Error('Alice did not receive doodle_erased_ack');
    console.log('✓ Doodle Erased Ack verified (Canvas unlocked for new turn!)');

    // Close sockets
    alice.ws.close();
    bob.ws.close();

    console.log('\n========================================');
    console.log('🎉 ALL END-TO-END VALIDATION TESTS PASSED!');
    console.log('========================================');
  } finally {
    if (serverProc) serverProc.kill();
  }
}

runE2ETest().catch((err) => {
  console.error('\n❌ E2E TEST FAILED:', err.message);
  if (serverProc) serverProc.kill();
  process.exit(1);
});
