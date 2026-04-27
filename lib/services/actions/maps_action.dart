// lib/services/actions/maps_action.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class MapsAction {
  final _log = Logger();

  Future<bool> navigate(String destination) async {
    _log.d('Maps navigate: $destination');
    final enc = Uri.encodeComponent(destination);

    // Try navigation deep link
    final navUri = Uri.parse('google.navigation:q=$enc&mode=d');
    if (await canLaunchUrl(navUri)) {
      await launchUrl(navUri);
      return true;
    }

    // Fallback: geo intent
    final geoUri = Uri.parse('geo:0,0?q=$enc');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
      return true;
    }

    // Final fallback: browser
    await launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$enc'),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }

  Future<bool> findNearby(String placeType) async {
    _log.d('Maps nearby: $placeType');
    final enc = Uri.encodeComponent('$placeType near me');
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/$enc'),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }

  Future<bool> search(String query) async {
    _log.d('Maps search: $query');
    final enc = Uri.encodeComponent(query);
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/$enc'),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }
}
