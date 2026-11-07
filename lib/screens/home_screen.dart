import 'package:flutter/material.dart';
import '../assistant_brain.dart';
import '../widgets/boy_avatar.dart';
import '../widgets/common.dart';
import '../widgets/wave_bars.dart';
import 'camera_assist_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.brain});
  final AssistantBrain brain;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: brain,
      builder: (BuildContext context, Widget? child) {
        String lastReply = '';
        if (brain.entries.isNotEmpty && !brain.entries.last.fromUser) {
          lastReply = brain.entries.last.text;
        }
        String status = 'Tap me to talk';
        if (brain.sleeping) {
          status = 'Zzz… tap me to wake me up';
        } else if (brain.active) {
          status = 'Listening…';
        } else if (brain.background) {
          status = 'Say "Hey Penta"';
        }
        final String caption = brain.thinking
            ? 'Thinking…'
            : (brain.liveText.isNotEmpty ? brain.liveText : lastReply);
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, color: Colors.white70, letterSpacing: 1),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Camera assistant',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (BuildContext c) => CameraAssistScreen(brain: brain)),
                        );
                      },
                      icon: const Icon(Icons.center_focus_strong, color: neonCyan),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 280,
                      height: 320,
                      child: BoyAvatar(mood: brain.mood, level: brain.level, onTap: brain.toggle),
                    ),
                  ),
                ),
              ),
              WaveBars(level: brain.level, active: brain.active),
              Container(
                constraints: const BoxConstraints(minHeight: 90),
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
                alignment: Alignment.center,
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, color: brain.liveText.isNotEmpty ? Colors.white : Colors.white60),
                ),
              ),
              Text(brain.lastEvent, style: const TextStyle(fontSize: 11, color: Colors.white38)),
              const CreditLine(),
            ],
          ),
        );
      },
    );
  }
}
