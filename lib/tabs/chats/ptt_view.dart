import 'package:marispeaks/api/group_api.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/config/app_config.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/models/group.dart';
import 'package:marispeaks/screens/ptt/websocket_ptt_controller.dart';
import 'package:marispeaks/services/push_notification_service.dart';
import 'package:marispeaks/tabs/chats/controllers/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/models/user.dart';
import 'package:get/get.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:marispeaks/models/location.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:marispeaks/screens/messages/controllers/message_controller.dart';
import 'package:marispeaks/screens/messages/message_screen.dart';
import 'package:marispeaks/models/message.dart';
import 'package:marispeaks/tabs/groups/controllers/group_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

class PttView extends StatefulWidget {
  @override
  _PttViewState createState() => _PttViewState();

}
class _PttViewState extends State<PttView> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final TextEditingController _control = TextEditingController();
  late final User? connectedUser;
  String ConnectedUserName = "None";
  String? channelID = customBottomSection.currentState?.TargetUserID;  
  String username = "";
  String ProfilePicUrl = "";
  String userId= "";
  bool isKeyboardVisible = false;
  bool isOnline = true;
  bool isTalking = false;
  bool? isGroupChat;
  bool allowedAll = false;
  final User currentUser = AuthController.instance.currentUser!;
@override
void initState() {
  super.initState();

  final GroupController groupController = Get.find<GroupController>();
  final ChatController chatController = ChatController.instance;

  connectedUser = chatController.getConnectedUser();
  username = connectedUser?.username ?? 'No user connected';
  userId = connectedUser?.userId ?? '0';

  if (groupController.selectedGroup.value != null) {
    isGroupChat = true;
    // It's a group chat
    final Group group = groupController.selectedGroup.value!;
    channelID = group.groupId;
    ConnectedUserName = group.name;

    // Initialize MessageController for group chat
    Get.put(MessageController(isGroup: true, user: connectedUser));

    print("Using group from GroupController: $ConnectedUserName");
  } else {
    isGroupChat = false;
    // It's a single user chat
    channelID = userId;
    ConnectedUserName = username;

    // Initialize MessageController for single user chat
    Get.put(MessageController(isGroup: false, user: connectedUser));

    print("Using single user from ChatController: $ConnectedUserName");
  }

  print("Channel ID: $channelID");
  print("ConnectedUserName: $ConnectedUserName");

  _animationController = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 450)
  );

  _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
    CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ),
  );
    // Use a post-frame callback to delay the keyboard visibility check until after the build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
     _checkKeyboardVisibility();
    });
}


    Future<bool> _isSubscribed() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  //return prefs.getBool('is_subscribed') ?? true;
  // Real
   return prefs.getBool('is_subscribed') ?? false;
}


  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkKeyboardVisibility() {
    setState(() {
      isKeyboardVisible = false;
      print(isKeyboardVisible);
    });
  }

  @override
