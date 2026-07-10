// lib/services/actions/action_router.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import '../tts_service.dart';
import 'maps_action.dart';
import 'blinkit_action.dart';
import 'swiggy_action.dart';
import 'whatsapp_action.dart';
import 'call_action.dart';
import '../../models/vani_intent.dart';
import '../../core/constants.dart';
import '../app_registry.dart';
import '../app_deep_links.dart';
import '../confirmation_service.dart';

class ActionRouter {
  final _log      = Logger();
  final _maps     = MapsAction();
  final _blinkit  = BlinkitAction();
  final _swiggy   = SwiggyAction();
  final _whatsapp = WhatsAppAction();
  final _call     = CallAction();

 /// Rejects placeholder/junk contacts (e.g. Gemma's "your_phone_number",
  /// "contact_name") so we never dial or message a non-real target.
  /// Returns a usable contact, or '' if it isn't real.
  String _sanitizeContact(String raw) {
    final c = raw.trim();
    if (c.isEmpty) return '';
    final lower = c.toLowerCase();

    // Schema placeholders almost always contain underscores or filler tokens.
    if (lower.contains('_')) return '';
    const placeholders = {
      'your phone number', 'phone number', 'phone', 'number', 'your number',
      'mobile number', 'contact', 'contact name', 'recipient',
      'recipient name', 'name', 'xxx', 'xxxx', 'xxxxx', 'unknown', 'null',
    };
    if (placeholders.contains(lower)) return '';

    // Looks numeric → must be a real phone (≥10 digits for an Indian mobile).
    final isNumeric = RegExp(r'^[0-9+\-\s()]+$').hasMatch(c);
    if (isNumeric) {
      final digits = c.replaceAll(RegExp(r'[^0-9]'), '');
      return digits.length >= 10 ? c : '';
    }

    // Otherwise treat as a real contact name.
    return c;
  }

  /// v1.1 reliability bar: every route ends in the right action OR a spoken
  /// graceful failure. Nothing fails silently, nothing crashes the flow.
  Future<void> execute(VaniIntent intent) async {
    try {
      await _execute(intent);
    } catch (e, st) {
      _log.e('❌ Action failed: ${intent.actionCode}: $e\n$st');
      await TtsService.instance
          .speak('Kuch gadbad ho gayi. Dobara try karein?');
    }
  }

  Future<void> _execute(VaniIntent intent) async {
    _log.d('Routing: ${intent.type} → ${intent.app} action=${intent.actionCode}');

    await TtsService.instance.speak(intent.speakText);
    await Future.delayed(VaniDurations.speechStartDelay);

    // Action-code-first routing (handles phone_dial which has no app)
    if (intent.actionCode == 'phone_dial') {
      final contact = _sanitizeContact(intent.parameters['contact'] ?? '');
      if (contact.isEmpty) {
        await _speakFail('Kis ko call karna hai, dobara bolein?');
        return;
      }
      final answer =
          await ConfirmationService.instance.confirm('$contact ko call karun?');
      if (answer == ConfirmResult.yes) {
        final ok = await _call.dial(contact);
        if (!ok) await _speakFail('Phone app nahi khul paya.');
        return;
      }
      if (answer == ConfirmResult.unclear) {
        // Honest copy — VANI did NOT understand, so it must not claim to.
        await TtsService.instance
            .speak('Samajh nahi aaya, isliye call cancel kar diya.');
        return;
      }
      // Explicit "no" → exactly ONE correction round. No loops, no recursion;
      // every path below ends in a dial or a spoken cancel.
      final reply = await ConfirmationService.instance
          .askOnce('Theek hai — kis ko call karun? Ya "cancel" bolein.');
      if (reply.trim().isEmpty ||
          ConfirmationService.instance.containsNo(reply)) {
        await TtsService.instance.speak('Koi baat nahi, cancel kar diya.');
        return;
      }
      final newContact = _sanitizeContact(reply);
      if (newContact.isEmpty) {
        await TtsService.instance
            .speak('Yeh naam samajh nahi aaya, cancel kar diya.');
        return;
      }
      final again = await ConfirmationService.instance
          .confirm('$newContact ko call karun?');
      if (again != ConfirmResult.yes) {
        await TtsService.instance.speak('Theek hai, cancel kar diya.');
        return;
      }
      final ok = await _call.dial(newContact);
      if (!ok) await _speakFail('Phone app nahi khul paya.');
      return;
    }
    if (intent.actionCode == 'app_launch') {
      final pkg  = intent.parameters['package'] ?? '';
      final name = intent.parameters['name'] ?? 'App';
      if (pkg.isEmpty) {
        await _speakFail('Kaunsa app kholna hai, samajh nahi aaya.');
        return;
      }
      final ok = await AppRegistry.instance.launchApp(pkg);
      if (!ok) await _speakFail('$name nahi khul paya.');
      return;
    }

    // Generic in-app search — https app-link PINNED into the package
    // (same mechanism as the ADB-verified Blinkit/Swiggy paths).
    if (intent.actionCode == 'app_search_deeplink') {
      await _searchDeepLink(intent);
      return;
    }

    switch (intent.app) {
      case AppTarget.googleMaps: await _handleMaps(intent);
      case AppTarget.blinkit:    await _handleBlinkit(intent);
      case AppTarget.swiggy:     await _handleSwiggy(intent);
      case AppTarget.zomato:     await _handleZomato(intent);
      case AppTarget.whatsapp:   await _handleWhatsApp(intent);
      case AppTarget.youtube:    await _handleYouTube(intent);
      case AppTarget.amazon:     await _handleAmazon(intent);
      case AppTarget.none:       break;
      default:
        _log.w('App not yet integrated: ${intent.app}');
        await TtsService.instance.speak(
          'Yeh app abhi connect nahi hai. Jaldi aayega!',
        );
    }
  }

