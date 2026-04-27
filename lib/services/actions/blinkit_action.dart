// lib/services/actions/blinkit_action.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import '../permission_service.dart';

class BlinkitAction {
  final _log = Logger();

  Future<bool> search(String item, String quantity) async {
    final query = quantity.isNotEmpty ? '$quantity $item' : item;
    _log.d('Blinkit search: $query');

    // Method 1: Deep link
    final deepLink = Uri.parse(
      'in.blinkit.android://search?q=${Uri.encodeComponent(query)}'
    );
    if (await canLaunchUrl(deepLink)) {
      await launchUrl(deepLink);
      return true;
    }

    // Method 2: Accessibility Service
    final installed = await PermissionService.instance
      .isAppInstalled('com.blinkit.consumer');

    if (installed) {
      await PermissionService.instance
        .setPendingAction('blinkit_search', query);

      final appUri = Uri.parse('in.blinkit.android://');
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return true;
      }
    }

    // Method 3: Web fallback
    await launchUrl(
      Uri.parse('https://blinkit.com/s/?q=${Uri.encodeComponent(query)}'),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }
}
