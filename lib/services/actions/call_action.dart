// lib/services/actions/call_action.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import '../contacts_service.dart';
import '../tts_service.dart';

class CallAction {
  final _log = Logger();

  /// Digits → dial directly. Name → resolve via contacts, then pre-fill dialer.
  /// (Pre-fills only; user taps call. Auto-call = later + CALL_PHONE perm.)
  Future<bool> dial(String contactOrNumber) async {
    final clean = contactOrNumber.trim();

    // Explicit empty target ("dialer kholo") → open empty dialer on purpose.
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

    // Named contact did NOT resolve → say so and STOP.
    // Do NOT open the dialer: an empty dialer surfaces recent contacts, which
    // looks like we're about to call the wrong person — the exact trust
    // violation VANI must never commit. Honest dead-end > wrong call.
    _log.w('Call: no contact match for "$clean" — refusing to dial');
    await TtsService.instance.speak('$clean naam contacts mein nahi mila.');
    return false;
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