  Future<void> _speakFail(String message) =>
      TtsService.instance.speak(message);

  /// Deep-link search chain:
  ///   1. Missing URI but query known → look up template (fixes the
  ///      single-grocery-app path, which sets only package + query).
  ///   2. Launch pinned into the package via the native bridge.
  ///   3. Pin failed but app installed → open the app plain, tell the user
  ///      honestly that they'll have to search inside.
  ///   4. App missing and the link is https → browser as last resort.
  Future<void> _searchDeepLink(VaniIntent intent) async {
    final pkg   = intent.parameters['package'] ?? '';
    final name  = intent.parameters['name'] ?? 'App';
    final query = intent.parameters['query'] ?? '';
    var uriStr  = intent.parameters['uri'] ?? '';

    if (uriStr.isEmpty && pkg.isNotEmpty && query.isNotEmpty) {
      uriStr = AppDeepLinks.searchUri(pkg, query)?.toString() ?? '';
      if (uriStr.isNotEmpty) {
        _log.i('🔎 Deep-link URI resolved at dispatch: $name → $uriStr');
      }
    }

    if (uriStr.isNotEmpty && pkg.isNotEmpty) {
      final ok = await AppRegistry.instance.launchUrlInPackage(uriStr, pkg);
      if (ok) {
        _log.i('🔎 Deep-link launch (pinned): $name → $uriStr');
        return;
      }
      _log.w('🔎 Pinned deep-link failed for $name, falling back');
    }

    // Fallback: open the app plain — honest copy, no fake "dhundh raha hoon".
    if (pkg.isNotEmpty) {
      final ok = await AppRegistry.instance.launchApp(pkg);
      if (ok) {
        _log.i('🔎 Deep-link fallback: opened $name plain');
        if (query.isNotEmpty) {
          await TtsService.instance
              .speak('$name khul gaya — $query wahan khud dhundhna.');
        }
        return;
      }
    }

    // App not installed / unlaunchable → browser for https links.
    if (uriStr.startsWith('https://')) {
      final uri = Uri.parse(uriStr);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _log.i('🔎 Deep-link browser fallback: $uri');
        return;
      } catch (e) {
        _log.w('Browser fallback failed: $e');
      }
    }

