import apn from "@parse/node-apn";
import path from "path";
import { fileURLToPath } from 'url';
import crypto from 'crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function testPush() {
  const options = {
    token: {
      key: path.join(__dirname, "AuthKey_AC7HTJC42H.p8"),
      keyId: "AC7HTJC42H",
      teamId: "R7VBW74U4H",
    },
    production: false, // Testing in Sandbox
  };

  const apnProvider = new apn.Provider(options);

  const deviceToken = "787df0edc2492f192e72ddea2162576b9cae78909738d8a3c9b0089e35f292aa"; // From user's log
  
  function makeChannelUUID(groupId) {
    const md5 = crypto.createHash('md5').update(groupId || "").digest('hex');
    return `${md5.substring(0,8)}-${md5.substring(8,12)}-${md5.substring(12,16)}-${md5.substring(16,20)}-${md5.substring(20,32)}`.toUpperCase();
  }

  const channelUUID = makeChannelUUID("ajaw9LhcwUSp5tyoVXorVYV8N473_bvzrZKSKA4RVEXFjJaEHfIWUo2O2");

  const note = new apn.Notification();
  note.expiry = 0; 
  note.priority = 10;
  note.rawPayload = {
    aps: {
      "channel-uuid": channelUUID,
      "active_remote_participant": "Agent Test"
    },
    type: "ptt",
    senderName: "Agent Test",
    groupId: "ajaw9LhcwUSp5tyoVXorVYV8N473",
  };
  note.topic = "com.pttcommunicate.pttmessenger.voip-ptt";
  note.pushType = "pushtotalk"; 

  console.log("Sending PushToTalk push to:", deviceToken);

  try {
    const result = await apnProvider.send(note, deviceToken);
    console.log("Result:", JSON.stringify(result, null, 2));
  } catch (e) {
    console.error("Error:", e);
  }
  process.exit(0);
}

testPush();
