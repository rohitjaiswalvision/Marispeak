import 'dart:ffi';

import 'package:intl/intl.dart';
import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/tabs/chats/ptt_view.dart';
import 'package:marispeaks/controllers/preferences_controller.dart';
import 'package:marispeaks/helpers/notification_helper.dart';
import 'package:marispeaks/helpers/routes_helper.dart';
import 'package:marispeaks/main.dart';
import 'package:marispeaks/provider/weatherProvider.dart';
import 'package:marispeaks/models/user.dart' as AppUser;

import 'package:marispeaks/models/group.dart';
import 'package:marispeaks/tabs/groups/controllers/group_controller.dart';

import 'package:marispeaks/screens/IAPs/SubscriptionPage.dart';
import 'package:marispeaks/helpers/settings_provider.dart';
import 'package:marispeaks/api/LocationUpdater.dart';
import 'package:marispeaks/screens/calling/controller/call_controller.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:marispeaks/screens/home/LatLngPoint.dart';
import 'package:marispeaks/screens/home/NoConnectionScreen.dart';
import 'package:marispeaks/screens/homeScreenWeather.dart';
import 'package:marispeaks/tabs/calls/controller/call_history_controller.dart';
import 'package:marispeaks/tabs/chats/controllers/chat_controller.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:marispeaks/screens/home/ptt_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/layer/scalebar/scalebar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:get/get_core/src/get_main.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../controllers/report_controller.dart';
import '../../tabs/calls/call_hsitory_screen.dart';
import '../../tabs/chats/chats_screen.dart';
import 'package:marispeaks/screens/home/home_screen.dart';
import '../../tabs/profile/profile_screen.dart';
import 'controller/home_controller.dart';
import 'ais_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:marispeaks/screens/home/SavedRoute.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:rxdart/rxdart.dart';
import 'package:marispeaks/models/user.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:collection/collection.dart';

final GlobalKey<_MainScreenState> mainScreenKey = GlobalKey();

class MainScreenUI extends StatefulWidget {
  MainScreenUI({Key? key}) : super(key: mainScreenKey);

  @override
  _MainScreenState createState() => _MainScreenState();
}

enum UsageType { plotter, layers }

class _MainScreenState extends State<MainScreenUI> with WidgetsBindingObserver {
  late MapController _mapController;
  late MapOptions _mapOptions;
  double? _headings;
  final String appId = '6a4381e12731aa8d38731d8994505143';
  bool isChartplotterOn = false;
  bool _hasCompass = false;
  bool _showPopup = false;
  bool _isChecking = true;
//  bool _hasCentered = false;
    bool _closeBox = false;
  bool isAisOn = false;
  bool isDepthShow = false;
  bool isFollow = false;
  bool _showClearButton = false;
  bool showTracker = false;
  String tempUnit = "--";
  double newTemp = 0.0;
  LatLng? _lastPosition;
  double totalDistanceMeters = 0.0;
  DateTime? startTime;
  Duration travelDuration = Duration.zero;
  bool isMoving = false;
  DateTime? tripStartTime;
  Duration travelTime = Duration.zero;
  LatLng? lastLocation;
  bool tripRunning = false;
  bool ShowMyLocation = false;
  int _selectedIndex = -1;
  double speed_of_boat = 0;
  double SliderAis = 4000;
  String tempText = "---";
  String windSpeedText = "--";
  double windSpeedDouble = 0;
  bool isMicVisible = true;
  double SliderUsers = 10;
  double? Otherslatitude;
  double? Otherslongitude;
  double? Otherslatitudetrack;
  double? Otherslongitudetrack;
  String? TrackerdeviceName;
  bool isLocationLoaded = false;
  bool? _magnetometerAvailable;
  LatLng currentLocation = LatLng(0, 0);
  List<Widget>? _staticMapLayers;
  StreamSubscription<Position>? _positionStream;
  List<Marker> _userMarkers = [];
  List<Marker> tempMarkers = [];
  double _heading = 0;
  late final Widget _mapScreen;
  bool isRecording = false;
  List<LatLng> routePoints = [];
  List<Polyline> _polylines = [];
  late Box<SavedRoute> savedRoutesBox;
  String speedUnit = "--";
  String WindspeedUnit = "m/s";
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _locationListenerTimer;
  Timer? _initialTimer;

  // ✅ Track Firestore listener for clean disposal (prevents 1-hour memory leak)
  StreamSubscription? _userLocationsSubscription;

  // ✅ Navigation: turn-by-turn state
  List<String> _navSteps = [];
  int _currentStep = 0;
  bool _isNavigating = false;
  String _currentInstruction = '';

  // ✅ Map layer toggles
  bool _showNoaaCharts = false;    // NOAA nautical charts
  bool _showSatellite = false;     // Esri Ocean satellite
  bool _showTrafficLayer = true;   // Maritime traffic separation zones
  Timer? _timer_plotter;
  late Timer _timerx;
  bool isOfflineScreenShown = false;

  final DailyUsageTimer _dailyTimer = DailyUsageTimer();
  bool isRunningLayers = false;
  bool isRunningPlotter = false;
  bool LayerTodayTimeEnd = false;
  bool PlotterTodayTimeEnd = false;

set CloseBox(bool value) {
    if (mounted) {
      setState(() {
        _closeBox = value;
      });
    }
  }

