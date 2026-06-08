// lib/services/permission_service.dart

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

class PermissionService {
  static PermissionService? _instance;
  static PermissionService get instance =>
    _instance ??= PermissionService._();
  PermissionService._();

  final _log     = Logger();
  final _channel = const MethodChannel('com.vani/app_actions');

  // ── Microphone ─────────────────────────────────
  Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    _log.d('Microphone: $status');
    return status.isGranted;
  }

  Future<bool> get hasMicrophone async =>
    await Permission.microphone.isGranted;

  // ── Accessibility Service ──────────────────────
  Future<bool> get hasAccessibility async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isAccessibilityEnabled'
      );
      return result ?? false;
    } catch (e) {
      _log.e('Accessibility check error: $e');
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      _log.e('Open accessibility settings error: $e');
    }
  }

  // ── App Installed Check ────────────────────────
  Future<bool> isAppInstalled(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isAppInstalled',
        {'packageName': packageName},
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  // ── Set Pending Action ─────────────────────────
  Future<void> setPendingAction(String action, String data) async {
    try {
      await _channel.invokeMethod('setPendingAction', {
        'action': action,
        'data':   data,
      });
    } catch (e) {
      _log.e('Set pending action error: $e');
    }
  }

  // ── Quick Settings tile auto-listen flag ──────
  // Native sets this when VANI is opened via the QS tile.
  // Returns true once, then clears (one-shot).
  Future<bool> consumeAutoListen() async {
    try {
      final result = await _channel.invokeMethod<bool>('consumeAutoListen');
      return result ?? false;
    } catch (e) {
      _log.e('consumeAutoListen error: $e');
      return false;
    }
  }

  // ── All Files Access (MANAGE_EXTERNAL_STORAGE) ─
  Future<bool> get hasAllFilesAccess async =>
      await Permission.manageExternalStorage.isGranted;

  // On Android 11+, this opens the "All files access" system settings screen.
  // Returns true if granted after returning from settings.
  Future<bool> requestAllFilesAccess() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    _log.d('MANAGE_EXTERNAL_STORAGE: $status');
    return status.isGranted;
  }

  // ── Check All Required Permissions ────────────
  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'microphone':   await hasMicrophone,
      'accessibility': await hasAccessibility,
    };
  }

  // ── Request All Required Permissions ──────────
  Future<bool> requestAll() async {
    final mic = await requestMicrophone();
    if (!mic) return false;
    // Accessibility is opened in settings — can't request programmatically
    return true;
  }
}
