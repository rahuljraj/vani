// lib/services/actions/blinkit_action.dart
//
// Verified Jun 2026 on device 6d6d9eef:
//   - Package: com.grofers.customerapp (legacy Grofers package, kept after rebrand)
//   - The custom grofers:// scheme is DEAD as of the current app version —
//     it opens the app but ignores the query.
//   - WORKING path: HTTPS app-link forced into the package opens in-app
//     search pre-filled.  ADB-verified:
//       am start -a android.intent.action.VIEW \
//         -d "https://blinkit.com/s/?q=doodh" -p com.grofers.customerapp

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class BlinkitAction {
  final _log = Logger();
  static const _pkg = 'com.grofers.customerapp';
  static const _channel = MethodChannel('com.vani/app_actions');

  Future<bool> search(String item, String quantity) async {
    final query = quantity.isNotEmpty ? '$quantity $item' : item;
    final enc = Uri.encodeComponent(query);
    _log.d('Blinkit search: $query');

    // App-link forced into the Blinkit package (verified working on-device).
    final ok = await _launchInPackage('https://blinkit.com/s/?q=$enc');
    if (ok) {
      _log.i('🛒 Blinkit opened (app-link) with query: $query');
      return true;
    }

    // Fallback — Blinkit not installed / link not handled → browser.
    await launchUrl(
      Uri.parse('https://blinkit.com/s/?q=$enc'),
      mode: LaunchMode.externalApplication,
    );
    _log.i('🛒 Blinkit fallback opened in browser with query: $query');
    return true;
  }

  /// Forces a VIEW intent into a specific package via the native bridge,
  /// mirroring the ADB `am start -d <url> -p <pkg>` that we verified.
  Future<bool> _launchInPackage(String url) async {
    try {
      final ok = await _channel.invokeMethod<bool>('launchUrlInPackage', {
        'url': url,
        'package': _pkg,
      });
      return ok ?? false;
    } catch (e) {
      _log.w('Blinkit launchUrlInPackage failed: $e');
      return false;
    }
  }
}