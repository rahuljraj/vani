// lib/services/actions/swiggy_action.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import '../permission_service.dart';

class SwiggyAction {
  final _log = Logger();

  Future<bool> search(String item) async {
    _log.d('Swiggy search: $item');

    final installed = await PermissionService.instance
      .isAppInstalled('in.swiggy.android');

    if (installed) {
      await PermissionService.instance
        .setPendingAction('swiggy_search', item);

      final appUri = Uri.parse('in.swiggy.android://');
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return true;
      }
    }

    // Web fallback
    await launchUrl(
      Uri.parse('https://www.swiggy.com/search?query=${Uri.encodeComponent(item)}'),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }
}
