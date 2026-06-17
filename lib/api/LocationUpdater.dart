import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationUpdater {
  Timer? _timer;

  void startLocationUpdates() {
    _timer = Timer.periodic(Duration(minutes: 1), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final showMe = prefs.getBool('showMyLocation') ?? false;

        String userId = FirebaseAuth.instance.currentUser!.uid;

if (showMe) {
  final lat = mainScreenKey.currentState?.currentLocation.latitude;
  final lon = mainScreenKey.currentState?.currentLocation.longitude;

  print("📍 Current location: lat=$lat, lon=$lon");

  await FirebaseFirestore.instance
      .collection('Users')
      .doc(userId)
      .update({
    'lat': lat,
    'lon': lon,
  });

  print("✅ Location updated for $userId");
} else {
  print("❌ Location hidden for $userId");
  await FirebaseFirestore.instance
      .collection('Users')
      .doc(userId)
      .update({
    'lat': null,
    'lon': null,
  });
}
      } catch (e) {
        print("⚠️ Error updating location: $e");
      }
    });
  }

  void stopLocationUpdates() {
    _timer?.cancel();
  }
}
