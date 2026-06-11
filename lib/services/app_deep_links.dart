// lib/services/app_deep_links.dart
//
// Central registry of search/action deep-link templates for installed apps.
// Adding a new app = adding one line to the appropriate map.
//
// {q} is replaced with the URL-encoded query at runtime.
//
// HOW THESE ARE LAUNCHED (v1.1): ActionRouter fires these as VIEW intents
// PINNED INTO THE PACKAGE (native launchUrlInPackage — the Dart equivalent of
// `adb shell am start -d <url> -p <pkg>`). HTTPS app-links are the preferred
// template form: vendor custom schemes (grofers://, zomato://...) rot silently
// across app updates; pinned https app-links degrade gracefully.
//
// Verification legend (test device 6d6d9eef, OnePlus Nord CE 2 Lite):
//   ✅ ADB-verified — opens in-app search pre-filled
//   ⏳ UNVERIFIED  — best-known app-link; probe via ADB before trusting:
//      adb -s 6d6d9eef shell am start -a android.intent.action.VIEW \
//        -d "<url>" -p "<package>"

class AppDeepLinks {
  // Search-style deep links — "X pe Y dhundho" style commands
  static const Map<String, String> _searchTemplates = {
    // ── Food & Grocery ──────────────────────────────────────────────
    'in.swiggy.android':                'https://www.swiggy.com/search?query={q}',   // ✅ Jun 2026
    'com.grofers.customerapp':          'https://blinkit.com/s/?q={q}',              // ✅ Jun 2026 — Blinkit (grofers:// scheme is DEAD, app ignores query)
    'com.bigbasket.mobileapp':          'https://www.bigbasket.com/ps/?q={q}',       // ⏳ UNVERIFIED — probe on device
    'com.zeptoconsumerapp':             'https://www.zeptonow.com/search?query={q}', // ⏳ UNVERIFIED — probe on device

    // Zomato intentionally ABSENT: zomato://search?keyword= opens the app but
    // ignores the query (verified broken Jun 2026), and no working https
    // app-link is known yet. Absence → graceful fallback to app_launch with
    // honest "khol raha hoon" copy. Re-add once a probe finds a real link
    // (try: adb shell dumpsys package com.application.zomato | grep -A5 VIEW).

    // ── E-commerce ──────────────────────────────────────────────────
    'in.amazon.mShop.android.shopping': 'amzn://www.amazon.in/s?k={q}',      // ⏳ UNVERIFIED
    'com.amazon.mShop.android.shopping': 'amzn://www.amazon.in/s?k={q}',     // ⏳ UNVERIFIED
    'com.flipkart.android':             'flipkart://dl/search?q={q}',        // ⏳ UNVERIFIED
    'com.myntra.android':               'myntra://search?q={q}',             // ⏳ UNVERIFIED
    'com.meesho.supply':                'meesho://search?q={q}',             // ⏳ UNVERIFIED

    // ── Media & Entertainment ───────────────────────────────────────
    'com.google.android.youtube':       'vnd.youtube://results?search_query={q}', // ✅ v0.1
    'com.spotify.music':                'spotify://search/{q}',              // ⏳ UNVERIFIED
    'in.startv.hotstar':                'hotstar://search?q={q}',            // ⏳ UNVERIFIED
    'com.netflix.mediaclient':          'nflx://www.netflix.com/search?q={q}', // ⏳ UNVERIFIED
    'com.jio.media.ondemand':           'jiocinema://search?q={q}',          // ⏳ UNVERIFIED

    // ── Maps & Navigation ───────────────────────────────────────────
    'com.google.android.apps.maps':     'geo:0,0?q={q}',                     // ✅ v0.1

    // ── Social & Professional ───────────────────────────────────────
    'com.linkedin.android':             'linkedin://search?keywords={q}',    // ⏳ UNVERIFIED
    'com.twitter.android':              'twitter://search?query={q}',        // ⏳ UNVERIFIED
    'com.instagram.android':            'instagram://search?query={q}',      // ⏳ UNVERIFIED

    // ── Travel ──────────────────────────────────────────────────────
    'com.makemytrip':                   'makemytrip://search?q={q}',         // ⏳ UNVERIFIED
    'com.cleartrip.android':            'cleartrip://search?q={q}',          // ⏳ UNVERIFIED
    'com.ixigo.train.ixitrain':         'ixigo://search?q={q}',              // ⏳ UNVERIFIED

    // ── Ride-hailing ────────────────────────────────────────────────
    'com.ubercab':                      'uber://search?q={q}',               // ⏳ UNVERIFIED
    'com.olacabs.customer':             'olacabs://search?q={q}',            // ⏳ UNVERIFIED

    // (Add more as we discover real schemes — graceful fallback to app_launch
    //  for any package not listed here)
  };

  /// Returns a search URI for the given package + query, or null if
  /// no deep-link scheme is known for that package.
  ///
  /// Caller should launch this pinned into the package (launchUrlInPackage);
  /// if that fails, fall back to plain app_launch.
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
