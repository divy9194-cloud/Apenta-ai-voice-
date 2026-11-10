import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'claude_client.dart';
import 'env.dart';
import 'local_edit.dart';
import 'local_store.dart';

/// Chat uses Claude (Gemini as backup). Pictures use Meta Muse Image, Gemini, or a free service.
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
  static String _clean(Object e) => _short(e.toString().replaceFirst('Exception: ', ''));

  // ---------------------------------------------------------------- chat

  static List<ChatEntry> _recent(List<ChatEntry> history) {
    final List<ChatEntry> recent =
        List<ChatEntry>.from(history.length > 10 ? history.sublist(history.length - 10) : history);
    while (recent.isNotEmpty && !recent.first.fromUser) {
      recent.removeAt(0);
    }
    return recent;
  }

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

  static Future<String?> _geminiChat(String prompt, List<ChatEntry> recent, List<String> problems) async {
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
    return null;
  }

  static Future<String> chat(String prompt, List<ChatEntry> history) async {
    final List<ChatEntry> recent = _recent(history);
    final List<String> problems = <String>[];

    if (ClaudeClient.ready) {
      try {
        final List<Map<String, dynamic>> msgs = <Map<String, dynamic>>[];
        for (final ChatEntry e in recent) {
          msgs.add({'role': e.fromUser ? 'user' : 'assistant', 'content': e.text});
        }
        msgs.add({'role': 'user', 'content': prompt});
        return await ClaudeClient.ask(system: _persona, messages: msgs);
      } on TimeoutException {
        problems.add('Claude took too long');
      } catch (e) {
        problems.add('Claude ${_clean(e)}');
      }
    } else {
      problems.add('Claude key is not set (add ANTHROPIC_API_KEY)');
    }

    if (AppEnv.geminiKey.isNotEmpty) {
      final String? answer = await _geminiChat(prompt, recent, problems);
      if (answer != null) return answer;
    }
    return 'AI problem: ${problems.join(' | ')}';
  }

  // ---------------------------------------------------------------- image helpers

  static String _mime(Uint8List b) {
    if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50) return 'image/png';
    if (b.length > 11 && b[8] == 0x57 && b[9] == 0x45) return 'image/webp';
    return 'image/jpeg';
  }

  static String _ext(String mime) {
    if (mime == 'image/png') return 'png';
    if (mime == 'image/webp') return 'webp';
    return 'jpg';
  }

  /// Reads an OpenAI-style image reply (Meta Model API uses this format).
  static Future<Uint8List?> _fromOpenAiStyle(String body) async {
    final Map<String, dynamic> data = jsonDecode(body) as Map<String, dynamic>;
    final List<dynamic>? list = data['data'] as List<dynamic>?;
    if (list == null || list.isEmpty) return null;
    final Map<dynamic, dynamic> first = list.first as Map;
    final dynamic b64 = first['b64_json'];
    if (b64 is String && b64.isNotEmpty) return base64Decode(b64);
    final dynamic url = first['url'];
    if (url is String && url.isNotEmpty) {
      final http.Response r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      if (r.statusCode == 200) return r.bodyBytes;
    }
    return null;
  }

  // ---------------------------------------------------------------- Meta Muse Image

  static Future<Uint8List?> _metaGenerate(String prompt) async {
    final http.Response res = await http
        .post(
          Uri.parse('${AppEnv.metaBase}/images/generations'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${AppEnv.metaKey}'},
          body: jsonEncode({'model': AppEnv.metaImageModel, 'prompt': prompt, 'n': 1}),
        )
        .timeout(const Duration(seconds: 100));
    final String body = utf8.decode(res.bodyBytes);
    if (res.statusCode != 200) throw Exception('error ${res.statusCode}: ${_short(body)}');
    return _fromOpenAiStyle(body);
  }

  static Future<Uint8List?> _metaEdit(Uint8List photo, String instruction) async {
    final String mime = _mime(photo);
    final http.MultipartRequest req = http.MultipartRequest('POST', Uri.parse('${AppEnv.metaBase}/images/edits'))
      ..headers['Authorization'] = 'Bearer ${AppEnv.metaKey}'
      ..fields['model'] = AppEnv.metaImageModel
      ..fields['prompt'] = instruction
      ..fields['n'] = '1'
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        photo,
        filename: 'photo.${_ext(mime)}',
        contentType: MediaType.parse(mime),
      ));
    final http.StreamedResponse streamed = await req.send().timeout(const Duration(seconds: 120));
    final http.Response res = await http.Response.fromStream(streamed);
    final String body = utf8.decode(res.bodyBytes);
    if (res.statusCode != 200) throw Exception('error ${res.statusCode}: ${_short(body)}');
    return _fromOpenAiStyle(body);
  }

  // ---------------------------------------------------------------- Gemini images

  static Future<Uint8List?> _geminiBytes(String model, List<Map<String, dynamic>> parts) async {
    final http.Response res = await http
        .post(
          Uri.parse('$_base/$model:generateContent'),
          headers: _headers,
          body: jsonEncode({
            'contents': [
              {'parts': parts}
            ],
            'generationConfig': {
              'responseModalities': ['TEXT', 'IMAGE']
            },
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode == 429) throw Exception('error 429 (Gemini pictures need a paid Google plan)');
    if (res.statusCode != 200) throw Exception('error ${res.statusCode}');
    final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List<dynamic>? candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final Map<dynamic, dynamic> first = candidates.first as Map;
    final Map<dynamic, dynamic>? content = first['content'] as Map?;
    final List<dynamic> outParts = (content?['parts'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic part in outParts) {
      final Map<dynamic, dynamic> map = part as Map;
      final dynamic inline = map['inlineData'] ?? map['inline_data'];
      if (inline != null) {
        return base64Decode((inline as Map)['data'] as String);
      }
    }
    return null;
  }

  static Future<Uint8List> _freeImage(String prompt) async {
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
    return res.bodyBytes;
  }

  // ---------------------------------------------------------------- public image API

  static Future<Uint8List> _generateBytes(String prompt) async {
    final List<String> problems = <String>[];
    if (AppEnv.metaKey.isNotEmpty) {
      try {
        final Uint8List? out = await _metaGenerate(prompt);
        if (out != null) return out;
        problems.add('Meta returned no image');
      } on TimeoutException {
        problems.add('Meta took too long');
      } catch (e) {
        problems.add('Meta ${_clean(e)}');
      }
    } else {
      problems.add('Meta key is not set (add META_API_KEY)');
    }
    if (AppEnv.geminiKey.isNotEmpty) {
      final List<String> models = <String>[AppEnv.imageModel, 'gemini-3.1-flash-lite-image'];
      final List<String> tried = <String>[];
      for (final String model in models) {
        if (tried.contains(model)) continue;
        tried.add(model);
        try {
          final Uint8List? out = await _geminiBytes(model, <Map<String, dynamic>>[
            {'text': prompt}
          ]);
          if (out != null) return out;
          problems.add('$model returned no image');
        } on TimeoutException {
          problems.add('$model took too long');
        } catch (e) {
          problems.add('$model ${_clean(e)}');
        }
      }
    }
    try {
      return await _freeImage(prompt);
    } on TimeoutException {
      problems.add('free image service took too long');
    } catch (e) {
      problems.add('free image service ${_clean(e)}');
    }
    throw Exception(problems.join(' | '));
  }

  /// Makes an image from text and saves it. Returns the saved file path.
  static Future<String> image(String prompt) async {
    final Uint8List bytes = await _generateBytes(prompt);
    return LocalStore.saveImage(bytes);
  }

  /// Edits a photo. Simple edits run on the phone; the rest use Meta Muse Image (Gemini as backup).
  static Future<Uint8List> editImage(Uint8List photo, String instruction) async {
    if (LocalEdit.canHandle(instruction)) {
      try {
        return await LocalEdit.apply(photo, instruction);
      } catch (_) {}
    }
    final List<String> problems = <String>[];
    if (AppEnv.metaKey.isNotEmpty) {
      try {
        final Uint8List? out = await _metaEdit(photo, instruction);
        if (out != null) return out;
        problems.add('Meta returned no image');
      } on TimeoutException {
        problems.add('Meta took too long');
      } catch (e) {
        problems.add('Meta ${_clean(e)}');
      }
    } else {
      problems.add('Meta key is not set (add META_API_KEY)');
    }
    if (AppEnv.geminiKey.isNotEmpty) {
      try {
        final Uint8List? out = await _geminiBytes(AppEnv.imageModel, <Map<String, dynamic>>[
          {
            'inlineData': {'mimeType': _mime(photo), 'data': base64Encode(photo)}
          },
          {'text': instruction},
        ]);
        if (out != null) return out;
        problems.add('Gemini returned no image');
      } on TimeoutException {
        problems.add('Gemini took too long');
      } catch (e) {
        problems.add('Gemini ${_clean(e)}');
      }
    }
    problems.add('Tip: black and white, sepia, brighten, darken, enhance, warm, cool, flip and rotate work without any key');
    throw Exception(problems.join(' | '));
  }
}
