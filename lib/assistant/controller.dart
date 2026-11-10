import 'package:flutter/foundation.dart';

class ChatMessage {
  ChatMessage({required this.text, required this.user});
  final String text;
  final bool user;
}

class PentaController extends ChangeNotifier {
  PentaController();

  final List<ChatMessage> chat = [];

  bool active = false;
  bool wakeMode = false;
  bool speaking = false;
  bool thinking = false;
  double level = 0.0;
  String live = '';

  void setWakeMode(bool value) {
    if (wakeMode == value) return;
    wakeMode = value;
    notifyListeners();
  }

  void setSpeaking(bool value) {
    if (speaking == value) return;
    speaking = value;
    notifyListeners();
  }

  void setThinking(bool value) {
    if (thinking == value) return;
    thinking = value;
    notifyListeners();
  }

  void setLevel(double value) {
    final next = value.clamp(0.0, 1.0);
    if ((level - next).abs() < 0.0001) return;
    level = next;
    notifyListeners();
  }

  void setLive(String text) {
    if (live == text) return;
    live = text;
    notifyListeners();
  }

  void addChat(String text, {required bool user}) {
    chat.add(ChatMessage(text: text, user: user));
    notifyListeners();
  }

  void toggleOrb() {
    active = !active;
    if (!active) {
      live = '';
    }
    notifyListeners();
  }

  void reset() {
    active = false;
    wakeMode = false;
    speaking = false;
    thinking = false;
    level = 0.0;
    live = '';
    chat.clear();
    notifyListeners();
  }
}
