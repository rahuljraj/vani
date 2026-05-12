// lib/services/fast_intent_engine.dart

import '../models/vani_intent.dart';

class FastIntentEngine {
  static VaniIntent? tryMatch(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return null;

    // Logging for diagnostic — to see what STT actually gives us
    print('🔍 FastIntent matching: "$t"');

    final result = _call(t)
        ?? _navigate(t)
        ?? _nearby(t)
        ?? _blinkit(t)
        ?? _swiggy(t)
        ?? _zomato(t)
        ?? _youtube(t)
        ?? _whatsapp(t)
        ?? _greeting(t);

    if (result == null) {
      print('🔍 No FastIntent match for: "$t" — falling through to Gemma');
    } else {
      print('🔍 FastIntent matched: ${result.actionCode}');
    }

    return result;
  }

  // ── Call ────────────────────────────────────────────────────────────────────
  static VaniIntent? _call(String t) {
    final hasCallVerb = t.contains('call ') ||
                        t.contains('phone karo') ||
                        t.contains('phone kar') ||
                        t.contains(' ko call') ||
                        t.contains('dial ');
    if (!hasCallVerb) return null;

    var contact = t
        .replaceAll(RegExp(r'\b(call|phone|dial)\s*(karo|kar)?\b'), '')
        .replaceAll(RegExp(r'\bko\b'), '')
        .replaceAll(RegExp(r'\b(abhi|please|jaldi)\b'), '')
        .trim();

    contact = _clean(contact) ?? '';

    return _intent(
      type:   IntentType.sendMessage, // reusing — no separate enum yet
      app:    AppTarget.none,
      params: {'contact': contact},
      speak:  contact.isNotEmpty
                ? '$contact ko call kar raha hoon'
                : 'Dialer khol raha hoon',
      action: 'phone_dial',
    );
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  static VaniIntent? _navigate(String t) {
    String? dest;

    if (t.contains('navigate to '))        dest = _after(t, 'navigate to ');
    else if (t.contains('navigate karo ')) dest = _after(t, 'navigate karo ');
    else if (t.contains(' ka rasta'))      dest = t.split(' ka rasta').first.trim();
    else if (t.contains(' navigate'))      dest = t.split(' navigate').first.trim();
    else if (t.contains(' jaana hai'))     dest = t.split(' jaana hai').first.trim();
    else if (t.startsWith('le chal '))     dest = _after(t, 'le chal ');
    else if (t.contains('direction to '))  dest = _after(t, 'direction to ');

    dest = _clean(dest);
    if (dest == null) return null;

    return _intent(
      type:    IntentType.navigate,
      app:     AppTarget.googleMaps,
      params:  {'destination': dest},
      speak:   '$dest ka rasta dikha raha hoon',
      action:  'maps_navigate',
    );
  }

  // ── Nearby ──────────────────────────────────────────────────────────────────
  static VaniIntent? _nearby(String t) {
    String? place;

    if (t.contains('paas mein '))      place = _after(t, 'paas mein ');
    else if (t.contains('paas me '))   place = _after(t, 'paas me ');
    else if (t.contains('aas paas '))  place = _after(t, 'aas paas ');
    else if (t.contains('nearby '))    place = _after(t, 'nearby ');
    else if (t.contains(' near me'))   place = t.split(' near me').first.trim();
    else if (t.contains('najdiki '))   place = _after(t, 'najdiki ');
    else if (t.contains('nazdiki '))   place = _after(t, 'nazdiki ');

    place = _clean(place);
    if (place == null) return null;

    return _intent(
      type:   IntentType.findNearby,
      app:    AppTarget.googleMaps,
      params: {'place_type': place},
      speak:  'Paas ka $place dhundh raha hoon',
      action: 'maps_nearby',
    );
  }

  // ── Blinkit ─────────────────────────────────────────────────────────────────
  static VaniIntent? _blinkit(String t) {
    if (!t.contains('blinkit')) return null;
    final item = _extractFoodItem(t, 'blinkit');
    if (item == null) return null;

    final qty = _extractQty(item);
    final cleaned = qty != null ? item.replaceFirst(qty, '').trim() : item;
    if (cleaned.isEmpty) return null;

    return _intent(
      type:   IntentType.orderFood,
      app:    AppTarget.blinkit,
      params: {'item': cleaned, if (qty != null) 'quantity': qty},
      speak:  'Blinkit pe $cleaned dhundh raha hoon',
      action: 'blinkit_search',
    );
  }

  // ── Swiggy ──────────────────────────────────────────────────────────────────
  static VaniIntent? _swiggy(String t) {
    if (!t.contains('swiggy')) return null;
    final item = _extractFoodItem(t, 'swiggy');
    if (item == null) return null;

    return _intent(
      type:   IntentType.orderFood,
      app:    AppTarget.swiggy,
      params: {'item': item},
      speak:  'Swiggy pe $item dhundh raha hoon',
      action: 'swiggy_search',
    );
  }

  // ── Zomato ──────────────────────────────────────────────────────────────────
  static VaniIntent? _zomato(String t) {
    if (!t.contains('zomato')) return null;
    final item = _extractFoodItem(t, 'zomato');
    if (item == null) return null;

    return _intent(
      type:   IntentType.orderFood,
      app:    AppTarget.zomato,
      params: {'item': item},
      speak:  'Zomato pe $item dhundh raha hoon',
      action: 'zomato_search',
    );
  }

  /// Aggressively strip filler words so we get just the food item.
  /// Handles: "Swiggy pe mere lie pav bhaji order karo" → "pav bhaji"
  static String? _extractFoodItem(String t, String appName) {
    var item = t
      // Remove app name + postpositions
      .replaceAll(RegExp('$appName\\s*(pe|par|se|mein|me|ke|ki)?'), ' ')
      // Remove "mere lie / mere liye / ke lie / ke liye / mujhe / mujhko"
      .replaceAll(RegExp(r'\b(mere|mujhe|mujhko|hamare|humein|apke|aapke|tere)\s*(lie|liye|ke\s*lie|ke\s*liye)?\b'), ' ')
      .replaceAll(RegExp(r'\bke\s*(lie|liye)\b'), ' ')
      // Remove order verbs and intent markers
      .replaceAll(RegExp(r'\b(order\s*karo|order\s*kar\s*do|mangao|mangwa\s*do|mangwana\s*hai|search\s*karo|dhundh\s*do|dhundo|chahiye|lao|dedo|de\s*do|add\s*karo|ka\s*order|ek)\b'), ' ')
      // Remove time/urgency fillers
      .replaceAll(RegExp(r'\b(abhi|jaldi|please|bhai|yaar|hai|hain|h)\b'), ' ')
      .trim();

    item = _clean(item) ?? '';
    if (item.isEmpty) return null;
    return item;
  }

  // ── YouTube ─────────────────────────────────────────────────────────────────
  static VaniIntent? _youtube(String t) {
    String? query;

    if (t.contains('youtube pe '))       query = _after(t, 'youtube pe ');
    else if (t.contains('youtube par ')) query = _after(t, 'youtube par ');
    else if (t.contains(' youtube'))     query = t.split(' youtube').first.trim();
    else if (t.contains(' sunao'))       query = t.replaceAll(' sunao', '').trim();
    else if (t.contains(' chalao'))      query = t.replaceAll(' chalao', '').trim();
    else if (t.contains(' play karo'))   query = t.split(' play karo').first.trim();

    query = _clean(query);
    if (query == null) return null;

    return _intent(
      type:   IntentType.playMedia,
      app:    AppTarget.youtube,
      params: {'query': query},
      speak:  'YouTube pe $query laga raha hoon',
      action: 'youtube_search',
    );
  }

  // ── WhatsApp ────────────────────────────────────────────────────────────────
  static VaniIntent? _whatsapp(String t) {
    if (!t.contains('whatsapp') &&
        !t.contains('message karo') &&
        !t.contains('msg karo')) return null;

    var contact = t
        .replaceAll(RegExp(r'(ko\s+)?whatsapp(\s+karo)?'), '')
        .replaceAll(RegExp(r'(ko\s+)?(message|msg)\s+karo'), '')
        .replaceAll(RegExp(r'whatsapp\s*(pe|par)?'), '')
        .replaceAll(' ko ', ' ')
        .trim();

    contact = _clean(contact) ?? '';

    return _intent(
      type:   IntentType.sendMessage,
      app:    AppTarget.whatsapp,
      params: {'contact': contact},
      speak:  contact.isNotEmpty
                ? '$contact ka WhatsApp khol raha hoon'
                : 'WhatsApp khol raha hoon',
      action: 'whatsapp_open',
    );
  }

  // ── Greetings ───────────────────────────────────────────────────────────────
  static const _greetMap = <String, String>{
    'hello':        'Hello! Kya madad kar sakta hoon?',
    'hi ':          'Hi! Bataiye kya karein?',
    'namaste':      'Namaste! Kya seva karein?',
    'namaskar':     'Namaskar! Kya madad karein?',
    'shukriya':     'Ji bilkul! Koi aur kaam?',
    'dhanyawad':    'Ji bilkul! Koi aur kaam?',
    'thank you':    'My pleasure! Koi aur kaam?',
    'thanks':       'My pleasure! Koi aur kaam?',
    'good morning': 'Good morning! Aaj kya karein?',
    'good night':   'Good night! Shubh ratri.',
    'kya haal':     'Sab theek hai! Kya seva karein?',
    'kya chal':     'Sab badhiya! Kya karein?',
    'kaise ho':     'Main theek hoon! Aap bataiye?',
    'bye':          'Alvida! Phir milenge.',
    'alvida':       'Alvida! Phir milenge.',
  };

  static VaniIntent? _greeting(String t) {
    for (final entry in _greetMap.entries) {
      if (t.contains(entry.key)) {
        return _intent(
          type:   IntentType.chat,
          app:    AppTarget.none,
          params: {},
          speak:  entry.value,
          action: 'none',
        );
      }
    }
    return null;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  static VaniIntent _intent({
    required IntentType type,
    required AppTarget app,
    required Map<String, String> params,
    required String speak,
    required String action,
  }) => VaniIntent(
    type:       type,
    app:        app,
    parameters: params,
    speakText:  speak,
    actionCode: action,
  );

  static String _after(String text, String prefix) {
    final idx = text.indexOf(prefix);
    if (idx < 0) return '';
    return text.substring(idx + prefix.length).trim();
  }

  static String? _clean(String? s) {
    if (s == null || s.isEmpty) return null;
    final out = s
        .replaceAll(RegExp(r'\b(karo|karna|dikhao|dhundho|dhundh|batao|lao|dedo)\b'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return out.isEmpty ? null : out;
  }

  static String? _extractQty(String text) {
    final m = RegExp(
      r'\d+\s*(?:kg|g|gm|gram|litre|liter|l|piece|pcs|dozen)',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(0);
  }
}