    await _speakFail('$name nahi khul paya.');
  }

  Future<void> _handleMaps(VaniIntent intent) async {
    final p = intent.parameters;
    bool ok;
    switch (intent.actionCode) {
      case 'maps_navigate':
        final dest = p['destination'] ?? '';
        if (dest.isEmpty) { await _speakFail('Kahaan jaana hai, dobara bolein?'); return; }
        ok = await _maps.navigate(dest);
      case 'maps_nearby':
        final type = p['place_type'] ?? '';
        if (type.isEmpty) { await _speakFail('Kya dhundhna hai, dobara bolein?'); return; }
        ok = await _maps.findNearby(type);
      case 'maps_search':
        final q = p['query'] ?? p['destination'] ?? '';
        if (q.isEmpty) { await _speakFail('Kya dhundhna hai, dobara bolein?'); return; }
        ok = await _maps.search(q);
      default:
        final dest = p['destination'] ?? '';
        if (dest.isEmpty) { await _speakFail('Kahaan jaana hai, dobara bolein?'); return; }
        ok = await _maps.navigate(dest);
    }
    if (!ok) await _speakFail('Maps nahi khul paya.');
  }

  Future<void> _handleBlinkit(VaniIntent intent) async {
    final item = intent.parameters['item']     ?? '';
    final qty  = intent.parameters['quantity'] ?? '';
    if (item.isEmpty) { await _speakFail('Kya order karna hai, dobara bolein?'); return; }
    final ok = await _blinkit.search(item, qty);
    if (!ok) await _speakFail('Blinkit nahi khul paya.');
  }

  Future<void> _handleSwiggy(VaniIntent intent) async {
    final item = intent.parameters['item'] ?? intent.parameters['query'] ?? '';
    if (item.isEmpty) { await _speakFail('Kya order karna hai, dobara bolein?'); return; }
    final ok = await _swiggy.search(item);
    if (!ok) await _speakFail('Swiggy nahi khul paya.');
  }

  /// Zomato v1.1 — DEGRADED ON PURPOSE, honestly. The zomato:// search scheme
  /// opens the app but ignores the query (verified Jun 2026), and no working
  /// https app-link is known yet. So: open the app, no fake search promise
  /// (speak copy says "khol raha hoon"). Web search only if app is missing.
  /// Probe for a real link before re-enabling in-app search — see
  /// docs/v1.1-device-checklist.md.
  Future<void> _handleZomato(VaniIntent intent) async {
    final opened = await AppRegistry.instance.launchApp(VaniPackages.zomato);
    if (opened) return;

    // App not installed → zomato.com search DOES work in the browser.
    final item = intent.parameters['item'] ?? intent.parameters['query'] ?? '';
    final uri = Uri.parse(item.isEmpty
        ? 'https://www.zomato.com/'
        : 'https://www.zomato.com/search?q=${Uri.encodeComponent(item)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _log.w('Zomato web fallback failed: $e');
      await _speakFail('Zomato nahi khul paya.');
    }
  }

 Future<void> _handleWhatsApp(VaniIntent intent) async {
    final contact = _sanitizeContact(intent.parameters['contact'] ?? '');
    final message = intent.parameters['message'] ?? '';
    final bool ok;
    if (message.isNotEmpty && contact.isNotEmpty) {
      // Draft ONLY — message is pre-filled, the user taps send. Never auto-send.
      ok = await _whatsapp.sendMessage(contact, message);
    } else {
      ok = await _whatsapp.open(contact);
    }
    if (!ok) await _speakFail('WhatsApp nahi khul paya. Install hai kya?');
  }

  Future<void> _handleYouTube(VaniIntent intent) async {
    final query = intent.parameters['query'] ?? '';
    if (query.isEmpty) { await _speakFail('Kya chalana hai, dobara bolein?'); return; }
    final enc = Uri.encodeComponent(query);
    final appUri = Uri.parse('vnd.youtube://results?search_query=$enc');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      await launchUrl(
        Uri.parse('https://www.youtube.com/results?search_query=$enc'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

   Future<void> _handleAmazon(VaniIntent intent) async {
  final item = intent.parameters['item'] ?? intent.parameters['query'] ?? '';
  if (item.isEmpty) {
    // Just open the Amazon app
    final appUri = Uri.parse('com.amazon.mShop.android.shopping://');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
      return;
    }
    await launchUrl(Uri.parse('https://www.amazon.in/'), mode: LaunchMode.externalApplication);
    return;
  }
  final enc = Uri.encodeComponent(item);

  // Amazon India app deep link
  final appUri = Uri.parse('amzn://www.amazon.in/s?k=$enc');
  if (await canLaunchUrl(appUri)) {
    await launchUrl(appUri, mode: LaunchMode.externalApplication);
    return;
  }

  // Web fallback
  await launchUrl(
    Uri.parse('https://www.amazon.in/s?k=$enc'),
    mode: LaunchMode.externalApplication,
  );
}

}
