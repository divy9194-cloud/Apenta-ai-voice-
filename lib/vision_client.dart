import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'env.dart';

/// Sends a camera picture and a question to Gemini and returns a short answer.
class VisionClient {
  static const String _base = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _persona =
      'You are Penta, a voice assistant looking through the phone camera. Answer the question about the picture '
      'in the language the user used (English, Hindi or Hinglish). Keep it short and easy to speak, under 60 words. '
      'Do not use markdown.';

  static String _short(String s) => s.length > 160 ? s.substring(0, 160) : s;

  static String? _read(String body) {
    final Map<String, dynamic> data = jsonDecode(body) as Map<String, dynamic>;
    final List<dynamic>? candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final Map<dynamic, dynamic> first = candidates.first as Map;
    final Map<dynamic, dynamic>? content = first['content'] as Map?;
    final List<dynamic> parts = (content?['parts'] as List<dynamic>?) ?? <dynamic>[];
    final StringBuffer out = StringBuffer();
    for (final dynamic p in parts) {
      final Map<dynamic, dynamic> part = p as Map;
      if (part['thought'] == true) continue;
      final dynamic t = part['text'];
      if (t is String) out.write(t);
    }
    final String answer = out.toString().trim();
    return answer.isEmpty ? null : answer;
  }

  static Future<String> ask(String question, Uint8List jpeg) async {
    if (AppEnv.geminiKey.isEmpty) return 'The Gemini API key is not configured.';
    final String payload = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _persona}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {'mimeType': 'image/jpeg', 'data': base64Encode(jpeg)}
            },
            {'text': question},
          ],
        }
      ],
    });
    final List<String> models = <String>[AppEnv.chatModel, 'gemini-flash-lite-latest', 'gemini-3.6-flash'];
    final List<String> tried = <String>[];
    String lastProblem = 'no model answered';
    for (final String model in models) {
      if (tried.contains(model)) continue;
      tried.add(model);
      try {
        final http.Response res = await http
            .post(
              Uri.parse('$_base/$model:generateContent'),
              headers: {'Content-Type': 'application/json', 'x-goog-api-key': AppEnv.geminiKey},
              body: payload,
            )
            .timeout(const Duration(seconds: 30));
        final String body = utf8.decode(res.bodyBytes);
        if (res.statusCode == 200) {
          final String? answer = _read(body);
          if (answer != null) return answer;
          lastProblem = '$model gave an empty answer';
          continue;
        }
        lastProblem = '$model error ${res.statusCode}: ${_short(body)}';
        if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) break;
      } on TimeoutException {
        lastProblem = '$model took too long';
      } catch (e) {
        lastProblem = '$model: ${_short(e.toString())}';
      }
    }
    return 'Vision problem: $lastProblem';
  }
}
