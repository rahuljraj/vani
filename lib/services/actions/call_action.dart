// lib/services/actions/call_action.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class CallAction {
  final _log = Logger();

  /// If [contactOrNumber] is a digit string → dial directly.
  /// Otherwise → open dialer with name pre-filled (user taps to call).
  Future<bool> dial(String contactOrNumber) async {
    final clean = contactOrNumber.trim();
    if (clean.isEmpty) {
      // Open empty dialer
      final uri = Uri.parse('tel:');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    }

    // Pure digits/+ → tel: URI
    final digitsOnly = RegExp(r'^[\d+\-\s]+$').hasMatch(clean);
    if (digitsOnly) {
      final uri = Uri.parse('tel:${clean.replaceAll(RegExp(r'\s'), '')}');
      _log.d('Call dial: $uri');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
    }

    // Name → open contacts search
    final uri = Uri.parse(
      'content://com.android.contacts/contacts/lookup/${Uri.encodeComponent(clean)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }

    // Final fallback — open dialer
    await launchUrl(Uri.parse('tel:'));
    return true;
  }
}