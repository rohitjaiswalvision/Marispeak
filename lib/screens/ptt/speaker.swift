import AVFoundation

func forceSpeakerAfterDisable() {
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(.playback, options: [.defaultToSpeaker])
        try session.setMode(.default)
        try session.setActive(true)
    } catch {
        print("🔴 AVAudioSession error: \(error)")
    }
}
