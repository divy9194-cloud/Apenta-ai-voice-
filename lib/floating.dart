import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'assistant_brain.dart';
import 'local_store.dart';
import 'native_bridge.dart';
import 'permission_helper.dart';

/// Talks to the floating box and the screen capture code in Kotlin.
class Floating {
  static const MethodChannel _ch = MethodChannel('penta/device');
  static bool _ready = false;
  static void Function(String type, Map<String, dynamic> data)? onEvent;

  static void init() {
    if (_ready) return;
    _ready = true;
    _ch.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'overlayEvent') {
        final dynamic a = call.arguments;
        if (a is Map) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(a);
          onEvent?.call((data['type'] ?? '').toString(), data);
        }
      }
      return null;
    });
  }

  static Future<dynamic> _call(String name, [Map<String, dynamic>? args]) async {
    try {
      return await _ch.invokeMethod<dynamic>(name, args);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _flag(String name, [Map<String, dynamic>? args]) async => (await _call(name, args)) == true;

  static Future<void> setFloating(bool on) async {
    await _call('setFloating', {'on': on});
  }

  static Future<bool> canOverlay() => _flag('canOverlay');

  static Future<void> askOverlayPermission() async {
    await _call('askOverlayPermission');
  }

  static Future<bool> showOverlay() => _flag('showOverlay');

  static Future<void> hideOverlay() async {
    await _call('hideOverlay');
  }

  static Future<void> overlayUpdate(String text, String mood, bool listening, bool sharing) async {
    await _call('overlayUpdate', {'text': text, 'mood': mood, 'listening': listening, 'sharing': sharing});
  }

  static Future<void> minimizeApp() async {
    await _call('minimizeApp');
  }

  static Future<bool> startShare() => _flag('startShare');

  static Future<void> stopShare() async {
    await _call('stopShare');
  }

  static Future<Uint8List?> captureScreen() async {
    final dynamic r = await _call('captureScreen');
    return r is Uint8List ? r : null;
  }
}

/// Keeps the floating box and screen sharing in step with Penta.
class FloatingHub {
  static AssistantBrain? _brain;
  static bool enabled = false;
  static bool sharing = false;
  static String _key = '';
  static DateTime _lastGreet = DateTime(2000);

  static void attach(AssistantBrain brain) {
    _brain = brain;
    Floating.init();
    Floating.onEvent = _onEvent;
    enabled = LocalStore.flag('floating');
    Floating.setFloating(enabled);
    if (enabled) _resumeService();
  }

  static Future<void> _resumeService() async {
    if (await Permission.microphone.isGranted) await Device.startListenService();
  }

  static void detach() {
    if (_brain != null) Floating.hideOverlay();
    _brain = null;
    Floating.onEvent = null;
  }

  /// Sends Penta's current words and mood to the floating box.
  static void sync(AssistantBrain b) {
    if (!enabled) return;
    String text;
    if (b.sleeping) {
      text = 'Zzz… mic dabao, main uth jaunga';
    } else if (b.thinking) {
      text = 'Soch raha hoon…';
    } else if (b.speaking && b.spokenText.isNotEmpty) {
      text = b.spokenText;
    } else if (b.active) {
      text = b.liveText.trim().isNotEmpty ? b.liveText : 'Bol ${b.callName}, main sun raha hoon…';
    } else {
      text = 'Main yahin hoon, ${b.callName}.';
      for (int i = b.entries.length - 1; i >= 0; i--) {
        if (!b.entries[i].fromUser) {
          text = b.entries[i].text;
          break;
        }
      }
    }
    if (text.length > 110) text = '${text.substring(0, 107)}…';
    final String mood = b.mood.name;
    final String key = '$mood|${b.active}|$sharing|$text';
    if (key == _key) return;
    _key = key;
    Floating.overlayUpdate(text, mood, b.active, sharing);
  }

  static Future<void> _onEvent(String type, Map<String, dynamic> data) async {
    final AssistantBrain? b = _brain;
    if (b == null) return;
    if (type == 'shown') {
      await greet();
    } else if (type == 'mic') {
      await b.toggle();
    } else if (type == 'share') {
      if (sharing) {
        await Floating.stopShare();
      } else {
        await Floating.startShare();
      }
    } else if (type == 'close') {
      if (b.active) await b.toggle();
    } else if (type == 'shareState') {
      sharing = data['on'] == true;
      _key = '';
      b.refresh();
    }
  }

  /// Penta says hello and starts listening (used when you leave the app).
  static Future<void> greet() async {
    final AssistantBrain? b = _brain;
    if (b == null || !enabled) return;
    if (b.active) return;
    if (DateTime.now().difference(_lastGreet).inSeconds < 4) return;
    _lastGreet = DateTime.now();
    await b.toggle();
    await b.speak('Haan ${b.callName}, main yahin hoon. Bol!');
  }

  static Future<String?> setFloating(bool on) async {
    if (on) {
      if (!await Floating.canOverlay()) {
        await Floating.askOverlayPermission();
        return 'Allow "Display over other apps" for Penta, then switch this on again.';
      }
      final bool mic = await askPermission(
        Permission.microphone,
        'Penta needs the microphone to talk to you from the floating box.',
      );
      if (!mic) return 'Microphone permission is needed.';
      await askPermission(
        Permission.notification,
        'Android shows a small notification while Penta can hear you in the floating box.',
      );
      await Device.startListenService();
    } else if (!(_brain?.background ?? false)) {
      await Device.stopListenService();
    }
    enabled = on;
    await LocalStore.setFlag('floating', on);
    await Floating.setFloating(on);
    if (!on) await Floating.hideOverlay();
    return null;
  }

  static Future<String> startShare() async {
    if (sharing) return 'Screen share pehle se chalu hai.';
    await Floating.startShare();
    return 'Screen capture ki permission de do, phir mujhse screen ke baare mein kuch bhi poochho.';
  }

  static Future<String> stopShare() async {
    if (!sharing) return 'Screen share chalu nahi hai.';
    await Floating.stopShare();
    sharing = false;
    _key = '';
    _brain?.refresh();
    return 'Screen share band kar diya.';
  }
}

/// Boy or girl voice, and a picker for specific voices.
class VoiceHub {
  static final FlutterTts _preview = FlutterTts();

  static bool get boy => LocalStore.prefs.getBool('voiceBoy') ?? true;

  static Future<void> setBoy(bool v) async {
    await LocalStore.prefs.setBool('voiceBoy', v);
  }

  /// Called before every spoken reply.
  static Future<void> apply(FlutterTts tts, bool hindi) async {
    try {
      await tts.setPitch(boy ? 0.75 : 1.15);
      final String? name = LocalStore.prefs.getString(hindi ? 'voiceHi' : 'voiceEn');
      final String? loc = LocalStore.prefs.getString(hindi ? 'voiceHiLoc' : 'voiceEnLoc');
      if (name != null && loc != null) {
        await tts.setVoice(<String, String>{'name': name, 'locale': loc});
      }
    } catch (_) {}
  }

  static int _rank(String locale) {
    final String l = locale.toLowerCase().replaceAll('_', '-');
    return (l.startsWith('en-in') || l.startsWith('hi-in')) ? 0 : 1;
  }

  static Future<List<Map<String, String>>> voices() async {
    final List<Map<String, String>> out = <Map<String, String>>[];
    try {
      final dynamic raw = await _preview.getVoices;
      if (raw is List) {
        for (final dynamic v in raw) {
          if (v is Map) {
            final String name = (v['name'] ?? '').toString();
            final String loc = (v['locale'] ?? '').toString();
            final String l = loc.toLowerCase();
            if (name.isNotEmpty && (l.startsWith('en') || l.startsWith('hi'))) {
              out.add(<String, String>{'name': name, 'locale': loc});
            }
          }
        }
      }
    } catch (_) {}
    out.sort((Map<String, String> a, Map<String, String> b) {
      final int r = _rank(a['locale']!).compareTo(_rank(b['locale']!));
      if (r != 0) return r;
      final int c = a['locale']!.compareTo(b['locale']!);
      if (c != 0) return c;
      return a['name']!.compareTo(b['name']!);
    });
    return out;
  }

  static String? chosenFor(Map<String, String> v) {
    final bool hindi = v['locale']!.toLowerCase().startsWith('hi');
    return LocalStore.prefs.getString(hindi ? 'voiceHi' : 'voiceEn');
  }

  static Future<void> choose(Map<String, String> v) async {
    final bool hindi = v['locale']!.toLowerCase().startsWith('hi');
    await LocalStore.prefs.setString(hindi ? 'voiceHi' : 'voiceEn', v['name']!);
    await LocalStore.prefs.setString(hindi ? 'voiceHiLoc' : 'voiceEnLoc', v['locale']!);
  }

  static Future<void> reset() async {
    for (final String k in <String>['voiceHi', 'voiceHiLoc', 'voiceEn', 'voiceEnLoc']) {
      await LocalStore.prefs.remove(k);
    }
  }

  static Future<void> preview(Map<String, String> v) async {
    try {
      final bool hindi = v['locale']!.toLowerCase().startsWith('hi');
      await _preview.stop();
      await _preview.setLanguage(v['locale']!);
      await _preview.setVoice(v);
      await _preview.setPitch(boy ? 0.75 : 1.15);
      await _preview.speak(hindi ? 'Namaste, main Penta hoon.' : 'Hello, I am Penta.');
    } catch (_) {}
  }
}
