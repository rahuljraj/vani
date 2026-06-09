// lib/services/actions/call_action.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import '../contacts_service.dart';
import '../tts_service.dart';

class CallAction {
  final _log = Logger();

  /// Digits → dial directly. Name → resolve via contacts, then pre-fill dialer.
  /// (Pre-fills only; user taps call. Auto-call = v1.1 + CALL_PHONE perm.)
  Future<bool> dial(String contactOrNumber) async {
    final clean = contactOrNumber.trim();
    if (clean.isEmpty) return _openDialer(null);

    // Pure digits/symbols → dial directly.
    if (RegExp(r'^[\d+\-\s]+$').hasMatch(clean)) {
      return _openDialer(clean.replaceAll(RegExp(r'\s'), ''));
    }

    // Name → resolve against on-device contacts.
    final number = await ContactsService.instance.resolveNumber(clean);
    if (number != null && number.isNotEmpty) {
      _log.d('Call: resolved "$clean" → $number');
      return _openDialer(number);
    }

    // No match → say so honestly, then open empty dialer (graceful).
    _log.w('Call: no contact match for "$clean" — opening dialer');
    await TtsService.instance
        .speak('$clean contacts mein nahi mila — dialer khol raha hoon.');
    return _openDialer(null);
  }

  Future<bool> _openDialer(String? number) async {
    final uri = Uri.parse(number == null ? 'tel:' : 'tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }
}