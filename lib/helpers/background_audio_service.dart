// import 'package:audioplayers/audioplayers.dart';

// class BackgroundAudioService {
//   static final AudioPlayer _audioPlayer = AudioPlayer();

//   static Future<void> startSilentAudio() async {
//     try {
//       await _audioPlayer.setReleaseMode(ReleaseMode.loop);
//       await _audioPlayer.play(AssetSource('audio/silent.mp3'), volume: 0.0);
//     } catch (e) {
//       print("Error playing silent audio: $e");
//     }
//   }

//   static Future<void> stopSilentAudio() async {
//     await _audioPlayer.stop();
//   }
// }
