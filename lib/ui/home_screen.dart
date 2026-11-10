import 'package:flutter/material.dart';

import '../assistant/controller.dart';
import 'avatar.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen(this.c, {super.key});
  final PentaController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (_, __) {
        final last = c.chat.isNotEmpty && !c.chat.last.user ? c.chat.last.text : '';
        final status = c.active
            ? 'Listening…'
            : (c.wakeMode ? 'Say "Hey Penta"' : 'Tap Penta to talk');

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF091120),
                Color(0xFF050A14),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 22),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: PentaAvatar(
                      active: c.active,
                      speaking: c.speaking,
                      thinking: c.thinking,
                      level: c.level,
                      onTap: c.toggleOrb,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Waveform(level: c.level, active: c.active),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 90),
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
                  alignment: Alignment.center,
                  child: Text(
                    c.thinking ? 'Thinking…' : (c.live.isNotEmpty ? c.live : last),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      color: c.live.isNotEmpty ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
                const DevCredit(),
              ],
            ),
          ),
        );
      },
    );
  }
}
