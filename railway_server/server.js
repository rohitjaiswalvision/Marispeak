import express from "express";
import http from "http";
import WebSocket, { WebSocketServer } from "ws";
import apn from "@parse/node-apn";
import path from "path";
import { fileURLToPath } from 'url';

// Setup for ES Modules __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.get("/testing", (req, res) => {
  console.log("=====hello World");
  res.send("✅ Voice WebSocket server running!");
});

const server = http.createServer(app);

// ─────────────────────────────────────────────────────────────────
// APNs VoIP Push Setup
// ─────────────────────────────────────────────────────────────────
let apnProvider = null;

function initAPNs() {
  try {
    const options = {
      token: {
        key: path.join(__dirname, "AuthKey_AC7HTJC42H.p8"), // ✅ Must be in same folder as server.js
        keyId: "AC7HTJC42H",                               // ✅ 10-char Key ID
        teamId: "R7VBW74U4H",                              // ✅ Apple Team ID
      },
      // ✅ TRUE for TestFlight and App Store (production APNs tokens)
      // Set to FALSE only when testing directly via Xcode USB cable (sandbox tokens)
      production: false,
    };

    apnProvider = new apn.Provider(options);
    console.log("✅ APNs VoIP provider initialized");
  } catch (e) {
    console.warn("⚠️ APNs VoIP not configured:", e.message);
  }
}

async function sendVoIPPush(deviceToken, senderName, groupId, senderId) {
  if (!apnProvider || !deviceToken) return;

  const note = new apn.Notification();
  note.expiry = 0;        // ✅ Deliver immediately
  note.priority = 10;     // ✅ REQUIRED header for Apple Push To Talk
  note.rawPayload = {
    aps: {
      "channel-uuid": "00000000-0000-0000-0000-000000000000",
      "active_remote_participant": senderName || "PTT Message"
    },
    type: "ptt",
    senderName: senderName || "PTT Message",
    groupId: groupId || "",
    senderId: senderId || "",
  };
  // VoIP pushes must use the .voip-ptt topic suffix for iOS 16 PushToTalk framework
  note.topic = "com.pttcommunicate.pttmessenger.voip-ptt";
  note.pushType = "pushtotalk"; // ✅ REQUIRED header for Apple Push To Talk

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
const PORT = process.env.PORT || 3010;
const wss = new WebSocketServer({ server });

// Map: userId → { ws, voipToken, groupId, name, pendingAudio }
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
      const targetGroupId = msg.groupId?.trim();
      const chunk = msg.chunk;
      const senderName = clients.get(userId)?.name || "PTT";

      console.log(`🎙️ Audio chunk from ${userId} to group ${targetGroupId}`);
      for (const [uid, client] of clients.entries()) {
        console.log(`  - Checking client ${uid} in group ${client.groupId}...`);
        if (uid === userId) {
          console.log(`    -> Skipped (is sender)`);
          continue;
        }

        // ✅ Deliver if:
        //   1. The client's userId matches the targetGroupId (1-on-1 direct delivery)
        //   2. OR the client is subscribed to the targetGroupId (group broadcast)
        const isDirectTarget = uid === targetGroupId;
        const isGroupMember = client.groupId === targetGroupId;
        if (!isDirectTarget && !isGroupMember) {
          console.log(`    -> Skipped (wrong group)`);
          continue;
        }

        if (client.ws && client.ws.readyState === WebSocket.OPEN) {
          console.log(`    -> ✅ Sent audio to ${uid}`);
          client.ws.send(
            JSON.stringify({ type: "audio", chunk, sender: userId })
          );
        } else {
          // Client is offline — send a VoIP push to wake the app!
          if (client.voipToken) {
            console.log(`📲 Client ${uid} is offline — sending VoIP push`);
            client.pendingAudio = client.pendingAudio || [];
            client.pendingAudio.push({ chunk, sender: userId });
            await sendVoIPPush(client.voipToken, senderName, targetGroupId, userId);
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
      } catch (_) { }
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

// Using single server.listen (Express + WS attached)
server.listen(PORT, () => {
  console.log(`🚀 PTT Voice Server running on port ${PORT}`);
});
