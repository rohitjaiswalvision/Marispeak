import 'dart:io';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/models/user.dart';
import 'package:get/get.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

abstract class ContactApi {
  static final _firestore = FirebaseFirestore.instance;

  // Add contact between current user and another user
  static Future<void> addContact({
    required String userId,
    bool showMsg = false,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser!;

      await Future.wait([
        _firestore
            .collection('Users/${currentUser.userId}/Contacts')
            .doc(userId)
            .set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        }),
        _firestore
            .collection('Users/$userId/Contacts')
            .doc(currentUser.userId)
            .set({
          'userId': currentUser.userId,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      ]);

      if (showMsg) {
        DialogHelper.showSnackbarMessage(SnackMsgType.success, "add_contact_success".tr);
      }
    } catch (e) {
      if (showMsg) {
        DialogHelper.showSnackbarMessage(
          SnackMsgType.error,
          "add_contact_error".trParams({'error': e.toString()}),
        );
      }
    }
  }

  // Search by username
  static Future<User?> searchContact(String username) async {
    try {
      final query = await _firestore
          .collection('Users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return User.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
      return null;
    }
  }
  
static Future<User?> searchContactByPhone(String phone) async {
  try {
    // Optional: Clean up input, like trimming spaces
    final phoneTrimmed = phone.trim();

    print('[DEBUG] Searching for phone: $phoneTrimmed');

    final query = await _firestore
        .collection('Users')
        .where('phone', isEqualTo: phoneTrimmed)
        .limit(1)
        .get();

    print('[DEBUG] Firestore query result: ${query.docs.length}');

    if (query.docs.isNotEmpty) {
      return User.fromMap(query.docs.first.data());
    }
    return null;
  } catch (e) {
    DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
    return null;
  }
}



static Future<void> addContactByPhoneNumber({
  required String phoneNumber,
  bool showMsg = false,
}) async {
  try {
    final User currentUser = AuthController.instance.currentUser!;

    // Directly use the phone number without normalization
    final user = await searchContactByPhone(phoneNumber);

    if (user == null) {
      if (showMsg) {
        DialogHelper.showSnackbarMessage(SnackMsgType.error,
            "No User Found!".trParams({'phone': phoneNumber}));
      }
      return;
    }

    await addContact(userId: user.userId, showMsg: showMsg);
  } catch (e) {
    if (showMsg) {
      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, "add_contact_error".trParams({'error': e.toString()}));
    }
  }
}


