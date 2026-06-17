import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:marispeaks/config/app_config.dart';

class PTTScreen extends StatefulWidget {
  const PTTScreen({super.key});

  @override
  _PTTScreenState createState() => _PTTScreenState();
}

class _PTTScreenState extends State<PTTScreen> {
  final String appId = AppConfig.agoraAppID; // Replace with your Agora App ID
  RtcEngine? _engine;
  final TextEditingController channelController = TextEditingController();
  final TextEditingController userController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getPermissions();
    _initAgora();
  }

  Future<void> _getPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.speech,
      Permission.location,
      Permission.contacts,
    ].request();

    statuses.forEach((permission, status) {
      final name = permission.toString().split('.').last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "$name permission ${status.isGranted ? "granted" : "denied"}.",
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    });

    if (statuses[Permission.microphone]?.isDenied ?? false) {
      debugPrint("Microphone permission denied.");
    }
    if (statuses[Permission.location]?.isDenied ?? false) {
      debugPrint("Location permission denied.");
    }
    if (statuses[Permission.contacts]?.isDenied ?? false) {
      debugPrint("Contacts permission denied.");
    }
  }

  Future<void> _initAgora() async {
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: appId));
      await _engine!.enableAudio();
      await _engine!.setChannelProfile(ChannelProfileType.channelProfileCommunication);
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onError: (ErrorCodeType err, String msg) =>
              debugPrint("Agora Error: $err, $msg"),
          onJoinChannelSuccess: (RtcConnection conn, int elapsed) =>
              debugPrint("Joined channel successfully!"),
        ),
      );

      debugPrint("Agora initialized successfully.");
    } catch (e) {
      debugPrint("Agora initialization failed: $e");
    }
  }

  Future<void> _joinChannel() async {
    if (_engine == null) {
      debugPrint("Agora engine is not initialized.");
      return;
    }

    String channel = channelController.text.trim();
    int uid = int.tryParse(userController.text.trim()) ?? 0;

    if (channel.isNotEmpty) {
      await _engine!.joinChannel(
        token: "",
        channelId: channel,
        uid: uid,
        options: const ChannelMediaOptions(),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(engine: _engine!),
        ),
      );
    }
  }

  @override
  void dispose() {
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Join Walkie Talkie Channel")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: channelController,
              decoration: const InputDecoration(labelText: "Enter Channel ID"),
            ),
            TextField(
              controller: userController,
              decoration: const InputDecoration(labelText: "Enter User ID"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _joinChannel,
              child: const Text("Join & Open Map"),
            ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  final RtcEngine engine;
  const MapScreen({super.key, required this.engine});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool isTalking = false;
  double _currentZoom = 10;
  LatLng? currentLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permissions are denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permissions are permanently denied");
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        _mapController.move(currentLocation!, 10.0);
      });

      debugPrint("Current Location: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  Future<void> _toggleTalk() async {
    await widget.engine.muteLocalAudioStream(isTalking);
    setState(() => isTalking = !isTalking);
  }

  @override
  void dispose() {
    widget.engine.leaveChannel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.app',
              ),
              TileLayer(
                tileSize: 256,
                userAgentPackageName: 'com.example.app',
                urlTemplate: "https://tiles.arcgis.com/tiles/C8EMgrsFcRFL6LrL/arcgis/rest/services/GEBCO_contours/MapServer/tile/{z}/{y}/{x}",
               
              ),
              
            ],
          ),
          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleTalk,
        backgroundColor: isTalking ? Colors.red : Colors.blue,
        child: const Icon(Icons.mic),
      ),
    );
  }
}
