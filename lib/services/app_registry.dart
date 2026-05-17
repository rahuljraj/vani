import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class AppRegistry {
  static AppRegistry? _instance;
  static AppRegistry get instance => _instance ??= AppRegistry._();
  AppRegistry._();

  final _channel = const MethodChannel('com.vani/app_actions');
  final _log = Logger();

  List<InstalledApp> _apps = [];
  bool _loaded = false;

  List<InstalledApp> get apps => _apps;
  bool get isLoaded => _loaded;

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

  /// Finds an app by display name (fuzzy match) or exact package name.
  InstalledApp? findByName(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;

    // Try exact package name first
    for (final app in _apps) {
      if (app.packageName.toLowerCase() == q) return app;
    }

    // Then exact display name
    for (final app in _apps) {
      if (app.displayName.toLowerCase() == q) return app;
    }

    // Then substring match on display name
    for (final app in _apps) {
      if (app.displayName.toLowerCase().contains(q)) return app;
    }

    // Then substring match on package name
    for (final app in _apps) {
      if (app.packageName.toLowerCase().contains(q)) return app;
    }

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