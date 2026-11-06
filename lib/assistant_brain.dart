import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'command_router.dart';
import 'local_store.dart';
import 'native_bridge.dart';
import 'permission_helper.dart';

/// A yes/no question Penta is waiting on (call / WhatsApp confirmation).
class PendingAsk {
  PendingAsk(this.question, this.onYes);
  final String question;
  final Future<String> Function() onYes;
}

/// Owns speech recognition, text-to-speech, wake phrase and chat state.
class AssistantBrain extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  late final CommandRouter _router = CommandRouter(this);

  static final RegExp _wakeWords = RegExp(r'\b(?:hi|hey|hello|ok|okay)\s+(?:penta|pentha|panta|pinta)\b');
  static final RegExp _stopWords = RegExp(r'stop listening|sunna band|listening band');
  static final RegExp _yesWords = RegExp(r'\b(yes|yeah|yep|sure|ok|okay|haan|ha|han|kar do|karo|go ahead)\b');
  static final RegExp _noWords = RegExp(r'\b(no|nope|nahi|nahin|cancel|mat)\b');

  List<ChatEntry> entries = <ChatEntry>[];
  PendingAsk? pending;
  bool active = false;
  bool background = false;
  bool thinking = false;
  String liveText = '';
  double level = 0.0;

  bool _keepListening = false;
  bool _speaking = false;
  bool _micReady = false;
  bool _working = false;
  bool _disposed = false;
  String _lastHeard = '';
  DateTime _lastHeardAt = DateTime(2000);
  String? _locale;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void refresh() => notifyListeners();

  Future<void> start() async {
    entries = LocalStore.loadChat();
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.5);
    } catch (_) {}
    background = LocalStore.flag('background');
    notifyListeners();
    if (background) {
      final bool ok = await _prepareMic();
      if (ok) {
        await Device.startListenService();
        _keepListening = true;
        _listenOnce();
      } else {
        background = false;
      }
    }
  }

  Future<bool> _prepareMic() async {
    if (_micReady) return true;
    final bool ok = await askPermission(
      Permission.microphone,
      'Penta needs the microphone to hear your voice commands. It listens only while Penta is active or background mode is switched on.',
    );
    if (!ok) return false;
    _micReady = await _stt.initialize(
      onStatus: (String status) {
        if ((status == 'done' || status == 'notListening') && _keepListening) {
          Future<void>.delayed(const Duration(milliseconds: 400), _listenOnce);
        }
      },
      onError: (dynamic error) {
        if (_keepListening) {
          Future<void>.delayed(const Duration(seconds: 1), _listenOnce);
        }
      },
    );
    if (_micReady) {
      try {
        final locales = await _stt.locales();
        for (final l in locales) {
          if (l.localeId.replaceAll('-', '_') == 'en_IN') _locale = l.localeId;
        }
      } catch (_) {}
    }
    return _micReady;
  }

  Future<void> _listenOnce() async {
    if (!_keepListening || _speaking || !_micReady || _stt.isListening) return;
    try {
      await _stt.listen(
        onResult: _onResult,
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 5),
        localeId: _locale,
        onSoundLevelChange: _onLevel,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (_) {}
  }

  void _onLevel(double l) {
    level = ((l + 2) / 12).clamp(0.0, 1.0).toDouble();
    notifyListeners();
  }

  void _onResult(SpeechRecognitionResult r) {
    if (_working || _speaking) return;
    liveText = r.recognizedWords;
    notifyListeners();
    if (r.finalResult && liveText.trim().isNotEmpty) {
      _heard(liveText);
    }
  }

  Future<void> _heard(String raw) async {
    final String text = raw.toLowerCase().trim();
    final bool duplicate = text == _lastHeard && DateTime.now().difference(_lastHeardAt).inSeconds < 4;
    if (_working || duplicate) return;
    _lastHeard = text;
    _lastHeardAt = DateTime.now();
    _working = true;
    try {
      final RegExpMatch? wake = _wakeWords.firstMatch(text);
      if (!active) {
        if (wake == null) return; // waiting for "Hey Penta"
        active = true;
        notifyListeners();
      }
      final String command = wake == null ? text : text.replaceFirst(_wakeWords, '').trim();
      if (command.isEmpty) {
        liveText = '';
        await speak('Yes, how can I help?');
        return;
      }
      await runCommand(command, spoken: true);
    } finally {
      _working = false;
    }
  }

  /// Runs one command, typed or spoken.
  Future<void> runCommand(String command, {bool spoken = false}) async {
    liveText = '';
    if (_stopWords.hasMatch(command)) {
      active = false;
      pending = null;
      if (!background) _keepListening = false;
      notifyListeners();
      await speak('Okay, I stopped listening.');
      if (!background) {
        try {
          await _stt.stop();
        } catch (_) {}
      }
      return;
    }
    _log(command, true);
    thinking = true;
    notifyListeners();
    String reply;
    final PendingAsk? ask = pending;
    if (ask != null) {
      if (_yesWords.hasMatch(command)) {
        pending = null;
        reply = await ask.onYes();
      } else if (_noWords.hasMatch(command)) {
        pending = null;
        reply = 'Okay, cancelled.';
      } else {
        reply = 'Please say yes or no. ${ask.question}';
      }
    } else {
      try {
        reply = await _router.route(command);
      } catch (_) {
        reply = 'Sorry, something went wrong.';
      }
    }
    thinking = false;
    _log(reply, false);
    if (spoken) {
      await speak(reply);
    }
  }

  Future<void> speak(String text) async {
    _speaking = true;
    try {
      await _stt.stop();
      final bool hindi = RegExp(r'[\u0900-\u097F]').hasMatch(text);
      await _tts.setLanguage(hindi ? 'hi-IN' : 'en-IN');
      await _tts.speak(text);
    } catch (_) {}
    _speaking = false;
    if (_keepListening) _listenOnce();
  }

  void _log(String text, bool fromUser) {
    final ChatEntry entry = ChatEntry(text, fromUser, DateTime.now().millisecondsSinceEpoch);
    entries.add(entry);
    LocalStore.saveChat(entries);
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null && LocalStore.flag('sync')) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chat')
          .add({...entry.toMap(), 'at': FieldValue.serverTimestamp()}).then((_) {}, onError: (Object e) {});
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    if (active) {
      active = false;
      pending = null;
      if (!background) {
        _keepListening = false;
        try {
          await _stt.stop();
        } catch (_) {}
      }
      notifyListeners();
      return;
    }
    if (!await _prepareMic()) return;
    active = true;
    _keepListening = true;
    notifyListeners();
    await speak('Penta is listening.');
  }

  /// Optional background listening (foreground service + visible notification).
  Future<String?> setBackground(bool on) async {
    if (on) {
      if (!await _prepareMic()) return 'Microphone permission is required.';
      await askPermission(
        Permission.notification,
        'Android requires a visible notification while Penta listens in the background.',
      );
      await Device.startListenService();
      background = true;
      _keepListening = true;
      await LocalStore.setFlag('background', true);
      _listenOnce();
    } else {
      background = false;
      await LocalStore.setFlag('background', false);
      await Device.stopListenService();
      if (!active) {
        _keepListening = false;
        try {
          await _stt.stop();
        } catch (_) {}
      }
    }
    notifyListeners();
    return null;
  }

  Future<void> clearChat() async {
    entries = <ChatEntry>[];
    await LocalStore.saveChat(entries);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _keepListening = false;
    _stt.cancel();
    _tts.stop();
    Device.stopListenService();
    super.dispose();
  }
}
