
import 'app_registry.dart';
class IntentDisambiguator {
  // Brand → strongly associated context words
  static const _contextWords = <String, List<String>>{
    'blinkit': [
      'atta', 'doodh', 'milk', 'sabzi', 'fruit', 'sugar', 'dal',
      'chawal', 'rice', 'masala', 'bread', 'egg', 'eggs', 'juice',
      'kg', 'litre', 'liter', 'gram', 'grocery', 'sodexo',
      'oil', 'tel', 'namak', 'cheeni', 'aata',
    ],
    'swiggy': [
      'biryani', 'pizza', 'chicken', 'paneer', 'food', 'khana',
      'order', 'restaurant', 'meal', 'dinner', 'lunch', 'breakfast',
      'burger', 'roll', 'dosa', 'thali',
    ],
    'zomato': [
      'biryani', 'pizza', 'restaurant', 'dine', 'food', 'khana',
      'order', 'menu',
    ],
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
      'order', 'product', 'delivery', 'cart', 'price', 'discount',
      'mobile', 'phone', 'laptop',
    ],
    'whatsapp': [
      'message', 'msg', 'send', 'chat', 'group', 'status',
    ],
    'maps': [
      'navigate', 'rasta', 'direction', 'distance', 'nearby',
      'paas', 'najdik', 'route',
    ],
  };

  // Phonetic aliases — what STT might mishear
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

  /// Returns the best-matching app for ambiguous input, or null if truly unclear.
  static String? resolve(String transcript) {
    final t = transcript.toLowerCase();
    final tNorm = t.replaceAll(RegExp(r'[\s._\-]+'), '');
    
    // GUARD: If any installed app's name appears in the transcript (with
    // or without spaces), skip disambiguation and let _openApp's exact/
    // fuzzy matching handle it. Prevents "chat gpt" → WhatsApp routing.
    for (final app in AppRegistry.instance.apps) {
      final name = app.displayName.toLowerCase();
      final nameNorm = name.replaceAll(RegExp(r'[\s._\-]+'), '');
      if (name.length >= 4 && 
          (t.contains(name) || tNorm.contains(nameNorm))) {
        return null;  // _openApp handles it via exact/fuzzy
      }
    }
    
    // Score each candidate app
    final scores = <String, int>{};
    for (final app in _contextWords.keys) {
      var score = 0;

      // Direct mention of the app name (or its phonetic alias)
      if (t.contains(app)) score += 3;
      for (final alias in (_aliases[app] ?? [])) {
        if (t.contains(alias)) score += 3;
      }

      // Context words boost the score
      for (final word in _contextWords[app]!) {
        if (RegExp('\\b$word\\b').hasMatch(t)) score += 2;
      }

      if (score > 0) scores[app] = score;
    }

    if (scores.isEmpty) return null;

    // Sort and check for clear winner
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Clear winner: top score is at least 2 higher than second
    if (sorted.length == 1) return sorted.first.key;
    if (sorted[0].value - sorted[1].value >= 2) return sorted.first.key;

    // Ambiguous — return null so caller can ask user
    return null;
  }
}