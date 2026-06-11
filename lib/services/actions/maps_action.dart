// lib/services/actions/maps_action.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class MapsAction {
  final _log = Logger();

  /// v1.1 reliability: every stage is guarded; returns false only when ALL
  /// fallbacks failed, so the router can speak a graceful failure.
  Future<bool> navigate(String destination) async {
    _log.d('Maps navigate: $destination');
    final enc = Uri.encodeComponent(destination);

    // 1. Native turn-by-turn (best UX)
    if (await _tryLaunch(Uri.parse('google.navigation:q=$enc&mode=d'))) {
      return true;
    }

    // 2. Geo intent — opens Maps with pin
    if (await _tryLaunch(Uri.parse('geo:0,0?q=$enc'))) {
      return true;
    }

    // 3. Web URL — force navigation mode (NOT just search)
    return _tryLaunch(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$enc'
        '&travelmode=driving'
        '&dir_action=navigate',
      ),
      external: true,
    );
  }

  Future<bool> findNearby(String placeType) async {
    _log.d('Maps nearby: $placeType');
    final enc = Uri.encodeComponent('$placeType near me');
    // Geo intent uses device location for "near me"
    if (await _tryLaunch(Uri.parse('geo:0,0?q=$enc'))) {
      return true;
    }
    return _tryLaunch(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$enc'),
      external: true,
    );
  }

  Future<bool> search(String query) async {
    _log.d('Maps search: $query');
    final enc = Uri.encodeComponent(query);
    return _tryLaunch(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$enc'),
      external: true,
    );
  }

  /// canLaunchUrl + launchUrl with all failure modes caught.
  Future<bool> _tryLaunch(Uri uri, {bool external = false}) async {
    try {
      if (!external && !await canLaunchUrl(uri)) return false;
      return await launchUrl(
        uri,
        mode: external ? LaunchMode.externalApplication : LaunchMode.platformDefault,
      );
    } catch (e) {
      _log.w('Maps launch failed for $uri: $e');
      return false;
    }
  }
}
