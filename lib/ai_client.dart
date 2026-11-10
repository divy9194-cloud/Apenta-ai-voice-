import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../core/store.dart';

/// Google Gemini chat. Key is injected with --dart-define=GEMINI_API_KEY=...
class AiService {
  static const _sys =
      'You are Penta, a friendly voice assistant made by Divyanshu Kumar. Reply in the same language the user speaks '
      '(English, Hindi or Hinglish). Keep answers short and speakable (under 60 words) unless asked for more. No markdown.';

  Future<String> ask(String prompt, List<ChatMsg> history) async {
    if (Env.geminiKey.isEmpty) return 'The Gemini API key is not configured.';
    var h = history.length > 10 ? history.sublist(history.length - 10) : history;
    while (h.isNotEmpty && !h.first.user) {
      h = h.sublist(1);
    }
    final contents = [
      for (final m in h)
        {'role': m.user ? 'user' : 'model', 'parts': [{'text': m.text}]},
      {'role': 'user', 'parts': [{'text': prompt}]},
    ];
    final r = await http
        .post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${Env.geminiModel}:generateContent'),
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': Env.geminiKey},
          body: jsonEncode({
            'systemInstruction': {'parts': [{'text': _sys}]},
            'contents': contents,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) return 'The AI service returned an error (${r.statusCode}).';
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    return (d['candidates'][0]['content']['parts'][0]['text'] as String).trim();
  }
}
