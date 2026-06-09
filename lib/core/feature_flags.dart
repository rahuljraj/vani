// lib/core/feature_flags.dart
//
// Runtime feature flags for everything still behind device or Play-review
// verification. ALL flags default OFF: with none enabled the app behaves
// identically to shipped v1.0. Toggles live on the Labs screen ('/labs').
//
// Rule: a feature graduates out of here (flag removed, always-on) only after
// its docs/future-device-checklist.md items pass on a real phone.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureFlags {
  FeatureFlags._();

  static const _kShareTarget    = 'ff_share_target';
  static const _kFloatingBubble = 'ff_floating_bubble';
  static const _kWakeWord       = 'ff_wake_word';

  /// VANI in the Android share sheet — "ye raju ko bhejo".
  static final shareTarget = ValueNotifier<bool>(false);

  /// Floating launcher bubble (SYSTEM_ALERT_WINDOW + special-use FGS).
  static final floatingBubble = ValueNotifier<bool>(false);

  /// In-app "Hey VANI" wake word (Vosk KWS, mic only while app is open).
  static final wakeWord = ValueNotifier<bool>(false);

  static SharedPreferences? _prefs;

  /// Loads persisted values. Call once in main() before runApp.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    shareTarget.value    = _prefs!.getBool(_kShareTarget)    ?? false;
    floatingBubble.value = _prefs!.getBool(_kFloatingBubble) ?? false;
    wakeWord.value       = _prefs!.getBool(_kWakeWord)       ?? false;
  }

  static Future<void> setShareTarget(bool on) async {
    shareTarget.value = on;
    await _prefs?.setBool(_kShareTarget, on);
  }

  static Future<void> setFloatingBubble(bool on) async {
    floatingBubble.value = on;
    await _prefs?.setBool(_kFloatingBubble, on);
  }

  static Future<void> setWakeWord(bool on) async {
    wakeWord.value = on;
    await _prefs?.setBool(_kWakeWord, on);
  }
}