  bool get CloseBox => _closeBox;
  
void startTrip() async {
   LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please allow location from settings to use this feature')),
      );
      return;
    }
    
  final prefs = await SharedPreferences.getInstance();

  tripStartTime = DateTime.now();
  travelTime = Duration.zero;
  totalDistanceMeters = 0.0;
  lastLocation = null;
  tripRunning = true;

  bool hasAccess =
      await customBottomSection.currentState!.isSubscribed();

  /// ---------- SUBSCRIBED USER ----------
  if (hasAccess) {
    if (!isRunningPlotter) {
      toggleRouteRecording(context);
      isRunningPlotter = true;
    }

  /// ---------- FREE USER ----------
  } else {
    
    PlotterTodayTimeEnd =
        prefs.getBool("_plotterLimitKey") ?? false;

    if (PlotterTodayTimeEnd) {
      showSalePopup(context);
      return;
    }

    if (!isRunningPlotter) {
      toggleRouteRecording(context);

      await _dailyTimer.start(
        type: UsageType.plotter,
        context: context,
        onLimitReached: () async {
          PlotterTodayTimeEnd = true;
          await prefs.setBool("_plotterLimitKey", true);

          showSalePopup(context);

          isRunningPlotter = false;
          await _dailyTimer.stop(UsageType.plotter);
          _saveRoute();
        },
      );

      isRunningPlotter = true;

      await showRemainingMinutesSnack(
        context,
        UsageType.plotter,
      );
    }
  }

  /// ---------- COMMON TIMER (BOTH USERS) ----------
  _timer_plotter?.cancel();
  _timer_plotter =
      Timer.periodic(const Duration(seconds: 1), (_) {
    if (tripRunning) {
      setState(() {
        travelTime =
            DateTime.now().difference(tripStartTime!);
      });
    }
  });
}
  void stopTrip() async {
    
    isRunningPlotter = false;
    tripRunning = false;
    _timer_plotter?.cancel();
    _timer_plotter = null;
    await _dailyTimer.stop(UsageType.plotter);
  }

  void _startNetworkMonitoring() {
    _timerx = Timer.periodic(Duration(seconds: 5), (_) async {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none && !isOfflineScreenShown) {
        isOfflineScreenShown = true;
        if (context.mounted) {
          showOfflineBanner(context);
        }
      } else if (result != ConnectivityResult.none && isOfflineScreenShown) {
        isOfflineScreenShown = false;
        if (context.mounted) {
          hideOfflineBanner(context);
        }
      }
    });
  }

  void showOfflineBanner(BuildContext context) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text(
          'No Internet Connection',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        leading: const Icon(Icons.wifi_off, color: Colors.red, size: 20),
        backgroundColor: Colors.white,
        actions: const [],
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  void hideOfflineBanner(BuildContext context) {
    ScaffoldMessenger.of(context).clearMaterialBanners();
  }

  final List<Widget> _screens = [
    HomeScreen(),
    CallHistoryScreen(),
    ProfileScreen(),
    ChatsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void hideMic() {
    setState(() {
      isMicVisible = false;
    });
  }

  void showMic() {
    setState(() {
      isMicVisible = true;
    });
  }

  void _updateMapLayers() {
    setState(() {
      _staticMapLayers = [
        // ─── Base layer ─────────────────────────────────────────────
        if (_showSatellite)
          // ✅ Esri Ocean basemap — detailed satellite imagery for sea
          TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.pttcommunicate.pttmessenger',
            maxNativeZoom: 13,
          )
        else
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.pttcommunicate.pttmessenger',
          ),

        // ─── NOAA Nautical Charts ────────────────────────────────────
        if (_showNoaaCharts)
          // ✅ NOAA Raster Navigational Charts (free, no API key)
          TileLayer(
            urlTemplate:
                'https://tileservice.charts.noaa.gov/tiles/50000_1/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.pttcommunicate.pttmessenger',
            maxNativeZoom: 18,
            tileProvider: NetworkTileProvider(),
            errorTileCallback: (tile, error, stackTrace) {},
          ),

        // ─── Maritime overlays ───────────────────────────────────────
        // OpenSeaMap seamark layer (nav aids, buoys, hazards)
        TileLayer(
          urlTemplate: 'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pttcommunicate.pttmessenger',
        ),

        // ✅ Maritime traffic separation schemes + closures (no API key)
        if (_showTrafficLayer)
          TileLayer(
            urlTemplate:
                'https://tiles.openseamap.org/routing/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.pttcommunicate.pttmessenger',
            tileProvider: NetworkTileProvider(),
            errorTileCallback: (tile, error, stackTrace) {},
          ),

        // ─── Depth contours ──────────────────────────────────────────
        if (isDepthShow)
          TileLayer(
            urlTemplate:
                'https://tiles.arcgis.com/tiles/C8EMgrsFcRFL6LrL/arcgis/rest/services/GEBCO_contours/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.pttcommunicate.pttmessenger',
          ),
      ];
    });
  }

  /// Toggle NOAA charts layer
  void toggleNoaaCharts() {
    _showNoaaCharts = !_showNoaaCharts;
    _updateMapLayers();
  }

  /// Toggle Esri Ocean satellite base
  void toggleSatellite() {
    _showSatellite = !_showSatellite;
    _updateMapLayers();
  }

  /// Toggle maritime traffic separation overlay
  void toggleTrafficLayer() {
    _showTrafficLayer = !_showTrafficLayer;
    _updateMapLayers();
  }

  String direction(double heading) {
    if (_heading >= 337.5 || _heading < 22.5) return "N";
    if (_heading >= 22.5 && _heading < 67.5) return "NE";
    if (_heading >= 67.5 && _heading < 112.5) return "E";
    if (_heading >= 112.5 && _heading < 157.5) return "SE";
    if (_heading >= 157.5 && _heading < 202.5) return "S";
    if (_heading >= 202.5 && _heading < 247.5) return "SW";
    if (_heading >= 247.5 && _heading < 292.5) return "W";
    if (_heading >= 292.5 && _heading < 337.5) return "NW";
    return "";
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
    _loadShowMyLocation();
    _startNetworkMonitoring();
    
    resumeIfRunning();
    _checkMagnetometer();
    Get.put(HomeController(), permanent: true);
    Get.put(CallHistoryController(), permanent: true);
    Get.put(ChatController(), permanent: true);
    Get.put(ReportController(), permanent: true);
    _compassSub = FlutterCompass.events!
        .throttleTime(Duration(milliseconds: 50))
        .listen((event) {
      if (event.heading != null) {
        setState(() {
          _headings = event.heading;
        });
      } else {
        print("❌ No compass sensor found on this device.");
      }
    });
    // ✅ Call once — Firestore .snapshots() is already real-time, no need to poll
    _initialTimer = Timer(Duration(seconds: 5), () {
      listenForUserLocations();
    });
    WidgetsBinding.instance.addObserver(this);
    _updateMapLayers();
    KeepScreenOn.turnOn();
    LocationUpdater().startLocationUpdates();
    savedRoutesBox = Hive.box<SavedRoute>('savedRoutes');
    _mapController = MapController();
    _mapOptions = MapOptions(
      onLongPress: onMapLongPress,
      initialCenter: LatLng(0.0, 0.0),
      initialZoom: 13.0,
    );
    
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    SliderAis = settings.aisRange;
    speedUnit = settings.speedFormat;
    WindspeedUnit = settings.windFormat;
    tempUnit = settings.tempUnit;

    settings.addListener(() {
      if (mounted) {
        setState(() {
          SliderAis = settings.aisRange;
          speedUnit = settings.speedFormat;
          WindspeedUnit = settings.windFormat;
          tempUnit = settings.tempUnit;
      
          if (windSpeedDouble != 0) { 
            setState(() {
              if( newTemp != 0.0){
                if (tempUnit == "F") {
                    // Convert to Fahrenheit and take integer only
                    tempText = ((newTemp * 9 / 5) + 32).toInt().toString();
                    tempText = "$tempText°F";
                  } else {
                    // Keep Celsius as integer
                    tempText = newTemp.toInt().toString();
                    tempText = "$tempText°C";
                  }
              }
           // windSpeedText = windSpeedDouble.toStringAsFixed(0);
            if (WindspeedUnit == "m/s") {
              windSpeedText = (windSpeedDouble).toStringAsFixed(0);
            } else if (WindspeedUnit == "km/h") { 
              windSpeedText = (windSpeedDouble * 3.6).toStringAsFixed(0);
            } else if (WindspeedUnit == "mph") {
              windSpeedText = (windSpeedDouble * 2.23694).toStringAsFixed(0);
            } else if (WindspeedUnit == "knots") {
              windSpeedText = (windSpeedDouble * 1.94384).toStringAsFixed(0);
            }

          print("Windspeed Listened: $windSpeedText");
          print(tempUnit);
            });
          }

          Provider.of<AISService>(context, listen: false).clearShips();
          Provider.of<AISService>(context, listen: false).showShips = false;
        });
        
      }
    });
    _loadOtherLocation();
    _loadTrackerLocation();
    getCurrentLocation();
  }

