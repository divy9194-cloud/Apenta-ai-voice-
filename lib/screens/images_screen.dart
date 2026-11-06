import 'dart:io';
import 'package:flutter/material.dart';
import '../ai_client.dart';
import '../assistant_brain.dart';
import '../local_store.dart';

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key, required this.brain});
  final AssistantBrain brain;

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  final TextEditingController _prompt = TextEditingController();
  bool _busy = false;

  Future<void> _generate() async {
    final String text = _prompt.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await AiClient.image(text);
      _prompt.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not generate the image.')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.brain,
        builder: (BuildContext context, Widget? child) {
          final List<String> files = LocalStore.imagePaths().where((p) => File(p).existsSync()).toList();
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Images', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _prompt,
                        decoration: InputDecoration(
                          hintText: 'Describe an image',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      IconButton.filled(onPressed: _generate, icon: const Icon(Icons.auto_awesome)),
                  ],
                ),
              ),
              Expanded(
                child: files.isEmpty
                    ? const Center(
                        child: Text(
                          'No images yet.\nTry: "Hey Penta, generate an image of a neon city".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: files.length,
                        itemBuilder: (BuildContext context, int i) {
                          final String path = files[i];
                          return GestureDetector(
                            onTap: () {
                              showDialog<void>(
                                context: context,
                                builder: (BuildContext c) => Dialog(child: InteractiveViewer(child: Image.file(File(path)))),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(File(path), fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
