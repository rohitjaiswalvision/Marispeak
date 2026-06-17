import apn from "@parse/node-apn";
import path from "path";
import { fileURLToPath } from 'url';

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

  const note = new apn.Notification();
  note.expiry = 0; 
  note.priority = 10;
  note.payload = {
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
