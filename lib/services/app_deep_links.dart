// lib/services/app_deep_links.dart
//
// Central registry of search/action deep-link templates for installed apps.
// Adding a new app = adding one line to the appropriate map.
//
// {q} is replaced with the URL-encoded query at runtime.

class AppDeepLinks {
  // Search-style deep links — "X pe Y dhundho" style commands
  static const Map<String, String> _searchTemplates = {
    // ── Food & Grocery ──────────────────────────────────────────────
    'in.swiggy.android':                'https://www.swiggy.com/search?query={q}',
    'com.application.zomato':           'zomato://search?keyword={q}',
    'app.zomato.android':               'zomato://search?keyword={q}',
    'com.grofers.customerapp':          'grofers://search?q={q}',  // verified May 19, 2026 — Blinkit (rebranded Grofers, kept legacy package)
    'com.bigbasket.mobileapp':          'bigbasket://search?q={q}',
    'com.zeptoconsumerapp':             'zepto://search?q={q}',

    // ── E-commerce ──────────────────────────────────────────────────
    'in.amazon.mShop.android.shopping': 'amzn://www.amazon.in/s?k={q}',
    'com.amazon.mShop.android.shopping': 'amzn://www.amazon.in/s?k={q}',
    'com.flipkart.android':             'flipkart://dl/search?q={q}',
    'com.myntra.android':               'myntra://search?q={q}',
    'com.meesho.supply':                'meesho://search?q={q}',

    // ── Media & Entertainment ───────────────────────────────────────
    'com.google.android.youtube':       'vnd.youtube://results?search_query={q}',
    'com.spotify.music':                'spotify://search/{q}',
    'in.startv.hotstar':                'hotstar://search?q={q}',
    'com.netflix.mediaclient':          'nflx://www.netflix.com/search?q={q}',
    'com.jio.media.ondemand':           'jiocinema://search?q={q}',

    // ── Maps & Navigation ───────────────────────────────────────────
    'com.google.android.apps.maps':     'geo:0,0?q={q}',

    // ── Social & Professional ───────────────────────────────────────
    'com.linkedin.android':             'linkedin://search?keywords={q}',
    'com.twitter.android':              'twitter://search?query={q}',
    'com.instagram.android':            'instagram://search?query={q}',

    // ── Travel ──────────────────────────────────────────────────────
    'com.makemytrip':                   'makemytrip://search?q={q}',
    'com.cleartrip.android':            'cleartrip://search?q={q}',
    'com.ixigo.train.ixitrain':         'ixigo://search?q={q}',

    // ── Ride-hailing ────────────────────────────────────────────────
    'com.ubercab':                      'uber://search?q={q}',
    'com.olacabs.customer':             'olacabs://search?q={q}',

    // (Add more as we discover real schemes — graceful fallback to app_launch
    //  for any package not listed here)
  };

  /// Returns a search URI for the given package + query, or null if
  /// no deep-link scheme is known for that package.
  ///
  /// Caller should attempt this URI via canLaunchUrl; if that fails,
  /// fall back to plain app_launch.
  static Uri? searchUri(String packageName, String query) {
    final template = _searchTemplates[packageName];
    if (template == null || template.isEmpty) return null;
    return Uri.parse(template.replaceAll('{q}', Uri.encodeComponent(query)));
  }

  /// True if we have a known search deep link for this package.
  static bool hasSearchTemplate(String packageName) =>
    _searchTemplates.containsKey(packageName);

  /// Returns the count of apps with known search deep links.
  /// Useful for analytics / dashboard.
  static int get knownAppsCount => _searchTemplates.length;
}