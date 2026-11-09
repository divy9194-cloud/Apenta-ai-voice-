import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ai_client.dart';
import 'assistant_brain.dart';
import 'env.dart';
import 'floating.dart';
import 'local_store.dart';
import 'music_player.dart';
import 'native_bridge.dart';
import 'permission_helper.dart';
import 'screens/camera_assist_screen.dart';
import 'screens/photo_editor_screen.dart';
import 'vision_client.dart';

/// Decides what a sentence means: device action, contacts, music, image, or AI chat.
class CommandRouter {
  CommandRouter(this.brain);
  final AssistantBrain brain;

  bool _is(String text, String pattern) => RegExp(pattern).hasMatch(text);

  /// Lowercases and fixes common speech-to-text spellings (you tube becomes youtube).
  String _normalize(String s) {
    String t = s.toLowerCase().replaceAll('.', '').trim();
    t = t.replaceAll(RegExp(r'\byou tube\b'), 'youtube');
    t = t.replaceAll(RegExp(r"\b(?:whats app|what's app|watsapp)\b"), 'whatsapp');
    t = t.replaceAll(RegExp(r'\binsta gram\b'), 'instagram');
    t = t.replaceAll(RegExp(r'\binsta\b'), 'instagram');
    t = t.replaceAll(RegExp(r'\bface book\b'), 'facebook');
    t = t.replaceAll(RegExp(r'\bg mail\b'), 'gmail');
    return t;
  }

  String get _style =>
      '(Reply like a close friend in friendly Hinglish, call me ${brain.callName}, keep it under 50 words, '
      'no emojis, no markdown. If I speak another language, reply in that language.) ';

