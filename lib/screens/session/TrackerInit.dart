import 'dart:convert';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TrackerInit extends StatefulWidget {
  @override
  _TrackerInitState createState() => _TrackerInitState();
}

class _TrackerInitState extends State<TrackerInit> {
  String trackerNumber = "defaultValue"; // Example tracker number
  double latitude = 0.0;
  double longitude = 0.0;
  String regName = '';

  @override
  void initState() {
    super.initState();
    _getTrackerNumber();
    loginUser("Sophie", "123456");  // Example login
  }

  // Fetch tracker number from SharedPreferences
  _getTrackerNumber() async {
    final prefs = await SharedPreferences.getInstance();
    trackerNumber = prefs.getString("tracker_number") ?? "defaultValue";
    
    print("$trackerNumber");
  }

  // Login user
  Future<void> loginUser(String userCode, String password) async {
    const String url = "https://www.ezzloc.net/gpsapi";

    // 🔒 Hash password with MD5
    String _md5(String input) {
      return md5.convert(utf8.encode(input)).toString();
    }

    String md5Password = _md5(password);

    // 📦 Request payload
    Map<String, dynamic> body = {
      "Cmd": "Login",
      "token": "",
      "params": {
        "UserCode": userCode,
        "Password": md5Password, // ✅ lowercase 'w' confirmed
      },
      "language": 2, // English
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      print("🟢 Raw response: $data");

      if (data['result'] == 1) {
        final detail = data['detail'];
        if (detail['result'] == 1) {
          String token = detail['token'];
          print("✅ Login successful. Token: $token");

          // 🚀 Call next step
          getVehicleByDeviceNum(token, trackerNumber);
        } else {
          print("❌ Login failed inside detail. Result: ${detail['result']}");
        }
      } else {
        print("❌ API returned failure. Result: ${data['result']}, Note: ${data['resultNote']}");
      }

      // Debug info
      print("🔑 Raw Password: $password");
      print("🔒 MD5 Password: $md5Password");

    } catch (e) {
      print("❌ Exception during login: $e");
    }
  }

  // Method to make POST requests
  Future<Map<String, dynamic>?> _makePostRequest(String url, Map<String, dynamic> params) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(params),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Request failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error: $e"); 
      return null;
    }
  }
Future<void> getVehicleByDeviceNum(String token, String deviceNum) async {
  const String url = "https://www.ezzloc.net/gpsapi";

  // 📦 Request payload
  Map<String, dynamic> body = {
    "Cmd": "getVehicleByDeviceNum",
    "token": token,
    "language": 2, // English
    "params": {
      "DeviceNum": deviceNum, // Pass the device number
    },
  };

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);
    print("🟢 Raw response: $data");

    if (data['result'] == 1) {
      final detail = data['detail'];
      int vehicleID = detail['VehicleID'];
      String regName = detail['RegName'];
      String deviceNum = detail['DeviceNum'];

      print("✅ Vehicle found for DeviceNum $deviceNum:");
      print("VehicleID: $vehicleID");
      print("RegName: $regName");
      print("DeviceNum: $deviceNum");
      getVehiclePosition(token, vehicleID);
    } else {
      print("❌ API returned failure. Result: ${data['result']}, Note: ${data['resultNote']}");
    }
  } catch (e) {
    print("❌ Exception during getVehicleByDeviceNum: $e");
  }
}


Future<void> getVehiclePosition(String token, int vehicleID) async {
  String url = "https://www.ezzloc.net/gpsapi";

  Map<String, dynamic> params = {
    "cmd": "getVehiclesLocation",
    "token": token,
    "language": 2,
    "params": {
      "VehicleIDs": vehicleID.toString(),
      "LastTime": "0"
    }
  };

  var response = await _makePostRequest(url, params);
  if (response != null && response['result'] == 1) {
    List dataArray = response['detail']['data'];

    if (dataArray.isNotEmpty) {
      var data = dataArray.first;

      latitude = double.tryParse(data['Lat'].toString()) ?? 0.0;
      longitude = double.tryParse(data['Lon'].toString()) ?? 0.0;
      regName = data['RegName'] ?? "";

      print("✅ Real-time position:");
      print("VehicleID: ${data['VehicleID']}, RegName: $regName");
      print("Lat: $latitude, Lon: $longitude");

      // Save to SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString("Otherlatitudetrack", latitude.toString());
      prefs.setString("Otherlongitudetrack", longitude.toString());
      prefs.setString("DeviceName", regName);
     
      mainScreenKey.currentState?.updateState();
    
     

      // Navigate back or forward
      goBack();
    } else {
      print("❌ No real-time location found.");
    }
  } else {
    print("❌ Error: ${response?['resultNote'] ?? 'Unknown'}");
  }
}




  // Navigate to another screen
  void goBack() {
   mainScreenKey.currentState?.isLocationLoaded = false;
   Navigator.of(context).pop();
                // Close the dialog
                Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Tracker Init")),
      body: Center(child: Text("Initializing...")),
    );
  }
}
