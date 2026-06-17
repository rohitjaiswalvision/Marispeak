import 'package:flutter_contacts/flutter_contacts.dart';

class PhoneContactHelper {
  static Future<List<Contact>> getPhoneContacts() async {
    if (!await FlutterContacts.requestPermission()) return [];

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    return contacts;
  }


  
}
