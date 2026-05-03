// lib/services/actions/maps_action.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class MapsAction {
  final _log = Logger();

  Future<bool> navigate(String destination) async {
    _log.d('Maps navigate: $destination');
    final enc = Uri.encodeComponent(destination);

    // 1. Native turn-by-turn (best UX)
    final navUri = Uri.parse('google.navigation:q=$enc&mode=d');
    if (await canLaunchUrl(navUri)) {
      await launchUrl(navUri);
      return true;
    }

    // 2. Geo intent — opens Maps with pin
    final geoUri = Uri.parse('geo:0,0?q=$enc');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
      return true;
    }

    // 3. Web URL — force navigation mode (NOT just search)
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$enc'
        '&travelmode=driving'
        '&dir_action=navigate',
      ),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }

  Future<bool> findNearby(String placeType) async {
    _log.d('Maps nearby: $placeType');
    final enc = Uri.encodeComponent('$placeType near me');
    // Geo intent uses device location for "near me"
    final geoUri = Uri.parse('geo:0,0?q=$enc');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
      return true;
    }
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$enc'),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }

  Future<bool> search(String query) async {
    _log.d('Maps search: $query');
    final enc = Uri.encodeComponent(query);
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$enc'),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }
}