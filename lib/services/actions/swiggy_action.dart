// lib/services/actions/swiggy_action.dart
//
// Verified Jun 2026 on device 6d6d9eef:
//   - Package: in.swiggy.android
//   - HTTPS app-link forced into the package opens in-app search pre-filled:
//       am start -a android.intent.action.VIEW \
//         -d "https://www.swiggy.com/search?query=biryani" -p in.swiggy.android
//   - The old in.swiggy.android:// "scheme" was never real (that's the package
//     name); the accessibility-typing pendingAction is no longer needed —
//     the app-link pre-fills search directly.

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class SwiggyAction {
  final _log = Logger();
  static const _pkg = 'in.swiggy.android';
  static const _channel = MethodChannel('com.vani/app_actions');

  Future<bool> search(String item) async {
    final enc = Uri.encodeComponent(item);
    _log.d('Swiggy search: $item');

    final ok = await _launchInPackage('https://www.swiggy.com/search?query=$enc');
    if (ok) {
      _log.i('🍔 Swiggy opened (app-link) with query: $item');
      return true;
    }

    // Fallback — Swiggy not installed / link not handled → browser.
    await launchUrl(
      Uri.parse('https://www.swiggy.com/search?query=$enc'),
      mode: LaunchMode.externalApplication,
    );
    _log.i('🍔 Swiggy fallback opened in browser with query: $item');
    return true;
  }

  Future<bool> _launchInPackage(String url) async {
    try {
      final ok = await _channel.invokeMethod<bool>('launchUrlInPackage', {
        'url': url,
        'package': _pkg,
      });
      return ok ?? false;
    } catch (e) {
      _log.w('Swiggy launchUrlInPackage failed: $e');
      return false;
    }
  }
}