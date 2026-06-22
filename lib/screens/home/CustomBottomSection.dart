import 'dart:convert';

import 'dart:io';

import 'package:marispeaks/config/app_config.dart';

import 'package:audio_session/audio_session.dart';

import 'package:just_audio/just_audio.dart';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flutter/services.dart';

import 'package:marispeaks/api/user_api.dart';

import 'package:marispeaks/controllers/auth_controller.dart';

import 'package:marispeaks/controllers/preferences_controller.dart';

import 'package:marispeaks/main.dart';

import 'package:marispeaks/models/user.dart';

import 'package:marispeaks/screens/ptt/websocket_ptt_controller.dart';

import 'package:path_provider/path_provider.dart';

import 'package:vibration/vibration.dart';

import 'package:marispeaks/screens/home/home_screen.dart';

import 'package:marispeaks/models/group.dart';

import 'package:marispeaks/tabs/groups/controllers/group_controller.dart';

import 'package:marispeaks/services/push_notification_service.dart';

import 'package:marispeaks/screens/home/MainScreenUI.dart';

import 'package:marispeaks/tabs/calls/call_hsitory_screen.dart';

import 'package:marispeaks/tabs/chats/components/chat_card.dart';

import 'package:marispeaks/tabs/chats/controllers/chat_controller.dart';

import 'package:marispeaks/tabs/chats/ptt_view.dart';

import 'package:marispeaks/tabs/profile/profile_screen.dart';

import 'package:marispeaks/screens/session/TrackerInit.dart';

import 'package:marispeaks/screens/about/more_settings.dart';

import 'package:marispeaks/screens/messages/controllers/message_controller.dart';

import 'package:marispeaks/models/message.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:get/get.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:marispeaks/screens/ptt/agora_controller.dart';

import 'package:speech_to_text/speech_to_text.dart';

import 'dart:async';

final GlobalKey<_CustomBottomSectionState> customBottomSection = GlobalKey();

class CustomBottomSection extends StatefulWidget {
  CustomBottomSection({Key? key}) : super(key: customBottomSection);

  @override
  _CustomBottomSectionState createState() => _CustomBottomSectionState();
}

