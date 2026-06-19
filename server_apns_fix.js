// ─────────────────────────────────────────────────────────────────
// CORRECTED APNs Configuration for VoIP Push
// ─────────────────────────────────────────────────────────────────

import apn from "@parse/node-apn";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let apnProvider = null;

function initAPNs() {
  try {
    const options = {
      token: {
        key: path.join(__dirname, "AuthKey_AC7HTJC42H.p8"),
        keyId: "AC7HTJC42H",
        teamId: "R7VBW74U4H",
      },
      // ✅ CRITICAL: Must be FALSE for TestFlight
      production: false,
    };

    apnProvider = new apn.Provider(options);
    console.log("✅ APNs VoIP provider initialized (SANDBOX mode)");
  } catch (e) {
    console.error("❌ APNs initialization failed:", e.message);
  }
}

async function sendVoIPPush(deviceToken, senderName, groupId) {
  if (!apnProvider || !deviceToken) {
    console.log("⚠️ No APNs provider or device token");
    return;
  }

  const note = new apn.Notification();
  note.expiry = 0; // Deliver immediately
  note.priority = 10; // High priority

  // ✅ VoIP push payload
  note.payload = {
    type: "ptt",
    senderName: senderName || "PTT Message",
    groupId: groupId || "",
  };

  // ✅ CRITICAL: Standard VoIP topic (NOT .voip-ptt)
  // Use .voip-ptt ONLY if you're using iOS 16+ Push-to-Talk framework
  // For standard VoIP pushes that wake the app, use .voip
  note.topic = "com.pttcommunicate.pttmessenger.voip";
  
  // ✅ CRITICAL: pushType must be "voip" (NOT "pushtotalk")
  note.pushType = "voip";

  try {
    console.log(`📲 Sending VoIP push to ${deviceToken.substring(0, 12)}...`);
    
    const result = await apnProvider.send(note, deviceToken);

    if (result.sent && result.sent.length > 0) {
      console.log("✅ VoIP push sent successfully!");
      console.log(`   Sent to: ${result.sent.length} device(s)`);
    }

    if (result.failed && result.failed.length > 0) {
      console.error("❌ VoIP push FAILED:");
      for (const failure of result.failed) {
        console.error(`   Device: ${failure.device?.substring(0, 12)}...`);
        console.error(`   Error: ${failure.error?.message || failure.error}`);
        console.error(`   Status: ${failure.status}`);
        console.error(`   Response: ${JSON.stringify(failure.response)}`);
      }
    }

    return result;
  } catch (e) {
    console.error("❌ VoIP push exception:", e.message);
    console.error("   Stack:", e.stack);
    return null;
  }
}

// Test function
async function testAPNsPush() {
  initAPNs();
  
  // Wait for initialization
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // Test with a device token (replace with real token from your app)
  const testToken = "46e77f46754f7ec2914c4fc385e3380f719a0c7b6751cd6155c1c69c8a2345cb";
  
  console.log("\n🧪 Testing APNs VoIP Push...\n");
  
  const result = await sendVoIPPush(testToken, "Test User", "test-group-123");
  
  console.log("\n📊 Test Result:", result ? "Sent" : "Failed");
  
  process.exit(0);
}

// Uncomment to test:
// testAPNsPush();

export { initAPNs, sendVoIPPush };
