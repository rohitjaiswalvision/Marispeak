/**
 * Railway WebSocket PTT Server — with iOS VoIP Push Support
 * 
 * HOW TO USE:
 * 1. npm install ws @parse/node-apn
 * 2. Set environment variables on Railway:
 *    - VOIP_KEY_PATH   → path to your .p8 VoIP key file (or paste inline)
 *    - VOIP_KEY_ID     → 10-char Key ID from Apple Developer portal
 *    - TEAM_ID         → Your Apple Team ID (R7VBW74U4H for Thalas Apps)
 *    - BUNDLE_ID       → com.pttcommunicate.pttmessenger
 * 3. Deploy to Railway
 */

const WebSocket = require("ws");
const apn = require("@parse/node-apn");
const path = require("path");

// ─────────────────────────────────────────────────────────────────
// APNs VoIP Push Setup
// ─────────────────────────────────────────────────────────────────
let apnProvider = null;

function initAPNs() {
  try {
    const options = {
      token: {
        key: path.join(__dirname, "AuthKey_AC7HTJC42H.p8"), // ✅ Absolute path — works from any directory
        keyId: "AC7HTJC42H",            // <-- Your 10-char Key ID
        teamId: "R7VBW74U4H",           // <-- Your Apple Team ID (Thalas Apps Pty Ltd)
      },
      production: false, // Set to false for Xcode local testing, change to true for TestFlight/App Store
    };

    apnProvider = new apn.Provider(options);
    console.log("✅ APNs VoIP provider initialized");
  } catch (e) {
    console.warn("⚠️ APNs VoIP not configured:", e.message);
  }
}

async function sendVoIPPush(deviceToken, senderName, groupId) {
  if (!apnProvider || !deviceToken) return;

  const note = new apn.Notification();
  note.expiry = Math.floor(Date.now() / 1000) + 3600; // expires in 1 hour
  note.payload = {
    type: "ptt",
    senderName: senderName || "PTT Message",
    groupId: groupId || "",
  };
  // VoIP pushes must use the .voip-ptt topic suffix for PushToTalk framework
  note.topic = "com.pttcommunicate.pttmessenger.voip-ptt";
  note.pushType = "pushtotalk"; // REQUIRED header for Apple APNs PushToTalk

  try {
    const result = await apnProvider.send(note, deviceToken);
    if (result.failed.length > 0) {
      console.warn("⚠️ VoIP push failed:", result.failed[0].response);
    } else {
      console.log(`📲 VoIP push sent to ${deviceToken.substring(0, 10)}...`);
    }
  } catch (e) {
    console.error("❌ VoIP push error:", e.message);
  }
}

// ─────────────────────────────────────────────────────────────────
// WebSocket Server
// ─────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
const wss = new WebSocket.Server({ port: PORT });

// Map: userId → { ws, voipToken, groupId, name }
const clients = new Map();

initAPNs();

wss.on("connection", (ws) => {
  let userId = null;

  ws.on("message", async (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }

    // ── REGISTER ──────────────────────────────────────────────
    if (msg.type === "register") {
      userId = msg.userId?.trim();
      if (!userId) return;

      const existing = clients.get(userId) || {};
      
      const newClient = {
        ...existing,
        ws,
        voipToken: msg.voipToken || existing.voipToken || null,
        groupId: existing.groupId || userId,
        name: msg.name || existing.name || "User",
      };
      
      clients.set(userId, newClient);
      console.log(`✅ Registered: ${userId}`);

      // Send any pending audio that was queued while offline
      if (newClient.pendingAudio && newClient.pendingAudio.length > 0) {
        console.log(`📦 Sending ${newClient.pendingAudio.length} pending audio chunks to ${userId}`);
        for (const audio of newClient.pendingAudio) {
          ws.send(JSON.stringify({ type: "audio", chunk: audio.chunk, sender: audio.sender }));
        }
        newClient.pendingAudio = []; // clear after sending
      }
    }

    // ── UPDATE VOIP TOKEN ─────────────────────────────────────
    if (msg.type === "voip_token" && userId) {
      const client = clients.get(userId);
      if (client) {
        client.voipToken = msg.token;
        console.log(`📲 VoIP token saved for ${userId}`);
      }
    }

    // ── SWITCH GROUP ──────────────────────────────────────────
    if (msg.type === "switch" && userId) {
      const client = clients.get(userId);
      if (client) {
        client.groupId = msg.newGroupId?.trim();
        console.log(`👥 ${userId} joined group ${client.groupId}`);
      }
    }

    // ── AUDIO ─────────────────────────────────────────────────
    if (msg.type === "audio" && userId) {
      const groupId = msg.groupId?.trim();
      const chunk = msg.chunk;
      const senderName = clients.get(userId)?.name || "PTT";

      // Broadcast to all group members (except sender)
      for (const [uid, client] of clients.entries()) {
        if (uid === userId) continue;
        if (client.groupId !== groupId) continue;

        if (client.ws && client.ws.readyState === WebSocket.OPEN) {
          // ✅ Client is connected and awake — send audio directly
          client.ws.send(
            JSON.stringify({ type: "audio", chunk, sender: userId })
          );
        } else {
          // ✅ Client WebSocket is closed (app in background/locked)
          // Send a VoIP push to wake the app!
          if (client.voipToken) {
            console.log(`📲 Client ${uid} is offline — sending VoIP push`);
            // Store the audio to send when they wake up
            client.pendingAudio = client.pendingAudio || [];
            client.pendingAudio.push({ chunk, sender: userId });
            await sendVoIPPush(client.voipToken, senderName, groupId);
          } else {
            console.log(`⚠️ Client ${uid} is offline but has no VoIP token`);
          }
        }
      }
    }

    // ── PING ─────────────────────────────────────────────────
    if (msg.type === "ping") {
      try {
        ws.send(JSON.stringify({ type: "pong" }));
      } catch (_) {}
    }
  });

  ws.on("close", () => {
    if (userId) {
      // Keep client record (with voipToken) so we can still push them
      const client = clients.get(userId);
      if (client) {
        client.ws = null; // mark as offline
      }
      console.log(`🔌 ${userId} disconnected (kept for VoIP push)`);
    }
  });

  ws.on("error", (err) => {
    console.error("❌ WebSocket error:", err.message);
  });
});

console.log(`🚀 PTT Voice Server running on port ${PORT}`);