  Future<String> route(String raw) async {
    // Removes a leading "Penta" or "Hey Penta" so the real command is matched.
    final String stripped = raw
        .replaceFirst(RegExp(r'^\s*(?:hey |hi |hello |ok |okay )?penta\s*,?\s+', caseSensitive: false), '')
        .trim();
    final String t = _normalize(stripped);
    RegExpMatch? m;

    // WhatsApp message
    m = RegExp(r'(?:message|msg|text)\s+(.+?)\s+(?:on whatsapp\s+)?(?:saying|that|bolo|likho)\s+(.+)').firstMatch(t);
    m ??= RegExp(r'(.+?)\s+ko\s+(?:whatsapp\s+(?:par|pe)\s+)?(?:message|msg)\s+(?:bhejo|karo|send)\s*(?:ki|ke)?\s*(.+)')
        .firstMatch(t);
    if (m != null) {
      final String who = m.group(1)!.replaceFirst(RegExp(r'^to\s+'), '').trim();
      return _whatsApp(who, m.group(2)!.trim());
    }

    // Call
    m = RegExp(r'^(?:call|phone)\s+(.+)$').firstMatch(t);
    m ??= RegExp(r'^(.+?)\s+ko\s+(?:call|phone)(?:\s+(?:karo|kar do))?$').firstMatch(t);
    if (m != null) return _call(m.group(1)!.trim());

    // Camera assistant (live camera: ask questions or take a photo)
    if (_is(t, r'camera (assist|assistant|ai|vision)|(assist|assistant|ai|vision) camera|look at this|what am i (holding|showing)|scan this')) {
      return _openCameraAssist();
    }

    // Photo editor
    if (_is(t, r'(edit|improve|fix|retouch)\s+(a |the |my |this )?(photo|picture|image|pic)|photo edit(or)?|image edit(or)?')) {
      return _openPhotoEditor();
    }

    // Change Penta's voice
    if (_is(t, r'(boy|male|ladka|ladke)\s*(voice|awaaz|awaz)|(voice|awaaz|awaz).*\b(boy|male|ladka|ladke)\b')) {
      await VoiceHub.setBoy(true);
      return 'Theek hai, ab main ladke ki awaaz mein bolunga.';
    }
    if (_is(t, r'(girl|female|ladki)\s*(voice|awaaz|awaz)|(voice|awaaz|awaz).*\b(girl|female|ladki)\b')) {
      await VoiceHub.setBoy(false);
      return 'Theek hai, ab main ladki ki awaaz mein bolungi.';
    }

    // Screen sharing
    if (_is(t, r'(start|begin|turn on)\s+(screen\s*share|sharing)|share\s+(my|the|your)?\s*screen|screen\s*share\s*(karo|on|start)|apni screen')) {
      return FloatingHub.startShare();
    }
    if (_is(t, r'(stop|end|turn off|band)\s+(screen\s*share|sharing)|screen\s*share\s*(band|off|stop)')) {
      return FloatingHub.stopShare();
    }
    if (_is(t, r'(look at|see|check|watch)\s+(my|the)\s+screen|what do you see|screen (dekho|dekh)')) {
      return _askScreen('Describe briefly what is on my screen and what I could do next.');
    }

    // Phone control
    if (_is(t, r'^(go )?home( screen)?$|^go to (the )?home( screen)?$|^ghar jao$')) return _global('home', 'Going home.');
    if (_is(t, r'^(go )?back$|^peeche (jao|chalo)$')) return _global('back', 'Going back.');
    if (_is(t, r'recent apps|^recents$|show recent|^overview$')) return _global('recents', 'Showing recent apps.');
    if (_is(t, r'(open|show|pull down) (the |my )?notifications?|notification (panel|shade|kholo)')) {
      return _global('notifications', 'Opening notifications.');
    }
    if (_is(t, r'quick settings|control (panel|center|centre)')) return _global('quick', 'Opening quick settings.');
    if (_is(t, r'power menu|shut ?down menu|power off menu')) return _global('power', 'Opening the power menu.');

    m = RegExp(r'^scroll\s+(down|up)$|^(neeche|niche|upar)\s+scroll(?:\s+karo)?$').firstMatch(t);
    if (m != null) {
      final String word = m.group(1) ?? m.group(2) ?? 'down';
      return _scroll(word == 'down' || word == 'neeche' || word == 'niche');
    }

    if (_is(t, r"read (the |my )?screen|what('s| is) on (the |my )?screen|screen (padho|padh)|explain (the |my )?screen|summari[sz]e (the |my )?screen")) {
      return _readScreen();
    }

    // Lock screen / screen off
    if (_is(t, r'\block (the )?(screen|phone|mobile)\b|screen (off|lock)|turn off (the )?screen|screen band|phone lock|lock karo')) {
      return _lockScreen();
    }

    // Time and date
    if (_is(t, r"what('s| is) the time|current time|time kya hai|kitne baje|tell me the time")) {
      return 'It is ${_timeText()}.';
    }
    if (_is(t, r"what('s| is) (the )?(date|day)|today's date|aaj (kya|kaun)|which day")) {
      return 'Today is ${_dateText()}.';
    }

    // Reminder: "remind me in 10 minutes to drink water"
    m = RegExp(r'^remind me (?:in|after)\s+(\d+)\s*(second|sec|minute|min|hour)s?\s*(?:to|that|about)?\s*(.*)$').firstMatch(t);
    if (m != null) {
      final int n = int.parse(m.group(1)!);
      final String unit = m.group(2)!;
      int seconds = n;
      if (unit.startsWith('h')) {
        seconds = n * 3600;
      } else if (unit.startsWith('m')) {
        seconds = n * 60;
      }
      final String what = (m.group(3) ?? '').trim();
      final bool ok = await Device.timer(seconds, what.isEmpty ? 'Penta reminder' : what);
      return ok ? 'Okay, I will remind you in $n $unit${n == 1 ? '' : 's'}.' : 'I could not set the reminder.';
    }

    // Type into the app that is open
    final RegExpMatch? typing = RegExp(r'^type\s+(.+)$', caseSensitive: false).firstMatch(stripped);
    if (typing != null) return _type(typing.group(1)!.trim());
    if (_is(t, r'^(press enter|hit enter|press search|submit|search it)$')) return _pressSearch();

    // Open an app and search in one sentence: "open youtube and search funny video"
    m = RegExp(r'^(?:open|launch|start)\s+(.+?)\s+(?:and|then|aur)\s+(?:search|find|look up)(?:\s+for)?\s+(.+)$')
        .firstMatch(t);
    m ??= RegExp(r'^(.+?)\s+(?:kholo|khol do|open karo)\s+(?:aur|and)\s+(.+?)\s+(?:search|dhundho|khojo)(?:\s+karo)?$')
        .firstMatch(t);
    if (m != null) return _searchInApp(m.group(1)!.trim(), m.group(2)!.trim());

    // Search inside an app
    m = RegExp(r'^(?:search|find|look up)\s+(?:for\s+)?(.+?)\s+(?:on|in)\s+(.+)$').firstMatch(t);
    if (m != null) return _searchInApp(m.group(2)!.trim(), m.group(1)!.trim());
    m = RegExp(r'^(.+?)\s+(?:par|pe)\s+(.+?)\s+(?:search|dhundho|khojo)(?:\s+karo)?$').firstMatch(t);
    if (m != null) return _searchInApp(m.group(1)!.trim(), m.group(2)!.trim());
    m = RegExp(r'^(?:search|google)\s+(?:for\s+)?(.+)$').firstMatch(t);
    if (m != null) return _searchInApp('google', m.group(1)!.trim());

    // Image generation
    m = RegExp(r'(?:generate|create|make|draw)\s+(?:me\s+)?(?:an?\s+)?(?:image|picture|photo|pic)\s*(?:of|for)?\s*(.+)')
        .firstMatch(t);
    if (m != null) {
      try {
        await AiClient.image(m.group(1)!);
        brain.refresh();
        return 'Your image is ready. You can see it in the Images tab.';
      } catch (e) {
        return 'Image problem: ${e.toString().replaceFirst('Exception: ', '')}';
      }
    }

    // Music controls
    if (_is(t, r'\b(pause|stop|ruko|roko)\b.*\b(music|song|gana|gaana)\b')) {
      return (await Device.mediaKey(127)) ? 'Music paused.' : 'I could not pause the music.';
    }
    if (_is(t, r'next (song|track)|agla (gana|gaana)|skip')) {
      return (await Device.mediaKey(87)) ? 'Playing the next song.' : 'I could not skip the song.';
    }
    if (_is(t, r'^(play|resume)( the)? (music|song)?$|^music (chalao|play)$')) {
      return (await Device.mediaKey(126)) ? 'Playing music.' : 'I could not play music.';
    }
    m = RegExp(r'^play\s+(.+)$').firstMatch(t);
    if (m != null) {
      final String q = m.group(1)!.replaceFirst(RegExp(r'\bon (youtube|spotify)( music)?$'), '').trim();
      return MusicPlayer.play(q);
    }

    // Volume
    if (_is(t, r'volume|awaaz|awaz')) {
      String action = '';
      int percent = 0;
      final RegExpMatch? d = RegExp(r'(\d{1,3})').firstMatch(t);
      if (d != null) {
        action = 'set';
        percent = int.parse(d.group(1)!);
      } else if (_is(t, r'unmute')) {
        action = 'unmute';
      } else if (_is(t, r'\bmute\b|silent|chup')) {
        action = 'mute';
      } else if (_is(t, r'\bmax\b|\bfull\b')) {
        action = 'set';
        percent = 100;
      } else if (_is(t, r'increase|\bup\b|raise|badha|zyada|louder|tez')) {
        action = 'up';
      } else if (_is(t, r'decrease|\bdown\b|lower|\bkam\b|ghata|softer|dheere')) {
        action = 'down';
      }
      if (action.isNotEmpty) {
        final int now = await Device.volume(action, percent);
        return now < 0 ? 'I could not change the volume.' : 'Volume is at $now percent.';
      }
    }

    // Flashlight
    if (_is(t, r'flash ?light|torch')) {
      final bool off = _is(t, r'\b(off|band|bujha|bujhao)\b');
      final bool on = _is(t, r'\b(on|chalu|jala|jalao)\b');
      if (off || on) {
        final bool ok = await Device.torch(!off);
        if (!ok) return 'I could not control the flashlight.';
        return off ? 'Flashlight turned off.' : 'Flashlight turned on.';
      }
    }

    // Brightness
    if (_is(t, r'brightness|roshni')) {
      if (!await Device.canWriteSettings()) {
        await Device.askWriteSettings();
        return 'Please allow Penta to modify system settings, then ask me again.';
      }
      final int current = await Device.brightness();
      int? target;
      final RegExpMatch? digits = RegExp(r'(\d{1,3})').firstMatch(t);
      if (digits != null) {
        target = int.parse(digits.group(1)!);
      } else if (_is(t, r'increase|badha|zyada|\bup\b|raise')) {
        target = current + 20;
      } else if (_is(t, r'decrease|kam|ghata|\bdown\b|lower|reduce')) {
        target = current - 20;
      }
      if (target != null) {
        final int level = target < 1 ? 1 : (target > 100 ? 100 : target);
        final bool ok = await Device.setBrightness(level);
        return ok ? 'Brightness set to $level percent.' : 'I could not change the brightness.';
      }
    }

    // Screenshot
    if (_is(t, r'screenshot|screen shot')) {
      if (!await Device.screenshotReady()) {
        await Device.askScreenshotAccess();
        return 'Please enable Penta under Accessibility to allow screenshots.';
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return (await Device.screenshot()) ? 'Screenshot taken.' : 'I could not take a screenshot.';
    }

    // Alarm
    if (_is(t, r'\balarm\b')) {
      final RegExpMatch? a = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?').firstMatch(t);
      if (a == null) return 'Tell me the time, for example: set alarm for 7 AM.';
      int hour = int.parse(a.group(1)!);
      final int minute = int.tryParse(a.group(2) ?? '0') ?? 0;
      final String? ap = a.group(3);
      if (ap == 'pm' && hour < 12) hour += 12;
      if (ap == 'am' && hour == 12) hour = 0;
      if (hour > 23 || minute > 59) return 'That time does not look right.';
      final bool ok = await Device.alarm(hour, minute);
      if (!ok) return 'I could not set the alarm.';
      final String mm = minute.toString().padLeft(2, '0');
      final String suffix = ap == null ? '' : ' ${ap.toUpperCase()}';
      return 'Alarm set for ${a.group(1)}:$mm$suffix.';
    }

    // Timer
    if (_is(t, r'\btimer\b')) {
      final RegExpMatch? a = RegExp(r'(\d+)\s*(second|sec|minute|min|hour|ghante|ghanta)').firstMatch(t);
      if (a == null) return 'Tell me the duration, for example: set timer for 10 minutes.';
      final int n = int.parse(a.group(1)!);
      final String unit = a.group(2)!;
      int seconds = n;
      if (unit.startsWith('h') || unit.startsWith('g')) {
        seconds = n * 3600;
      } else if (unit.startsWith('m')) {
        seconds = n * 60;
      }
      final bool ok = await Device.timer(seconds);
      return ok ? 'Timer set for $n $unit${n == 1 ? '' : 's'}.' : 'I could not set the timer.';
    }

    // Battery
    if (_is(t, r'battery')) {
      final int b = await Device.battery();
      return b < 0 ? 'I could not read the battery level.' : 'Your battery is at $b percent.';
    }

    // Settings pages
    if (_is(t, r'bluetooth')) {
      return (await Device.settingsPage('bluetooth')) ? 'Opening Bluetooth settings.' : 'I could not open Bluetooth settings.';
    }
    if (_is(t, r'wi-?fi|wi fi')) {
      return (await Device.settingsPage('wifi')) ? 'Opening Wi-Fi settings.' : 'I could not open Wi-Fi settings.';
    }

    // Tap a button or text on the screen: "tap subscribe"
    m = RegExp(r'^(?:tap|click|press|select)\s+(?:on\s+)?(.+)$').firstMatch(t);
    if (m != null && !_is(t, r'photo|picture|selfie|\bpic\b')) {
      return _tapText(m.group(1)!.trim());
    }

    // Open any app
    m = RegExp(r'^(?:please\s+)?(?:open|launch|start)\s+(.+)$').firstMatch(t);
    m ??= RegExp(r'^(.+?)\s+(?:kholo|khol do|khol de|open karo|chalu karo|chalao|start karo)$').firstMatch(t);
    if (m != null) return _openApp(m.group(1)!);

    // While the screen is shared, questions are answered from what is on the screen
    if (FloatingHub.sharing) return _askScreen(stripped);

    // Everything else goes to the AI
    final List<ChatEntry> history = brain.entries.length > 1
        ? brain.entries.sublist(0, brain.entries.length - 1)
        : <ChatEntry>[];
    try {
      return await AiClient.chat('$_style$stripped', history);
    } catch (_) {
      return 'Sorry, I could not reach the AI service.';
    }
  }

  String _timeText() {
    final DateTime n = DateTime.now();
    final int h12 = n.hour % 12 == 0 ? 12 : n.hour % 12;
    final String mm = n.minute.toString().padLeft(2, '0');
    final String ap = n.hour >= 12 ? 'PM' : 'AM';
    return '$h12:$mm $ap';
  }

  String _dateText() {
    const List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final DateTime n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]} ${n.year}';
  }

  Future<String> _askScreen(String question) async {
    final Uint8List? shot = await Floating.captureScreen();
    if (shot == null || shot.isEmpty) {
      return 'I could not capture the screen. Please start screen share again.';
    }
    return VisionClient.ask('$_style$question', shot);
  }

  Future<String> _openPhotoEditor() async {
    final NavigatorState? nav = rootNav.currentState;
    if (nav == null) return 'I could not open the photo editor.';
    nav.push(MaterialPageRoute<void>(builder: (BuildContext c) => PhotoEditorScreen(brain: brain)));
    return 'Photo editor is open. Pick a photo and tell me what to change.';
  }

  Future<String> _openCameraAssist() async {
    final NavigatorState? nav = rootNav.currentState;
    if (nav == null) return 'I could not open the camera assistant.';
    nav.push(MaterialPageRoute<void>(builder: (BuildContext c) => CameraAssistScreen(brain: brain)));
    return 'Camera assistant is open. Show me something and ask a question, or say take a photo.';
  }

  Future<String> _needAccessibility(String what) async {
    await Device.askScreenshotAccess();
    return 'Please enable Penta under Accessibility so I can $what, then ask again.';
  }

  Future<String> _global(String name, String okText) async {
    if (!await Device.screenshotReady()) return _needAccessibility('control the phone');
    return (await Device.globalAction(name)) ? okText : 'I could not do that.';
  }

  Future<String> _scroll(bool forward) async {
    if (!await Device.screenshotReady()) return _needAccessibility('scroll');
    return (await Device.scroll(forward)) ? 'Scrolling.' : 'I could not find anything to scroll.';
  }

  Future<String> _tapText(String text) async {
    if (!await Device.screenshotReady()) return _needAccessibility('tap on the screen');
    return (await Device.tapText(text)) ? 'Tapped $text.' : 'I could not find $text on the screen.';
  }

  Future<String> _readScreen() async {
    if (FloatingHub.sharing) return _askScreen('Tell me briefly what is on my screen.');
    if (!await Device.screenshotReady()) return _needAccessibility('read the screen');
    final String text = await Device.readScreen();
    if (text.isEmpty || text == 'no_service' || text == 'error') return 'I could not read this screen.';
    final String prompt = '$_style'
        'This is the text visible on my phone screen right now. Tell me briefly what is on it:\n$text';
    return AiClient.chat(prompt, <ChatEntry>[]);
  }

  Future<String> _lockScreen() async {
    if (!await Device.screenshotReady()) return _needAccessibility('lock the screen');
    final bool ok = await Device.lockScreen();
    return ok ? 'Locking the screen.' : 'I could not lock the screen. This needs Android 9 or newer.';
  }

  Future<String> _type(String text) async {
    final String status = await Device.typeText(text);
    if (status == 'ok') return 'Typed.';
    if (status == 'no_service') return _needAccessibility('type');
    return 'I could not find a text box. Tap a text box in the app first, then say type and your text.';
  }

  Future<String> _pressSearch() async {
    final String status = await Device.pressSearch();
    if (status == 'ok') return 'Done.';
    if (status == 'no_service') return _needAccessibility('press search');
    return 'I could not find a search button.';
  }

  /// Web address that opens an app's search results directly, or null for other apps.
  String? _deepLink(String app, String query) {
    final String q = Uri.encodeQueryComponent(query);
    switch (app) {
      case 'youtube':
        return 'https://www.youtube.com/results?search_query=$q';
      case 'google':
      case 'chrome':
      case 'web':
      case 'browser':
        return 'https://www.google.com/search?q=$q';
      case 'maps':
      case 'google maps':
        return 'https://www.google.com/maps/search/?api=1&query=$q';
      case 'play store':
      case 'playstore':
      case 'google play':
        return 'https://play.google.com/store/search?q=$q&c=apps';
      case 'spotify':
        return 'spotify:search:${Uri.encodeComponent(query)}';
      case 'amazon':
        return 'https://www.amazon.in/s?k=$q';
      case 'flipkart':
        return 'https://www.flipkart.com/search?q=$q';
      case 'wikipedia':
        return 'https://en.wikipedia.org/w/index.php?search=$q';
      case 'facebook':
        return 'https://www.facebook.com/search/top?q=$q';
      case 'twitter':
      case 'x':
        return 'https://x.com/search?q=$q';
      default:
        return null;
    }
  }

  Future<String> _searchInApp(String appRaw, String query) async {
    final String app = appRaw.replaceAll(RegExp(r'\b(the|app|application)\b'), '').trim();
    final String? link = _deepLink(app, query);
    if (link != null) {
      final bool ok = await Device.openUrl(link);
      return ok ? 'Searching $query on $app.' : 'I could not open $app.';
    }
    // Any other app: open it, then use its own search box.
    if (!await Device.screenshotReady()) return _needAccessibility('search inside $app');
    if (!await Device.openApp(app)) return 'Penta could not find that app.';
    final String status = await Device.searchInOpenApp(query);
    if (status == 'ok') return 'Searching $query in $app.';
    if (status == 'no_search_box') return 'I opened $app but could not find its search box.';
    return 'I could not type in the $app search box.';
  }

  Future<String> _openApp(String raw) async {
    final String name = raw.replaceAll(RegExp(r'\b(the|app|application|please)\b'), '').trim();
    const String notFound = 'Penta could not find that app.';
    if (name == 'camera') return (await Device.camera()) ? 'Opening camera.' : notFound;
    if (name == 'gallery' || name == 'photos') return (await Device.gallery()) ? 'Opening gallery.' : notFound;
    if (name == 'settings' || name == 'setting') return (await Device.settingsPage('settings')) ? 'Opening settings.' : notFound;
    return (await Device.openApp(name)) ? 'Opening $name.' : notFound;
  }

  Future<Map<String, String>?> _lookup(String who) async {
    final bool ok = await askPermission(
      Permission.contacts,
      'Penta reads your contacts only to find the person you ask me to call or message. Contacts are not uploaded or stored.',
    );
    if (!ok) return null;
    return Device.findContact(who);
  }

  String _e164(String raw) {
    final String d = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (d.startsWith('+')) return d;
    if (d.startsWith('00')) return '+${d.substring(2)}';
    if (d.length == 10) return '+${AppEnv.countryCode}$d';
    if (d.startsWith('0')) return '+${AppEnv.countryCode}${d.substring(1)}';
    return '+$d';
  }

  Future<String> _call(String who) async {
    final Map<String, String>? c = await _lookup(who);
    if (c == null) return 'I could not find $who in your contacts.';
    final String name = c['name']!;
    final String number = _e164(c['number']!);
    brain.pending = PendingAsk('Should I call $name?', () async {
      final bool ok = await askPermission(Permission.phone, 'Penta needs the phone permission to place the call you confirmed.');
      if (!ok) return 'I need the phone permission to place calls.';
      return (await Device.dial(number)) ? 'Calling $name.' : 'I could not place the call.';
    });
    return 'Should I call $name?';
  }

  Future<String> _whatsApp(String who, String text) async {
    final Map<String, String>? c = await _lookup(who);
    if (c == null) return 'I could not find $who in your contacts.';
    final String name = c['name']!;
    final String digits = _e164(c['number']!).replaceAll('+', '');
    final String question = 'Should I open WhatsApp to send "$text" to $name?';
    brain.pending = PendingAsk(question, () async {
      final bool ok = await Device.openUrl('https://wa.me/$digits?text=${Uri.encodeComponent(text)}');
      return ok ? 'WhatsApp is open with your message to $name. Tap send to deliver it.' : 'I could not open WhatsApp.';
    });
    return question;
  }
}