class _CustomBottomSectionState extends State<CustomBottomSection>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _ringController;
  late Animation<double> _ringScale;

  bool isBlinking = false;

  late AnimationController _blinkController;

  late Animation<double> _blinkAnimation;

  bool mainTrackerIntroVisibility = true;

  bool inputTrackerVisibility = false;

  bool pttViewOpened = false;

  bool onMapView = false;

  bool isMicPressed = false;

  bool isGroupChat = false;

  bool? allowedAll;

  String userPhoneNumber = "0";

  String ConnectedUserName = "";

  TextEditingController _trackerController = TextEditingController();

  String channelID = "0";

  // ✅ Generate a consistent shared group ID for 1-to-1 chats
  String getSharedChannelID(String userId1, String userId2) {
    return WebSocketPTTController.sharedChannelId(userId1, userId2);
  }

  /// Subscribe to a PTT channel so incoming audio is heard without pressing talk first.
  void subscribePttChannel(String id) {
    if (id.isEmpty) return;
    channelID = id;
    WebSocketPTTController().joinGroup(id);
    print("📻 Subscribed to PTT group: $id");
  }

  String TargetUserID = "0";

  final SpeechToText _speech = SpeechToText();

  bool isListening = false;

  String _userSpeech = '';

  String _response = '';

  bool _isLoading = false;

  double minheight = 0.3;

  double maxHeightBar = 0.3;

  bool isTalking = false;

  final User currentUser = AuthController.instance.currentUser!;

  late final AudioPlayer audioPlayer; // = AudioPlayer();

  Timer? _timer;

  int _seconds = 0;

  int chatCount = 3;

  GroupController groupController = Get.find<GroupController>();

  bool _isRunning = false;

  Timer? idleTimer;

  RxBool? showOverlay = false.obs;

  ValueNotifier<String> connectedUserName = ValueNotifier("");

  static const platform = MethodChannel('custom.audio');

  Future<void> forceSpeakerOnIOS() async {
    if (Platform.isIOS) {
      try {
        await platform.invokeMethod('forceSpeaker');
      } catch (e) {
        print("Failed to force speaker: $e");
      }
    }
  }

  Future<void> forceMicOnIOS() async {
    if (Platform.isIOS) {
      try {
        await platform.invokeMethod('forceMic');
      } catch (e) {
        print("Failed to force speaker: $e");
      }
    }
  }

  void _onIdleTimeout() {
    print('⚠️ No action for 1 minute. Closing now.');

    ExitChat();
  }

  void _startTimer() {
    if (_isRunning) return;

    _isRunning = true;

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });

    print("Timer Started, $_timer");
  }

  void _stopTimer() {
    print("Timer Stopped , $_timer");
    _timer?.cancel();
    _isRunning = false;
  }

  void _resetTimer() {
    _stopTimer();
    setState(() {
      _seconds = 0;
    });
  }

  void initSpeech() async {
    await _speech.initialize();
  }

  Future<void> playBeep() async {
    try {
      await audioPlayer.setAsset('assets/sounds/pttpress.wav');

      await audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing beep sound: $e');
    }
  }

  Future<void> startListening() async {
    mainScreenKey.currentState?.statusNotifier.value = "🚀 AI Onboard ..!";

    bool available = await _speech.initialize();

    if (available) {
      setState(() => isListening = true);

      _userSpeech = "";

      _speech.listen(onResult: (result) {
        setState(() {
          _userSpeech = result.recognizedWords;
        });
      });

      await playBeep();

      mainScreenKey.currentState?.statusNotifier.value = "🎙️ Speak Now...";
    } else {
      mainScreenKey.currentState?.statusNotifier.value =
          "👉 Hold & Press to Talk";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Speech recognition not available.")),
      );
    }
  }

  Future<void> stopListeningAndSend() async {
    if (isListening) {
      await _speech.stop();

      setState(() => isListening = false);

      if (_userSpeech.trim().isNotEmpty) {
        mainScreenKey.currentState?.statusNotifier.value =
            "⏳ Processing your request...";

        await _sendToChatGPT(_userSpeech.trim());
      } else {
        mainScreenKey.currentState?.statusNotifier.value =
            "👉 Hold & Press to Talk";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ No speech detected.")),
        );

        switchToPlaybackMode();
      }
    }
  }

  Future<void> _sendToChatGPT(String prompt) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final uri = Uri.parse("https://api.openai.com/v1/chat/completions");

    final headers = {
      'Authorization': AppConfig.chatGPTKey,
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "model": "gpt-4.1-mini",
      "modalities": ["text"], // future: ["text","audio"]
      "audio": {"voice": "nova", "format": "mp3"},
      "max_tokens": 440,
      "messages": [
        {
          "role": "system",
          "content":
              "You are MariSpeak, a professional marine AI assistant..., dont talk about personal stuff."
        },
        {
          "role": "user",
          "content": prompt.length > 500 ? prompt.substring(0, 500) : prompt
        }
      ]
    });

    try {
      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final content = data['choices'][0]['message']['content'];

        if (!mounted) return;

        setState(() {
          _response = content;

          _isLoading = false;
        });

        if (mounted) {
          mainScreenKey.currentState?.statusNotifier.value = "🤔 Asking AI...";
        }

        switchToPlaybackMode();

        await speakWithOpenAITTS(content);
      } else {
        mainScreenKey.currentState?.statusNotifier.value =
            "👉 Hold & Press to Talk";
      }
    } catch (e) {
      print("GPT Exception: $e");

      setState(() => _isLoading = false);

      EneablePttVoice();

      mainScreenKey.currentState?.statusNotifier.value =
          "👉 Hold & Press to Talk";
    }
  }

  Future<void> speakWithOpenAITTS(String text) async {
    try {
      mainScreenKey.currentState?.statusNotifier.value =
          "💡 Preparing AI reply...";

      final chunks = _splitIntoChunks(text, 300);

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);

      mainScreenKey.currentState?.statusNotifier.value = "🔊 AI is Speaking...";

      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];

        // Start generating next chunk while current chunk is playing
        final responseFuture = http.post(
          Uri.parse("https://api.openai.com/v1/audio/speech"),
          headers: {
            'Authorization': AppConfig.chatGPTKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(
              {"model": "gpt-4o-mini-tts", "input": chunk, "voice": "nova"}),
        );

        // Await previous chunk to finish playing (skip for first chunk)
        if (i > 0) {
          await audioPlayer.playerStateStream.firstWhere(
            (state) => state.processingState == ProcessingState.completed,
          );
        }

        // Wait for current chunk response
        final response = await responseFuture;
        if (response.statusCode != 200) {
          throw Exception("TTS error: ${response.body}");
        }

        final filePath = '${tempDir.path}/tts_$i.mp3';
        await File(filePath).writeAsBytes(response.bodyBytes);

        // Set audio source and play immediately
        await audioPlayer.setAudioSource(AudioSource.uri(Uri.file(filePath)));
        await audioPlayer.play();
      }

      // Wait for last chunk to finish
      await audioPlayer.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );
    } catch (e) {
      debugPrint("TTS Exception: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Speaking failed: $e")),
      );
    } finally {
      mainScreenKey.currentState?.statusNotifier.value =
          "👉 Hold & Press to Talk";
      EneablePttVoice();
    }
  }

  List<String> _splitIntoChunks(String text, int maxLength) {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final chunks = <String>[];

    String current = "";

    for (final sentence in sentences) {
      if ((current + sentence).length > maxLength) {
        chunks.add(current.trim());
        current = sentence;
      } else {
        current += " $sentence";
      }
    }

    if (current.trim().isNotEmpty) {
      chunks.add(current.trim());
    }

    return chunks;
  }

  void EneablePttVoice() async {
    Future.delayed(const Duration(milliseconds: 100), () {
      switchToPlaybackMode();
    });
  }

  Future<void> startSession() async {
    final session = await AudioSession.instance;

    await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.duckOthers,
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck));
    await session.setActive(true);
  }

  Future<void> switchToPlaybackMode() async {
    Future.delayed(const Duration(microseconds: 10), () async {
      final session = await AudioSession.instance;

      await session.configure(const AudioSessionConfiguration.music());
    });
  }

  void EnablePtt() async {
    print("🔊 Speaker Activated");
  }

  void DisablePtt() async {
    print("Speaker DeActivated");
  }

  void PttInit() async {
    await WebSocketPTTController().initialize();

    await WebSocketPTTController().connect(currentUser.userId);
  }

  @override
  void initState() {
    super.initState();

    // Register if not already registered

    channelID = currentUser.userId;

    TargetUserID = currentUser.userId;

    userPhoneNumber = currentUser.phone;

    PttInit();

    clear();

    audioPlayer = AudioPlayer();

    // Main button animation (for press)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.9, // pressed size
      upperBound: 1.0, // normal size
    );
    _scaleAnimation =
        _scaleController.drive(Tween<double>(begin: 1.3, end: 1.0));

    // Rings animation (repeating)
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _ringScale = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
    );

    // Optional: listen to _scaleController to update rings visibility
    // _scaleController.addListener(() {
    //   setState(() {
    //     // Show rings only when button is pressed (value < 1.0)
    //     if (mainScreenKey.currentState?.showOverlay ?? false) {
    //       _ringController.repeat(reverse: true);
    //     } else {
    //       _ringController.stop();
    //     }
    //     print("Show Rings: ${mainScreenKey.currentState?.showOverlay}");
    //   });
    // });

    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat(reverse: true);

    _blinkAnimation =
        Tween<double>(begin: 1.0, end: 0.3).animate(_blinkController);
  }

  // Future<void> joinChannel(String ChannelID) async {

  //   int uid = 0;

  //   print("Joined UserId $ChannelID");

  //    WebSocketPTTController().joinGroup(channelID);

  // }

  Future<void> goToCallHistoryFromHome(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('fromHome', value);

    print(value);
  }

  @override
  void dispose() {
    WebSocketPTTController().dispose();

    _scaleController.dispose();
    _ringController.dispose();

    audioPlayer.dispose();

    _timer?.cancel();

    idleTimer?.cancel();

    _blinkController.dispose();

    super.dispose();
  }

  void OpenPttView() {
    if (TargetUserID == currentUser.userId) {
      Get.snackbar(
        "Caution: Not Connected",
        "Please connect to a user or group to open PTT View.",
        snackPosition: SnackPosition.TOP,
        duration: Duration(seconds: 3),
        backgroundColor: const Color.fromARGB(255, 234, 160, 0),
        colorText: Colors.white,
      );
      return;
    }

    pttViewOpened = true;
    Get.to(() => PttView());
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    double heightFraction = maxHeightBar / screenHeight;

    double minheightFraction = minheight / screenHeight;

    return Stack(
      children: [
        // DraggableScrollableSheet(

        //   initialChildSize: maxHeightBar,

        //   minChildSize: minheight,

        //   maxChildSize: maxHeightBar,

        //   builder: (context, scrollController) {

        //     return LayoutBuilder(

        //       builder: (context, constraints) {

        //         double heightFraction = constraints.maxHeight / MediaQuery.of(context).size.height;

        //         bool showNewRow = heightFraction > 0.3;

        //         return SafeArea(

        //           bottom: false,

        //           child: Container(

        //             decoration: BoxDecoration(

        //               color: Theme.of(context).scaffoldBackgroundColor,

        //               borderRadius: BorderRadius.vertical(top: Radius.circular(20)),

        //             ),

        //             padding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),

        //             child: SingleChildScrollView(

        //               controller: scrollController,

        //               child: Column(

        //                 mainAxisSize: MainAxisSize.min,

        //                 children: [

        //                   Row(

        //                     mainAxisAlignment: MainAxisAlignment.center,

        //                     children: [

        //                       Padding(

        //                         padding: const EdgeInsets.only(left: 0),

        //                         child: Align(

        //                           alignment: Alignment.topCenter,

        //                           child: Container(

        //                             decoration: BoxDecoration(

        //                               borderRadius: BorderRadius.circular(10),

        //                               boxShadow: [

        //                                 BoxShadow(

        //                                   color: const Color.fromARGB(184, 0, 0, 0),

        //                                   spreadRadius: 0,

        //                                   blurRadius: 0,

        //                                   offset: Offset(0, -5),

        //                                 ),

        //                               ],

        //                             ),

        //                             child: _buildButtonWithText(

        //                               assetPath: 'assets/maris/line_h.png',

        //                               label: '',

        //                               width: 60,

        //                               txtwidth: 0,

        //                               height: 3,

        //                             ),

        //                           ),

        //                         ),

        //                       ),

        //                     ],

        //                   ),

        //                   Row(

        //                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,

        //                     children: [

        //                       AnimatedBuilder(

        //                         animation: _blinkAnimation,

        //                         builder: (context, child) {

        //                           return Opacity(

        //                             opacity: isBlinking ? _blinkAnimation.value : 1.0,

        //                             child:

        //                             _buildButtonWithTextColor(

        //                               assetPath: 'assets/maris/recordon.png',

        //                               label: 'Chart \n Plotter',

        //                               width: 130,

        //                               txtwidth: 0,

        //                               height: 60,

        //                               onPressed: () async {

        //                                 bool hasAccess = await _isSubscribed();

        //                                 print(hasAccess);

        //                                 if (hasAccess) {

        //                                   mainScreenKey.currentState?.toggleRouteRecording(context);

        //                                   setState(() {

        //                                     isBlinking = !isBlinking;

        //                                     if (isBlinking) {

        //                                       Get.snackbar(

        //                                         'Chart Plotter',

        //                                         'Started!',

        //                                         snackPosition: SnackPosition.TOP,

        //                                         backgroundColor: Colors.blue,

        //                                         colorText: Colors.white,

        //                                         margin: EdgeInsets.all(12),

        //                                         borderRadius: 10,

        //                                         duration: Duration(seconds: 2),

        //                                       );

        //                                       _blinkController.repeat(reverse: true);

        //                                     } else {

        //                                       Get.snackbar(

        //                                         'Chart Plotter',

        //                                         'Stopped!',

        //                                         snackPosition: SnackPosition.TOP,

        //                                         backgroundColor: Colors.blue,

        //                                         colorText: Colors.white,

        //                                         margin: EdgeInsets.all(12),

        //                                         borderRadius: 10,

        //                                         duration: Duration(seconds: 2),

        //                                       );

        //                                       _blinkController.stop();

        //                                     }

        //                                   });

        //                                 } else {

        //                                   Future.delayed(const Duration(seconds: 2), () {

        //                                     showSalePopup(context);

        //                                   });

        //                                   ScaffoldMessenger.of(context).showSnackBar(

        //                                     SnackBar(content: Text('This feature is for subscribed users only.'))

        //                                   );

        //                                 }

        //                               },

        //                             ),

        //                           );

        //                         },

        //                       ),

        //                       SizedBox(width: 15),

        //                       Image.asset(

        //                         'assets/maris/line_v.png',

        //                         width: 1,

        //                         height: 50,

        //                         fit: BoxFit.contain,

        //                       ),

        //                       SizedBox(width: 10),

        //                       Row(

        //                         mainAxisSize: MainAxisSize.min,

        //                         children: [

        //                           Padding(

        //                             padding: const EdgeInsets.only(right: 0),

        //                             child: InkWell(

        //                               onTap: () {

        //                                 _showSavedTrackersDialog(context);

        //                               },

        //                               child: Container(

        //                                 child: Center(

        //                                   child: Image.asset(

        //                                     'assets/maris/tracker.png',

        //                                     width: 50,

        //                                     height: 50,

        //                                     fit: BoxFit.contain,

        //                                   ),

        //                                 ),

        //                               ),

        //                             ),

        //                           ),

        //                           InkWell(

        //                             onTap: () async {

        //                               bool hasAccess = await _isSubscribed();

        //                               if (hasAccess) {

        //                                 _showTrackerInputDialog(context);

        //                               } else {

        //                                 Future.delayed(const Duration(seconds: 2), () {

        //                                   showSalePopup(context);

        //                                 });

        //                                 ScaffoldMessenger.of(context).showSnackBar(

        //                                   const SnackBar(content: Text('This feature is for subscribed users only.')),

        //                                 );

        //                               }

        //                             },

        //                             child: _buildButtonOnlytext(

        //                               label: 'Tracker \n Live Track',

        //                               width: 90,

        //                               height: 50,

        //                               txtwidth: 80,

        //                             ),

        //                           ),

        //                         ],

        //                       )

        //                     ],

        //                   ),

        //                   const SizedBox(height: 5),

        //                   Image.asset(

        //                     'assets/maris/seprator.png',

        //                     height: 2,

        //                     width: double.infinity,

        //                     fit: BoxFit.cover,

        //                   ),

        //                   if (showNewRow) ...[

        //                     SizedBox(height: 0),

        //                     Row(

        //                       children: [

        //                         Padding(

        //                           padding: const EdgeInsets.only(right: 0),

        //                           child: _buildButtonWithText(

        //                             assetPath: 'assets/maris/exit_chat.png',

        //                             label: '',

        //                             width: 155,

        //                             txtwidth: 0,

        //                             onPressed: () {

        //                               ExitChat();

        //                             }

        //                           ),

        //                         ),

        //                         Spacer(),

        //                         Padding(

        //                           padding: const EdgeInsets.only(right: 10),

        //                           child: _buildButtonWithTextAndIcon(

        //                             assetPath: 'assets/maris/green_rect.png',

        //                             label: "Connected: $ConnectedUserName",

        //                             iconPath: 'assets/maris/enabledopt.png',

        //                           ),

        //                         ),

        //                       ],

        //                     ),

        //                     SizedBox(height: 0),

        //                     Row(

        //                       mainAxisAlignment: MainAxisAlignment.center,

        //                       children: [

        //                         Padding(

        //                           padding: const EdgeInsets.only(left: 30),

        //                           child: _buildButtonWithText(

        //                             assetPath: 'assets/maris/mute.png',

        //                             label: '',

        //                             width: 90,

        //                             onPressed: () => print('Replay Pressed'),

        //                             imgColor: Color.fromARGB(255, 250, 250, 250),

        //                             bgColor: Color.fromARGB(255, 18, 183, 236),

        //                           ),

        //                         ),

        //                         Spacer(),

        //                         Padding(

        //                           padding: const EdgeInsets.only(right: 0),

        //                           child: _buildButtonWithText(

        //                             assetPath: 'assets/maris/ptt_view.png',

        //                             label: '',

        //                             width: 160,

        //                             onPressed: () async {

        //                               bool hasAccess = await _isSubscribed();

        //                               if (hasAccess) {

        //                                 Get.to(() => PttView());

        //                               } else {

        //                                 Future.delayed(const Duration(seconds: 2), () {

        //                                   showSalePopup(context);

        //                                 });

        //                                 ScaffoldMessenger.of(context).showSnackBar(

        //                                   SnackBar(content: Text('This feature is for subscribed users only.'))

        //                                 );

        //                               }

        //                             },

        //                           ),

        //                         ),

        //                       ],

        //                     ),

        //                   ],

        //                 ],

        //               ),

        //             ),

        //           ),

        //         );

        //       },

        //     );

        //   },

        // ),

        // Positioned(

        //   top: 0,

        //   left: 0,

        //   right: 0,

        //   child: Align(

        //     alignment: Alignment.topCenter,

        //     child: Image.asset(

        //       'assets/maris/line_h.png',

        //       width: 140,

        //       height: 30,

        //       fit: BoxFit.contain,

        //     ),

        //   ),

        // ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80, // same height as your image

                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color.fromARGB(222, 28, 28, 28)
                      : Colors.white, // choose your light mode color
                ),
              ),
              Container(
                height: 95,
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 10,
                        left: 5,
                      ),
                      child: Obx(() {
                        final chatUnread =
                            ChatController.instance.totalUnreadChats;

                        final groupUnread =
                            GroupController.instance.totalUnreadGroups;

                        final unreadCount = chatUnread + groupUnread;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildButton(
                              'assets/maris/chats.png',
                              '',
                              onPressed: () async {
                                idleTimer?.cancel();
                                ExitChat();

                                if (Get.isRegistered<MessageController>()) {
                                  Get.delete<MessageController>();

                                  print("Deleted");
                                } else {
                                  print("Not Found Controller");
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => HomeScreen()),
                                );
                              },
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 0),
                      child: _buildButton('assets/maris/calls.png', '',
                          onPressed: () async {
                        await goToCallHistoryFromHome(true);

                        if (Get.isRegistered<MessageController>()) {
                          Get.delete<MessageController>();

                          print("Deleted");
                        } else {
                          print("Not Found Controller");
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CallHistoryScreen()),
                        );
                      }),
                    ),
                    Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 5,
                        left: 10,
                      ),
                      child: _buildButton('assets/maris/account.png', '',
                          onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ProfileScreen()),
                        );
                      }),
                    ),
                    _buildButton('assets/maris/more.png', '', onPressed: () {
                      Get.to(() => MoreSettings());
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Listener(
            onPointerDown: (_) async {
              final prefs = await SharedPreferences.getInstance();

              // Idle timer logic
              idleTimer?.cancel();
              idleTimer = Timer(Duration(minutes: 1), _onIdleTimeout);

              if (TargetUserID == currentUser.userId) {
                // Direct PTT flow for self (no limit check)
                final result = await Connectivity().checkConnectivity();

                if (result == ConnectivityResult.none &&
                    mainScreenKey.currentState!.isOfflineScreenShown == false) {
                  rootScaffoldKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text("No internet connection"),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                } else {
                  if (Get.find<PreferencesController>().isAudioEnabled.value ==
                      true) {
                    showChatSelectionModal(
                      context,
                      (User user) async {
                        ChatController.instance.setConnectedUser(user);
                        setState(() {
                          TargetUserID = user.userId;
                          maxHeightBar = 0.41;
                          mainScreenKey.currentState?.CloseBox = true;
                          ConnectedUserName = user.fullname;
                          connectedUserName.value = ConnectedUserName;
                          // ✅ Use shared group ID for 1-to-1 PTT
                          subscribePttChannel(getSharedChannelID(
                              currentUser.userId, user.userId));
                          Get.put(
                              MessageController(isGroup: false, user: user));
                          isGroupChat = false;
                        });
                        setState(() {
                          maxHeightBar = 0.41;
                        });
                      },
                      (String groupId) async {
                        GroupController groupController =
                            Get.find<GroupController>();
                        final group = groupController.groups
                            .firstWhere((g) => g.groupId == groupId);
                        Future.delayed(Duration(seconds: 1), () {
                          setState(() {
                            TargetUserID = group.groupId;
                            groupController.selectedGroup.value = group;
                            Get.put(MessageController(
                                isGroup: true,
                                user: ChatController.instance
                                    .getConnectedUser()));
                            maxHeightBar = 0.41;
                            isGroupChat = true;
                            ConnectedUserName = group.name;
                            connectedUserName.value = ConnectedUserName;
                            subscribePttChannel(group.groupId);
                          });
                        });
                      },
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'PTT Live Streaming is off. Enable it to start streaming from more settings.',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.only(top: 20, left: 16, right: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  }
                }
              } else {
                bool hasAccess =
                    await customBottomSection.currentState!.isSubscribed();
                if (!hasAccess) {
                  // ✅ Check daily limit / subscription inside handleLimitedButtonPress
                  print("Checking PTT button limit/subscription...");
                  final allowed = await mainScreenKey.currentState!
                      .handleLimitedButtonPress(
                          context: context, buttonId: 'PTT');

                  if (!allowed) {
                    await prefs.setBool("allowedAll", true);
                    print(
                        "Button press blocked: limit or subscription restriction");
                    return; // stop if limit or subscription not allowed
                  }
                }

                print("Button press allowed, starting timer and session");

                // Always show overlay and start animation for all non-self users
                _scaleController.forward();
                setState(() {
                  showOverlay?.value = true;
                  isMicPressed = false;
                });

                _startTimer();

                // Rest of your original PTT logic
                if (isGroupChat) {
                  final groupController = Get.find<GroupController>();
                  final group = groupController.groups
                      .where((g) => g.groupId == TargetUserID)
                      .firstOrNull;

                  if (group != null) {
                    final List<String> visibleUserIds =
                        mainScreenKey.currentState?.visibleUserIds ?? [];
                    final currentUserId =
                        AuthController.instance.currentUser!.userId;

                    final recipients = group.participants.where((member) {
                      if (member.userId == currentUserId) return false;
                      if (group.groupId ==
                          '1e8bf062-772f-42b3-9a09-7f0021f936db') {
                        return visibleUserIds.contains(member.userId) &&
                            member.userId != currentUserId;
                      }
                      return true;
                    }).toList();

                    for (final member in recipients) {
                      final user = await UserApi.getUser(member.userId);
                      if (user?.deviceToken != null) {
                        await PushNotificationService.sendNotification(
                          type: NotificationType.message,
                          title: group.name,
                          body: 'Group Msg',
                          deviceToken: member.deviceToken,
                          chatId: TargetUserID,
                        );
                      }
                    }
                  }
                }

                // ✅ FIX: Removed startSession() — it was calling AudioSession.configure(.voiceChat) which
                // undoes our playAndRecord+defaultToSpeaker fix and routes audio to earpiece silently.
                // ✅ FIX: joinGroup BEFORE startRecording so the first chunk targets the correct group.
                WebSocketPTTController().joinGroup(channelID);
                await WebSocketPTTController().startRecording();

                if (await Vibration.hasVibrator() ?? false) {
                  if (await Vibration.hasAmplitudeControl() ?? false) {
                    Vibration.vibrate(duration: 50, amplitude: 128);
                  } else {
                    Vibration.vibrate(duration: 50);
                  }
                }
              }
            },
            onPointerUp: (_) async {
              final prefs = await SharedPreferences.getInstance();
              allowedAll = prefs.getBool("allowedAll");

              // Always hide overlay when pointer is released
              setState(() {
                showOverlay?.value = false;
              });
              // Always reverse the scale animation
              _scaleController.reverse();
              bool hasAccess = await isSubscribed();

              if (!hasAccess) {
                // Check if we should block the action
                if (allowedAll == true) {
                  print(
                      "Button press blocked: limit or subscription restriction");
                  return; // Block only the action, not the UI reset
                }
              }
              // Only process PTT logic if it's not self
              if (TargetUserID != currentUser.userId) {
                if (WebSocketPTTController().isConnected) {
                  if (_seconds >= 2) {
                    await WebSocketPTTController().stopRecording();
                    await WebSocketPTTController().sendAudio();
                    // ✅ FIX: Removed switchToPlaybackMode() — it was reconfiguring AudioSession to .music()
                    // which has no defaultToSpeaker, routing incoming reply audio through the earpiece.

                    // Get.snackbar(
                    //   "Notification Sent!",
                    //   "PTT Sent Success!",
                    //   snackPosition: SnackPosition.TOP,
                    //   duration: Duration(seconds: 2),
                    //   backgroundColor: const Color.fromARGB(255, 41, 164, 246),
                    //   colorText: Colors.white,
                    // );

                    if (isGroupChat) {
                      final groupController = Get.find<GroupController>();
                      final group = groupController.groups
                          .where((g) => g.groupId == TargetUserID)
                          .firstOrNull;

                      if (group != null) {
                        final List<String> visibleUserIds =
                            mainScreenKey.currentState?.visibleUserIds ?? [];
                        final currentUserId =
                            AuthController.instance.currentUser!.userId;

                        final recipients = group.participants.where((member) {
                          if (member.userId == currentUserId) return false;
                          if (group.groupId ==
                              '1e8bf062-772f-42b3-9a09-7f0021f936db') {
                            return visibleUserIds.contains(member.userId) &&
                                member.userId != currentUserId;
                          }
                          return true;
                        }).toList();

                        for (final member in recipients) {
                          final user = await UserApi.getUser(member.userId);
                          if (user?.deviceToken != null) {
                            await PushNotificationService.sendNotification(
                              type: NotificationType.message,
                              title: group.name,
                              body: 'Group PTT Ends',
                              deviceToken: member.deviceToken,
                              chatId: TargetUserID,
                            );

                            Get.find<MessageController>().sendMessage(
                              MessageType.text,
                              text: "I just sent a Group PTT",
                              isRecAudio: false,
                            );
                          }
                        }
                      }
                    } else {
                      final User? Pttcaller =
                          await UserApi.getUser(TargetUserID);
                      print("Targetid : $TargetUserID");

                      Get.find<MessageController>().sendMessage(
                        MessageType.text,
                        text: "I just sent a PTT",
                        isRecAudio: false,
                      );
                    }

                    // ❌ DON'T switch back to own ID - causes group mismatch!
                    // WebSocketPTTPlayer().joinGroup(currentUser.userId);
                  } else {
                    // ✅ FIX: Ensure we stop recording even if they let go too early!
                    // Otherwise the microphone stays open forever broadcasting silence/noise!
                    await WebSocketPTTController().stopRecording();

                    Get.snackbar(
                      "PTT Error!",
                      "Try to hold on a bit longer!",
                      snackPosition: SnackPosition.TOP,
                      duration: Duration(seconds: 2),
                      backgroundColor: const Color.fromARGB(255, 224, 0, 0),
                      colorText: Colors.white,
                    );

                    // ❌ DON'T switch back to own ID - causes group mismatch!
                    // WebSocketPTTController().joinGroup(currentUser.userId);
                  }

                  _stopTimer();
                  _resetTimer();

                  setState(() {
                    isMicPressed = true;
                  });
                }
              }
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 🔵 Animated Rings (repeating animation)
                      //   if (showOverlay)
                      Visibility(
                        visible: showOverlay?.value ?? false,
                        child: ScaleTransition(
                          scale:
                              _ringScale, // _ringScale is an Animation<double> controlled by _scaleController
                          child: Image.asset(
                            'assets/maris/ptt_rings.png',
                            width: 140,
                            height: 145,
                          ),
                        ),
                      ),

                      // 🟢 Main PTT Button (centered, static or slightly zoomed)
                      ScaleTransition(
                        scale:
                            _scaleController, // can be static or one-time zoom
                        child: Container(
                          width: 115,
                          height: 115,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            'assets/maris/ptta.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Static image below (line or any asset)
                  Image.asset(
                    'assets/maris/b_line.png', // your 20x5 image
                    width: 80,
                    height: 5,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void showSavedTrackersDialog(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> trackers = prefs.getStringList('saved_trackers') ?? [];
    List<String> filteredTrackers = List.from(trackers);

    bool isSearching = false;
    TextEditingController searchController = TextEditingController();
    TextEditingController newTrackerController = TextEditingController();

    void filterTrackers(String query) {
      filteredTrackers = trackers
          .where((t) => t.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return GestureDetector(
            onTap: () {
              if (isSearching) {
                setState(() {
                  isSearching = false;
                  filteredTrackers = List.from(trackers);
                  searchController.clear();
                  FocusScope.of(context).unfocus();
                });
              }
            },
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  // Top Bar
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              isSearching = !isSearching;
                              if (!isSearching) {
                                filteredTrackers = List.from(trackers);
                                searchController.clear();
                                FocusScope.of(context).unfocus();
                              }
                            });
                          },
                          icon: Icon(
                            isSearching ? Icons.close : Icons.search,
                            color: Colors.white,
                          ),
                        ),
                        if (isSearching)
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              autofocus: true,
                              style: TextStyle(color: Colors.white),
                              cursorColor: Colors.white,
                              decoration: InputDecoration(
                                hintText: 'Search trackers',
                                hintStyle: TextStyle(color: Colors.grey[300]),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  filterTrackers(value);
                                });
                              },
                            ),
                          )
                        else
                          Expanded(
                            child: Text(
                              'Saved Tracker Numbers',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        IconButton(
                          onPressed: () async {
                            if (trackers.isEmpty) return;
                            bool confirm = await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Delete All Trackers?'),
                                content: Text(
                                    'Are you sure you want to delete all saved trackers?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text('Cancel')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text('Delete',
                                          style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              setState(() {
                                trackers.clear();
                                filteredTrackers.clear();
                                prefs.setStringList('saved_trackers', trackers);
                              });
                            }
                          },
                          icon: Icon(Icons.delete, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Add new tracker
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newTrackerController,
                            decoration: InputDecoration(
                              hintText: 'Enter new tracker number',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey)),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, color: Colors.blue),
                          onPressed: () async {
                            if (newTrackerController.text.trim().isEmpty)
                              return;
                            setState(() {
                              trackers.add(newTrackerController.text.trim());
                              filteredTrackers = List.from(trackers);
                            });
                            await prefs.setStringList(
                                'saved_trackers', trackers);
                            newTrackerController.clear();
                          },
                        ),
                      ],
                    ),
                  ),

                  // Tracker list + hint
                  Flexible(
                    child: filteredTrackers.isEmpty
                        ? Center(
                            child: Text(
                              'No trackers saved',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredTrackers.length + 1,
                            separatorBuilder: (context, index) =>
                                Divider(height: 1, color: Colors.grey[300]),
                            itemBuilder: (context, index) {
                              if (index == filteredTrackers.length) {
                                return ListTile(
                                  title: Center(
                                    child: Text(
                                      'Swipe left to delete',
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12),
                                    ),
                                  ),
                                  enabled: false,
                                );
                              }

                              final tracker = filteredTrackers[index];

                              return Dismissible(
                                key: Key(tracker),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child:
                                      Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (direction) async {
                                  setState(() {
                                    trackers.remove(tracker);
                                    filteredTrackers.removeAt(index);
                                    prefs.setStringList(
                                        'saved_trackers', trackers);
                                  });
                                },
                                child: ListTile(
                                  title: Text(
                                    tracker,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black),
                                  ),
                                  onTap: () async {
                                    mainScreenKey.currentState
                                        ?.clearOtherTrackerPrefs();
                                    await prefs.setString(
                                        'tracker_number', tracker);
                                    Future.delayed(Duration.zero, () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => TrackerInit()));
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void showTrackerInputDialog(BuildContext context) {
    TextEditingController trackerController = _trackerController;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Top header bar
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tracker Number',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/maris/tracker_reff.jpg',
                        width: 150,
                        height: 100,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Please refer to the image above and enter the tracker number.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: trackerController,
                        decoration: InputDecoration(
                          hintText: 'Enter Tracker Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          launchUrl(Uri.parse(
                              "https://www.marispeak.com/ordertracker"));
                        },
                        child: Text(
                          "Don't have a tracker? Purchase here",
                          style: TextStyle(
                            color: Colors.red,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            if (trackerController.text.trim().isEmpty) return;

                            mainScreenKey.currentState
                                ?.clearOtherTrackerPrefs();
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('tracker_number',
                                trackerController.text.trim());

                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => TrackerInit()),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Save',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButtonWithTextAndIcon({
    required String assetPath,
    required String label,
    String? iconPath,
    double height = 25,
    double borderRadius = 20.0,
    Color textColor = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(assetPath),
              fit: BoxFit.fill,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconPath != null) ...[
                Image.asset(iconPath, width: 16, height: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> isSubscribed() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.getBool('is_subscribed') ?? true;

    // real

    //    return prefs.getBool('is_subscribed') ?? false;
  }

  Widget _buildButtonWithText({
    required String assetPath,
    required String label,
    double width = 100,
    double txtwidth = 0,
    double height = 45,
    VoidCallback? onPressed,
    String? iconPath,
    Color imgColor = const Color.fromARGB(255, 250, 250, 250),
    Color bgColor = Colors.transparent,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              assetPath,
              width: width - 66,
              height: height,
              fit: BoxFit.contain,
            ),
            if (iconPath != null) ...[
              Image.asset(
                iconPath,
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ],
            SizedBox(width: txtwidth),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color.fromARGB(255, 18, 183, 236),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonWithTextColor({
    required String assetPath,
    required String label,
    double width = 100,
    double txtwidth = 0,
    double height = 50,
    VoidCallback? onPressed,
    String? iconPath,
    Color bgColor = Colors.transparent,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              assetPath,
              width: width - 66,
              height: height,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color.fromARGB(255, 22, 173, 243)
                  : null,
              colorBlendMode: BlendMode.srcIn,
              fit: BoxFit.contain,
            ),
            if (iconPath != null) ...[
              Image.asset(
                iconPath,
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ],
            SizedBox(width: txtwidth),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color.fromARGB(255, 18, 183, 236),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonOnlytext({
    required String label,
    required double width,
    required double height,
    required double txtwidth,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.blue, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildButton(String assetPath, String label,
      {required VoidCallback onPressed}) {
    return FloatingActionButton(
      heroTag: null,
      onPressed: onPressed,
      backgroundColor: const Color.fromARGB(0, 47, 172, 255),
      elevation: 0,
      highlightElevation: 0,
      child: SizedBox(
        width: 50,
        height: 48,
        child: Image.asset(
          assetPath,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color, // default color in light mode

          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void showChatSelectionModal(
    BuildContext context,
    Function(User) onUserSelected,
    Function(String groupId)? onGroupSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        // ✅ Move bottom sheet 200px up
        padding: const EdgeInsets.only(bottom: 1),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: "Chats"),
                    Tab(text: "Groups"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // ------------------ CHATS TAB ------------------
                      Obx(() {
                        final controller = Get.find<ChatController>();
                        final chats = controller.chats;

                        if (controller.isLoading.value) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (chats.isEmpty) {
                          return const Center(child: Text("No Chats"));
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: chats.length,
                          itemBuilder: (_, index) {
                            final chat = chats[index];

                            return ChatCard(
                              chat,
                              isForPTT: true,
                              onSelectUser: (user) async {
                                await saveLastChat(
                                  id: user.userId,
                                  name: user.username,
                                  isGroup: false,
                                );

                                onUserSelected(user);
                                Navigator.pop(context);
                              },
                              onDeleteChat: () => controller.deleteChat(
                                chat.receiver!.userId,
                              ),
                            );
                          },
                        );
                      }),
                      // ------------------ GROUPS TAB ------------------
                      Obx(() {
                        final groupController = Get.find<GroupController>();

                        if (groupController.isLoading.value) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (groupController.groups.isEmpty) {
                          return const Center(child: Text("No Groups"));
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: groupController.groups.length,
                          itemBuilder: (_, index) {
                            final group = groupController.groups[index];

                            return ListTile(
                              leading: group.photoUrl.isNotEmpty
                                  ? CircleAvatar(
                                      radius: 24,
                                      backgroundImage:
                                          NetworkImage(group.photoUrl),
                                    )
                                  : CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.blueGrey,
                                      child: Text(
                                        group.name.isNotEmpty
                                            ? group.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                              title: Text(group.name),

                              // ✅ FIXED COUNT (same as AppBar)
                              subtitle: Text(
                                '${group.isBroadcast ? group.recipients.length : group.participants.length} members',
                              ),

                              onTap: () async {
                                if (onGroupSelected != null) {
                                  await saveLastChat(
                                    id: group.groupId,
                                    name: group.name,
                                    isGroup: true,
                                  );

                                  onGroupSelected(group.groupId);
                                  setState(() {
                                    mainScreenKey.currentState
                                        ?.selectedGroupId = group.groupId;
                                  });
                                  print(
                                      "Selected Group Id: ${mainScreenKey.currentState?.selectedGroupId}");

                                  Navigator.pop(context);
                                }
                              },
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void reconnecttoChats() {
    // reconnectToLastChat(context);
  }

  Future<void> reconnectToLastChat(BuildContext context) async {
    final lastChat = await getLastChat();
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);

    if (lastChat == null) {
      return;
    }

    final id = lastChat['id'] as String;

    final name = lastChat['name'] as String;

    final isGroup = lastChat['isGroup'] as bool;

    if (!isGroup) {
      final user = ChatController.instance.chats
          .map((c) => c.receiver)
          .firstWhere((u) => u?.userId == id, orElse: () => null);

      if (user == null) {
        return;
      }

      ChatController.instance.setConnectedUser(user);

      if (Get.isRegistered<MessageController>()) {
        final current = Get.find<MessageController>();

        if (current.user?.userId != id || current.isGroup != false) {
          Get.delete<MessageController>();
        }
      }

      Get.put(MessageController(isGroup: false, user: user));

      setState(() {
        maxHeightBar = 0.41;
        TargetUserID = id;

        ConnectedUserName = user.username;
        connectedUserName.value = ConnectedUserName;

        // ✅ Use shared group ID for 1-to-1 PTT
        subscribePttChannel(getSharedChannelID(currentUser.userId, id));
      });
    } else {
      final groupController = Get.find<GroupController>();

      final group = groupController.groups.firstWhere(
        (g) => g.groupId == id,
        orElse: () => Group(groupId: id, name: name, members: []),
      );

      groupController.selectedGroup.value = group;

      if (Get.isRegistered<MessageController>()) {
        Get.delete<MessageController>();
      }

      Get.put(MessageController(
        isGroup: true,
        user: ChatController.instance.getConnectedUser(),
      ));

      setState(() {
        TargetUserID = id;
        ConnectedUserName = name;
        connectedUserName.value = ConnectedUserName;
        subscribePttChannel(id);
      });
    }
  }

  static const String _keyId = 'last_chat_id';

  static const String _keyName = 'last_chat_name';

  static const String _keyIsGroup = 'last_chat_is_group';

  static Future<void> saveLastChat({
    required String id,
    required String name,
    required bool isGroup,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyId, id);

    await prefs.setString(_keyName, name);

    await prefs.setBool(_keyIsGroup, isGroup);
  }

  static Future<Map<String, dynamic>?> getLastChat() async {
    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getString(_keyId);

    final name = prefs.getString(_keyName);

    final isGroup = prefs.getBool(_keyIsGroup);

    if (id != null && name != null && isGroup != null) {
      return {
        'id': id,
        'name': name,
        'isGroup': isGroup,
      };
    }

    return null;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_keyId);

    await prefs.remove(_keyName);

    await prefs.remove(_keyIsGroup);
  }

  void ExitChat() async {
    if (pttViewOpened) {
      Navigator.pop(context);
      pttViewOpened = false;
    }

    setState(() {
      maxHeightBar = 0.3;

      ConnectedUserName = "Disconnected";

      channelID = currentUser.userId;

      TargetUserID = channelID;

      print(TargetUserID);
      print("Channel ID: $channelID");

      mainScreenKey.currentState?.CloseBox = false;

      if (Get.isRegistered<MessageController>()) {
        Get.delete<MessageController>();

        print("Deleted Controller");
      } else {
        print("Not Found Controller");
      }
    });

    await clear();
  }
}
