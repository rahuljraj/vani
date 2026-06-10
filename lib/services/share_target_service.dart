// lib/services/share_target_service.dart
//
// Dart side of the share-target Labs feature ("ye raju ko bhejo").
// VANI is a share TARGET: it handles only content the user explicitly
// shared to it from another app, asks (by voice) who to send it to, and
// forwards via WhatsApp as a DRAFT — the user always taps send.

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../core/feature_flags.dart';

class SharePayload {
  final String text;
  final String subject;
  final String mimeType;
  final List<String> uris;

  const SharePayload({
    required this.text,
    required this.subject,
    required this.mimeType,
    required this.uris,
  });

  bool get hasMedia => uris.isNotEmpty;
  bool get hasText  => text.isNotEmpty;

  /// Short human summary for the UI — "1 photo", "2 files", or the text.
  String get summary {
    if (hasMedia) {
      final kind = mimeType.startsWith('image/')
          ? 'photo'
          : mimeType.startsWith('video/') ? 'video' : 'file';
      return uris.length == 1 ? '1 $kind' : '${uris.length} ${kind}s';
    }
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  factory SharePayload.fromMap(Map<dynamic, dynamic> map) => SharePayload(
        text:     (map['text'] ?? '') as String,
        subject:  (map['subject'] ?? '') as String,
        mimeType: (map['mimeType'] ?? '') as String,
        uris:     ((map['uris'] ?? const []) as List)
            .map((e) => e.toString())
            .toList(),
      );
}

class ShareTargetService {
  static ShareTargetService? _instance;
  static ShareTargetService get instance =>
      _instance ??= ShareTargetService._();
  ShareTargetService._();

  final _channel = const MethodChannel('com.vani/app_actions');
  final _log = Logger();

  static const _whatsappPkg = 'com.whatsapp';

  /// One-shot: returns and clears the payload VANI was share-launched with.
  Future<SharePayload?> consumePending() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('consumeSharePayload');
      if (raw == null) return null;
      final payload = SharePayload.fromMap(raw);
      _log.i('📤 Share payload: ${payload.summary} (${payload.mimeType})');
      return payload;
    } catch (e) {
      _log.e('consumeSharePayload failed: $e');
      return null;
    }
  }

  /// Flips the manifest activity-alias so VANI appears in / disappears
  /// from the Android share sheet.
  Future<bool> setEnabled(bool enabled) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
          'setShareTargetEnabled', {'enabled': enabled});
      return ok ?? false;
    } catch (e) {
      _log.e('setShareTargetEnabled failed: $e');
      return false;
    }
  }

  /// Component enabled-state survives app-data clears; the flag doesn't.
  /// Called once at startup so the share sheet always matches the flag.
  Future<void> syncNativeState() async {
    await setEnabled(FeatureFlags.shareTarget.value);
  }

  /// Forwards shared media into WhatsApp (its own share/picker UI —
  /// the user picks the chat and taps send there).
  Future<bool> forwardMediaToWhatsApp(SharePayload payload) async {
    try {
      final ok = await _channel.invokeMethod<bool>('forwardShareToPackage', {
        'package':  _whatsappPkg,
        'text':     payload.text,
        'mimeType': payload.mimeType,
        'uris':     payload.uris,
      });
      return ok ?? false;
    } catch (e) {
      _log.e('forwardShareToPackage failed: $e');
      return false;
    }
  }
}
