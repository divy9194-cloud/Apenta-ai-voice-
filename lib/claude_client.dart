import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';

/// Talks to Claude (Anthropic Messages API).
class ClaudeClient {
  static const String _url = 'https://api.anthropic.com/v1/messages';

  static bool get ready => AppEnv.claudeKey.isNotEmpty;

  static Map<String, String> get _headers => {
        'content-type': 'application/json',
        'x-api-key': AppEnv.claudeKey,
        'anthropic-version': '2023-06-01',
      };

  static String _short(String s) => s.length > 140 ? s.substring(0, 140) : s;

  /// Pulls the readable message out of an Anthropic error reply.
  static String _errorText(String body) {
    try {
      final Map<String, dynamic> data = jsonDecode(body) as Map<String, dynamic>;
      final Map<dynamic, dynamic>? err = data['error'] as Map?;
      final dynamic m = err?['message'];
      if (m is String) return _short(m);
    } catch (_) {}
    return _short(body);
  }

  static String? _readText(String body) {
    final Map<String, dynamic> data = jsonDecode(body) as Map<String, dynamic>;
    final List<dynamic>? content = data['content'] as List<dynamic>?;
    if (content == null) return null;
    final StringBuffer out = StringBuffer();
    for (final dynamic b in content) {
      final Map<dynamic, dynamic> block = b as Map;
      if (block['type'] == 'text') {
        final dynamic t = block['text'];
        if (t is String) out.write(t);
      }
    }
    final String s = out.toString().trim();
    return s.isEmpty ? null : s;
  }

  static Future<http.Response> _post(Map<String, dynamic> body, Duration timeout) {
    return http.post(Uri.parse(_url), headers: _headers, body: jsonEncode(body)).timeout(timeout);
  }

  /// Sends the messages and returns Claude's text answer. Throws an Exception with a short reason on failure.
  static Future<String> ask({
    required String system,
    required List<Map<String, dynamic>> messages,
    int maxTokens = 2048,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'model': AppEnv.claudeModel,
      'max_tokens': maxTokens,
      'system': system,
      'messages': messages,
      'output_config': <String, dynamic>{'effort': AppEnv.claudeEffort},
    };
    http.Response res = await _post(body, timeout);
    String text = utf8.decode(res.bodyBytes);
    // If this account or model does not accept the effort setting, try again without it.
    if (res.statusCode == 400 && (text.contains('effort') || text.contains('output_config'))) {
      body.remove('output_config');
      res = await _post(body, timeout);
      text = utf8.decode(res.bodyBytes);
    }
    if (res.statusCode != 200) {
      throw Exception('error ${res.statusCode}: ${_errorText(text)}');
    }
    final String? answer = _readText(text);
    if (answer == null) throw Exception('gave an empty answer');
    return answer;
  }
    /// Quick check used by Settings. Returns a short report.
  static Future<String> test() async {
    if (!ready) return 'No key. Add the ANTHROPIC_API_KEY secret and rebuild the app.';
    final String k = AppEnv.claudeKey;
    final String masked = k.length > 12 ? '${k.substring(0, 7)}…${k.substring(k.length - 4)}' : 'too short';
    final String warn = k != k.trim() ? '\nWarning: the key has a space or new line. Re-paste it.' : '';
    final DateTime start = DateTime.now();
    try {
      final String reply = await ask(
        system: 'Reply with exactly: OK',
        messages: <Map<String, dynamic>>[
          {'role': 'user', 'content': 'Test'}
        ],
        maxTokens: 300,
        timeout: const Duration(seconds: 25),
      );
      final int ms = DateTime.now().difference(start).inMilliseconds;
      final String shown = reply.length > 40 ? reply.substring(0, 40) : reply;
      return 'Claude is working.\nModel: ${AppEnv.claudeModel}\nEffort: ${AppEnv.claudeEffort}\nReply: $shown\nTime: $ms ms\nKey: $masked$warn';
    } catch (e) {
      return 'Claude failed.\n${e.toString().replaceFirst('Exception: ', '')}\nKey: $masked$warn';
    }
  }
}
