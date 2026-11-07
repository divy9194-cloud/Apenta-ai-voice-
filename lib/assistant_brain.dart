import 'dart:async';
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

  /// When a screen (like the camera assistant) sets this, spoken sentences go to it instead of the router.
  Future<void> Function(String text)? onHeardOverride;

  bool active = false;
  bool background = false;
  bool continuous = false;
  bool thinking = false;
  String liveText = '';
  String lastEvent = '';
  double level = 0.0;

  bool _keepListening = false;
  bool _speaking = false;
  bool _micReady = false;
  bool _working = false;
  bool _disposed = false;
  bool _expectMore = false;
  String _lastHeard = '';
  DateTime _lastHeardAt = DateTime(2000);
  String? _locale;
  Timer? _watchdog;
  Timer? _assistPoll;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void refresh() => notifyListeners();

  /// Adds a line to the chat history (used by the camera assistant).
  void addEntry(String text, bool fromUser) => _log(text, fromUser);

  /// True when the mic should reopen after Penta finishes speaking.
  bool _shouldResume() => continuous || background || pending != null || _expectMore;

  void _startWatchdog() {
    _watchdog ??= Timer.periodic(const Duration(seconds: 3), (Timer t) {
      if ((continuous || background) &&
          _keepListening &&
          _micReady &&
          !_speaking &&
          !_working &&
          !_stt.isListening) {
        _listenOnce();
      }
    });
  }

  Future<void> start() async {
    entries = LocalStore.loadChat();
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.5);
    } catch (_) {}
    background = LocalStore.flag('background');
    continuous = LocalStore.flag('continuous');
    notifyListeners();

    // Checks whether Penta was opened by a long press on Home.
    _assistPoll ??= Timer.periodic(const Duration(milliseconds: 800), (Timer t) async {
      final bool launched = await Device.consumeAssistLaunch();
      if (launched) await startFromAssist();
    });

    if (background) {
      final bool ok = await _prepareMic();
      if (ok) {
        await Device.startListenService();
        _keepListening = true;
        _startWatchdog();
        _listenOnce();
      } else {
        background = false;
      }
    }
  }

  /// Starts listening right away when opened as the default assistant.
  Future<void> startFromAssist() async {
    if (active) return;
    await toggle();
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
        lastEvent = 'mic: $status';
        notifyListeners();
        if (status == 'done' || status == 'notListening') {
          if (liveText.trim().isNotEmpty && !_working && !_speaking) {
            _heard(liveText);
          } else if (!_working && !_speaking && _keepListening) {
            if (_shouldResume()) {
              Future<void>.delayed(const Duration(milliseconds: 400), _listenOnce);
            } else {
              _endSession();
            }
          }
        }
      },
      onError: (dynamic error) {
        lastEvent = 'mic error: $error';
        notifyListeners();
        if (_keepListening && !_working && !_speaking) {
          if (_shouldResume()) {
            Future<void>.delayed(const Duration(seconds: 1), _listenOnce);
          } else {
            _endSession();
          }
        }
      },
    );
    if (!_micReady) {
      lastEvent = 'mic could not start (check Google speech service)';
      notifyListeners();
    }
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
        pauseFor: const Duration(seconds: 4),
        localeId: _locale,
        onSoundLevelChange: _onLevel,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      lastEvent = 'listen failed: $e';
      notifyListeners();
    }
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

  /// Ends one listening session. In background mode the mic stays open for the wake phrase.
  Future<void> _endSession() async {
    active = false;
    _keepListening = background;
    liveText = '';
    level = 0.0;
    try {
      await _stt.stop();
    } catch (_) {}
    notifyListeners();
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
        if (wake == null) {
          liveText = '';
          notifyListeners();
          return; // waiting for "Hey Penta"
        }
        active = true;
        notifyListeners();
      }
      final String command = wake == null ? text : text.replaceFirst(_wakeWords, '').trim();
      if (command.isEmpty) {
        liveText = '';
        _expectMore = true;
        await speak('Yes, how can I help?');
        _expectMore = false;
        return;
      }
      final Future<void> Function(String text)? hook = onHeardOverride;
      if (hook != null && !_stopWords.hasMatch(command)) {
        liveText = '';
        notifyListeners();
        await hook(command);
        if (!_shouldResume()) {
          await _endSession();
        }
        return;
      }
      await runCommand(command, spoken: true);
      if (!_shouldResume()) {
        await _endSession();
      }
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
      await _tts.speak(text).timeout(const Duration(seconds: 20), onTimeout: () => null);
    } catch (_) {}
    _speaking = false;
    if (_keepListening && _shouldResume()) _listenOnce();
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
      await _endSession();
      pending = null;
      return;
    }
    if (!await _prepareMic()) return;
    active = true;
    _keepListening = true;
    _expectMore = false;
    _startWatchdog();
    notifyListeners();
    _listenOnce();
  }

  Future<void> setContinuous(bool on) async {
    continuous = on;
    await LocalStore.setFlag('continuous', on);
    notifyListeners();
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
      _startWatchdog();
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
    _watchdog?.cancel();
    _assistPoll?.cancel();
    _stt.cancel();
    _tts.stop();
    Device.stopListenService();
    super.dispose();
  }
}
