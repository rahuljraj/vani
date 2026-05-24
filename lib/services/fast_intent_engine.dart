// lib/services/fast_intent_engine.dart

import '../models/vani_intent.dart';
import 'intent_disambiguator.dart';
import 'app_registry.dart';
import 'app_deep_links.dart';


class FastIntentEngine {
 static VaniIntent? tryMatch(String text) {
  var t = text.toLowerCase().trim();
  if (t.isEmpty) return null;

  // Logging for diagnostic — see what STT actually gives us
  print('🎤 Heard: "$t"');

  // Step 1: Normalize common STT phonetic splits and misrecognitions
  t = t
    // Brand name normalization
    .replaceAll(RegExp(r'\bblink\s*kit\b'), 'blinkit')
    .replaceAll(RegExp(r'\bblink\s*it\b'), 'blinkit')
    .replaceAll(RegExp(r'\bblinked\b'), 'blinkit')
    .replaceAll(RegExp(r'\bblinking\b'), 'blinkit')
    .replaceAll(RegExp(r'\blink\s*it\b'), 'blinkit')
    .replaceAll(RegExp(r'\bpink\s*it\b'), 'blinkit')
    .replaceAll(RegExp(r'\bblanket\b'), 'blinkit')
    .replaceAll(RegExp(r'\bblink\s+gate\b'), 'blinkit')
    .replaceAll(RegExp(r'\bblinking\b'), 'blinkit')
    .replaceAll(RegExp(r'\bblanket\b'), 'blinkit')
    .replaceAll(RegExp(r'\bblink\s+gate\b'), 'blinkit')
    .replaceAll(RegExp(r'\bblanking\b'), 'blinkit')
    .replaceAll(RegExp(r'\blinkin\b'), 'blinkit')
    .replaceAll(RegExp(r'\bswigy\b'), 'swiggy')
    .replaceAll(RegExp(r'\bswiggi\b'), 'swiggy')
    .replaceAll(RegExp(r'\bzomatto\b'), 'zomato')
    .replaceAll(RegExp(r'\bjomato\b'), 'zomato')
    .replaceAll(RegExp(r'\bwhats\s*app\b'), 'whatsapp')
    .replaceAll(RegExp(r'\bwhats\s*up\b'), 'whatsapp')
    .replaceAll(RegExp(r'\bwatsap\b'), 'whatsapp')
    .replaceAll(RegExp(r'\byou\s*tube\b'), 'youtube')
    .replaceAll(RegExp(r'\bgoogle\s*map(s)?\b'), 'maps')
    // Common Hinglish noun misrecognitions
    .replaceAll(RegExp(r'\b(aata|ata|aadha|adha|aatta)\b'), 'atta')
    .replaceAll(RegExp(r'\b(doodh|doodt|dudh)\b'), 'doodh')
    // Verb misrecognitions
    .replaceAll(RegExp(r'\b(doondo|dundho|doondho|dhundo|dhondo|dundo)\b'), 'dhundho')
    .replaceAll(RegExp(r'\bchaalao\b'), 'chalao')
    .replaceAll(RegExp(r'\bsunaao\b'), 'sunao')
    // Preposition fixes (STT often hears 'per' or 'pr' instead of 'pe')
    .replaceAll(RegExp(r'\bper\b'), 'pe')
    .replaceAll(RegExp(r'\bpr\b'), 'pe')
    .replaceAll(RegExp(r'\bpaar\b'), 'pe');

  print('🔍 FastIntent normalized: "$t"');

  // Step 2: Disambiguate ambiguous brand mentions (Blinkit vs LinkedIn, etc.)
  final resolved = IntentDisambiguator.resolve(t);
  if (resolved != null) {
    print('🎯 Disambiguator resolved to: $resolved');
    if (!t.contains(resolved)) {
      t = '$resolved $t';
    }
  }

  // Step 3: Run the match chain
  final result = _call(t)
      ?? _openApp(t)  
      ?? _navigate(t)
      ?? _nearby(t)
      ?? _blinkit(t)
      ?? _swiggy(t)
      ?? _amazon(t)    
      ?? _zomato(t)
      ?? _youtube(t)
      ?? _searchInApp(t)  
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
  
     static VaniIntent? _openApp(String t) {
  String? appName;

  // Pattern 1 (MOST SPECIFIC FIRST): "X open karo" / "X open kar do" — app BEFORE "open"
  final beforeOpenMatch = RegExp(r'^(.+?)\s+open(?:\s+karo|\s+kar\s+do)\s*$').firstMatch(t);
  if (beforeOpenMatch != null) {
    appName = beforeOpenMatch.group(1)?.trim();
  }

  // Pattern 2: "X khol do" / "X kholo" / "X khol" — app BEFORE "khol"
  if (appName == null) {
    final kholMatch = RegExp(r'^(.+?)\s+khol(?:\s+do|o)?\s*$').firstMatch(t);
    if (kholMatch != null) appName = kholMatch.group(1)?.trim();
  }

  // Pattern 3: "X open" (no trailing verb) — app BEFORE "open"
  if (appName == null) {
    final bareOpenMatch = RegExp(r'^(.+?)\s+open\s*$').firstMatch(t);
    if (bareOpenMatch != null) appName = bareOpenMatch.group(1)?.trim();
  }

  // Pattern 4 (LESS SPECIFIC): "open X" — but X must NOT be a filler word
  if (appName == null) {
    final openMatch = RegExp(r'^open\s+(.+?)(?:\s+karo|\s+kar\s+do|\s+please)?\s*$').firstMatch(t);
    if (openMatch != null) {
      final candidate = openMatch.group(1)?.trim() ?? '';
      // Reject if it's just a filler word
      if (!RegExp(r'^(karo|kar\s*do|please|abhi|jaldi|app|application)$').hasMatch(candidate)) {
        appName = candidate;
      }
    }
  }

  // Pattern 5: "launch X"
  if (appName == null) {
    final launchMatch = RegExp(r'^launch\s+(.+?)\s*$').firstMatch(t);
    if (launchMatch != null) appName = launchMatch.group(1)?.trim();
  }

  if (appName == null || appName.isEmpty) return null;

  // Strip filler words from extracted name
  // 'application' / 'app' / 'wala' / 'wali' often follow app name in spoken Hinglish
  appName = appName
    .replaceAll(RegExp(r'\b(application|app|please|abhi|jaldi|wala|wali|ek)\b'), '')
    .replaceAll(RegExp(r'\s+'), ' ')   // collapse multiple spaces
    .trim();

  if (appName.isEmpty) return null;

  print('🚀 _openApp extracted name: "$appName"');

  final app = AppRegistry.instance.findByName(appName);

  if (app == null) {
    print('🚀 _openApp NO MATCH for "$appName"');
    print('🚀 Sample apps: ${AppRegistry.instance.apps.take(20).map((a) => a.displayName).join(", ")}');
    return null;
  }

  print('🚀 _openApp MATCHED: ${app.displayName} (${app.packageName})');

  return _intent(
    type:   IntentType.chat,
    app:    AppTarget.none,
    params: {'package': app.packageName, 'name': app.displayName},
    speak:  '${app.displayName} khol raha hoon',
    action: 'app_launch',
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
    else if (t.contains(' jana hai'))      dest = t.split(' jana hai').first.trim();
    else if (t.contains(' jaane'))         dest = t.split(' jaane').first.trim();
    else if (t.contains(' jane'))          dest = t.split(' jane').first.trim();
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


   static VaniIntent? _amazon(String t) {
  if (!t.contains('amazon')) return null;

  String? item;

  // Pattern 1: "amazon pe X dhundho" / "amazon par X dhundho"
  final m1 = RegExp(r'amazon\s+(?:pe|par|me|mein)\s+(.+?)(?:\s+dhundho|\s+dikha|\s+search)?\s*$').firstMatch(t);
  if (m1 != null) item = m1.group(1)?.trim();

  // Pattern 2: "amazon pe X" (bare)
  if (item == null) {
    final m2 = RegExp(r'amazon\s+(?:pe|par|me|mein)\s+(.+?)\s*$').firstMatch(t);
    if (m2 != null) item = m2.group(1)?.trim();
  }

  // Pattern 3: "X amazon" or "amazon X dhundho"
  if (item == null) {
    final m3 = RegExp(r'amazon\s+(.+?)\s+dhundho\s*$').firstMatch(t);
    if (m3 != null) item = m3.group(1)?.trim();
  }

  // Pattern 4: just "amazon dhundho" — open Amazon, no specific item
  if (item == null && (t.contains('amazon dhundho') || t == 'amazon')) {
    item = ''; // empty query, just open Amazon
  }

  if (item == null) return null;

  return _intent(
    type:   IntentType.searchProduct,
    app:    AppTarget.amazon,
    params: {'item': item, 'query': item},
    speak:  item.isEmpty ? 'Amazon khol raha hoon' : 'Amazon pe $item dhundh raha hoon',
    action: 'amazon_search',
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
      .replaceAll(RegExp(r'\b(order\s*karo|order\s*kar\s*do|mangao|mangwa\s*do|mangwana\s*hai|search\s*karo|dhundho|dhundh\s*do|dhundo|dhundh|dhoondho|dhoond|chahiye|lao|dedo|de\s*do|add\s*karo|ka\s*order|ek)\b'), ' ')
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

         // ── Generic search across any installed app ──────────────────────────
// Pattern: "<app> pe <query> dhundho/search/dikha/find"
// Works for ALL apps in AppRegistry — looks up package, then looks up
// deep-link template in AppDeepLinks.
//
// Falls back to app_launch (just open the app) for apps without
// a known deep-link scheme.
static VaniIntent? _searchInApp(String t) {
  // Match: <app name> + (pe|par|me|mein) + <query> + optional verb
  final m = RegExp(
    r'^(.+?)\s+(?:pe|par|me|mein)\s+(.+?)'
    r'(?:\s+dhundho|\s+dhundh|\s+dikha|\s+dikhao|\s+search\s+karo|\s+search|\s+find|\s+kholo|\s+khol)?\s*$'
  ).firstMatch(t);

  if (m == null) return null;

  final appPhrase = m.group(1)?.trim() ?? '';
  final query     = m.group(2)?.trim() ?? '';

  if (appPhrase.isEmpty || query.isEmpty) return null;

  // Try to resolve the spoken app name against the installed-apps registry
  final app = AppRegistry.instance.findByName(appPhrase);
  if (app == null) {
    print('🔎 _searchInApp: no installed app matches "$appPhrase"');
    return null;
  }

  // Look up known deep-link template
  final uri = AppDeepLinks.searchUri(app.packageName, query);

  if (uri != null) {
    print('🔎 _searchInApp MATCHED with deep link: ${app.displayName} ← "$query"');
    return _intent(
      type:   IntentType.searchProduct,
      app:    AppTarget.none,
      params: {
        'package': app.packageName,
        'name':    app.displayName,
        'query':   query,
        'uri':     uri.toString(),
      },
      speak:  '${app.displayName} pe $query dhundh raha hoon',
      action: 'app_search_deeplink',
    );
  }

  // No deep-link known — fall back to just opening the app
  print('🔎 _searchInApp: no deep link for ${app.displayName}, falling back to launch');
  return _intent(
    type:   IntentType.chat,
    app:    AppTarget.none,
    params: {
      'package': app.packageName,
      'name':    app.displayName,
    },
    speak:  '${app.displayName} khol raha hoon',
    action: 'app_launch',
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