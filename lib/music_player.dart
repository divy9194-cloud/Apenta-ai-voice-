import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';
import 'native_bridge.dart';

/// Opens YouTube Music. With YOUTUBE_API_KEY it opens the top result directly.
class MusicPlayer {
  static Future<String> play(String query) async {
    String url = Uri.https('music.youtube.com', '/search', {'q': query}).toString();
    if (AppEnv.youtubeKey.isNotEmpty) {
      try {
        final http.Response r = await http.get(Uri.https('www.googleapis.com', '/youtube/v3/search', {
          'part': 'snippet',
          'q': query,
          'type': 'video',
          'videoCategoryId': '10',
          'maxResults': '1',
          'key': AppEnv.youtubeKey,
        }));
        final dynamic data = jsonDecode(r.body);
        final String id = data['items'][0]['id']['videoId'] as String;
        url = 'https://music.youtube.com/watch?v=$id';
      } catch (_) {}
    }
    final bool ok = await Device.openUrl(url);
    return ok ? 'Playing $query.' : 'I could not open a music app.';
  }
}
