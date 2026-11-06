import 'package:flutter/material.dart';
import '../assistant_brain.dart';
import '../local_store.dart';
import '../widgets/common.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.brain});
  final AssistantBrain brain;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();

  void _send() {
    final String text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    widget.brain.runCommand(text);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.brain,
        builder: (BuildContext context, Widget? child) {
          final List<ChatEntry> msgs = widget.brain.entries.reversed.toList();
          final bool thinking = widget.brain.thinking;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    const Expanded(child: Text('Chat', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600))),
                    IconButton(onPressed: widget.brain.clearChat, icon: const Icon(Icons.delete_outline)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length + (thinking ? 1 : 0),
                  itemBuilder: (BuildContext context, int i) {
                    if (thinking && i == 0) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Penta is thinking…', style: TextStyle(color: Colors.white54)),
                      );
                    }
                    final ChatEntry m = msgs[i - (thinking ? 1 : 0)];
                    return Align(
                      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                        decoration: BoxDecoration(
                          color: m.fromUser ? neonViolet.withAlpha(150) : panelColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(m.text),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        onSubmitted: (String _) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Ask or command Penta',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                    IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
