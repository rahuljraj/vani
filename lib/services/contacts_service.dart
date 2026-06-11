// lib/services/contacts_service.dart
//
// Resolves a spoken name → phone number using on-device contacts
// (READ_CONTACTS via the com.vani/app_actions MethodChannel).
// Normalized matching handles "mummy ji" → "Mummyji" vs "Mummy" cleanly.

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:logger/logger.dart';

class Contact {
  final String name;
  final String number;
  const Contact(this.name, this.number);
}

class ContactsService {
  static ContactsService? _instance;
  static ContactsService get instance => _instance ??= ContactsService._();
  ContactsService._();

  final _channel = const MethodChannel('com.vani/app_actions');
  final _log = Logger();

  List<Contact> _contacts = [];
  bool _loaded = false;

  // Raised from 0.45 → 0.62: a lone "best" guess was dialing wrong people.
  static const double _fuzzyThreshold = 0.62;
  // Top match must also beat the runner-up by this margin to commit.
  static const double _fuzzyMargin = 0.12;

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s._\-]+'), '');

  /// Requests permission (first time) and loads contacts into cache.
  Future<bool> ensureLoaded() async {
    if (_loaded) return true;
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      _log.w('📇 READ_CONTACTS not granted');
      return false;
    }
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getContacts');
      if (raw == null) return false;
      _contacts = raw
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return Contact(
              (m['name'] ?? '').toString(),
              (m['number'] ?? '').toString(),
            );
          })
          .where((c) => c.name.isNotEmpty && c.number.isNotEmpty)
          .toList();
      _loaded = true;
      _log.i('📇 Loaded ${_contacts.length} contacts');
      return true;
    } catch (e) {
      _log.e('📇 getContacts failed: $e');
      return false;
    }
  }

  /// Best match for a spoken name → phone number, or null if no good match.
  Future<String?> resolveNumber(String spokenName) async {
    if (!await ensureLoaded() || _contacts.isEmpty) return null;
    final q = spokenName.toLowerCase().trim();
    final qn = _norm(q);

    // Stage 1: normalized exact — "mummy ji" → "Mummyji", "mummy" → "Mummy".
    for (final c in _contacts) {
      if (_norm(c.name) == qn) {
        _log.d('📇 exact: "$q" → ${c.name}');
        return c.number;
      }
    }
    // Stage 2: substring — "raju" → "Raju Bhaisa".
    for (final c in _contacts) {
      if (c.name.toLowerCase().contains(q)) {
        _log.d('📇 substring: "$q" → ${c.name}');
        return c.number;
      }
    }
    // Stage 3: normalized substring.
    for (final c in _contacts) {
      if (_norm(c.name).contains(qn)) {
        _log.d('📇 norm-substring: "$q" → ${c.name}');
        return c.number;
      }
    }
    // Stage 4: fuzzy (Dice) — commit ONLY if the top match clears the
    // threshold AND beats the runner-up by the margin. Otherwise return null
    // so VANI honestly says "nahi mila" instead of dialing the wrong person.
    Contact? best;
    double bestScore = 0;
    double secondScore = 0;
    for (final c in _contacts) {
      final s = q.similarityTo(c.name.toLowerCase());
      if (s > bestScore) {
        secondScore = bestScore;
        bestScore = s;
        best = c;
      } else if (s > secondScore) {
        secondScore = s;
      }
    }
    final margin = bestScore - secondScore;
    _log.d('📇 fuzzy top: "$q" → ${best?.name} '
        '(${bestScore.toStringAsFixed(2)}, margin ${margin.toStringAsFixed(2)})');
    if (best != null && bestScore >= _fuzzyThreshold && margin >= _fuzzyMargin) {
      _log.d('📇 fuzzy commit: "$q" → ${best.name}');
      return best.number;
    }
    _log.w('📇 no confident match for "$q" '
        '(top ${bestScore.toStringAsFixed(2)}, '
        'runner-up ${secondScore.toStringAsFixed(2)})');
    return null;
  }
}