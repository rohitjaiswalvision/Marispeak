import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

enum LoginProvider { email, google, apple }

class User {
  String userId;
  String fullname;
  String username;
  String photoUrl;
  String phone;
  String email;
  String bio;
  bool isOnline;
  DateTime? lastActive;
  String deviceToken;
  String status;
  LoginProvider loginProvider;
  bool isTyping;
  String typingTo;
  bool isRecording;
  String recordingTo;
  List<String> mutedGroups;
  DateTime? createdAt;
  double? lat; // Added latitude
  double? lon; // Added longitude

  User({
    this.userId = '',
    this.fullname = '',
    this.username = '',
    this.photoUrl = '',
    this.phone = '',
    this.email = '',
    this.bio = '',
    this.isOnline = false,
    this.lastActive,
    this.deviceToken = '',
    this.status = 'active',
    this.loginProvider = LoginProvider.email,
    this.isTyping = false,
    this.typingTo = '',
    this.isRecording = false,
    this.recordingTo = '',
    this.mutedGroups = const [],
    this.createdAt,
    this.lat, // Initialize latitude
    this.lon, // Initialize longitude
  });

  // Get User first name
  String get firstName => fullname.split(' ').first;

  @override
  String toString() {
    return 'User(userId: $userId, fullname: $fullname, username:$username,  photoUrl: $photoUrl, phone:$phone, bio: $bio, isOnline: $isOnline, lastActive: $lastActive, deviceToken: $deviceToken, isTyping: $isTyping, typingTo: $typingTo, lat: $lat, lon: $lon)';
  }

  factory User.fromMap(Map<String, dynamic> data) {
    return User(
      userId: data['userId'] ?? '',
      fullname: data['fullname'] ?? '',
      username: data['username'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      phone: data['phone']?.toString() ?? '',
      email: data['email'] ?? '',
      bio: data['bio'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastActive: DateTime.fromMillisecondsSinceEpoch(data['lastActive'] ?? 0),
      deviceToken: data['deviceToken'] ?? '',
      status: data['status'] ?? '',
      loginProvider: LoginProvider.values
              .firstWhereOrNull((el) => el.name == data['loginProvider']) ??
          LoginProvider.email,
      isTyping: data['isTyping'] ?? false,
      typingTo: data['typingTo'] ?? '',
      isRecording: data['isRecording'] ?? false,
      recordingTo: data['recordingTo'] ?? '',
      mutedGroups: List.from(data['mutedGroups'] ?? []),
      createdAt: data['createdAt']?.toDate(),
      lat: data['lat'] ?? 0.0, // Latitude from Firestore
      lon: data['lon'] ?? 0.0, // Longitude from Firestore
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullname': fullname,
      'username': username,
      'photoUrl': photoUrl,
      'phone': phone,
      'email': email,
      'bio': bio,
      'isOnline': isOnline,
      'lastActive': lastActive?.millisecondsSinceEpoch,
      'deviceToken': deviceToken,
      'status': status,
      'isTyping': isTyping,
      'typingTo': typingTo,
      'createdAt': FieldValue.serverTimestamp(),
      'lat': lat,  // Add latitude to map
      'lon': lon,  // Add longitude to map
    };
  }

  // Method to update lat and lon
 Future<void> updateLocation() async {
  if (userId == null || userId.trim().isEmpty) {
    print('❌ ERROR: userId is null or empty');
    return;
  }

  try {
    final docRef = FirebaseFirestore.instance.collection('Users').doc(userId);
    print('🔍 Checking document at: /Users/$userId');

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      print('📄 Document exists. Proceeding to update location...');
      await docRef.set({
        'lat': lat,
        'lon': lon,
      }, SetOptions(merge: true));
      print('✅ Location updated: $lat, $lon, $userId');
    } else {
      print('❌ Document does NOT exist at /Users/$userId');
    }
  } catch (e) {
    print('🔥 Firestore error: $e');
  }
}

}

