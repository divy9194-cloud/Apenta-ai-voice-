import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';
import 'local_store.dart';

/// Google Gemini: text answers and image generation.
class AiClient {
  static const String _base = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _persona =
      'You are Penta, a friendly voice assistant made by Divyanshu Kumar. Reply in the language the user speaks '
      '(English, Hindi or Hinglish). Keep answers short and easy to speak, under 60 words unless asked for more. '
      'Do not use markdown.';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-goog-api-key': AppEnv.geminiKey,
      };

  static String _short(String s) => s.length > 160 ? s.substring(0, 160) : s;

  /// Reads the text out of a Gemini reply. Returns null when there is no text.
  static String? _readAnswer(String body) {
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

  static Future<String> chat(String prompt, List<ChatEntry> history) async {
    if (AppEnv.geminiKey.isEmpty) return 'The Gemini API key is not configured.';
    final List<ChatEntry> recent =
        List<ChatEntry>.from(history.length > 10 ? history.sublist(history.length - 10) : history);
    while (recent.isNotEmpty && !recent.first.fromUser) {
      recent.removeAt(0);
    }
    final List<Map<String, dynamic>> contents = <Map<String, dynamic>>[];
    for (final ChatEntry e in recent) {
      contents.add({
        'role': e.fromUser ? 'user' : 'model',
        'parts': [
          {'text': e.text}
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });
    final String payload = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _persona}
        ]
      },
      'contents': contents,
    });

    // Tries the main model first, then faster backups if it is slow or missing.
    final List<String> models = <String>[AppEnv.chatModel, 'gemini-flash-lite-latest', 'gemini-3.6-flash'];
    final List<String> tried = <String>[];
    String lastProblem = 'no model answered';
    for (final String model in models) {
      if (tried.contains(model)) continue;
      tried.add(model);
      try {
        final http.Response res = await http
            .post(Uri.parse('$_base/$model:generateContent'), headers: _headers, body: payload)
            .timeout(const Duration(seconds: 20));
        final String body = utf8.decode(res.bodyBytes);
        if (res.statusCode == 200) {
          final String? answer = _readAnswer(body);
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
    return 'AI problem: $lastProblem';
  }

  /// Returns the saved image file path.
  static Future<String> image(String prompt) async {
    if (AppEnv.geminiKey.isEmpty) throw Exception('Gemini API key is not configured.');
    final http.Response res = await http
        .post(
          Uri.parse('$_base/${AppEnv.imageModel}:generateContent'),
          headers: _headers,
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'responseModalities': ['TEXT', 'IMAGE']
            },
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) throw Exception('Image API error ${res.statusCode}');
    final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List<dynamic> parts =
        (((data['candidates'] as List<dynamic>).first as Map)['content'] as Map)['parts'] as List<dynamic>;
    for (final dynamic part in parts) {
      final Map<dynamic, dynamic> map = part as Map;
      final dynamic inline = map['inlineData'] ?? map['inline_data'];
      if (inline != null) {
        final String b64 = (inline as Map)['data'] as String;
        return LocalStore.saveImage(base64Decode(b64));
      }
    }
    throw Exception('No image returned');
  }
}