Future<void> resumeIfRunning() async {
  final prefs = await SharedPreferences.getInstance();

  if (prefs.containsKey('plotter_start')) {
    //isRunningPlotter = true;

    await _dailyTimer.start(
      type: UsageType.plotter,
      context: context,
      onLimitReached: () {
        showSalePopup(context);
        PlotterTodayTimeEnd  = true;
      //  isRunningPlotter = false;
      },
    );
  }

  if (prefs.containsKey('layers_start')) {
    await _dailyTimer.start(
      type: UsageType.layers,
      context: context,
      onLimitReached: () {
        showSalePopup(context);
        LayerTodayTimeEnd = true;
      },
    );
  }
}
  Future<void> _checkMagnetometer() async {}

  LatLng? _selectedPoint;
  List<LatLng> _polylinePoints = [];

  void getDirections(double latitude, double longitude) {
    setState(() {
      _selectedPoint = LatLng(latitude, longitude);
    });
    _showClearButton = true;
    print("🛠 Marker Set at: $_selectedPoint");
    Future.delayed(Duration(milliseconds: 10), () {
      setState(() {});
    });
    _showDirectionDialog(LatLng(latitude, longitude));
  }

  Future<void> getWeatherDetails({
    required double latitude,
    required double longitude,
    required void Function(String temperature, String windSpeed) onSuccess,
    required void Function(String error) onError,
  }) async {
    final String url =
        'https://api.openweathermap.org/data/3.0/onecall?lat=$latitude&lon=$longitude&appid=$appId&units=metric';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final current = json['current'];
        if (current == null) {
          onError('Current weather data not found');
          return;
        }
        final temp = current['temp'];
        final windSpeed = current['wind_speed'].toString();
        if (temp == null) {
          onError('Temperature not found in the API response');
          return;
        }
        final formattedTemp = "${temp.toStringAsFixed(0)}°";
        final formattedWindSpeed = windSpeed;
        onSuccess(formattedTemp, formattedWindSpeed);
      } else {
        onError('Failed to fetch weather data. Status: ${response.statusCode}');
      }
    } catch (e) {
      onError('Error fetching weather: $e');
    }
  }

  void onMapLongPress(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedPoint = point;
    });
    _showClearButton = true;
    print("🛠 Marker Set at: $_selectedPoint");
    Future.delayed(Duration(milliseconds: 10), () {
      setState(() {});
    });
    _showDirectionDialog(point);
  }

  void showSalePopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SubscriptionPage()),
              );
            },
            child: Stack(
              children: [
                Container(
                  color: Colors.black.withOpacity(0.7),
                  width: double.infinity,
                  height: double.infinity,
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Image.asset(
                      'assets/maris/limit.jpg',
                      fit: BoxFit.contain,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDirectionDialog(LatLng destination) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Directions"),
          content: Text("Do you want directions to this point?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("No"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _drawPolyline(destination);
              },
              child: Text("Yes"),
            ),
          ],
        );
      },
    );
  }

  List<LatLng> _calculateBoundingBox(LatLng center, double radiusKm) {
    const double earthRadiusKm = 6371.0;
    double latDiff = (radiusKm / earthRadiusKm) * (180 / pi);
    double lngDiff = (radiusKm / (earthRadiusKm * cos(center.latitude * pi / 180))) * (180 / pi);
    double minLat = center.latitude - latDiff;
    double maxLat = center.latitude + latDiff;
    double minLng = center.longitude - lngDiff;
    double maxLng = center.longitude + lngDiff;
    return [
      LatLng(minLat, minLng),
      LatLng(minLat, maxLng),
      LatLng(maxLat, maxLng),
      LatLng(maxLat, minLng),
      LatLng(minLat, minLng)
    ];
  }

  /// Fetch OSRM route + extract turn-by-turn steps (free, no API key)
  Future<void> _drawPolyline(LatLng destination) async {
    Position position = await Geolocator.getCurrentPosition();
    final LatLng myLocation = LatLng(position.latitude, position.longitude);

    try {
      // ✅ OSRM open-source routing (no API key required)
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${myLocation.longitude},${myLocation.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?steps=true&geometries=geojson&overview=full',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final route = json['routes'][0];
        final legs = route['legs'] as List;

        // ─── Extract polyline coordinates ────────────────────────────
        final coords = route['geometry']['coordinates'] as List;
        final routeLatLngs =
            coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();

        // ─── Extract step-by-step instructions ──────────────────────
        final List<String> steps = [];
        for (final leg in legs) {
          for (final step in leg['steps'] as List) {
            final maneuver = step['maneuver'];
            final type = maneuver['type'] ?? '';
            final modifier = maneuver['modifier'] ?? '';
            final name = step['name'] ?? '';
            final distanceM = (step['distance'] as num).toInt();
            final dist = distanceM >= 1000
                ? '${(distanceM / 1000).toStringAsFixed(1)} km'
                : '$distanceM m';
            final direction = modifier.isNotEmpty ? '$type $modifier' : type;
            steps.add('$direction on $name ($dist)'.trim());
          }
        }

        setState(() {
          _polylinePoints = routeLatLngs;
          _navSteps = steps;
          _currentStep = 0;
          _isNavigating = steps.isNotEmpty;
          _currentInstruction = steps.isNotEmpty ? steps[0] : '';
          print('🗺 Route: ${routeLatLngs.length} points, ${steps.length} steps');
        });

        // ─── Auto-advance steps as user moves ────────────────────────
        _startNavStepTracker(destination);
      } else {
        // Fallback: straight line if OSRM fails
        setState(() {
          _polylinePoints = [myLocation, destination];
          _isNavigating = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Routing error: $e');
      setState(() {
        _polylinePoints = [myLocation, destination];
        _isNavigating = false;
      });
    }
  }

  Timer? _navStepTimer;

  /// Advance navigation step when user is within 30m of the current waypoint
  void _startNavStepTracker(LatLng destination) {
    _navStepTimer?.cancel();
    _navStepTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isNavigating || _navSteps.isEmpty) {
        _navStepTimer?.cancel();
        return;
      }
      // Check if near destination → end navigation
      final dist = _calculateDistance(
        currentLocation.latitude, currentLocation.longitude,
        destination.latitude, destination.longitude,
      );
      if (dist < 0.05) { // within 50m of destination
        setState(() {
          _isNavigating = false;
          _currentInstruction = '✅ You have arrived!';
          _navSteps.clear();
        });
        _navStepTimer?.cancel();
        return;
      }
      // Advance step if within 80m of next waypoint
      if (_currentStep < _navSteps.length - 1) {
        setState(() {
          _currentStep++;
          _currentInstruction = _navSteps[_currentStep];
        });
      }
    });
  }

  void updateState() {
    setState(() {
      showTracker = true;
    });
  }

  void hideOrShowTracker() {
    if (Otherslatitudetrack == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Recent Tracker Saved')),
      );
      return;
    }
    setState(() {
      showTracker = !showTracker;
      if (showTracker) {
        _mapController.move(LatLng(Otherslatitudetrack!, Otherslongitudetrack!), _mapController.camera.zoom);
        Future.delayed(Duration(milliseconds: 1300), () {
          getDirections(Otherslatitudetrack!, Otherslongitudetrack!);
        });
      }
    });
  }

  void _clearMap() {
    showTracker = false;
    setState(() {
      _selectedPoint = null;
      _polylinePoints.clear();
      if (routePoints.isNotEmpty) {
        routePoints.clear();
      }
      _showClearButton = false;
      isLocationLoaded = true;
      print("Updating Clear map ");
    });
  }

  void _onLocationUpdate(LatLng newLocation) {
    if (isRecording) {
      setState(() {
        routePoints.add(newLocation);
        _mapController.move(currentLocation, 15);
      });
      if (!tripRunning) return;
      travelTime = DateTime.now().difference(tripStartTime!);
      if (lastLocation != null) {
        final distance = _distanceBetween(lastLocation!, newLocation);
        if (distance > 1) {
          totalDistanceMeters += distance;
        }
      }
      lastLocation = newLocation;
    }
  }

  double _distanceBetween(LatLng a, LatLng b) {
    const earthRadius = 6371000;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * earthRadius * asin(sqrt(h));
  }

  double _degToRad(double deg) => deg * pi / 180;

  void toggleRouteRecording(BuildContext context) {
    
    setState(() {
      if (isRecording) {
        isRecording = false;
        print("toggle route recording stopped");
      } else {
        isRecording = true;
        routePoints.clear();
        print("toggle route recording starts");
      }
    });
  }

  void _saveRoute() {
    TextEditingController routeNameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 60,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Resume Route',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Image.asset(
                      'assets/maris/close_grey.png',
                      width: 20,
                      height: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Route details:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              TextField(
                controller: routeNameController,
                decoration: const InputDecoration(
                  hintText: 'Route Name, Route Place',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 40),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (isRecording) {
                      toggleRouteRecording(context);
                      stopTrip();
                      _showSpeedAgain();
                    }
                    print(isRecording);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue, width: 1),
                    ),
                    child: const Center(
                      child: Text(
                        'Discard Plotter Route',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  toggleRouteRecording(context);
                  if (tripRunning) stopTrip();
                  print(isRecording);
                  String routeName = routeNameController.text.trim();
                  if (routeName.isNotEmpty) {
                    List<LatLngPoint> points = routePoints
                        .map((e) => LatLngPoint(latitude: e.latitude, longitude: e.longitude))
                        .toList();
                    double distance = 0.0;
                    try {
                      distance = double.parse(distanceText);
                    } catch (e) {
                      distance = 0.0;
                    }
                    SavedRoute newRoute = SavedRoute(
                      name: routeName,
                      points: points,
                      dateTime: DateTime.now(),
                      distance: distance,
                    );
                    savedRoutesBox.add(newRoute);
                    Navigator.pop(context);
                    routePoints.clear();
                    _showSpeedAgain();
                  }
                },
                child: Image.asset(
                  "assets/maris/save_plotter.png",
                  width: double.infinity,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Distance',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "$distanceText, km",
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Time',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "$timeText, min",
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _retrieveRoute(SavedRoute selectedRoute) {
    setState(() {
      routePoints = selectedRoute.points.map((point) {
        return LatLng(point.latitude, point.longitude);
      }).toList();
    });
    _showClearButton = true;
  }

  void clearOtherTrackerPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("Otherlatitudetrack", 0.toString());
    prefs.setString("Otherlongitudetrack", 0.toString());
    prefs.setString("DeviceName", '');
    print("Tracker prefs cleared");
    Otherslatitudetrack = 0;
    Otherslongitudetrack = 0;
  }

  void showRoutesDialog(BuildContext context) async {
    var box = await Hive.openBox<SavedRoute>('savedRoutes');
    List<SavedRoute> savedRoutes = box.values.toList();
    List<SavedRoute> filteredRoutes = List.from(savedRoutes);
    bool isSearching = false;
    TextEditingController searchController = TextEditingController();
    void filterRoutes(String query) {
      final filtered = savedRoutes.where((route) {
        return route.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
      filteredRoutes = filtered;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return GestureDetector(
              onTap: () {
                if (isSearching) {
                  setState(() {
                    isSearching = false;
                    filteredRoutes = List.from(savedRoutes);
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                isSearching = !isSearching;
                                if (!isSearching) {
                                  filteredRoutes = List.from(savedRoutes);
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
                                  hintText: 'Search routes',
                                  hintStyle: TextStyle(color: Colors.grey[300]),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    filterRoutes(value);
                                  });
                                },
                              ),
                            )
                          else
                            Expanded(
                              child: Text(
                                'Saved Plotter Routes',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ),
                          IconButton(
                            onPressed: () async {
                              if (savedRoutes.isEmpty) return;
                              bool confirm = await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Delete All Routes?'),
                                  content: Text('Are you sure you want to delete all saved routes?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await box.clear();
                                setState(() {
                                  savedRoutes.clear();
                                  filteredRoutes.clear();
                                });
                                Navigator.pop(context);
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
                    Flexible(
                      child: filteredRoutes.isEmpty
                          ? Center(
                              child: Text(
                                'No saved routes',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredRoutes.length + 1,
                              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[300]),
                              itemBuilder: (context, index) {
                                if (index == filteredRoutes.length) {
                                  return ListTile(
                                    title: Center(
                                      child: Text(
                                        'Swipe left to delete',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                      ),
                                    ),
                                    enabled: false,
                                  );
                                }
                                final route = filteredRoutes[index];
                                String formattedDate = DateFormat('MMM dd, yyyy').format(route.dateTime);
                                return Dismissible(
                                  key: Key(route.key.toString()),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.symmetric(horizontal: 20),
                                    child: Icon(Icons.delete, color: Colors.white),
                                  ),
                                  onDismissed: (direction) async {
                                    await box.delete(route.key);
                                    setState(() {
                                      filteredRoutes.removeAt(index);
                                      savedRoutes.remove(route);
                                    });
                                  },
                                  child: ListTile(
                                    title: Text(
                                      route.name,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
                                    ),
                                    trailing: Text(
                                      '${route.distance.toStringAsFixed(2)} km\n$formattedDate',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    onTap: () {
                                      _retrieveRoute(route);
                                      Navigator.pop(context);
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
          },
        );
      },
    );
  }

  Future<void> _loadTrackerLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lat = prefs.getString('Otherlatitudetrack');
    String? lon = prefs.getString('Otherlongitudetrack');
    String? name = prefs.getString('DeviceName');
    if (lat != null && lon != null) {
      setState(() {
        Otherslatitudetrack = double.tryParse(lat);
        Otherslongitudetrack = double.tryParse(lon);
        TrackerdeviceName = name;
      });
    }
  }

  Future<void> _loadOtherLocation() async {
    if (isLocationLoaded) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lat = prefs.getString('Otherslatitude');
    String? lon = prefs.getString('Otherlongitude');
    String? name = prefs.getString('DeviceName');
    if (lat != null && lon != null) {
      setState(() {
        Otherslatitude = double.tryParse(lat);
        Otherslongitude = double.tryParse(lon);
        TrackerdeviceName = name;
      });
    }
  }

  Widget _buildMap(BuildContext context) {
    final aisService = Provider.of<AISService>(context, listen: true);
    if (!_showClearButton && !isLocationLoaded) {
      _loadOtherLocation();
      _loadTrackerLocation();
    }
    if (Otherslatitude != 0 && !_showClearButton && Otherslatitude != null && !isLocationLoaded) {
      _mapController.move(LatLng(Otherslatitude!, Otherslongitude!), _mapController.camera.zoom);
      _showClearButton = true;
      isLocationLoaded = true;
    }
    if (Otherslatitudetrack != 0 && showTracker && Otherslatitudetrack != null && !isLocationLoaded) {
      _mapController.move(LatLng(Otherslatitudetrack!, Otherslongitudetrack!), _mapController.camera.zoom);
      Future.delayed(Duration(milliseconds: 300), () {
        getDirections(Otherslatitudetrack!, Otherslongitudetrack!);
      });
      isLocationLoaded = true;
    }
    if (isFollow) {
      _mapController.move(currentLocation, _mapController.camera.zoom);
    }
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: FlutterMap(
        mapController: _mapController,
        options: _mapOptions,
        children: [
          RepaintBoundary(child: Stack(children: _staticMapLayers!)),
          if (aisService.showShips)
            MarkerLayer(
              markers: aisService.ships.values.map((ship) => _buildShipMarker(ship)).toList(),
            ),
          const Scalebar(
            alignment: Alignment.topLeft,
            padding: EdgeInsets.only(left: 25, top: 155),
            textStyle: TextStyle(color: Colors.black, fontSize: 14),
            lineColor: Colors.black,
            strokeWidth: 2,
            lineHeight: 5,
            length: ScalebarLength.m,
          ),
          MarkerLayer(
            markers: [
              if (currentLocation != LatLng(0, 0))
                Marker(
                  point: currentLocation,
                  width: 90,
                  height: 90,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("My Location"),
                          content: const Text("This is your location marker."),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("OK"),
                            )
                          ],
                        ),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: ((_headings ?? 0) * (pi / 180) * -1),
                          child: Image.asset(
                            "assets/maris/boat_direct.png",
                            width: 90,
                            height: 90,
                          ),
                        ),
                        Transform.rotate(
                          angle: _heading * pi / 180,
                          child: Image.asset(
                            'assets/maris/my_boat3.png',
                            width: 35,
                            height: 35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          MarkerLayer(
            markers: [
              if (Otherslatitudetrack != null && Otherslongitudetrack != null && showTracker)
                Marker(
                  point: LatLng(Otherslatitudetrack!, Otherslongitudetrack!),
                  width: 100,
                  height: 40,
                  child: Column(
                    children: [
                      Text(
                        '$TrackerdeviceName',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          backgroundColor: Colors.white70,
                        ),
                      ),
                      Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 20,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          MarkerLayer(
            markers: [
              if (Otherslatitude != null && Otherslongitude != null)
                Marker(
                  point: LatLng(Otherslatitude!, Otherslongitude!),
                  width: 100,
                  height: 40,
                  child: Column(
                    children: [
                      Text(
                        '$TrackerdeviceName',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          backgroundColor: Colors.white70,
                        ),
                      ),
                      Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 20,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          MarkerLayer(
            markers: [
              if (_selectedPoint != null)
                Marker(
                  point: _selectedPoint!,
                  width: 20,
                  height: 20,
                  child: Icon(Icons.location_pin, color: Colors.red, size: 20),
                ),
            ],
          ),
          if (_polylinePoints.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _polylinePoints,
                  strokeWidth: 4.0,
                  color: Colors.red,
                ),
              ],
            ),
          if (!isRecording)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints.map((point) => LatLng(point.latitude, point.longitude)).toList(),
                  strokeWidth: 4.0,
                  color: Colors.blue,
                ),
              ],
            ),
          if (isRecording)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints.map((point) => LatLng(point.latitude, point.longitude)).toList(),
                  strokeWidth: 4.0,
                  color: Colors.red,
                ),
              ],
            ),
          MarkerLayer(
            markers: _userMarkers,
          ),

          // ✅ Turn-by-turn navigation instruction banner
          if (_isNavigating && _currentInstruction.isNotEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.turn_right, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _currentInstruction,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_currentStep + 1}/${_navSteps.length}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

String _getShipIcon(String? vesselType) {
  //if (vesselType == null || vesselType.isEmpty) return "assets/maris/cargoship.png";
    switch (vesselType) {
      case "BaseStationReport":
        return "assets/maris/basestation.png";
      case "DataLinkManagementMessage":
        return "assets/maris/signal_station.png";
      case "StaticDataReport":
        return "assets/maris/signal_station.png";
      case "AidsToNavigationReport":
        return "assets/maris/ref_point.png";
      case "AddressedBinaryMessage":
        return "assets/maris/signal_station.png";
      case "BinaryAcknowledge":
        return "assets/maris/signal_station.png";
      case "StandardClassBPositionReport":
        return "assets/maris/sailingboat.png";
      case "PositionReport":
        return "assets/maris/cargoship1.png";
      case "UnknownMessage":
        return "assets/maris/cargoship.png";
      case "ShipStaticData":
        return "assets/maris/signal_station.png";
      case "CargoShip":
        return "assets/maris/cargoship.png";
      case "PassengerShip":
        return "assets/maris/ferryboat.png";
      case "Tanker":
        return "assets/maris/lng.png";
      case "FishingVessel":
        return "assets/maris/fishing_boat.png";
      case "PleasureCraft":
        return "assets/maris/sailingboat.png";
      case "HighSpeedCraft":
        return "assets/maris/ferryboat.png";
      case "MilitaryVessel":
        return "assets/maris/speedboat.png";
      case "SearchAndRescue":
        return "assets/maris/speedboat.png";
      case "PilotVessel":
        return "assets/maris/tug.png";
      case "Tug":
        return "assets/maris/tug.png";
      default:
        return "assets/maris/cargoship.png";
    }
}

Marker _buildShipMarker(Ship ship) {
  print(
      "📍 Drawing marker for newShip: MMSI: ${ship.mmsi}, ShipName: ${ship.name}, Type: ${ship.shipType}, Lat: ${ship.position.latitude}, Lon: ${ship.position.longitude}");

  String iconPath = _getShipIcon(ship.shipType); 
  

  return Marker(
    point: ship.position,
    width: 25, // keep original size
    height: 25,
    rotate: false,
    child: GestureDetector(
      onTap: () => _showShipInfoDialog(ship),
      child: Image.asset(
          iconPath,
          width: 25,
          height: 25,
        ),
    ),
  );
}

  List<LatLng> generateCircle(LatLng center, double radiusKm, int pointsCount) {
    const double earthRadiusKm = 6371.0;
    List<LatLng> circlePoints = [];
    for (int i = 0; i < pointsCount; i++) {
      double angle = (i / pointsCount) * (2 * pi);
      double deltaLat = (radiusKm / earthRadiusKm) * sin(angle);
      double deltaLng = (radiusKm / (earthRadiusKm * cos(center.latitude * pi / 180))) * cos(angle);
      double newLat = center.latitude + (deltaLat * 180 / pi);
      double newLng = center.longitude + (deltaLng * 180 / pi);
      circlePoints.add(LatLng(newLat, newLng));
    }
    return circlePoints;
  }

  @override
  void dispose() {
    _timerx.cancel();
    _initialTimer?.cancel();
    _locationListenerTimer?.cancel();
    _navStepTimer?.cancel();
    // ✅ Cancel Firestore listener — prevents memory leak over long sessions
    _userLocationsSubscription?.cancel();
    final aisService = Provider.of<AISService>(context, listen: true);
    aisService.showShips = false;
    Provider.of<AISService>(context, listen: false).disconnect();
    LocationUpdater().stopLocationUpdates();
    _compassSub?.cancel();
    KeepScreenOn.turnOn(on: false);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOtherLocation();
    _loadTrackerLocation();
  }

  final PreferencesController prefController = Get.find();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final aisService = Provider.of<AISService>(context, listen: false);
    switch (state) {
      case AppLifecycleState.resumed:
        KeepScreenOn.turnOn();
        switchToPlaybackMode();
        if (isAisOn) {
          aisService.showShips = true;
        }
        UserApi.updateUserPresence(true);
        print("🟢 App resumed, Wakelock enabled, User Online");
        break;
    
      case AppLifecycleState.paused:
        KeepScreenOn.turnOn(on: false);
        switchToPlaybackMode();
        aisService.showShips = false;
        UserApi.updateUserPresence(false);
    
    if (customBottomSection.currentState?.TargetUserID != customBottomSection.currentState?.currentUser.userId)
        { customBottomSection.currentState?.idleTimer?.cancel();  }

        print("🟡 App paused, Wakelock disabled, User Offline");
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        UserApi.updateUserPresence(false);
        print("🔴 App inactive/hidden/detached, User Offline");
        break;
    }
  }

void listenForUserLocations() {
  // ✅ Cancel any existing listener before creating a new one
  _userLocationsSubscription?.cancel();
  _userLocationsSubscription = FirebaseFirestore.instance
      .collection('Users')
      .snapshots()
      .listen((snapshot) {
    if (!mounted) return; // ✅ Safety check — don't setState on disposed widget
    if (snapshot.docs.isNotEmpty) {
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      usersCache = users; // cache for toggle
      _updateMarkersFromFirestore(usersCache, currentLocation, SliderUsers);
    }
  }, onError: (e) {
    debugPrint('⚠️ User locations listener error: $e');
  });
}

  final Map<String, Marker> _userMarkerMap = {};
  final User = FirebaseAuth.instance.currentUser;
  List<String> visibleUserIds = [];

  bool showOnlyGroupUsers = false;       // toggle state
  String? selectedGroupId;               // current group
  List<Map<String, dynamic>> usersCache = []; // cache Firestore users

void _updateMarkersFromFirestore(
  List<Map<String, dynamic>> users,
  LatLng currentUserLocation,
  double radiusInKm,
) {
  final updatedMarkerMap = <String, Marker>{};
  final visibleIds = <String>[];

  // Clear old state first!
  setState(() {
    visibleUserIds.clear();
    _userMarkerMap.clear();
    _userMarkers.clear();
  });

  final groupController = Get.find<GroupController>();

  /// Allowed users when filter is ON
  Set<String> allowedUserIds = {};

  if (showOnlyGroupUsers && selectedGroupId != null) {
    final group = groupController.groups.firstWhereOrNull(
      (g) => g.groupId == selectedGroupId,
    );

    if (group != null) {
      allowedUserIds = group.members
          .map((m) => m.userId?.toString().trim())
          .where((id) => id != null && id!.isNotEmpty)
          .cast<String>()
          .toSet();

     print(users
    .where((u) => allowedUserIds.contains(u['id']?.toString().trim()))
    .map((u) => u['fullname'])
    .toList());
    }
  }

  for (var user in users) {
    final userId = user['id']?.toString().trim();
    if (userId == null) continue;

    // Skip yourself
    if (userId == User?.uid) continue;

    // Parse location
    final lat = double.tryParse(user['lat']?.toString() ?? '');
    final lon = double.tryParse(user['lon']?.toString() ?? '');
    if (lat == null || lon == null) continue;

    final userLocation = LatLng(lat, lon);

    // Always apply radius filter
    final distance = _calculateDistance(
      currentUserLocation.latitude,
      currentUserLocation.longitude,
      lat,
      lon,
    );

    if (distance > radiusInKm) continue;

    // If filter ON → must belong to group
    if (showOnlyGroupUsers && !allowedUserIds.contains(userId)) continue;

    // Passed all filters → visible
    visibleIds.add(userId);

    final marker = Marker(
      width: 80,
      height: 80,
      point: userLocation,
      child: GestureDetector(
        onTap: () async {
          final userObj = await UserApi.getUser(userId);
          if (userObj != null) {
            RoutesHelper.toMessages(user: userObj);
          }
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 3),
                ],
              ),
              child: Text(
                user['fullname'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Image.asset(
              'assets/maris/my_boat3.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );

    updatedMarkerMap[userId] = marker;
  }

  // Always keep yourself in visible list
  if (User?.uid != null) {
    visibleIds.add(User!.uid);
  }

  // Final rebuild after filtering
  setState(() {
    visibleUserIds = visibleIds;
    _userMarkerMap.addAll(updatedMarkerMap);
    _userMarkers.addAll(_userMarkerMap.values);
  });
}

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  String get distanceText {
    return (totalDistanceMeters / 1000).toStringAsFixed(2);
  }

  String get timeText {
    final minutes = travelTime.inMinutes;
    final seconds = travelTime.inSeconds % 60;
    return "$minutes . $seconds";
  }


  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        setState(() {
          currentLocation = LatLng(position.latitude, position.longitude);
          _heading = position.heading;
          _onLocationUpdate(currentLocation);
        });
        if (position.speed > 1) {
          if (speedUnit == "Km/h") {
            speed_of_boat = position.speed * 3.6;
          } else if (speedUnit == "Mph") {
            speed_of_boat = position.speed * 2.23694;
          } else if (speedUnit == "M/s") {
            speed_of_boat = position.speed;
          } else if (speedUnit == "Knots") {
            speed_of_boat = position.speed * 1.94384;
          }
        } else {
          speed_of_boat = 0;
        }
        //if (!_hasCentered) {
          _mapController.move(currentLocation, _mapController.camera.zoom);
         // _hasCentered = true;
       
      //  }
      });

   Future.delayed(const Duration(seconds: 1), () {
            getWeatherDetails(
              latitude: currentLocation.latitude,
              longitude: currentLocation.longitude,
              onSuccess: (temperature, windSpeed) {
              

              setState(() {
                
               //   newTemp = double.parse(temperature);
                  
                newTemp = double.parse(temperature.replaceAll(RegExp(r'[^0-9.-]'), ''));
              
                if (tempUnit == "F") {
                    // Convert to Fahrenheit and take integer only
                    tempText = ((newTemp * 9 / 5) + 32).toInt().toString();
                    tempText = "$tempText°F";
                  } else {
                    // Keep Celsius as integer
                    tempText = newTemp.toInt().toString();
                    tempText = "$tempText°C";
                  }

                  windSpeedDouble = double.parse(windSpeed);
                 if (WindspeedUnit == "m/s") {
              windSpeedText = (windSpeedDouble).toStringAsFixed(0);
            } else if (WindspeedUnit == "km/h") { 
              windSpeedText = (windSpeedDouble * 3.6).toStringAsFixed(0);
            } else if (WindspeedUnit == "mph") {
              windSpeedText = (windSpeedDouble * 2.23694).toStringAsFixed(0);
            } else if (WindspeedUnit == "knots") {
              windSpeedText = (windSpeedDouble * 1.94384).toStringAsFixed(0);
            }
                });

                print('Temperature: $temperature°C, Wind Speed: $windSpeed m/s');
                print('Wind Speed Unit: $WindspeedUnit');
              },
              onError: (error) {
                print(error);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              },
            );
          });

        print('call sent to openweather');
             print("Windspeed: $windSpeedDouble");

    } else {
      print("❌ Location permission not granted");
    }
    
  }

  void _centerToCurrentLocation() {
    if (currentLocation != LatLng(0, 0)) {
      _mapController.move(currentLocation, _mapController.camera.zoom);
    }
  }


/// =======================
/// BEAUTIFUL INFO DIALOG
/// =======================
void _showShipInfoDialog(Ship ship) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  ship.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _infoRow("MMSI", ship.mmsi),
              _infoRow("IMO", ship.imo ?? "N/A"),
              _infoRow("Call Sign", ship.callSign ?? "N/A"),
              _infoRow("Type", ship.shipType ?? "N/A"),
              _infoRow("Length", ship.length != null ? "${ship.length} m" : "N/A"),
              _infoRow("Width", ship.width != null ? "${ship.width} m" : "N/A"),
              const Divider(height: 20, thickness: 1),
              _infoRow("Speed", ship.speed != null ? "${ship.speed} kn" : "0 kn"),
              _infoRow("Course", ship.course != null ? "${ship.course}°" : "0°"),
              _infoRow("Heading", ship.heading != null ? "${ship.heading}°" : "0°"),
              _infoRow("Nav Status", ship.navStatus ?? "N/A"),
              const Divider(height: 20, thickness: 1),
              _infoRow("Destination", ship.destination ?? "N/A"),
              _infoRow("ETA", ship.eta ?? "N/A"),
              _infoRow("Draught", ship.draught != null ? "${ship.draught} m" : "N/A"),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Helper for a clean info row
Widget _infoRow(String label, dynamic value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            "$label:",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            "$value",
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex >= 0) {
          setState(() {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MainScreenUI()),
            );
            _selectedIndex = -1;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: (_selectedIndex >= 0)
            ? _screens[_selectedIndex]
            : Stack(
                children: [
                  _buildMap(context),
                  _buildTopOverlay(),
                  if (_showClearButton)
                    Positioned(
                      top: 150,
                      right: 60,
                      child: _buildOverlay(),
                    ),
                  _buildSpeedUI(),
                  Positioned(
                    bottom: 267,
                    left: 20,
                    child: _buildHideMeButton(),
                  ),
                  if (CloseBox)
                    Positioned(
                      bottom: 390,
                      left: 20,
                      child: _buildButtonWithTextAndIcon(
                        assetPath: 'assets/maris/green_rect.png',
                        label: ValueListenableBuilder<String>(
                          valueListenable: customBottomSection.currentState!.connectedUserName,
                          builder: (context, value, _) {
                            return Text(
                              "$value:         ",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        iconPath: 'assets/maris/enabledopt.png',
                        onTap: () {
                          customBottomSection.currentState?.ExitChat();
                        },
                      ),
                    ),
                                  if (customBottomSection.currentState?.isGroupChat == true 
                                  && customBottomSection.currentState?.TargetUserID != customBottomSection.currentState?.currentUser.userId)
                            Positioned(
                                bottom: 420,
                                left: 20,
                                child: StatefulBuilder(
                                  builder: (context, setState) {
                                     return GestureDetector(
                                     onTap: () {
                                            setState(() {
                                              showOnlyGroupUsers = !showOnlyGroupUsers;
                                              // Refresh map markers based on the toggle
                                              _updateMarkersFromFirestore(
                                                usersCache,        // cached Firestore users
                                                currentLocation,   // your current user location
                                                SliderUsers,       // radius
                                              ); 
                                            });
                                            print("Show Group Boats: $showOnlyGroupUsers");
                                          },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: showOnlyGroupUsers ? const Color.fromARGB(237, 32, 212, 0) : Colors.grey[700],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              "Show Group Boats",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              showOnlyGroupUsers ? Icons.check_circle : Icons.radio_button_unchecked,
                                              color: Colors.white,
                                              size: 20,
                                            ), 
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                  Positioned(
                    top: 105,
                    right: 10,
                    child: Column(
                      children: [
                        _buildWindText(() async {
                         //   bool hasAccess = await customBottomSection.currentState!.isSubscribed();
                         //   print(hasAccess);
                           // if (hasAccess) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => HomeScreenWeather()),
                              );
                            // } else {
                            //   Future.delayed(const Duration(seconds: 2), () {
                            //     showSalePopup(context);
                            //   });
                            //   ScaffoldMessenger.of(context).showSnackBar(
                            //     SnackBar(content: Text('This feature is for subscribed users only.')),
                            //   );
                            // }
                          }),

                      ],
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 320,
                    child: Listener(
                      onPointerDown: (_) async {
                        // bool hasAccess = await customBottomSection.currentState!.isSubscribed();
                        // if (hasAccess) {
                        //   final result = await Connectivity().checkConnectivity();
                        //   if (result == ConnectivityResult.none && mainScreenKey.currentState!.isOfflineScreenShown == false) {
                        //     rootScaffoldKey.currentState?.showSnackBar(
                        //       const SnackBar(
                        //         content: Text("No internet connection"),
                        //         backgroundColor: Colors.red,
                        //         behavior: SnackBarBehavior.floating,
                        //       ),
                        //     );
                        //     return;
                        //   } else {
                            customBottomSection.currentState?.initSpeech();
                            _showMicPopup(context);
                        //   // }
                        // } else {
                        //   Future.delayed(const Duration(seconds: 2), () {
                        //     showSalePopup(context);
                        //   });
                        //   ScaffoldMessenger.of(context).showSnackBar(
                        //     const SnackBar(content: Text('This feature is for subscribed users only.')),
                        //   );
                        // }
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic, size: 22, color: Colors.white),
                            SizedBox(height: 2),
                            Text(
                              'AI',
                              style: TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 70,
                    left: 20,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: ((_headings ?? 0) * (3.1415926535 / 180) * -1),
                          child: Image.asset(
                            "assets/maris/my_direction.png",
                            width: 70,
                            height: 70,
                          ),
                        ),
                        Text(
                          direction(_heading ?? 0),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (currentLocation != const LatLng(0, 0))
                    Positioned(
                      top: 55,
                      right: 10,
                      child: Column(
                        children: [
                          _buildTempBtn(() async {
                            // bool hasAccess = await customBottomSection.currentState!.isSubscribed();
                            // print(hasAccess);
                            // if (hasAccess) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => HomeScreenWeather()),
                              );
                            // } else {
                            //   Future.delayed(const Duration(seconds: 2), () {
                            //     showSalePopup(context);
                            //   });
                            //   ScaffoldMessenger.of(context).showSnackBar(
                            //     SnackBar(content: Text('This feature is for subscribed users only.')),
                            //   );
                            // }
                          }),
                        ],
                      ),
                    ),
                  Positioned(
                    left: 20,
                    bottom: 225,
                    child: InkWell(
                      onTap: () => showRoutesDialog(context),
                      child: Image.asset(
                        'assets/maris/saved_route.png',
                        width: 120,
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  if (_isCallActive && _showFloatingBtn)
                    Positioned(
                      bottom: 80,
                      right: 16,
                      child: Draggable(
                        feedback: _floatingCallButton(),
                        childWhenDragging: const SizedBox.shrink(),
                        child: _floatingCallButton(),
                      ),
                    ),
                    Obx(() {
                      final overlayObs = customBottomSection.currentState?.showOverlay;
                      // GetX requires us to read at least one observable inside Obx.
                      // If overlayObs is null (during first frame), we read a dummy observable.
                      final isOverlayVisible = overlayObs?.value ?? false.obs.value;
                      if (isOverlayVisible) {
                        return Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    }),
                  CustomBottomSection(),
                ],
              ),
      ),
    );
  }

  bool _isCallActive = false;
  bool _showFloatingBtn = false;

  void notifyCallStatusChange({required bool active, required bool showBtn}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = mainScreenKey.currentState;
      Future.delayed(const Duration(seconds: 1), () {
        NotificationHelper.showPendingCallIfAny();
      });
      if (state != null && state.mounted) {
        state.setState(() {
          state._isCallActive = active;
          state._showFloatingBtn = showBtn;
        });
      }
    });
  }

  Widget _floatingCallButton() {
    return GestureDetector(
      onTap: () {
        Get.toNamed('/callScreen');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: const Icon(Icons.call, color: Colors.white),
      ),
    );
  }

  Widget _buildTopOverlay() {
    return Positioned(
      bottom: 280,
      right: 10,
      child: Column(
        children: [
          if (_showClearButton) _buildClearBtn(),
          SizedBox(height: 3),
          _buildFishButton(openFishBase),
          SizedBox(height: 3),
          _buildAISButton(),
          SizedBox(height: 3),
          _buildToggleFollow(),
          SizedBox(height: 3),
          _buildLayersBtn(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return FloatingActionButton.extended(
      onPressed: _toggleAISView,
      backgroundColor: Colors.white.withOpacity(0.7),
      elevation: 0,
      label: Text(
        "See Ships Here",
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _getLocationBtn() {
    return Positioned(
      top: 40,
      left: 20,
      child: Column(
        children: [
          _buildIconButton(_centerToCurrentLocation),
        ],
      ),
    );
  }

  Widget _buildAISButtonView() {
    return FloatingActionButton(
      heroTag: null,
      mini: true,
      onPressed: _toggleAISView,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Image.asset(
        isAisOn ? "assets/maris/ais_btn.png" : "assets/maris/ais_pressed.png",
        width: 50,
        height: 50,
      ),
    );
  }

  bool _showSpeed = true;

  void _hideSpeed() {
    setState(() {
      _showSpeed = false;
    });
  }

  void _showSpeedAgain() {
    setState(() {
      _showSpeed = true;
    });
  }

  Widget _buildSpeedUI() {
    return Positioned(
      bottom: 90,
      left: 3,
      right: 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: animation,
              child: child,
            ),
          );
        },
        child: _showSpeed
            ? GestureDetector(
                onTap: _hideSpeed,
                key: const ValueKey(1),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 150,
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          "assets/maris/rectknots.png",
                          width: 135,
                          height: 125,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: "${speed_of_boat.toStringAsFixed(0)}\n",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Arial',
                                    color: Colors.black,
                                    height: 1.2,
                                  ),
                                ),
                                TextSpan(
                                  text: speedUnit,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    fontFamily: 'Arial',
                                    color: Colors.black,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : GestureDetector(
                onTap: _showSpeedAgain,
                key: const ValueKey(2),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double width = constraints.maxWidth;
                        final double scale = width / 360;
                        return SizedBox(
                          width: width,
                          height: 122 * scale,
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 500),
                                  child: Image.asset(
                                    isRecording ? "assets/maris/new_bottom_red.png" : "assets/maris/new_bottom.png",
                                    key: ValueKey(isRecording),
                                    width: width,
                                    height: 120 * scale,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.center,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "${speed_of_boat.toStringAsFixed(0)}\n",
                                        style: TextStyle(
                                          fontSize: 22 * scale,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Arial',
                                          color: Colors.black,
                                          height: 1.2,
                                        ),
                                      ),
                                      TextSpan(
                                        text: speedUnit,
                                        style: TextStyle(
                                          fontSize: 16 * scale,
                                          fontWeight: FontWeight.normal,
                                          fontFamily: 'Arial',
                                          color: Colors.black,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  customBottomSection.currentState?.OpenPttView();
                                },
                                child: Opacity(
                                  opacity: 0.05,
                                  child: Image.asset(
                                    "assets/maris/Rectangle_red.png",
                                    width: 100 * scale,
                                    height: 40 * scale,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 25 * scale,
                                top: 45 * scale,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "$distanceText\n",
                                        style: TextStyle(
                                          fontSize: 24 * scale,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Arial',
                                          color: Colors.black,
                                          height: 1.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: "Distance (km)",
                                        style: TextStyle(
                                          fontSize: 12 * scale,
                                          fontWeight: FontWeight.normal,
                                          fontFamily: 'Arial',
                                          color: Colors.black,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Positioned(
                                right: 10 * scale,
                                top: 0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (!isRecording) {
                                        //  toggleRouteRecording(context);
                                          startTrip();
                                        } else {
                                          _saveRoute();
                                        }
                                      },
                                      child: Opacity(
                                        opacity: 0.05,
                                        child: Image.asset(
                                          "assets/maris/Rectangle_red.png",
                                          width: 80 * scale,
                                          height: 40 * scale,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 8 * scale),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: "$timeText\n",
                                            style: TextStyle(
                                              fontSize: 24 * scale,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Arial',
                                              color: Colors.black,
                                              height: 1.2,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "Time (min)",
                                            style: TextStyle(
                                              fontSize: 12 * scale,
                                              fontWeight: FontWeight.normal,
                                              fontFamily: 'Arial',
                                              color: Colors.black,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _toggleAISView() async {
  //  bool hasAccess = await customBottomSection.currentState!.isSubscribed();
  //  if (hasAccess) {
      setState(() {
        isAisOn = !isAisOn;
      });
      final bounds = _mapController.camera.visibleBounds;
      final southWest = bounds.southWest;
      final northEast = bounds.northEast;
      print("SW: ${southWest.latitude}, ${southWest.longitude}");
      print("NE: ${northEast.latitude}, ${northEast.longitude}");
      Provider.of<AISService>(context, listen: false).toggleShipsVisibilityWithBounds(bounds);
    // } else {
    //   Future.delayed(const Duration(seconds: 2), () {
    //     showSalePopup(context);
    //   });
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('This feature is for subscribed users only.')),
    //   );
//    }
  }

  void _toggleAIS() async {
    // bool hasAccess = await customBottomSection.currentState!.isSubscribed();
    // print(hasAccess);
    // if (hasAccess) {
      setState(() {
        isAisOn = !isAisOn;
      });
      var boundingBox = _calculateBoundingBox(currentLocation, SliderAis);
      Provider.of<AISService>(context, listen: false).toggleShipsVisibility(currentLocation, SliderAis);
    // } else {
    //   Future.delayed(const Duration(seconds: 2), () {
    //     showSalePopup(context);
    //   });
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('This feature is for subscribed users only.')),
    //   );
    // }
  }

  Future<void> openFishBase() async {
    final url = Uri.parse('https://fishbase.se/search.php');
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.inAppWebView,
      );
    } else {
      throw 'Could not launch $url';
    }
  }

  void _showSnackBar(String Title, String message) {
    Get.snackbar(
      Title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 2),
      backgroundColor: const Color.fromARGB(255, 41, 164, 246),
      colorText: Colors.white,
    );
  }

  Widget _buildFishButton(VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color.fromARGB(0, 0, 0, 0),
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                "assets/maris/fish_btn.png",
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 110,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color.fromARGB(0, 0, 0, 0),
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                "assets/maris/rect_main.png",
                width: 125,
                height: 40,
                fit: BoxFit.fill,
              ),
              Text(
                'Get Location',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWindText(VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 100,
          height: 40,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Image.asset(
                "assets/maris/wind.png",
                width: 100,
                height: 40,
                fit: BoxFit.fill,
              ),
              Positioned(
                bottom: 12,
                right: 16,
                child: Text(
                  "$windSpeedText$WindspeedUnit",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTempBtn(VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 90,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color.fromARGB(0, 0, 0, 0),
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                "assets/maris/weather.png",
                width: 90,
                height: 50,
                fit: BoxFit.fill,
              ),
              Positioned(
                top: 6,
                right: 8,
                child: Text(
                  tempText,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _loadShowMyLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool value = prefs.getBool('showMyLocation') ?? false;
    setState(() {
      ShowMyLocation = value;
    });
    print(ShowMyLocation);
  }


Future<bool> handleLimitedButtonPress({
  required BuildContext context,
  required String buttonId,
}) async {
  print("handleLimitedButtonPress called for buttonId: $buttonId");

  final prefs = await SharedPreferences.getInstance();
  print("SharedPreferences loaded");

  final today = DateTime.now().toIso8601String().substring(0, 10);
  print("Today is $today");

  final dateKey = 'date_$buttonId';
  final countKey = 'count_$buttonId';

  int count = prefs.getInt(countKey) ?? 0;
  final lastDate = prefs.getString(dateKey);

  print("Last date for this button: $lastDate");
  print("Current count for this button: $count");

  // Reset if new day
  if (lastDate != today) {
    print("New day detected, resetting count to 0");
    await prefs.setBool("allowedAll", false);
    count = 0;
    await prefs.setString(dateKey, today);
  }

  // Limit reached
  if (count >= 5) {
    print("Limit reached for $buttonId, count: $count");
    Future.delayed(const Duration(seconds: 2), () {
      print("Showing sale popup for $buttonId");
      showSalePopup(context);
    });
    return false; // action not allowed
  }

  // Increase count
  count++;
  await prefs.setInt(countKey, count);
  print("Count increased for $buttonId, new count: $count");
  if(buttonId == "PTT"){
 ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("$count/5 Chats Remaining"),
      duration: const Duration(seconds: 2),
    ),
  );
  return true; // action allowed
  }
  else{
     ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("$count/5 Questions Remaining"),
      duration: const Duration(seconds: 2),
    ),
  );
  return true; // action allowed
  }
}


  void _toggleMyLocation() async {
    // bool hasAccess = await customBottomSection.currentState!.isSubscribed();
    // if (hasAccess) {
 LocationPermission permission = await Geolocator.checkPermission();
   if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please allow location from settings to use this feature')),
      );
      return;
    }

      setState(() {
        ShowMyLocation = !ShowMyLocation;
      });
      print("$ShowMyLocation, Show Me");
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('showMyLocation', ShowMyLocation);
      LocationUpdater().startLocationUpdates();
      listenForUserLocations();
   // }
  }

  Widget _buildHideMeButton() {
    return IconButton(
      onPressed: _toggleMyLocation,
      icon: Image.asset(
        ShowMyLocation ? "assets/maris/hideme.png" : "assets/maris/showme.png",
        width: 120,
        height: 50,
      ),
      padding: EdgeInsets.zero,
      splashRadius: 28,
    );
  }

  Widget _buildButtonWithTextAndIcon({
    required String assetPath,
    required Widget label,
    required String iconPath,
    VoidCallback? onTap,
    double minWidth = 110,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minWidth: minWidth,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(assetPath),
            fit: BoxFit.fill,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconPath.isNotEmpty) Image.asset(iconPath, width: 20, height: 20),
            if (iconPath.isNotEmpty) const SizedBox(width: 8),
            Flexible(child: label),
          ],
        ),
      ),
    );
  }

  Widget _buildClearBtn() {
    return FloatingActionButton(
      heroTag: null,
      mini: true,
      onPressed: _clearMap,
      backgroundColor: Colors.white,
      child: Icon(Icons.clear, color: Colors.red),
    );
  }

  Widget _buildLayersBtn() {
    return FloatingActionButton(
      heroTag: null,
      mini: true,
      onPressed: () async => await ToggleSeaDepth(),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Image.asset(
        isDepthShow ? "assets/maris/layers.png" : "assets/maris/layers_pressed.png",
        width: 50,
        height: 50,
      ),
    );
  }

  Widget _buildToggleFollow() {
    return FloatingActionButton(
      heroTag: null,
      mini: true,
      onPressed: ToggleFollowing,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Image.asset(
        isFollow ? "assets/maris/tracker.png" : "assets/maris/tracker_red.png",
        width: 50,
        height: 50,
      ),
    );
  }

  bool isListening = false;
  ValueNotifier<String> statusNotifier = ValueNotifier("👉 Hold & Press to Talk");

  void updateStatus(String text) {
    statusNotifier.value = text;
  }

  void _showMicPopup(BuildContext context) async {

  
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void startListening() async {
 bool hasAccess = await customBottomSection.currentState!.isSubscribed();
                        if (!hasAccess) {
                final allowed = await handleLimitedButtonPress(context: context, buttonId: 'AI');
        if (!allowed) return;
                        }
                        
              setState(() {
                isListening = true;
              });
              customBottomSection.currentState?.startListening();
            }

            void stopListening() {
              setState(() {
                isListening = false;
              });
              customBottomSection.currentState?.stopListeningAndSend();
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(20),
                width: 380,
                height: 440,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    Text(
                      "MariSpeak Ai",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Listener(
                      onPointerDown: (_) => startListening(),
                      onPointerUp: (_) => stopListening(),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1.0, end: isListening ? 1.2 : 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Container(
                            width: 180 * value,
                            height: 180 * value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isListening ? Colors.redAccent : Colors.blue,
                            ),
                            child: const Icon(Icons.mic, size: 60, color: Colors.white),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<String>(
                      valueListenable: statusNotifier,
                      builder: (context, value, child) {
                        return Text(
                          value,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


void _showShipDetails(Ship ship) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(ship.name),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _info("MMSI", ship.mmsi),
            _info("IMO", ship.imo ?? "N/A"),
            _info("Call Sign", ship.callSign ?? "N/A"),
            _info("Type", ship.shipType ?? "Unknown"), 
            const Divider(),
            _info("Speed", "${ship.speed ?? 0} kn"),
            _info("Course", "${ship.course ?? 0}°"),
            _info("Heading", "${ship.heading ?? 0}°"),
            _info("Nav Status", ship.navStatus ?? "N/A"),
            const Divider(),
            _info("Destination", ship.destination ?? "N/A"),
            _info("ETA", ship.eta ?? "N/A"),
            _info("Draught", ship.draught != null ? "${ship.draught} m" : "N/A"),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );
}

Widget _info(String label, dynamic value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text("$label: $value"),
  );
}

Future<void> showRemainingMinutesSnack(
  BuildContext context,
  UsageType type,
) async {
  final seconds =
      await DailyUsageTimer().getRemainingSeconds(type);

  final minutes = (seconds / 60).ceil();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("Remaining daily allowance $minutes min"),
      duration: const Duration(seconds: 2),
    ),
  );

  print("Remaining minutes ($type): $minutes");
}

Future<void> ToggleSeaDepth() async {



     bool hasAccess = await customBottomSection.currentState!.isSubscribed();
        if(!hasAccess){

            if(LayerTodayTimeEnd) {
        showSalePopup(context); 
        return;
        }

  if (!isRunningLayers) {
    
  // Toggle feature UI
  setState(() {
    isDepthShow = !isDepthShow;
  });

    await _dailyTimer.start(
      type: UsageType.layers,
      context: context,
      onLimitReached: () {
        showSalePopup(context);
        isRunningLayers = false;
        LayerTodayTimeEnd = true;
        
  // Toggle feature UI
  setState(() {
    isDepthShow = !isDepthShow;
  });
        // ❌ DO NOT call ToggleSeaDepth() here
      },
    );

    // mark running ONLY after successful start
    isRunningLayers = true;

    await showRemainingMinutesSnack(
      context,
      UsageType.layers, // ✅ MATCH TYPE
    );
  } else {
    await _dailyTimer.stop(UsageType.layers);

    isRunningLayers = false;

  // Toggle feature UI
  setState(() {
    isDepthShow = !isDepthShow;
  });
    await showRemainingMinutesSnack(
      context,
      UsageType.layers, // ✅ MATCH TYPE
    );
  }
      
  _updateMapLayers();
        }
        else{
           // Toggle feature UI
  setState(() {
    isDepthShow = !isDepthShow;
  });

  _updateMapLayers();
        }
}

  void ToggleFollowing() async {
    
   LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please allow location from settings to use this feature')),
      );
      return;
    }

    setState(() {
      isFollow = !isFollow;
    });
    if (isFollow) {
      _showSnackBar("Camera", "Following");
    } else {
      _showSnackBar("Camera:", "Not Following");
    }
    _updateMapLayers();
  }

  Widget _buildAISButton() {
    return FloatingActionButton(
      heroTag: null,
      mini: false,
      onPressed: _toggleAIS,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Image.asset(
        isAisOn ? "assets/maris/ais_btn.png" : "assets/maris/ais_pressed.png",
        width: 42,
        height: 42,
      ),
    );
  }
}

Future<void> switchToPlaybackMode() async {
  Future.delayed(const Duration(milliseconds: 10), () async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint("switchToPlaybackMode ignored error: $e");
    }
  });
}


class DailyUsageTimer {
  static const int plotterMaxSeconds = 20 * 60; // 20 mins
  static const int layersMaxSeconds = 30 * 60;  // 30 mins

  /// 🔑 One timer per usage type
  final Map<UsageType, Timer> _timers = {};

  int _maxFor(UsageType type) {
    return type == UsageType.plotter
        ? plotterMaxSeconds
        : layersMaxSeconds;
  }

  String _usedKey(UsageType type) => '${type.name}_used';
  String _startKey(UsageType type) => '${type.name}_start';
  String _dateKey(UsageType type) => '${type.name}_date';

  /// ================= START =================
  Future<void> start({
    required UsageType type,
    required BuildContext context,
    required VoidCallback onLimitReached,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final maxSeconds = _maxFor(type);

    _resetIfNewDay(prefs, today, type);

    int usedSeconds = prefs.getInt(_usedKey(type)) ?? 0;

    if (usedSeconds >= maxSeconds) {
      onLimitReached();
      return;
    }

    // Already running → do nothing
    if (prefs.containsKey(_startKey(type))) return;

    await prefs.setInt(
      _startKey(type),
      DateTime.now().millisecondsSinceEpoch,
    );

    // Cancel only THIS type’s timer
    _timers[type]?.cancel();

    _timers[type] = Timer.periodic(
      const Duration(seconds: 1),
      (_) async {
        int currentUsed = _calculateUsed(prefs, type);

        if (currentUsed >= maxSeconds) {
          await stop(type);
          onLimitReached();
        }
      },
    );
  }

  /// ================= STOP =================
  Future<void> stop(UsageType type) async {
    final prefs = await SharedPreferences.getInstance();

    final start = prefs.getInt(_startKey(type));
    if (start != null) {
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - start) ~/ 1000;

      final used = prefs.getInt(_usedKey(type)) ?? 0;
      await prefs.setInt(_usedKey(type), used + elapsed);
      await prefs.remove(_startKey(type));
    }

    _timers[type]?.cancel();
    _timers.remove(type);
  }

  /// ================= REMAINING =================
  Future<int> getRemainingSeconds(UsageType type) async {
    final prefs = await SharedPreferences.getInstance();
    return _maxFor(type) - _calculateUsed(prefs, type);
  }

  /// ================= CALCULATE =================
  int _calculateUsed(SharedPreferences prefs, UsageType type) {
    int used = prefs.getInt(_usedKey(type)) ?? 0;
    int? start = prefs.getInt(_startKey(type));

    if (start != null) {
      int diff =
          ((DateTime.now().millisecondsSinceEpoch - start) / 1000).floor();
      used += diff;
    }
    return used;
  }

  /// ================= RESET =================
  void _resetIfNewDay(
    SharedPreferences prefs,
    String today,
    UsageType type,
  ) {
    final lastDate = prefs.getString(_dateKey(type));

    if (lastDate != today) {
      if (type == UsageType.plotter) {
        prefs.setBool("_plotterLimitKey", false);
      }

      prefs.setString(_dateKey(type), today);
      prefs.setInt(_usedKey(type), 0);
      prefs.remove(_startKey(type));
    }
  }

  String _today() =>
      DateTime.now().toIso8601String().substring(0, 10);
}