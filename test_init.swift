import PushToTalk
import UIKit
import AVFoundation

@available(iOS 16.0, *)
class MyClass: NSObject, PTChannelManagerDelegate, PTChannelRestorationDelegate {
    var channelManager: PTChannelManager!
    
    override init() {
        super.init()
        PTChannelManager.channelManager(delegate: self, restorationDelegate: self) { manager, error in
            if let manager = manager {
                self.channelManager = manager
            }
        }
    }
    
    func channelManager(_ channelManager: PTChannelManager, didJoinChannel channelUUID: UUID, reason: PTChannelJoinReason) {}
    func channelManager(_ channelManager: PTChannelManager, didLeaveChannel channelUUID: UUID, reason: PTChannelLeaveReason) {}
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {}
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didEndTransmittingFrom source: PTChannelTransmitRequestSource) {}
    func channelManager(_ channelManager: PTChannelManager, receivedEphemeralPushToken pushToken: Data) {}
    func incomingPushResult(channelManager: PTChannelManager, channelUUID: UUID, pushPayload: [String : Any]) -> PTPushResult { 
        return .activeRemoteParticipant(PTParticipant(name: "a", image: nil)) 
    }
    func channelDescriptor(restoredChannelUUID channelUUID: UUID) -> PTChannelDescriptor { 
        return PTChannelDescriptor(name: "a", image: nil) 
    }
    func channelManager(_ channelManager: PTChannelManager, didActivate audioSession: AVAudioSession) {}
    func channelManager(_ channelManager: PTChannelManager, didDeactivate audioSession: AVAudioSession) {}
}
