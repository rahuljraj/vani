// lib/services/bubble_service.dart
//
// Dart side of the floating-bubble Labs feature (default OFF).
// The bubble is additive: the Quick Settings tile remains the default
// launcher. Play approval + OxygenOS survival are ⏳ UNVERIFIED — see
// docs/play-bubble-permissions.md and docs/future-device-checklist.md.

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class BubbleService {
  static BubbleService? _instance;
  static BubbleService get instance => _instance ??= BubbleService._();
  BubbleService._();

  final _channel = const MethodChannel('com.vani/app_actions');
  final _log = Logger();

  Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } catch (e) {
      _log.e('hasOverlayPermission failed: $e');
      return false;
    }
  }

  /// Opens the system "Display over other apps" settings page.
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      _log.e('requestOverlayPermission failed: $e');
    }
  }

  /// Starts the bubble foreground service. False = permission missing or
  /// service refused to start.
  Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('startBubble') ?? false;
    } catch (e) {
      _log.e('startBubble failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopBubble');
    } catch (e) {
      _log.e('stopBubble failed: $e');
    }
  }

  Future<bool> isRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isBubbleRunning') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Cold-start path: bring the bubble back if the flag was left on AND the
  /// overlay permission still exists. No boot receiver by design — after a
  /// reboot the bubble returns the next time VANI opens.
  Future<bool> startIfPermitted() async {
    if (!await hasOverlayPermission()) {
      _log.w('🫧 Bubble flag on but overlay permission missing — not starting');
      return false;
    }
    return start();
  }
}
