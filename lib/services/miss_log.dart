// lib/services/miss_log.dart
//
// Records utterances that FastIntentEngine failed to route. This is the
// rule-gap roadmap for v1.2+ — 20 strangers will phrase things in ways
// that were never anticipated, and without this their first week is lost.
//
// Stays on the device. With allowBackup=false it is never synced off.
// Retrieval is manual and user-visible: the tester opens the log and
// chooses to share it. Nothing is uploaded.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class MissLog {
  static MissLog? _instance;
  static MissLog get instance => _instance ??= MissLog._();
  MissLog._();

  final _log = Logger();

  static const _key = 'vani_miss_log';
  static const _maxEntries = 200;

  /// Record an utterance VANI could not route. Never throws — a logging
  /// failure must not break the voice path.
  Future<void> record(String utterance) async {
    final text = utterance.trim();
    if (text.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? <String>[];

      raw.add(jsonEncode({
        't': DateTime.now().toIso8601String(),
        'u': text,
      }));

      // Keep the most recent entries only.
      if (raw.length > _maxEntries) {
        raw.removeRange(0, raw.length - _maxEntries);
      }

      await prefs.setStringList(_key, raw);
     print('🔎 miss logged: "$text" (${raw.length} total)');
    } catch (e) {
      _log.e('MissLog.record failed: $e');
    }
  }

  /// Newest first, for display.
  Future<List<MissEntry>> entries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? <String>[];
      final out = <MissEntry>[];
      for (final s in raw) {
        try {
          final m = jsonDecode(s) as Map<String, dynamic>;
          out.add(MissEntry(
            utterance: m['u'] as String? ?? '',
            at: DateTime.tryParse(m['t'] as String? ?? '') ?? DateTime(2000),
          ));
        } catch (_) {
          // Skip a corrupt row rather than losing the whole log.
        }
      }
      return out.reversed.toList();
    } catch (e) {
      _log.e('MissLog.entries failed: $e');
      return [];
    }
  }

  /// Plain text for copy-to-clipboard.
  Future<String> asText() async {
    final list = await entries();
    if (list.isEmpty) return 'No unmatched commands recorded.';
    return list
        .map((e) => '${e.at.toIso8601String().substring(0, 19)}  ${e.utterance}')
        .join('\n');
  }

  Future<int> count() async => (await entries()).length;

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      _log.e('MissLog.clear failed: $e');
    }
  }
}

class MissEntry {
  final String utterance;
  final DateTime at;
  const MissEntry({required this.utterance, required this.at});
}