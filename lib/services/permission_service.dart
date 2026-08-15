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

    // ── Phone (CALL_PHONE) ─────────────────────────
  // Needed for ACTION_CALL. Without it CallAction falls back to opening the
  // dialer pre-filled — VANI still works, the user just taps green. Asked
  // during onboarding so the system dialog never lands mid voice command.
  Future<bool> requestPhone() async {
    final status = await Permission.phone.request();
    _log.d('Phone: $status');
    return status.isGranted;
  }

  Future<bool> get hasPhone async =>
    await Permission.phone.isGranted;



  // ── Assistant slot ─────────────────────────────
  // Cannot be requested — the assistant is a user choice in a secure setting.
  // We can only take them to the screen; they select VANI themselves.
  Future<void> openAssistantSettings() async {
    try {
      await _channel.invokeMethod('openAssistantSettings');
    } catch (e) {
      _log.e('Open assistant settings error: $e');
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

  // ── Check All Required Permissions ────────────
  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'microphone':    await hasMicrophone,
      'phone':         await hasPhone,
          };
  }

  // ── Request All Required Permissions ──────────
  Future<bool> requestAll() async {
    final mic = await requestMicrophone();
    if (!mic) return false;
    return true;
  }
}