import 'app_registry.dart';

class IntentDisambiguator {
  // Generic action/intent words — present in many commands, say nothing about
  // WHICH app. Scored low so they can't outweigh a specific item word.
  static const _genericWords = <String>{
    'order', 'mangwa', 'mangao', 'mangwana', 'chahiye', 'lao',
    'dedo', 'search', 'dhundho', 'dhundh', 'add', 'karo', 'do',
  };

  // Brand → specific context words (items/topics that point at this app).
  // Generic verbs deliberately removed from here (see _genericWords).
  static const _contextWords = <String, List<String>>{
    'blinkit': [
      'atta', 'aata', 'doodh', 'milk', 'sabzi', 'fruit', 'sugar', 'dal',
      'chawal', 'rice', 'masala', 'bread', 'egg', 'eggs', 'juice',
      'kg', 'litre', 'liter', 'gram', 'grocery', 'sodexo',
      'oil', 'tel', 'namak', 'cheeni', 'paneer', 'curd', 'dahi', 'maggi',
    ],
    'swiggy': [
      'biryani', 'pizza', 'chicken', 'food', 'khana',
      'restaurant', 'meal', 'dinner', 'lunch', 'breakfast',
      'burger', 'roll', 'dosa', 'thali', 'bhaji', 'samosa', 'chaat',
    ],
    // 'zomato' deferred to v1.1 — its in-app search deep link is unverified
    // (opens the app but never pre-fills search). Removed from scoring so it's
    // never offered as a disambiguation option. Food → Swiggy for v1.0.
    
    'linkedin': [
      'job', 'jobs', 'naukri', 'profile', 'resume', 'cv',
      'connection', 'hiring', 'post', 'recruiter', 'company',
      'apply', 'interview', 'career',
    ],
    'youtube': [
      'gana', 'song', 'songs', 'video', 'music', 'movie',
      'episode', 'channel', 'subscribe',
    ],
    'amazon': [
      'product', 'delivery', 'cart', 'price', 'discount',
      'mobile', 'phone', 'laptop', 'charger', 'headphone', 'kitab', 'book',
    ],
    'whatsapp': [
      'message', 'msg', 'send', 'chat', 'group', 'status',
    ],
    'maps': [
      'navigate', 'rasta', 'direction', 'distance', 'nearby',
      'paas', 'najdik', 'route',
    ],
  };

  // Phonetic aliases — what STT might mishear (app NAME mishears only).
  static const _aliases = <String, List<String>>{
    'blinkit': ['blink it', 'linked in', 'linkedin', 'blinking', 'blinked', 'link in', 'pink it'],
    'swiggy': ['swigy', 'switchy', 'swiggi', 'swig'],
    'zomato': ['zomatto', 'jomato', 'tomato'],
    'zepto': ['septo', 'zip to', 'zipto'],
    'linkedin': ['linked in', 'link in'],
    'youtube': ['you tube', 'yt'],
    'whatsapp': ['whats app', 'whats up', 'watsap'],
    'amazon': ['amazone', 'amezon'],
  };

  // Installed grocery apps to offer on a grocery command, in preference order.
  // Package names must match AppDeepLinks search templates (real grocery search).
  // Swiggy is intentionally absent — its only scheme is FOOD search, not Instamart.
  static const _groceryApps = <String, String>{
    'com.grofers.customerapp': 'Blinkit',
    'com.zeptoconsumerapp':    'Zepto',
    'com.bigbasket.mobileapp': 'BigBasket',
  };

  /// Grocery apps the user actually has installed, in preference order.
  /// Returns package→displayName entries; empty if none installed.
  static List<MapEntry<String, String>> installedGroceryApps() {
    final installed = AppRegistry.instance.apps
        .map((a) => a.packageName.toLowerCase())
        .toSet();
    return _groceryApps.entries
        .where((e) => installed.contains(e.key.toLowerCase()))
        .toList();
  }

