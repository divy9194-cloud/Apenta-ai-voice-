import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatEntry {
  const ChatEntry(this.text, this.fromUser, this.time);
  final String text;
  final bool fromUser;
  final int time;

  Map<String, dynamic> toMap() => {'t': text, 'u': fromUser, 'ts': time};

  factory ChatEntry.fromMap(Map<String, dynamic> m) {
    return ChatEntry(m['t'] as String, m['u'] as bool, m['ts'] as int);
  }
}

/// Phone-side storage: chat history, generated images, simple flags.
class LocalStore {
  static SharedPreferences? _prefs;
  static SharedPreferences get prefs => _prefs!;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool flag(String key) => prefs.getBool(key) ?? false;

  static Future<void> setFlag(String key, bool value) async {
    await prefs.setBool(key, value);
  }

  static List<ChatEntry> loadChat() {
    final String? raw = prefs.getString('chat');
    if (raw == null) return <ChatEntry>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ChatEntry.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return <ChatEntry>[];
    }
  }

  static Future<void> saveChat(List<ChatEntry> list) async {
    final List<ChatEntry> keep = list.length > 200 ? list.sublist(list.length - 200) : list;
    await prefs.setString('chat', jsonEncode(keep.map((e) => e.toMap()).toList()));
  }

  static List<String> imagePaths() => prefs.getStringList('images') ?? <String>[];

  static Future<String> saveImage(Uint8List bytes) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/penta_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    await prefs.setStringList('images', <String>[file.path, ...imagePaths()]);
    return file.path;
  }
}  static String getLanguage() => prefs.getString('language') ?? 'English';

  static Future<void> setLanguage(String lang) async {
    await prefs.setString('language', lang);
  }

