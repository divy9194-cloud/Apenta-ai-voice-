import 'package:flutter/services.dart';

/// Talks to Kotlin (MainActivity.kt) for everything that needs Android APIs.
class Device {
  static const MethodChannel _ch = MethodChannel('penta/device');

  static Future<dynamic> _call(String name, [Map<String, dynamic>? args]) async {
    try {
      return await _ch.invokeMethod<dynamic>(name, args);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _flag(String name, [Map<String, dynamic>? args]) async {
    final dynamic r = await _call(name, args);
    return r == true;
  }

  static Future<String> _status(String name, [Map<String, dynamic>? args]) async {
    final dynamic r = await _call(name, args);
    return r is String ? r : 'error';
  }

  static Future<bool> torch(bool on) => _flag('torch', {'on': on});
  static Future<bool> canWriteSettings() => _flag('canWriteSettings');
  static Future<void> askWriteSettings() async {
    await _call('askWriteSettings');
  }

  static Future<int> brightness() async {
    final dynamic r = await _call('getBrightness');
    return r is int ? r : 50;
  }

  static Future<bool> setBrightness(int percent) => _flag('setBrightness', {'percent': percent});
  static Future<bool> openApp(String name) => _flag('openApp', {'name': name});

  static Future<List<String>> appNames() async {
    final dynamic r = await _call('appNames');
    if (r is List) {
      return r.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  static Future<Map<String, String>?> findContact(String query) async {
    final dynamic r = await _call('findContact', {'query': query});
    if (r is Map) {
      return {'name': r['name'].toString(), 'number': r['number'].toString()};
    }
    return null;
  }

  static Future<bool> dial(String number) => _flag('dial', {'number': number});
  static Future<bool> alarm(int hour, int minute) => _flag('alarm', {'hour': hour, 'minute': minute});
  static Future<bool> timer(int seconds) => _flag('timer', {'seconds': seconds});
  static Future<bool> settingsPage(String page) => _flag('settingsPage', {'page': page});

  static Future<int> battery() async {
    final dynamic r = await _call('battery');
    return r is int ? r : -1;
  }

  static Future<bool> mediaKey(int code) => _flag('mediaKey', {'code': code});
  static Future<bool> camera() => _flag('camera');
  static Future<bool> gallery() => _flag('gallery');
  static Future<bool> openUrl(String url) => _flag('openUrl', {'url': url});

  // Accessibility features (screenshot, lock, type, search)
  static Future<bool> screenshot() => _flag('screenshot');
  static Future<bool> screenshotReady() => _flag('screenshotReady');
  static Future<void> askScreenshotAccess() async {
    await _call('askScreenshotAccess');
  }

  static Future<bool> lockScreen() => _flag('lockScreen');

  /// Returns: ok, no_service, no_field
  static Future<String> typeText(String text) => _status('typeText', {'text': text});

  /// Returns: ok, no_service, failed
  static Future<String> pressSearch() => _status('pressSearch');

  /// Returns: ok, no_service, no_search_box, no_field
  static Future<String> searchInOpenApp(String query) => _status('searchInOpenApp', {'query': query});

  /// True once after Penta was opened with a long press on Home.
  static Future<bool> consumeAssistLaunch() => _flag('consumeAssistLaunch');

  static Future<void> openAssistantSettings() async {
    await _call('openAssistantSettings');
  }

  static Future<void> startListenService() async {
    await _call('startListen');
  }

  static Future<void> stopListenService() async {
    await _call('stopListen');
  }
}