  static Stream<List<User>> getContacts() async* {
  final currentUser = AuthController.instance.currentUser!;

  // Debug: Log current user ID
  print("[DEBUG] Current user ID: ${currentUser.userId}");

  // Loop until user grants permission or exits manually
  while (true) {
    final permission = await Permission.contacts.status;
    if (permission.isGranted) break;

    final result = await Permission.contacts.request();

    if (result.isGranted) {
      break; // continue to load contacts
    } else if (result.isPermanentlyDenied) {
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        "contact_permission_permanently_denied".tr,
      );
      await openAppSettings(); // optional: open app settings
      yield [];
      return;
    } else {
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        "contact_permission_denied".tr,
      );
      await Future.delayed(const Duration(seconds: 2));
      // Ask again
    }
  }

  // Get contacts from device
  final contactsFromDevice = await FlutterContacts.getContacts(withProperties: true);

  // Debug: Log the number of contacts fetched from the device
  print("[DEBUG] Contacts fetched from device: ${contactsFromDevice.length}");

  final phoneNumbers = <String>{};

  // Normalize phone numbers
  for (var contact in contactsFromDevice) {
    for (var phone in contact.phones) {
      final cleaned = _normalizePhone(phone.number);
      if (cleaned.isNotEmpty) {
        phoneNumbers.add(cleaned);
      }
    }
  }

  // Debug: Log the phone numbers to be searched
  print("[DEBUG] Phone numbers to search: $phoneNumbers");

  if (phoneNumbers.isEmpty) {
    yield [];
    return;
  }

  // Fetch users from Firebase based on phone numbers
  final matchedUsers = await getUsersByPhoneList(phoneNumbers.toList());

  // Debug: Log the number of users matched from Firebase
  print("[DEBUG] Users matched from Firebase: ${matchedUsers.length}");

  // Return the list of matched users (excluding the current user)
  yield matchedUsers.where((u) => u.userId != currentUser.userId).toList();
  }
  //// Normalize Phone book
  static String _normalizePhone(String number) {
  number = number.replaceAll(RegExp(r'[^\d+]'), '');
  if (number.startsWith('+')) return number;

  // 🌍 Priority countries first (avoid prefix confusion)
  // 🇵🇰 Pakistan
  if (number.length == 11 && number.startsWith('03')) {
    return '+92${number.substring(1)}';
  }

  // 🇺🇸 / 🇨🇦 United States & Canada
  if (number.length == 10 && RegExp(r'^[2-9]\d{9}$').hasMatch(number)) {
    return '+1$number';
  }

  // 🇦🇺 Australia (mobiles start with 04)
  if (number.startsWith('04') && number.length == 10) {
  return '+61${number.substring(1)}'; // remove leading 0
  }

  // 🇳🇿 New Zealand
  if (number.length == 9 && number.startsWith('0')) {
    return '+64${number.substring(1)}';
  }

  // 🇨🇳 China
  if (number.length == 11 && number.startsWith('1')) {
    return '+86$number';
  }

  // 🇯🇵 Japan
  if (number.startsWith('070') ||
      number.startsWith('080') ||
      number.startsWith('090')) {
    return '+81${number.substring(1)}';
  }

  // 🇭🇰 Hong Kong
  if (number.length == 8 && RegExp(r'^[5,6,9]').hasMatch(number)) {
    return '+852$number';
  }

  // 🇸🇬 Singapore
  if (number.length == 8 && RegExp(r'^[8,9]').hasMatch(number)) {
    return '+65$number';
  }

  // 🇲🇾 Malaysia
  if (number.startsWith('01') && number.length >= 9 && number.length <= 11) {
    return '+60${number.substring(1)}';
  }

  // 🇮🇩 Indonesia
  if (number.startsWith('08') && number.length >= 9) {
    return '+62${number.substring(1)}';
  }

  // 🇵🇭 Philippines
  if (number.startsWith('09') && number.length == 11) {
    return '+63${number.substring(1)}';
  }

  // 🇹🇭 Thailand
  if (number.startsWith('0') && number.length == 10) {
    return '+66${number.substring(1)}';
  }

  // 🇻🇳 Vietnam
  if (number.startsWith('0') && number.length == 10) {
    return '+84${number.substring(1)}';
  }

  // 🇱🇰 Sri Lanka
  if (number.startsWith('07') && number.length == 10) {
    return '+94${number.substring(1)}';
  }

  // 🇧🇩 Bangladesh
  if (number.startsWith('01') && number.length == 11) {
    return '+880${number.substring(1)}';
  }

  // 🇮🇳 India
  if (number.startsWith('9') ||
      number.startsWith('8') ||
      number.startsWith('7')) {
    return '+91$number';
  }

  // 🇳🇵 Nepal
  if (number.startsWith('98') && number.length == 10) {
    return '+977${number.substring(1)}';
  }

  // 🌍 Middle East / Africa coastal
  // 🇸🇦 Saudi Arabia
  if (number.startsWith('05') && number.length == 10) {
    return '+966${number.substring(1)}';
  }

  // 🇴🇲 Oman
  if (number.startsWith('9') && number.length == 8) {
    return '+968$number';
  }

  // 🇪🇬 Egypt
  if (number.startsWith('01') && number.length == 11) {
    return '+20${number.substring(1)}';
  }

  // 🇿🇦 South Africa
  if (number.startsWith('0') && number.length == 10) {
    return '+27${number.substring(1)}';
  }

  // 🇰🇪 Kenya
  if (number.startsWith('07') && number.length == 10) {
    return '+254${number.substring(1)}';
  }

  // 🇹🇿 Tanzania
  if (number.startsWith('0') && number.length == 10) {
    return '+255${number.substring(1)}';
  }

  // 🇲🇿 Mozambique
  if (number.startsWith('8') && number.length == 9) {
    return '+258$number';
  }

  // 🇧🇷 Brazil
  if (number.length == 11 && number.startsWith('9')) {
    return '+55$number';
  }

  // 🇨🇱 Chile
  if (number.startsWith('9') && number.length == 9) {
    return '+56$number';
  }

  // 🇦🇷 Argentina
  if (number.startsWith('15') && number.length == 10) {
    return '+54${number.substring(2)}';
  }

  // 🇲🇽 Mexico
  if (number.length == 10 && RegExp(r'^[1-9]').hasMatch(number)) {
    return '+52$number';
  }

  // 🇨🇴 Colombia
  if (number.length == 10 && number.startsWith('3')) {
    return '+57$number';
  }

  // 🇵🇪 Peru
  if (number.length == 9 && number.startsWith('9')) {
    return '+51$number';
  }

  // 🇻🇪 Venezuela
  if (number.length == 10 && number.startsWith('04')) {
    return '+58${number.substring(1)}';
  }

  // 🇨🇷 Costa Rica
  if (number.length == 8 && number.startsWith('8')) {
    return '+506$number';
  }

  // 🇵🇦 Panama
  if (number.length == 8 && RegExp(r'^[6-8]').hasMatch(number)) {
    return '+507$number';
  }

  // 🇬🇹 Guatemala
  if (number.length == 8 && number.startsWith('5')) {
    return '+502$number';
  }

  // 🇩🇴 Dominican Republic
  if (number.length == 10 && RegExp(r'^[8]').hasMatch(number)) {
    return '+1$number';
  }

  // 🇧🇸 Bahamas
  if (number.length == 7) {
    return '+1242$number';
  }

  // 🇧🇧 Barbados
  if (number.length == 7) {
    return '+1246$number';
  }

  // 🇫🇯 Fiji
  if (number.length == 7) {
    return '+679$number';
  }

  // 🇵🇬 Papua New Guinea
  if (number.length == 8) {
    return '+675$number';
  }

  // 🇹🇴 Tonga
  if (number.length == 5) {
    return '+676$number';
  }

  // 🇻🇺 Vanuatu
  if (number.length == 7) {
    return '+678$number';
  }

  // 🇸🇧 Solomon Islands
  if (number.length == 7) {
    return '+677$number';
  }

  // 🇹🇻 Tuvalu
  if (number.length == 5) {
    return '+688$number';
  }

  // 🇲🇭 Marshall Islands
  if (number.length == 7) {
    return '+692$number';
  }

  // 🇰🇮 Kiribati
  if (number.length == 5) {
    return '+686$number';
  }

  // Default fallback — keep number safe
  print('+1$number');
  return '+1$number';

}



  // Delete contact
  static Future<void> deleteContact(String userId) async {
    try {
      final User currentUser = AuthController.instance.currentUser!;

      await _firestore
          .collection('Users/${currentUser.userId}/Contacts')
          .doc(userId)
          .delete();

      DialogHelper.showSnackbarMessage(SnackMsgType.success, "delete_contact_success".tr);
    } catch (e) {
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        "delete_contact_error".trParams({'error': e.toString()}),
      );
    }
  }

  // Fetch Firebase users by phone list (handles 10-item Firestore limits)
  static Future<List<User>> getUsersByPhoneList(List<String> phoneNumbers) async {
    final List<User> result = [];
    final chunks = <List<String>>[];

    for (var i = 0; i < phoneNumbers.length; i += 10) {
      chunks.add(phoneNumbers.sublist(
        i,
        i + 10 > phoneNumbers.length ? phoneNumbers.length : i + 10,
      ));
    }

    for (final chunk in chunks) {
      final query = await _firestore
          .collection('Users')
          .where('phone', whereIn: chunk)
          .get();

      result.addAll(query.docs.map((e) => User.fromMap(e.data())));
    }

    return result;
  }
}
 