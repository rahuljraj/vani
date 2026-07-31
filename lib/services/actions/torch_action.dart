// lib/services/actions/torch_action.dart
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class TorchAction {
  static final _log = Logger();
  static const _channel = MethodChannel('com.vani/app_actions');

  /// Toggles the device torch. Returns false if the device has no flash
  /// or the camera is in use by another app.
  static Future<bool> setTorch(bool on) async {
    try {
      final ok = await _channel.invokeMethod<bool>('setTorch', {'on': on});
      return ok ?? false;
    } catch (e) {
      _log.e('setTorch failed: $e');
      return false;
    }
  }
}