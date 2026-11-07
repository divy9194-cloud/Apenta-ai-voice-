import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';
import 'local_store.dart';

/// Google Gemini for text, with image generation that falls back to a free service.
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

  /// Returns the saved image file path. Tries Google first, then a free service.
  static Future<String> image(String prompt) async {
    final List<String> problems = <String>[];
    if (AppEnv.geminiKey.isNotEmpty) {
      final List<String> models = <String>[AppEnv.imageModel, 'gemini-3.1-flash-lite-image'];
      final List<String> tried = <String>[];
      for (final String model in models) {
        if (tried.contains(model)) continue;
        tried.add(model);
        try {
          final String? path = await _geminiImage(model, prompt);
          if (path != null) return path;
          problems.add('$model returned no image');
        } on TimeoutException {
          problems.add('$model took too long');
        } catch (e) {
          problems.add('$model ${_short(e.toString().replaceFirst('Exception: ', ''))}');
        }
      }
    }
    try {
      return await _freeImage(prompt);
    } on TimeoutException {
      problems.add('free image service took too long');
    } catch (e) {
      problems.add('free image service ${_short(e.toString().replaceFirst('Exception: ', ''))}');
    }
    throw Exception(problems.join(' | '));
  }

  static Future<String?> _geminiImage(String model, String prompt) async {
    final http.Response res = await http
        .post(
          Uri.parse('$_base/$model:generateContent'),
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
        .timeout(const Duration(seconds: 45));
    if (res.statusCode == 429) throw Exception('error 429 (image generation needs a paid Google plan)');
    if (res.statusCode != 200) throw Exception('error ${res.statusCode}');
    final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List<dynamic>? candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final Map<dynamic, dynamic> first = candidates.first as Map;
    final Map<dynamic, dynamic>? content = first['content'] as Map?;
    final List<dynamic> parts = (content?['parts'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic part in parts) {
      final Map<dynamic, dynamic> map = part as Map;
      final dynamic inline = map['inlineData'] ?? map['inline_data'];
      if (inline != null) {
        final String b64 = (inline as Map)['data'] as String;
        return LocalStore.saveImage(base64Decode(b64));
      }
    }
    return null;
  }

  static Future<String> _freeImage(String prompt) async {
    final String clean = prompt.replaceAll('/', ' ').trim();
    final Uri url = Uri.https('image.pollinations.ai', '/prompt/$clean', {
      'width': '768',
      'height': '768',
      'nologo': 'true',
    });
    final http.Response res = await http.get(url).timeout(const Duration(seconds: 90));
    final String type = res.headers['content-type'] ?? '';
    if (res.statusCode != 200 || !type.startsWith('image/')) {
      throw Exception('error ${res.statusCode}');
    }
    return LocalStore.saveImage(res.bodyBytes);
  }
}
