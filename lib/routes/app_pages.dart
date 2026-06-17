import 'package:marispeaks/models/group.dart';
import 'package:marispeaks/models/story/story.dart';
import 'package:marispeaks/screens/auth/Welcome.dart';
import 'package:marispeaks/screens/auth/signup/controllers/agreement.dart';
import 'package:marispeaks/screens/contacts/contact_search_screen.dart';
import 'package:marispeaks/screens/contacts/contacts_screen.dart';
import 'package:marispeaks/screens/contacts/select_contacts_screen.dart';
import 'package:marispeaks/screens/messages/message_screen.dart';
import 'package:marispeaks/tabs/groups/screens/create_group_screen.dart';
import 'package:marispeaks/tabs/groups/screens/edit_group_screen.dart';
import 'package:marispeaks/tabs/groups/screens/group_details_screen.dart';
import 'package:marispeaks/tabs/profile/edit_profile_screen.dart';
import 'package:marispeaks/tabs/profile/profile_view_screen.dart';
import 'package:marispeaks/tabs/stories/story_view_screen.dart';
import 'package:marispeaks/tabs/stories/write_story_screen.dart';
import 'package:get/get.dart';
import 'package:marispeaks/models/call.dart';
import 'package:marispeaks/screens/auth/password/binding/forgot_pwd_binding.dart';
import 'package:marispeaks/screens/auth/signin-or-signup/signin_or_signup_screen.dart';
import 'package:marispeaks/screens/auth/signup/verify_email_screen.dart';
import 'package:marispeaks/screens/blocked/blocked_account_screen.dart';
import 'package:marispeaks/screens/calling/incoming_call_screen.dart';
import 'package:marispeaks/screens/calling/video_call_screen.dart';
import 'package:marispeaks/screens/calling/voice_call_screen.dart';
import 'package:marispeaks/screens/home/binding/home_binding.dart';
import 'package:marispeaks/screens/auth/signin/binding/signin_binding.dart';
import 'package:marispeaks/screens/auth/signup/bindings/signup_binding.dart';
import 'package:marispeaks/screens/auth/signup/bindings/signup_with_email_binding.dart';
import 'package:marispeaks/screens/about/about_screen.dart';
import 'package:marispeaks/screens/auth/password/forgot_password_screen.dart';
import 'package:marispeaks/screens/auth/signup/signup_with_email_screen.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/screens/home/home_screen.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:marispeaks/screens/record-video/record_video_screen.dart';
import 'package:marispeaks/screens/session/session_screen.dart';
import 'package:marispeaks/screens/auth/signin/signin_screen.dart';
import 'package:marispeaks/screens/auth/signup/signup_screen.dart';
import 'package:marispeaks/screens/splash/splash_screen.dart';
import 'package:marispeaks/screens/auth/signin/pushtalkintro.dart';

import 'app_routes.dart';

abstract class AppPages {
  //
  // <-- Pages list -->
  //
  static final pages = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
    ),
    GetPage(
      name: AppRoutes.signInOrSignUp,
      page: () => const SigninOrSignupScreen(),
    ),
    GetPage(
      name: AppRoutes.signIn,
      binding: SignInBinding(),
      page: () => PhoneSignInScreen(),
    ),
    
    GetPage(
      name: AppRoutes.welCome,
     // binding: SignInBinding(),
      page: () => Welcome(),
    ),
   
    GetPage(
      name: AppRoutes.pushTalk,
     // binding: SignInBinding(),
      page: () => Pushtalkintro(),
    ),


    GetPage(
      name: AppRoutes.signUp,
      binding: SignUpBinding(),
      page: () => const SignUpScreen(),
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      binding: ForgotPasswordBinding(),
      page: () => const ForgotPasswordScreen(),
    ),
    GetPage(
      name: AppRoutes.signUpWithEmail,
      binding: SignUpWithEmailBinding(),
      page: () => const SignUpWithEmailScreen(),
    ),
    GetPage(
      name: AppRoutes.verifyEmail,
      page: () => const VerifyEmailScreen(),
    ),
     GetPage(
      name: AppRoutes.agreement,
      page: () => const AgreementPage(),
    ),
    GetPage(
      name: AppRoutes.home,
      binding: HomeBinding(),
      page: () => const HomeScreen(),
    ),
    GetPage(
      name: AppRoutes.mapHome,
      page: () => MainScreenUI(),
    ),
    //YearlyPg
    GetPage(
      name: AppRoutes.recordVideo,
      page: () => const RecordVideoScreen(),
    ),
    GetPage(
      name: AppRoutes.messages,
      page: () {
        final args = Get.arguments;
        final bool isGroup = args['isGroup'];
        final User? user = args?['user'];
        final String? groupId = args['groupId'];

        return MessageScreen(
          isGroup: isGroup,
          user: user,
          groupId: groupId,
        );
      },
    ),
    GetPage(
      name: AppRoutes.videoCall,
      page: () {
        final args = Get.arguments;
        final Call call = args['call'];
        return VideoCallScreen(call: call);
      },
    ),
    GetPage(
      name: AppRoutes.voiceCall,
      page: () {
        final args = Get.arguments;
        final Call call = args['call'];
        return VoiceCallScreen(call: call);
      },
    ),
    GetPage(
      name: AppRoutes.incomingCall,
      page: () {
        final args = Get.arguments;
        final Call call = args['call'];
        return IncommingCallScreen(call: call);
      },
    ),
    GetPage(
      name: AppRoutes.session,
      page: () => const SesssionScreen(),
    ),
    GetPage(
      name: AppRoutes.about,
      page: () => const AboutScreen(),
    ),
    GetPage(
      name: AppRoutes.blockedAccount,
      page: () => const BlockedAccountScreen(),
    ),
    GetPage(
      name: AppRoutes.contacts,
      page: () => const ContactsScreen(),
    ),
    GetPage(
      name: AppRoutes.contactSearch,
      page: () => const ContactSearchScreen(),
    ),
    GetPage(
      name: AppRoutes.createGroup,
      page: () {
        final args = Get.arguments;
        final bool isBroadcast = args['isBroadcast'];
        return CreateGroupScreen(isBroadcast: isBroadcast);
      },
    ),
    GetPage(
      name: AppRoutes.groupDetails,
      page: () => const GroupDetailsScreen(),
    ),
    GetPage(
      name: AppRoutes.editGroup,
      page: () {
        final args = Get.arguments;
        final Group group = args['group'];
        return EditGroupScreen(group: group);
      },
    ),
    GetPage(
      name: AppRoutes.editProfile,
      page: () => const EditProfileScreen(),
    ),
    GetPage(
      name: AppRoutes.profileView,
      page: () {
        final args = Get.arguments;
        final User user = args['user'];
        final bool isGroup = args['isGroup'];
        return ProfileViewScreen(user: user, isGroup: isGroup);
      },
    ),
    GetPage(
      name: AppRoutes.selectContacts,
      page: () {
        final args = Get.arguments;
        final String title = args['title'];
        final bool showGroups = args?['showGroups'] ?? false;
        return SelectContactsScreen(title: title, showGroups: showGroups);
      },
    ),
    GetPage(
      name: AppRoutes.writeStory,
      page: () => const WriteStoryScreen(),
    ),
    GetPage(
      name: AppRoutes.storyView,
      page: () {
        final args = Get.arguments;
        final Story story = args['story'];
        return StoryViewScreen(story: story);
      },
    ),
  ];
}
