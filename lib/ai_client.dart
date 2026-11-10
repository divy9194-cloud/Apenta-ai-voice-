import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';

class AiClient {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';

  Future<String> sendMessage({
    required String prompt,
    List>? imageBytesList,
  }) async {
    final headers = {
      'x-api-key': Env.anthropicApiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    };

    final List> content = [];

    if (imageBytesList != null) {
      for (var img in imageBytesList) {
        content.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': img['media_type'] ?? 'image/jpeg',
            'data': img['data'],
          },
        });
      }
    }

    content.add({
      'type': 'text',
      'text': prompt,
    });

    final body = jsonEncode({
      'model': Env.defaultModel,
      'max_tokens': 2048,
      'messages': [
        {
          'role': 'user',
          'content': content,
        }
      ],
    });

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final contents = data['content'] as List<dynamic>;
        if (contents.isNotEmpty) {
          return contents.first['text'] as String? ?? '';
        }
        return '';
      } else {
        throw Exception('Claude API Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to Claude server: $e');
    }
  }
}
