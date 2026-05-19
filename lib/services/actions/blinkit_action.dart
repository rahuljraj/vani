// lib/services/actions/blinkit_action.dart
//
// Verified May 19, 2026:
//   - Blinkit package: com.grofers.customerapp (legacy Grofers package, kept after rebrand)
//   - Deep link scheme: grofers://search?q={query}
//   - Handler: com.blinkit.intent.IntentReceiverActivity
// ADB-verified: opens Blinkit natively with search query pre-filled.

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class BlinkitAction {
  final _log = Logger();

  Future<bool> search(String item, String quantity) async {
    final query = quantity.isNotEmpty ? '$quantity $item' : item;
    _log.d('Blinkit search: $query');

    final enc = Uri.encodeComponent(query);

    // Verified app deep link
    final appUri = Uri.parse('grofers://search?q=$enc');
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        _log.i('🛒 Blinkit opened natively with query: $query');
        return true;
      }
    } catch (e) {
      _log.w('Blinkit native launch failed: $e — falling back to web');
    }

    // Web fallback — opens in browser if app not installed
    await launchUrl(
      Uri.parse('https://blinkit.com/s/?q=$enc'),
      mode: LaunchMode.externalApplication,
    );
    _log.i('🛒 Blinkit fallback opened in browser with query: $query');
    return true;
  }
}