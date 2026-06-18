import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// VoIP service that bridges iOS PushKit VoIP tokens and push events
/// to the Flutter layer. Only active on iOS.
class VoIPService {
  static final VoIPService _instance = VoIPService._internal();
  factory VoIPService() => _instance;
  VoIPService._internal();

  static const _channel = MethodChannel('ptt/voip');

  String? _voipToken;
  String? get voipToken => _voipToken;

  // Callback that gets called when a VoIP push arrives while app is
  // in background/locked — use this to trigger PTT audio playback
  Function(Map<String, String>)? onVoIPPushReceived;
  Function(String?)? onVoIPTokenRefreshed; // ✅ NEW: fires when iOS issues a fresh token
  Function()? onCallAnswered;
  Function()? onCallEnded;

  /// Initialize the service and start listening for VoIP events from iOS.
  Future<void> initialize() async {
    if (!Platform.isIOS) return;

    // Set up method call handler for events coming FROM native iOS
    _channel.setMethodCallHandler(_handleNativeCall);

    // Try to fetch a cached VoIP token (might already be stored)
    try {
      final token = await _channel.invokeMethod<String>('getVoIPToken');
      if (token != null && token.isNotEmpty) {
        _voipToken = token;
        debugPrint('📲 Cached VoIP Token: $_voipToken');
      }
    } catch (e) {
      debugPrint('⚠️ Could not fetch cached VoIP token: $e');
    }
  }

  /// ✅ Call this on every app resume to handle pushes received while locked/killed.
  /// Native side stores payload in UserDefaults when Flutter isn't ready.
  Future<void> checkPendingVoIPPayload() async {
    if (!Platform.isIOS) return;
    try {
      final raw = await _channel.invokeMethod<Map>('getPendingVoIPPayload');
      if (raw != null && raw.isNotEmpty) {
        final payload = Map<String, String>.from(
          raw.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
        debugPrint('📦 Pending VoIP payload found on resume: $payload');
        onVoIPPushReceived?.call(payload);
        // Clear it from native side
        await _channel.invokeMethod('clearPendingVoIPPayload');
      }
    } catch (e) {
      debugPrint('⚠️ checkPendingVoIPPayload error: $e');
    }
  }

  /// Check if the iOS app is truly in the background/inactive
  Future<bool> isAppInBackground() async {
    if (!Platform.isIOS) return false;
    try {
      final isBackground = await _channel.invokeMethod<bool>('isAppInBackground');
      return isBackground ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Handles method calls from the iOS native side (AppDelegate)
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onVoIPToken':
        // iOS sent us a new/updated VoIP push token
        _voipToken = call.arguments as String?;
        debugPrint('📲 New VoIP Token received: $_voipToken');
        // ✅ FIX: Immediately notify the PTT controller so it forwards the
        // token to the server. Previously the token arrived but was never sent.
        onVoIPTokenRefreshed?.call(_voipToken);
        break;

      case 'onVoIPPush':
        // iOS woke the app via a VoIP push — audio should now be played
        debugPrint('📨 VoIP Push received in Flutter');
        final raw = call.arguments;
        if (raw is Map) {
          final payload = Map<String, String>.from(
            raw.map((k, v) => MapEntry(k.toString(), v.toString())),
          );
          debugPrint('📨 VoIP payload: $payload');
          onVoIPPushReceived?.call(payload);
        }
        break;

      case 'onCallAnswered':
        debugPrint('📞 User tapped Answer on CallKit screen');
        onCallAnswered?.call();
        break;

      case 'onCallEnded':
        debugPrint('📞 User tapped Decline on CallKit screen');
        onCallEnded?.call();
        break;

      default:
        debugPrint('⚠️ VoIPService: unknown method ${call.method}');
    }
  }
}
