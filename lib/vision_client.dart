import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'claude_client.dart';
import 'env.dart';

/// Sends a picture (camera or screen) and a question to Claude, with Gemini as backup.
class VisionClient {
  static const String _base = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _persona =
      'You are Penta, a voice assistant looking at a picture from the user\'s phone (the camera or the screen). '
      'Answer the question about the picture in the language the user used (English, Hindi or Hinglish). '
      'Keep it short and easy to speak, under 60 words. Do not use markdown.';

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
    final List<String> problems = <String>[];

    if (ClaudeClient.ready) {
      try {
        return await ClaudeClient.ask(
          system: _persona,
          maxTokens: 1500,
          timeout: const Duration(seconds: 40),
          messages: <Map<String, dynamic>>[
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': base64Encode(jpeg)},
                },
                {'type': 'text', 'text': question},
              ],
            }
          ],
        );
      } on TimeoutException {
        problems.add('Claude took too long');
      } catch (e) {
        problems.add('Claude ${_short(e.toString().replaceFirst('Exception: ', ''))}');
      }
    } else {
      problems.add('Claude key is not set (add ANTHROPIC_API_KEY)');
    }

    if (AppEnv.geminiKey.isNotEmpty) {
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
      final List<String> models = <String>[AppEnv.chatModel, 'gemini-flash-lite-latest'];
      final List<String> tried = <String>[];
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
            problems.add('$model gave an empty answer');
            continue;
          }
          problems.add('$model error ${res.statusCode}: ${_short(body)}');
          if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) break;
        } on TimeoutException {
          problems.add('$model took too long');
        } catch (e) {
          problems.add('$model: ${_short(e.toString())}');
        }
      }
    }
    return 'Vision problem: ${problems.join(' | ')}';
  }
}
