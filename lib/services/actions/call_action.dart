// lib/services/actions/call_action.dart

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import '../contacts_service.dart';
import '../tts_service.dart';

class CallAction {
  final _log = Logger();

  static const _channel = MethodChannel('com.vani/app_actions');

  /// Digits → call directly. Name → resolve via contacts, then call.
  /// Auto-dial requires CALL_PHONE. If it is not granted, or the native
  /// call fails for any reason, we degrade to pre-filling the dialer —
  /// the pre-v1.1 behaviour. A denied permission must never produce a
  /// dead command.
  Future<bool> dial(String contactOrNumber) async {
    final clean = contactOrNumber.trim();

    // Explicit empty target ("dialer kholo") → open empty dialer on purpose.
    if (clean.isEmpty) return _openDialer(null);

    // Pure digits/symbols → call directly.
    if (RegExp(r'^[\d+\-\s]+$').hasMatch(clean)) {
      return _place(clean.replaceAll(RegExp(r'\s'), ''));
    }

    // Name → resolve against on-device contacts.
    final number = await ContactsService.instance.resolveNumber(clean);
    if (number != null && number.isNotEmpty) {
      _log.d('Call: resolved "$clean" → $number');
      return _place(number);
    }

    // Named contact did NOT resolve → say so and STOP.
    // Do NOT open the dialer: an empty dialer surfaces recent contacts, which
    // looks like we're about to call the wrong person — the exact trust
    // violation VANI must never commit. Honest dead-end > wrong call.
    // This matters MORE with auto-dial: a bad match now rings a stranger.
    _log.w('Call: no contact match for "$clean" — refusing to dial');
    await TtsService.instance.speak('$clean naam contacts mein nahi mila.');
    return false;
  }

  /// Try native ACTION_CALL; fall back to dialer pre-fill on any failure.
  Future<bool> _place(String number) async {
    try {
      if (await Permission.phone.isGranted) {
        final ok = await _channel.invokeMethod<bool>(
          'placeCall',
          {'number': number},
        );
        if (ok == true) {
          _log.d('Call: placed directly → $number');
          return true;
        }
        _log.w('Call: native placeCall failed → dialer fallback');
      } else {
        _log.d('Call: CALL_PHONE not granted → dialer fallback');
      }
    } catch (e) {
      _log.w('Call: placeCall threw ($e) → dialer fallback');
    }
    return _openDialer(number);
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