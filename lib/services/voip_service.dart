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

  /// Handles method calls from the iOS native side (AppDelegate)
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onVoIPToken':
        // iOS sent us a new/updated VoIP push token
        _voipToken = call.arguments as String?;
        debugPrint('📲 New VoIP Token received: $_voipToken');
        // TODO: Send this token to your Railway backend so it knows
        // which APNs VoIP token to push to when a PTT message arrives.
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
