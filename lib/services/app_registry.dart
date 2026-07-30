import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:string_similarity/string_similarity.dart';

class AppRegistry {
  static AppRegistry? _instance;
  static AppRegistry get instance => _instance ??= AppRegistry._();
  AppRegistry._();

  final _channel = const MethodChannel('com.vani/app_actions');
  final _log = Logger();

  // Fuzzy match threshold (0.0 to 1.0). Higher = stricter.
  // 0.7 catches: "cloud" → "claude" (~0.83), "creed" → "cred" (~0.80)
  // 0.7 rejects: "swiggy" → "google" (~0.33)
  static const double _fuzzyThreshold = 0.40;

  List<InstalledApp> _apps = [];
  bool _loaded = false;

  List<InstalledApp> get apps => _apps;
  bool get isLoaded => _loaded;

  Future<void>? _loadFuture;

  /// Scans device for all installed user apps. Call once on app launch.
  Future<void> loadInstalledApps() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (raw == null) return;
      _apps = raw
          .map((e) => InstalledApp.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _loaded = true;
      _log.i('📱 Scanned ${_apps.length} installed apps');
    } catch (e) {
      _log.e('Failed to scan apps: $e');
    }
  }   


  /// Idempotent. Starts the scan if needed, awaits it if in flight.
  /// Retries on a previous failure rather than caching an empty result.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loadFuture ??= loadInstalledApps().whenComplete(() {
      if (!_loaded) _loadFuture = null;
    });
    await _loadFuture;
  }

  /// Strips spaces, dots, dashes, underscores for normalized comparison.
  /// "chat gpt" → "chatgpt", "confirm.tkt" → "confirmtkt"
  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[\s._\-]+'), '');
  }

  /// Finds an app by display name with progressive matching strategies.
  /// Stages: exact pkg → exact name → normalized name → substring → fuzzy
  InstalledApp? findByName(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;

    // STAGE 1: Exact package name
    for (final app in _apps) {
      if (app.packageName.toLowerCase() == q) {
        _log.d('🎯 findByName exact-pkg: "$q" → ${app.displayName}');
        return app;
      }
    }

    // STAGE 2: Exact display name
    for (final app in _apps) {
      if (app.displayName.toLowerCase() == q) {
        _log.d('🎯 findByName exact-name: "$q" → ${app.displayName}');
        return app;
      }
    }

    // STAGE 3: Normalized match (strips spaces/dots/dashes)
    // Catches: "chat gpt" → "chatgpt", "confirm tkt" → "confirmtkt"
    final qNorm = _normalize(q);
    for (final app in _apps) {
      if (_normalize(app.displayName) == qNorm) {
        _log.d('🎯 findByName normalized: "$q" → ${app.displayName}');
        return app;
      }
    }

   // STAGES 4-5: Substring matches (display name, then package name)
    // GUARD: skip for queries ≤3 chars to prevent "gp" matching "ChatGPT"
    if (q.length >= 4) {
      // STAGE 4: Substring on display name
      for (final app in _apps) {
        if (app.displayName.toLowerCase().contains(q)) {
          _log.d('🎯 findByName substring-name: "$q" → ${app.displayName}');
          return app;
        }
      }

      // STAGE 5: Substring on package name
      for (final app in _apps) {
        if (app.packageName.toLowerCase().contains(q)) {
          _log.d('🎯 findByName substring-pkg: "$q" → ${app.displayName}');
          return app;
        }
      }
    }

    // STAGE 6: Fuzzy match (Dice's coefficient via string_similarity)
    // Catches phonetic STT errors like "cloud" → "Claude" (~0.44)
    // GUARD: queries ≤3 chars are too ambiguous for fuzzy matching
    // (e.g. "gp" would fuzzy-match "ChatGPT" with high false-positive rate)
    if (q.length < 4) {
      _log.w('❌ findByName: no match for "$q" '
             '(query too short for fuzzy, tried ${_apps.length} apps exactly)');
      return null;
    }
    
    final scored = <MapEntry<InstalledApp, double>>[];
    for (final app in _apps) {
      final score = q.similarityTo(app.displayName.toLowerCase());
      if (score >= _fuzzyThreshold) {
        scored.add(MapEntry(app, score));
      }
    }
    
    // Sort by score descending, take the best
    scored.sort((a, b) => b.value.compareTo(a.value));
    
    // Diagnostic: log top 3 candidates regardless of match
    final top3 = _apps
      .map((a) => MapEntry(a, q.similarityTo(a.displayName.toLowerCase())))
      .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _log.i('🔎 Top 3 fuzzy candidates for "$q": '
           '${top3.take(3).map((e) => '${e.key.displayName}=${e.value.toStringAsFixed(2)}').join(", ")}');

    if (scored.isNotEmpty) {
      final best = scored.first;
      _log.i('🔎 findByName FUZZY: "$q" → ${best.key.displayName} '
             '(score: ${best.value.toStringAsFixed(2)})');
      return best.key;
    }

      
    _log.w('❌ findByName: no match for "$q" (tried ${_apps.length} apps)');
    return null;
  }

  /// Generic launch — opens any installed app by package name.
  Future<bool> launchApp(String packageName) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'launchApp',
        {'packageName': packageName},
      );
      return ok ?? false;
    } catch (e) {
      _log.e('Launch error for $packageName: $e');
      return false;
    }
  }

  /// Fires a VIEW intent for [url] PINNED into [packageName] — the Dart
  /// equivalent of `adb shell am start -d <url> -p <pkg>`. This is how
  /// https app-links open IN the app instead of the browser.
  /// Returns false if the package can't handle the URL (caller falls back).
  Future<bool> launchUrlInPackage(String url, String packageName) async {
    try {
      final ok = await _channel.invokeMethod<bool>('launchUrlInPackage', {
        'url': url,
        'package': packageName,
      });
      return ok ?? false;
    } catch (e) {
      _log.w('launchUrlInPackage failed for $packageName: $e');
      return false;
    }
  }
}

class InstalledApp {
  final String packageName;
  final String displayName;
  final bool hasLaunchIntent;

  InstalledApp({
    required this.packageName,
    required this.displayName,
    required this.hasLaunchIntent,
  });

  factory InstalledApp.fromMap(Map<String, dynamic> map) {
    return InstalledApp(
      packageName: map['packageName'] as String,
      displayName: map['displayName'] as String,
      hasLaunchIntent: map['hasLaunchIntent'] as bool? ?? true,
    );
  }
}