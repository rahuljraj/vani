// lib/services/actions/action_router.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import '../tts_service.dart';
import 'maps_action.dart';
import 'blinkit_action.dart';
import 'swiggy_action.dart';
import 'whatsapp_action.dart';
import '../../models/vani_intent.dart';
import '../../core/constants.dart';

class ActionRouter {
  final _log      = Logger();
  final _maps     = MapsAction();
  final _blinkit  = BlinkitAction();
  final _swiggy   = SwiggyAction();
  final _whatsapp = WhatsAppAction();

  Future<void> execute(VaniIntent intent) async {
    _log.d('Routing: ${intent.type} → ${intent.app}');

    // Always speak first
    await TtsService.instance.speak(intent.speakText);

    // Small delay — let speech start before app opens
    await Future.delayed(VaniDurations.speechStartDelay);

    // Route to correct handler
    switch (intent.app) {
      case AppTarget.googleMaps:
        await _handleMaps(intent);

      case AppTarget.blinkit:
        await _handleBlinkit(intent);

      case AppTarget.swiggy:
        await _handleSwiggy(intent);

      case AppTarget.zomato:
        await _handleZomato(intent);

      case AppTarget.whatsapp:
        await _handleWhatsApp(intent);

      case AppTarget.youtube:
        await _handleYouTube(intent);

      case AppTarget.amazon:
        await _handleAmazon(intent);

      case AppTarget.none:
        // Just talking — no app action needed
        break;

      default:
        _log.w('App not yet integrated: ${intent.app}');
        await TtsService.instance.speak(
          'Yeh app abhi connect nahi hai. Jaldi aayega!'
        );
    }
  }

  // ── Google Maps ─────────────────────────────────
  Future<void> _handleMaps(VaniIntent intent) async {
    final p = intent.parameters;
    switch (intent.actionCode) {
      case 'maps_navigate':
        final dest = p['destination'] ?? '';
        if (dest.isNotEmpty) await _maps.navigate(dest);
      case 'maps_nearby':
        final type = p['place_type'] ?? '';
        if (type.isNotEmpty) await _maps.findNearby(type);
      case 'maps_search':
        final q = p['query'] ?? p['destination'] ?? '';
        if (q.isNotEmpty) await _maps.search(q);
      default:
        final dest = p['destination'] ?? '';
        if (dest.isNotEmpty) await _maps.navigate(dest);
    }
  }

  // ── Blinkit ─────────────────────────────────────
  Future<void> _handleBlinkit(VaniIntent intent) async {
    final item = intent.parameters['item']     ?? '';
    final qty  = intent.parameters['quantity'] ?? '';
    if (item.isNotEmpty) await _blinkit.search(item, qty);
  }

  // ── Swiggy ──────────────────────────────────────
  Future<void> _handleSwiggy(VaniIntent intent) async {
    final item = intent.parameters['item'] ??
                 intent.parameters['query'] ?? '';
    if (item.isNotEmpty) await _swiggy.search(item);
  }

  // ── Zomato ──────────────────────────────────────
  Future<void> _handleZomato(VaniIntent intent) async {
    final item = intent.parameters['item'] ??
                 intent.parameters['query'] ?? '';
    if (item.isEmpty) return;

    final enc = Uri.encodeComponent(item);
    await launchUrl(
      Uri.parse('https://www.zomato.com/search?q=$enc'),
      mode: LaunchMode.externalApplication,
    );
  }

  // ── WhatsApp ────────────────────────────────────
  Future<void> _handleWhatsApp(VaniIntent intent) async {
    final contact = intent.parameters['contact'] ?? '';
    final message = intent.parameters['message'] ?? '';

    if (message.isNotEmpty && contact.isNotEmpty) {
      await _whatsapp.sendMessage(contact, message);
    } else {
      await _whatsapp.open(contact);
    }
  }

  // ── YouTube ─────────────────────────────────────
  Future<void> _handleYouTube(VaniIntent intent) async {
    final query = intent.parameters['query'] ?? '';
    if (query.isEmpty) return;

    final enc = Uri.encodeComponent(query);
    final appUri = Uri.parse(
      'vnd.youtube://results?search_query=$enc'
    );

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      await launchUrl(
        Uri.parse('https://www.youtube.com/results?search_query=$enc'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  // ── Amazon ──────────────────────────────────────
  Future<void> _handleAmazon(VaniIntent intent) async {
    final item = intent.parameters['item'] ??
                 intent.parameters['query'] ?? '';
    if (item.isEmpty) return;

    final enc = Uri.encodeComponent(item);
    await launchUrl(
      Uri.parse('https://www.amazon.in/s?k=$enc'),
      mode: LaunchMode.externalApplication,
    );
  }
}
