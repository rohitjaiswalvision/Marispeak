import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:marispeaks/config/app_config.dart';

/// =======================
/// SHIP MODEL
/// =======================
class Ship {
  final int mmsi;

  // Static info
  String name;
  String? callSign;
  int? imo;
  String? shipType; // <-- This will now be messageType
  int? length;
  int? width;

  // Dynamic info
  LatLng position;
  double? speed; // SOG
  double? course; // COG
  double? heading;
  String? navStatus;

  // Voyage
  String? destination;
  String? eta;
  double? draught;

  DateTime lastUpdate;

  Ship({
    required this.mmsi,
    required this.name,
    required this.position,
    this.callSign,
    this.imo,
    this.shipType,
    this.length,
    this.width,
    this.speed,
    this.course,
    this.heading,
    this.navStatus,
    this.destination,
    this.eta,
    this.draught,
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();
}

/// =======================
/// AIS SERVICE
/// =======================
class AISService extends ChangeNotifier {
  final String wsUrl = "wss://stream.aisstream.io/v0/stream";

  final Map<int, Ship> _ships = {};
  Map<int, Ship> get ships => _ships;

  WebSocketChannel? _channel;

  bool isConnected = false;
  bool showShips = false;

  bool _dirty = false;

  /// =======================
  /// CONNECT
  /// =======================
  void connectToAIS(LatLng center, double rangeKm) {
    if (isConnected) return;

    try {
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      final boundingBoxes = _calculateBoundingBox(center, rangeKm);

      final sub = jsonEncode({
        "APIKey": AppConfig.AisKey,
        "BoundingBoxes": boundingBoxes,
      });

      _channel!.sink.add(sub);

      _channel!.stream.listen(
        _onMessage,
        onError: (e) => debugPrint("❌ AIS error: $e"),
        onDone: () => isConnected = false,
      );

      isConnected = true;
      notifyListeners();
    } catch (e) {
      debugPrint("❌ AIS connection failed: $e");
    }
  }

  /// =======================
  /// MESSAGE HANDLER
  /// =======================
  void _onMessage(dynamic message) {
    try {
      final decoded = message is String
          ? message
          : utf8.decode(message as List<int>);

      final data = jsonDecode(decoded);
      final type = data["MessageType"];

      if (!data.containsKey("Message")) return;

      _updateShipData(data, type);
    } catch (e) {
      debugPrint("❌ Decode error: $e");
    }
  }

  /// =======================
  /// UPDATE SHIP DATA
  /// =======================
  void _updateShipData(dynamic data, String messageType) {
    final msg = data["Message"]?[messageType];
    final meta = data["MetaData"];
    if (msg == null) return;

    // Ensure MMSI exists, fallback if missing
    final int mmsi = msg["UserID"] ?? Random().nextInt(999999999);

    // Create new ship if it doesn't exist
    _ships.putIfAbsent(
      mmsi,
      () => Ship(
        mmsi: mmsi,
        name: meta?["ShipName"] ?? "Unknown Ship",
        position: const LatLng(0, 0),
        shipType: messageType, // <-- ALWAYS store the messageType
      ),
    );

    // Update ship
    final ship = _ships[mmsi]!;
    ship.lastUpdate = DateTime.now();
    ship.shipType = messageType; // <-- update on every new message

    /// 🔵 POSITION
    if (messageType == "PositionReport" ||
        messageType == "StandardClassBPositionReport") {
      ship.position = LatLng(msg["Latitude"], msg["Longitude"]);
      ship.speed = msg["Sog"]?.toDouble();
      ship.course = msg["Cog"]?.toDouble();
      ship.heading = msg["TrueHeading"]?.toDouble();
      ship.navStatus = msg["NavigationalStatus"]?.toString();
    }

    /// 🟢 STATIC DATA
    if (messageType == "ShipStaticData") {
      ship.name = msg["Name"] ?? ship.name;
      ship.callSign = msg["CallSign"];
      ship.imo = msg["ImoNumber"];
      ship.length =
          (msg["DimensionToBow"] ?? 0) + (msg["DimensionToStern"] ?? 0);
      ship.width =
          (msg["DimensionToPort"] ?? 0) + (msg["DimensionToStarboard"] ?? 0);
    }

    /// 🟡 VOYAGE DATA
    if (messageType == "VoyageData") {
      ship.destination = msg["Destination"];
      ship.eta = msg["Eta"];
      ship.draught = msg["Draught"]?.toDouble();
    }

    // Debug log for payload
    debugPrint("🧾 AIS messageType: $messageType, MMSI: $mmsi");

    _markDirty();
  }

  /// =======================
  /// BATCH NOTIFY
  /// =======================
  void _markDirty() {
    if (_dirty) return;
    _dirty = true;

    Future.delayed(const Duration(milliseconds: 300), () {
      _dirty = false;
      notifyListeners();
    });
  }

  /// =======================
  /// BOUNDING BOX (KM)
  /// =======================
  List<List<List<double>>> _calculateBoundingBox(LatLng center, double rangeKm) {
    const earthRadiusKm = 6371.0;

    final lat = center.latitude;
    final lon = center.longitude;

    final dLat = (rangeKm / earthRadiusKm) * (180 / pi);
    final dLon = (rangeKm / earthRadiusKm) * (180 / pi) / cos(lat * pi / 180);

    return [
      [
        [(lat - dLat).clamp(-85.05, 85.05), (lon - dLon).clamp(-180, 180)],
        [(lat + dLat).clamp(-85.05, 85.05), (lon + dLon).clamp(-180, 180)],
      ]
    ];
  }

  /// =======================
  /// TOGGLE SHIPS USING MAP BOUNDS
  /// =======================
  void toggleShipsVisibilityWithBounds(LatLngBounds bounds) {
    showShips = !showShips;

    debugPrint(
      showShips
          ? "👁️ Showing ships using map bounds"
          : "🙈 Hiding ships",
    );

    if (showShips) {
      if (!isConnected) {
        updateAISSubscriptionWithBounds(bounds);
      }
    } else {
      disconnect();
    }

    notifyListeners();
  }

  /// =======================
  /// MAP BOUNDS SUBSCRIBE
  /// =======================
  void updateAISSubscriptionWithBounds(LatLngBounds bounds) {
    disconnect();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      final sub = jsonEncode({
        "APIKey": AppConfig.AisKey,
        "BoundingBoxes": [
          [
            [bounds.south, bounds.west],
            [bounds.north, bounds.east],
          ]
        ]
      });

      _channel!.sink.add(sub);
      _channel!.stream.listen(_onMessage);

      isConnected = true;
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Bounds subscription failed: $e");
    }
  }

  /// =======================
  /// VISIBILITY
  /// =======================
  void toggleShipsVisibility(LatLng center, double km) {
    showShips = !showShips;

    if (showShips) {
      connectToAIS(center, km);
    } else {
      disconnect();
    }

    notifyListeners();
  }

  /// =======================
  /// CLEANUP
  /// =======================
  void clearShips() {
    _ships.clear();
    notifyListeners();
  }

  void disconnect() {
    if (!isConnected) return;

    _channel?.sink.close();
    isConnected = false;
  }
}
