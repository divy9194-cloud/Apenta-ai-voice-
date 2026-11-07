import 'package:permission_handler/permission_handler.dart';
import 'ai_client.dart';
import 'assistant_brain.dart';
import 'env.dart';
import 'music_player.dart';
import 'native_bridge.dart';
import 'permission_helper.dart';

/// Decides what a sentence means: device action, contacts, music, image, or AI chat.
class CommandRouter {
  CommandRouter(this.brain);
  final AssistantBrain brain;

  bool _is(String text, String pattern) => RegExp(pattern).hasMatch(text);

  Future<String> route(String raw) async {
    final String t = raw.replaceAll('.', '').trim();
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

    // Open any app
    m = RegExp(r'^(?:please\s+)?(?:open|launch|start)\s+(.+)$').firstMatch(t);
    m ??= RegExp(r'^(.+?)\s+(?:kholo|khol do|khol de|open karo|chalu karo|chalao|start karo)$').firstMatch(t);
    if (m != null) return _openApp(m.group(1)!);

    // Everything else goes to the AI
    final List<dynamic> history = brain.entries.length > 1
        ? brain.entries.sublist(0, brain.entries.length - 1)
        : <dynamic>[];
    try {
      return await AiClient.chat(raw, history.cast());
    } catch (_) {
      return 'Sorry, I could not reach the AI service.';
    }
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