  /// True when the command clearly points at grocery (a grocery app is the
  /// top scorer by a clear margin).
  static bool isGroceryCommand(String transcript) {
    final sorted = _scores(transcript.toLowerCase());
    if (sorted.isEmpty) return false;
    final top = sorted.first;
    if (_appCategory[top.key] != 'grocery') return false;
    // Clear grocery winner (or only grocery scored).
    // Clear grocery winner (or only grocery scored).
    if (sorted.length == 1) return true;
    return top.value - sorted[1].value >= 2;
  }

  /// True when the command points at food (a food app is the top scorer).
  /// With Zomato removed from scoring, Swiggy is the food signal for v1.0,
  /// so food-with-no-app-named routes straight to Swiggy.
  static bool isFoodCommand(String transcript) {
    final sorted = _scores(transcript.toLowerCase());
    if (sorted.isEmpty) return false;
    return _appCategory[sorted.first.key] == 'food';
  }
   



  // ── Scoring weights ──────────────────────────────────────────────
  static const _wAppName    = 5; // explicit app name / alias spoken
  static const _wItemWord   = 3; // SPECIFIC item word ("doodh", "biryani")
  static const _wGenericHit = 1; // generic action word ("order") — barely counts

  static String? resolve(String transcript) {
    final t = transcript.toLowerCase();
    final tNorm = t.replaceAll(RegExp(r'[\s._\-]+'), '');

    // GUARD: explicit installed-app name present → let _openApp handle it.
    for (final app in AppRegistry.instance.apps) {
      final name = app.displayName.toLowerCase();
      final nameNorm = name.replaceAll(RegExp(r'[\s._\-]+'), '');
      if (name.length >= 4 && (t.contains(name) || tNorm.contains(nameNorm))) {
        return null;
      }
    }

    final sorted = _scores(t);
    if (sorted.isEmpty) return null;
    if (sorted.length == 1) return sorted.first.key;
    if (sorted[0].value - sorted[1].value >= 2) return sorted.first.key;
    return null; // ambiguous → ask the user
  }

  static List<String> disambiguationCandidates(String transcript) {
    final t = transcript.toLowerCase();
    final sorted = _scores(t);
    if (sorted.length < 2) return const [];
    if (sorted[0].value - sorted[1].value >= 2) return const []; // clear winner

    final top = sorted.first.value;
    final tied = sorted.where((e) => e.value == top).map((e) => e.key).toList();
    if (tied.length < 2) return const [];

    // Only ever offer choices within ONE category.
    final byCategory = <String, List<String>>{};
    for (final app in tied) {
      byCategory.putIfAbsent(_appCategory[app] ?? 'other', () => []).add(app);
    }
    if (byCategory.length == 1) return byCategory.values.first;

    final ranked = byCategory.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.length.compareTo(a.value.length);
        return byCount != 0
            ? byCount
            : _categoryPriority(a.key).compareTo(_categoryPriority(b.key));
      });
    final winners = ranked.first.value;
    return winners.length >= 2 ? winners : const [];
  }

  /// Specific item words outscore generic action words, so "doodh" (grocery)
  /// decisively beats the generic "order" that also tags food apps.
  static List<MapEntry<String, int>> _scores(String t) {
    final scores = <String, int>{};
    for (final app in _contextWords.keys) {
      var score = 0;

      if (t.contains(app)) score += _wAppName;
      for (final alias in (_aliases[app] ?? const [])) {
        if (t.contains(alias)) score += _wAppName;
      }

      for (final word in _contextWords[app]!) {
        if (RegExp('\\b$word\\b').hasMatch(t)) {
          score += _genericWords.contains(word) ? _wGenericHit : _wItemWord;
        }
      }

      if (score > 0) scores[app] = score;
    }
    return scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  static const _appCategory = <String, String>{
    'swiggy': 'food',
    'zomato': 'food',
    'blinkit': 'grocery',
    'amazon': 'shopping',
    'youtube': 'media',
    'whatsapp': 'messaging',
    'linkedin': 'professional',
    'maps': 'navigation',
  };

  static int _categoryPriority(String category) {
    const order = [
      'food', 'grocery', 'shopping', 'media',
      'messaging', 'navigation', 'professional', 'other',
    ];
    final i = order.indexOf(category);
    return i < 0 ? order.length : i;
  }
}