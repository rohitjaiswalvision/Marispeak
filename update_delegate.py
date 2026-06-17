import re

filepath = "/Users/pc/Downloads/agora_ptt/ios/Runner/AppDelegate.swift"
with open(filepath, "r") as f:
    content = f.read()

missing_methods = """    
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didActivate audioSession: AVAudioSession) {
        print("🎙️ PTT Audio Session Activated")
    }
    
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didDeactivate audioSession: AVAudioSession) {
        print("🎙️ PTT Audio Session Deactivated")
    }
"""

content = content.replace('func channelManager(_ channelManager: PTChannelManager, didJoinChannel channelUUID: UUID, reason: PTChannelJoinReason) {', missing_methods + '\n    func channelManager(_ channelManager: PTChannelManager, didJoinChannel channelUUID: UUID, reason: PTChannelJoinReason) {')

with open(filepath, "w") as f:
    f.write(content)
