// lib/services/actions/whatsapp_action.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import '../app_registry.dart';
import '../contacts_service.dart';
import '../tts_service.dart';

class WhatsAppAction {
  final _log = Logger();
  static const _pkg = 'com.whatsapp';

  /// Open WhatsApp. If [contactName] resolves to a number → open that chat.
  Future<bool> open(String contactName) async {
    _log.d('WhatsApp open: "$contactName"');
    final name = contactName.trim();
    if (name.isNotEmpty) {
      final intl = await _resolveIntl(name);
      if (intl != null) {
        final uri = Uri.parse('https://wa.me/$intl');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      }
      _log.w('No usable number for "$name" — opening WhatsApp home');
      await TtsService.instance
          .speak('$name ka number nahi mila — WhatsApp khol raha hoon.');
    }
    return await AppRegistry.instance.launchApp(_pkg);
  }

  /// Open the contact's chat with [message] PRE-FILLED (user taps send).
  Future<bool> sendMessage(String contact, String message) async {
    _log.d('WhatsApp draft: to="$contact" msg="$message"');
    final intl = await _resolveIntl(contact);
    if (intl != null) {
      final uri = Uri.parse(
          'https://wa.me/$intl?text=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    }
    // Couldn't resolve number → can't prefill into a chat; open WhatsApp home
    // and say so honestly instead of pretending the draft is ready.
    _log.w('No number for "$contact" — opening WhatsApp home');
    await TtsService.instance.speak(
        '$contact ka number nahi mila — WhatsApp khol raha hoon, message khud bhejna.');
    return await AppRegistry.instance.launchApp(_pkg);
  }

  /// Name → resolved contact number in wa.me intl format, or null.
  Future<String?> _resolveIntl(String name) async {
    final number = await ContactsService.instance.resolveNumber(name);
    if (number == null || number.isEmpty) return null;
    return _toIntl(number);
  }

  /// Normalize a saved number to wa.me format (digits + country code).
  String? _toIntl(String raw) {
    final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return null;
    if (d.length == 12 && d.startsWith('91')) return d;        // already 91+10
    if (d.length == 10) return '91$d';                          // bare mobile
    if (d.length == 11 && d.startsWith('0')) return '91${d.substring(1)}';
    if (d.length >= 11 && d.length <= 15) return d;             // has a CC
    return null;
  }
}