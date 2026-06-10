// lib/services/wake_word_service.dart
//
// Dart side of the in-app "Hey VANI" wake word (Labs, default OFF).
// Engine: native Vosk KWS (VaniWakeWord.kt). Mic discipline:
//   - runs ONLY while the app is foregrounded (home screen stops it on
//     every lifecycle pause) — no background mic, no new permissions
//   - fully released before Google STT listens, restarted when idle again
// Battery + false-trigger rates are ⏳ UNVERIFIED — docs/wake-word-eval.md.

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../core/feature_flags.dart';

class WakeWordService {
  static WakeWordService? _instance;
  static WakeWordService get instance => _instance ??= WakeWordService._();
  WakeWordService._();

  final _channel = const MethodChannel('com.vani/app_actions');
  final _log = Logger();

  void Function()? _onWake;
  bool _engineOn = false;
  String? lastError;

  bool get isOn => _engineOn;

  /// Registers the trigger callback. This is the ONLY Dart-side
  /// setMethodCallHandler on the shared channel — keep it that way.
  void registerHandler(void Function() onWake) {
    _onWake = onWake;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWakeWord') {
        _log.i('🗣️ Wake word triggered');
        _onWake?.call();
      }
      return null;
    });
  }

  /// Starts the native engine. Returns null on success, or a reason code:
  /// 'flag_off', 'model_missing', 'init_failed: …', 'native_missing: …'.
  Future<String?> start() async {
    if (!FeatureFlags.wakeWord.value) return 'flag_off';
    try {
      final err = await _channel.invokeMethod<String>('wakeWordStart');
      _engineOn = err == null;
      lastError = err;
      if (err != null) _log.w('🗣️ Wake word start failed: $err');
      return err;
    } catch (e) {
      _engineOn = false;
      lastError = '$e';
      return '$e';
    }
  }

  Future<void> stop() async {
    _engineOn = false;
    try {
      await _channel.invokeMethod('wakeWordStop');
    } catch (e) {
      _log.e('wakeWordStop failed: $e');
    }
  }

  /// Where the Vosk model directory must live (Labs shows this to the user).
  Future<String> modelPath() async {
    try {
      return await _channel.invokeMethod<String>('wakeWordModelPath') ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Release the mic BEFORE Google STT grabs it. Engine stays logically on
  /// (_engineOn untouched) so resumeAfterStt restarts it.
  Future<void> pauseForStt() async {
    if (!FeatureFlags.wakeWord.value || !_engineOn) return;
    try {
      await _channel.invokeMethod('wakeWordStop');
    } catch (_) {}
  }

  /// Restart KWS once the voice command is done and the mic is free.
  Future<void> resumeAfterStt() async {
    if (!FeatureFlags.wakeWord.value || !_engineOn) return;
    try {
      await _channel.invokeMethod<String>('wakeWordStart');
    } catch (_) {}
  }
}
