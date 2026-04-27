// lib/services/actions/youtube_action.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class YouTubeAction {
  final _log = Logger();

  Future<bool> search(String query) async {
    _log.d('YouTube search: $query');
    final enc = Uri.encodeComponent(query);

    // Try YouTube app deep link
    final appUri = Uri.parse('vnd.youtube://results?search_query=$enc');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return true;
    }

    // Web fallback
    await launchUrl(
      Uri.parse('https://www.youtube.com/results?search_query=$enc'),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }

  Future<bool> play(String query) async {
    return await search(query);
  }
}
