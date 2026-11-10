import 'package:flutter/material.dart';
import 'boy_avatar.dart';

class CharacterView extends StatelessWidget {
  final bool isSpeaking;
  final bool isListening;

  const CharacterView({
    Key? key,
    this.isSpeaking = false,
    this.isListening = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BoyAvatar(
            isSpeaking: isSpeaking,
            isListening: isListening,
          ),
          const SizedBox(height: 20),
          Text(
            isSpeaking
                ? "Penta is speaking..."
                : isListening
                    ? "Listening..."
                    : "Ready",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
