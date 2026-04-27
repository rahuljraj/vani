// lib/models/vani_intent.dart

import 'dart:convert';

class VaniIntent {
  final IntentType type;
  final AppTarget  app;
  final Map<String, String> parameters;
  final String speakText;
  final String actionCode;

  const VaniIntent({
    required this.type,
    required this.app,
    required this.parameters,
    required this.speakText,
    required this.actionCode,
  });

  factory VaniIntent.fromJson(Map<String, dynamic> json) {
    return VaniIntent(
      type: IntentType.parse(json['intent'] as String? ?? 'chat'),
      app:  AppTarget.parse(json['app']    as String? ?? 'none'),
      parameters: _parseParams(json['parameters']),
      speakText:  json['speak']  as String? ?? 'Kuch samajh nahi aaya',
      actionCode: json['action'] as String? ?? 'none',
    );
  }

  // Parse from raw Gemma 4 response string
  factory VaniIntent.fromRaw(String raw) {
    try {
      String cleaned = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final start = cleaned.indexOf('{');
      final end   = cleaned.lastIndexOf('}');

      if (start >= 0 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return VaniIntent.fromJson(json);
    } catch (_) {
      return VaniIntent.error();
    }
  }

  // Graceful error fallback — always on-device, no cloud
  factory VaniIntent.error() => const VaniIntent(
    type:       IntentType.chat,
    app:        AppTarget.none,
    parameters: {},
    speakText:  'Samajh nahi aaya. Dobara bolein?',
    actionCode: 'none',
  );

  // Loading state
  factory VaniIntent.loading() => const VaniIntent(
    type:       IntentType.chat,
    app:        AppTarget.none,
    parameters: {},
    speakText:  'Ek second...',
    actionCode: 'none',
  );

  static Map<String, String> _parseParams(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return raw.map((k, v) =>
        MapEntry(k.toString(), v?.toString() ?? ''));
    }
    return {};
  }

  bool get hasAppAction => app != AppTarget.none;
  bool get isError      => actionCode == 'none' && type == IntentType.chat;

  @override
  String toString() =>
    'VaniIntent(type=$type, app=$app, action=$actionCode)';
}

// ── Intent Types ────────────────────────────────

enum IntentType {
  navigate,
  orderFood,
  searchProduct,
  readMessages,
  sendMessage,
  setReminder,
  findNearby,
  playMedia,
  checkBalance,
  chat;

  static IntentType parse(String value) {
    return IntentType.values.firstWhere(
      (e) => e.name == _camel(value),
      orElse: () => IntentType.chat,
    );
  }

  static String _camel(String s) {
    final parts = s.split('_');
    if (parts.length == 1) return s;
    return parts.first +
        parts.skip(1).map((p) =>
          p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)
        ).join();
  }
}

// ── App Targets ─────────────────────────────────

enum AppTarget {
  googleMaps,
  blinkit,
  swiggy,
  zomato,
  whatsapp,
  youtube,
  amazon,
  flipkart,
  phonePe,
  none;

  static AppTarget parse(String value) {
    return AppTarget.values.firstWhere(
      (e) => e.name == _camel(value),
      orElse: () => AppTarget.none,
    );
  }

  static String _camel(String s) {
    final parts = s.split('_');
    if (parts.length == 1) return s;
    return parts.first +
        parts.skip(1).map((p) =>
          p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)
        ).join();
  }
}
