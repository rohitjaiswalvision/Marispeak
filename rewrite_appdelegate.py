import re
import os

filepath = "/Users/pc/Downloads/agora_ptt/ios/Runner/AppDelegate.swift"
with open(filepath, "r") as f:
    content = f.read()

# Add PushToTalk import
content = content.replace("import CallKit", "import CallKit\nimport PushToTalk")

# Add channelManager to AppDelegate
content = content.replace("var activeCallUUID: UUID?", "var activeCallUUID: UUID?\n  var channelManager: Any? // PTChannelManager on iOS 16+")

# Replace PushKit initialization with PushKit + PushToTalk
setup_code = """    // ✅ Register for VoIP push notifications (PushKit)
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]"""

new_setup_code = """    // ✅ Register for VoIP push notifications (PushKit - for iOS < 16)
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]

    // ✅ Initialize Push To Talk Framework (iOS 16+)
    if #available(iOS 16.0, *) {
        do {
            channelManager = try PTChannelManager(delegate: self, restorationDelegate: self)
            // Request to join a default Walkie-Talkie channel so we can receive pushes
            let channelUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
            let descriptor = PTChannelDescriptor(name: "Walkie-Talkie", image: nil)
            let cm = channelManager as! PTChannelManager
            cm.requestJoinChannel(channelUUID: channelUUID, descriptor: descriptor)
        } catch {
            print("❌ Failed to initialize PTChannelManager: \\(error)")
        }
    }"""
content = content.replace(setup_code, new_setup_code)

# Add PushToTalk delegate methods at the end of the file
ptt_delegates = """
// ─────────────────────────────────────────────────────
// MARK: - Push To Talk Framework Delegates (iOS 16+)
// ─────────────────────────────────────────────────────
@available(iOS 16.0, *)
extension AppDelegate: PTChannelManagerDelegate, PTChannelRestorationDelegate {
    
    func channelManager(_ channelManager: PTChannelManager, receivedEphemeralPushToken pushToken: Data) {
        let token = pushToken.map { String(format: "%02x", $0) }.joined()
        print("📲 PTT Framework VoIP Token: \\(token)")
        UserDefaults.standard.set(token, forKey: "voip_token")
        sendVoIPTokenToFlutter(token)
    }
    
    func incomingPushResult(channelManager: PTChannelManager, channelUUID: UUID, pushPayload: [String : Any]) -> PTPushResult {
        print("📨 PTT Push Received: \\(pushPayload)")
        
        // Notify Flutter
        sendVoIPPushToFlutter(pushPayload)
        
        let sender = pushPayload["senderName"] as? String ?? "Walkie-Talkie"
        let participant = PTMutableParticipant(name: sender, image: nil)
        return .activeRemoteParticipant(participant)
    }
    
    func channelDescriptor(restoredChannelUUID channelUUID: UUID) -> PTChannelDescriptor {
        return PTChannelDescriptor(name: "Walkie-Talkie", image: nil)
    }
    
    func channelManager(_ channelManager: PTChannelManager, didJoinChannel channelUUID: UUID, reason: PTChannelJoinReason) {
        print("🎙️ Joined PTT Channel")
    }
    
    func channelManager(_ channelManager: PTChannelManager, didLeaveChannel channelUUID: UUID, reason: PTChannelLeaveReason) {
        print("🎙️ Left PTT Channel")
    }
    
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {
        print("🎙️ Began Transmitting")
    }
    
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didEndTransmittingFrom source: PTChannelTransmitRequestSource) {
        print("🎙️ Ended Transmitting")
    }
    
    func channelManager(_ channelManager: PTChannelManager, failedToJoinChannel channelUUID: UUID, error: Error) {
        print("❌ Failed to join PTT Channel: \\(error)")
    }
}
"""
content = content + ptt_delegates

with open(filepath, "w") as f:
    f.write(content)

