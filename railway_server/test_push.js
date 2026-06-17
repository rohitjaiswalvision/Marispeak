const WebSocket = require("ws");

const ws = new WebSocket("ws://127.0.0.1:8080");

ws.on("open", () => {
  console.log("Connected to local PTT server");
  
  // Register as a fake user
  ws.send(JSON.stringify({
    type: "register",
    userId: "FakeUser123"
  }));

  // Join the same group as the iPhone
  ws.send(JSON.stringify({
    type: "switch",
    newGroupId: "ajaw9LhcwUSp5tyoVXorVYV8N473"
  }));

  // Wait 1 second and send a fake audio message to trigger the VoIP Push
  setTimeout(() => {
    console.log("Sending fake audio message to trigger PushToTalk...");
    ws.send(JSON.stringify({
      type: "audio",
      groupId: "ajaw9LhcwUSp5tyoVXorVYV8N473",
      sender: "FakeUser123",
      chunk: Buffer.from("fake_audio_data").toString("base64")
    }));
    
    // Close after sending
    setTimeout(() => {
      ws.close();
      console.log("Done!");
    }, 1000);
  }, 1000);
});

ws.on("error", (err) => console.error(err));
