// lib/services/actions/whatsapp_action.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class WhatsAppAction {
  final _log = Logger();

  Future<bool> open(String contactName) async {
    _log.d('WhatsApp open: $contactName');

    // Open WhatsApp home (Accessibility will handle navigation)
    final uri = Uri.parse('whatsapp://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }

    // Fallback: Play Store
    await launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=com.whatsapp'),
      mode: LaunchMode.externalApplication,
    );
    return false;
  }

  Future<bool> sendMessage(String contact, String message) async {
    _log.d('WhatsApp send: to=$contact msg=$message');
    // Phase 2: Full Accessibility-based send
    // For now: just open WhatsApp
    return await open(contact);
  }
}