Widget build(BuildContext context) {
  double screenHeight = MediaQuery.of(context).size.height;
  double screenWidth = MediaQuery.of(context).size.width;
  final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

  return Scaffold(
    body: Stack(
      children: [
        // Add your map or other main content here
        // Example:
        // FlutterMap(...),
        // Connected User info display
      Positioned(
  top: screenHeight * 0.08,
  right: 30,
  child: Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
    ),
    clipBehavior: Clip.hardEdge,
    child: connectedUser?.photoUrl != null
        ? Image.network(
            connectedUser!.photoUrl,
            fit: BoxFit.cover, 
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/maris/invite.png',
                fit: BoxFit.cover,
              );
            },
          )
        : Image.asset(
            'assets/maris/invite.png',
            fit: BoxFit.cover,
          ),
  ),
),

        Positioned(
          top: screenHeight * 0.08,
          left: 20,
          child: Text(
            ConnectedUserName,
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),

        Positioned(
          top: screenHeight * 0.14,
          right: 20,
          child: Container(
      width: 130,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        "assets/maris/online_btn.png",  // Using the image path for the button
      //  fit: BoxFit.contain,
      ),
    ),
        ),
            // Input Field and Send Button
        Positioned(
          top: 160, // Adjust this value based on your layout
          left: 20,
          right: 20,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/maris/placehodler_back.png'), // Custom image for background
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _control,
                    decoration: InputDecoration(
                      hintText: 'Enter your message...',
                      hintStyle: TextStyle(color: const Color.fromARGB(255, 98, 98, 98)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                 Get.find<MessageController>().sendMessage(
              MessageType.text,  // Specify the message type as text
              text: _control.text,  // The message content
              isRecAudio: false,  // Set this as needed (assuming it's not a received audio)
            );

        if (isGroupChat == true) {
            Get.to(() => MessageScreen(
              user: connectedUser,
              groupId: channelID,
              isGroup: true,
            ));
          } else {
            Get.to(() => MessageScreen(
              user: connectedUser,
              isGroup: false,
            ));
          }

                },
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/maris/send.png'), // Custom send button background
                      fit: BoxFit.cover,
                    ),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(15),
                  child: Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
     // Positioned Row with Text Buttons
        Positioned(
          top: 230,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                 onTap: () {
            if (channelID == AppConfig.HelpGroupID) {
              _setText("Flat Battery");
            } else {
              _setText("Hello");
            }
          },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    channelID == AppConfig.HelpGroupID ? "Flat Battery" : "Hello",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              GestureDetector(
                    onTap: () {
            if (channelID == AppConfig.HelpGroupID) {
              _setText("Fuel Needed");
            } else {
              _setText("How are you?");
            }
          },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    channelID == AppConfig.HelpGroupID ? "Fuel Needed" : "How are you?",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              GestureDetector(
                         onTap: () {
            if (channelID == AppConfig.HelpGroupID) {
              _setText("Tow Needed");
            } else {
              _setText("Call me");
            }
          },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    channelID == AppConfig.HelpGroupID ? "Tow Needed" : "Call me",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              GestureDetector(
                                onTap: () {
            if (channelID == AppConfig.HelpGroupID) {
              _setText("Other Help");
            } else {
              _setText("Bye");
            }
          },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    channelID == AppConfig.HelpGroupID ? "Other Help" : "Bye",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        // PTT Button Positioned at Bottom Center
        Positioned(
          top: 290,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTapDown: (_) async {           
          bool hasAccess = await _isSubscribed(); // or await hasFullAccess() if using that
           print(hasAccess);
                    if (!hasAccess){
    // ✅ Check daily limit / subscription inside handleLimitedButtonPress
    print("Checking PTT button limit/subscription...");
    final allowed = await mainScreenKey.currentState!
        .handleLimitedButtonPress(context: context, buttonId: 'PTT');

    if (!allowed) {
      setState(() {
      allowedAll = allowed;
      });
      print("Button press blocked: limit or subscription restriction");
      return; // stop if limit or subscription not allowed
    }
       }

                // final User? Pttcaller = await UserApi.getUser(channelID!);
                //         await PushNotificationService.sendNotification(
                //           type: NotificationType.message,
                //           title: Pttcaller!.fullname,
                //           body: 'Incoming PTT', // message body
                //           deviceToken: Pttcaller.deviceToken,
                //         );

     //   await AgoraController().LeaveChannel();
      _animationController.forward(); // Animate when receiver is selected
      // ✅ FIX: joinGroup BEFORE startRecording so the first chunk goes to the right group.
      // Previously joinGroup was called AFTER, causing first press to send to wrong group (self).
      WebSocketPTTController().joinGroup(channelID!);
      await WebSocketPTTController().startRecording();
      
            if (await Vibration.hasVibrator() ?? false) {
              if (await Vibration.hasAmplitudeControl() ?? false) {
                Vibration.vibrate(duration: 50, amplitude: 128); // iOS + Android
              } else {
                Vibration.vibrate(duration: 50); // fallback
              }
            }
          },
            onTapUp: (_) async {
                                          if (!allowedAll) {
                              print("Button press blocked: limit or subscription restriction");
                              return; // stop if limit or subscription not allowed
                            }
                  await WebSocketPTTController().stopRecording();
                  await WebSocketPTTController().sendAudio();
  _animationController.reverse(); // Only reverse if it was animated
  // ✅ FIX: Removed joinGroup(currentUser.userId) here — switching the group back to self
  // was causing the receiver to miss audio chunks still in-flight.
       
        
        //    final User? Pttcaller = await UserApi.getUser(channelID!);
        // await PushNotificationService.sendNotification(
        //               type: NotificationType.message,
        //               title: Pttcaller!.fullname,
        //               body: 'Completed PTT',
        //               deviceToken: Pttcaller.deviceToken,
        //               data: {
        //                 'action': 'disable',
        //               },
        //             );
               // Send a text message using MessageController
  // Send a text message using MessageController
            Get.find<MessageController>().sendMessage(
              MessageType.text,  // Specify the message type as text
              text: "You just sent a PTT",  // The message content
              isRecAudio: false,  // Set this as needed (assuming it's not a received audio)
            );
              Get.snackbar(
                        "Notification Sent!",  // Title
                        "Message Sent Success!",  // Message
                        snackPosition: SnackPosition.TOP,  // Position at the bottom
                        duration: Duration(seconds: 1),  // Duration to show the snackbar
                        backgroundColor: const Color.fromARGB(255, 41, 164, 246),  // Background color of the snackbar
                        colorText: Colors.white,  // Text color
                      );
            },

            onTapCancel: () async {
      _animationController.reverse();
      
                  await WebSocketPTTController().stopRecording();
                  await WebSocketPTTController().sendAudio();
      // ✅ FIX: Removed joinGroup(currentUser.userId) on cancel — same race condition fix
      //  print(currentUser.userId);
            },
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 300,
                  height: 295,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/maris/static_pttviewbtn.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),

if (!isKeyboardVisible) ...[
        // Buttons at the Bottom (Two rows)
        Positioned(
          bottom: 120, // Adjust this value based on your UI layout
          left: 0,
          right: 0,
          child: Column(
            children: [
              // First row of buttons
             Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildButton(imagePath: 'assets/maris/voice.png',onTap: () {
                        print('attach_location button pressed');
                      },
                       ),
                  SizedBox(width: 10), // Space between buttons
                  _buildButton(imagePath: 'assets/maris/reply_audio2.png', onTap: () {
                        print('attach_location button pressed');
                      },
                      ),
                ],
              ),
              SizedBox(height: 10),
              // Second row of buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [                  
                  SizedBox(width: 10), // Space between buttons
                  _buildButton(
                      imagePath: 'assets/maris/attach_location.png',
                      onTap: () {
                       double? lon = mainScreenKey.currentState?.currentLocation.latitude;
                       double? lat = mainScreenKey.currentState?.currentLocation.longitude;
                     Get.find<MessageController>().sendLocationExternally(Location(latitude: lon! , longitude: lat!));                 
                        // Show Snackbar with success message
                      Get.snackbar(
                        "Location Shared",  // Title
                        "Your location has been shared successfully.",  // Message
                        snackPosition: SnackPosition.BOTTOM,  // Position at the bottom
                        duration: Duration(seconds: 2),  // Duration to show the snackbar
                        backgroundColor: const Color.fromARGB(255, 41, 164, 246),  // Background color of the snackbar
                        colorText: Colors.white,  // Text color
                      );
                      },
                    ),

                  SizedBox(width: 10), // Space between buttons
                  _buildButton(
                  imagePath: 'assets/maris/exit_pttview.png',
                  onTap: () {
                    Get.back();
                    ExitChat();
                  },
                ),
                ],
              ),
            ],
          ),
        ),

    Positioned(
  bottom: screenHeight * 0.08,
  right: 0,
  left: 0,
  child: GestureDetector(
    onTap: () {
      setStatus(!isOnline); // Toggle status on click
    },
    child: Container(
      width: 130,
      height: 30,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        isOnline
            ? "assets/maris/online_btn.png"
            : "assets/maris/status_busy.png",
        fit: BoxFit.contain,
      ),
    ),
  ),
),
],
],
),
);
}


void setStatus(bool online) {
  setState(() {
    isOnline = online;
  });
  if (isOnline) {

        UserApi.updateUserPresence(true);
 } else {
    print("Status set to busy");
        UserApi.updateUserPresence(false);
 }
}Widget _buildButton({
  required String imagePath,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 150,
      height: 40,
      child: Image.asset(
        imagePath,
        fit: BoxFit.contain,
      ),
    ),
  );
}

  void _setText(String text) {
    setState(() {
      _control.text = text;
    });
  }

void ExitChat(){
  customBottomSection.currentState?.ExitChat();
}

}

