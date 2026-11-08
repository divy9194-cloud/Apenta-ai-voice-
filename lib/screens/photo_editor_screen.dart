import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ai_client.dart';
import '../assistant_brain.dart';
import '../local_store.dart';
import '../native_bridge.dart';
import '../permission_helper.dart';
import '../widgets/common.dart';

/// Pick a photo, say or type what to change, and Meta Muse Image edits it.
/// You can also send it to Canva, or make it Penta's picture.
class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key, required this.brain});
  final AssistantBrain brain;

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _input = TextEditingController();
  final List<Uint8List> _history = <Uint8List>[];
  bool _busy = false;
  bool _showOriginal = false;
  String _note = 'Pick a photo, then tell me what to change.';

  static const List<String> _ideas = <String>[
    'Remove the background',
    'Make it black and white',
    'Enhance the quality',
    'Make it anime style',
    'Add a sunset sky',
    'Blur the background',
  ];

  Uint8List? get _current => _history.isEmpty ? null : _history.last;

  @override
  void initState() {
    super.initState();
    widget.brain.onHeardOverride = _onVoice;
  }

  @override
  void dispose() {
    widget.brain.onHeardOverride = null;
    _input.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setSource(Uint8List bytes) {
    if (!mounted) return;
    setState(() {
      _history
        ..clear()
        ..add(bytes);
      _note = 'Photo ready. What should I change?';
    });
  }

  Future<void> _pick(ImageSource source) async {
    if (source == ImageSource.camera) {
      final bool ok = await askPermission(
        Permission.camera,
        'Penta needs the camera to take the photo you want to edit.',
      );
      if (!ok) return;
    }
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 90,
      );
      if (file == null) return;
      _setSource(await file.readAsBytes());
    } catch (e) {
      if (mounted) setState(() => _note = 'Could not open the photo.');
    }
  }

  /// Photos Penta already made or saved.
  Future<void> _pickFromPenta() async {
    final List<String> files = LocalStore.imagePaths().where((String p) => File(p).existsSync()).toList();
    if (files.isEmpty) {
      _snack('No Penta images yet. Make one first.');
      return;
    }
    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: files.length,
            itemBuilder: (BuildContext context, int i) {
              return GestureDetector(
                onTap: () => Navigator.pop(sheetContext, files[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(files[i]), fit: BoxFit.cover, cacheWidth: 300),
                ),
              );
            },
          ),
        );
      },
    );
    if (chosen != null) {
      _setSource(await File(chosen).readAsBytes());
    }
  }

  /// Returns what Penta should say.
  Future<String> _apply(String instruction) async {
    final Uint8List? base = _current;
    final String text = instruction.trim();
    if (base == null) {
      _snack('Pick a photo first.');
      return 'Pehle photo choose karo ${widget.brain.callName}.';
    }
    if (text.isEmpty || _busy) return '';
    setState(() {
      _busy = true;
      _note = 'Editing with Meta AI…';
    });
    String reply;
    try {
      final Uint8List out = await AiClient.editImage(base, text);
      if (mounted) {
        setState(() {
          _history.add(out);
          _note = 'Done! Change something else, or save it.';
        });
      }
      reply = 'Ho gaya ${widget.brain.callName}! Photo edit ho gayi.';
    } catch (e) {
      final String msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) setState(() => _note = 'Edit problem: $msg');
      reply = 'Sorry, edit nahi ho paya.';
    }
    if (mounted) setState(() => _busy = false);
    return reply;
  }

  Future<void> _onVoice(String text) async {
    final String t = text.toLowerCase();
    if (RegExp(r'\bcanva\b').hasMatch(t)) {
      await _openInCanva();
      return;
    }
    if (RegExp(r'(use|set|make).*(avatar|your picture|my picture|profile)').hasMatch(t)) {
      final bool ok = await _useAsPenta();
      await widget.brain.speak(ok ? 'Ab yeh meri nayi photo hai.' : 'Pehle photo choose karo.');
      return;
    }
    if (RegExp(r'\b(save|download)\b').hasMatch(t)) {
      await _save();
      await widget.brain.speak('Save ho gaya.');
      return;
    }
    if (RegExp(r'\b(undo|go back one|wapas)\b').hasMatch(t)) {
      _undo();
      return;
    }
    if (RegExp(r'\b(close|exit)\b').hasMatch(t)) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final String reply = await _apply(text);
    if (reply.isNotEmpty) await widget.brain.speak(reply);
  }

  void _undo() {
    if (_history.length > 1) {
      setState(() {
        _history.removeLast();
        _note = 'Went back one step.';
      });
    }
  }

  Future<void> _save() async {
    final Uint8List? img = _current;
    if (img == null || _history.length < 2) {
      _snack('Nothing new to save yet.');
      return;
    }
    final String path = await LocalStore.saveImage(img);
    final bool gallery = await Device.saveToGallery(path);
    widget.brain.refresh();
    if (mounted) {
      _snack(gallery ? 'Saved to your Gallery and Penta Images.' : 'Saved in the Images tab.');
    }
  }

  /// Sends the current photo to the Canva app so you can use its AI tools (Magic Edit and more).
  Future<void> _openInCanva() async {
    final Uint8List? img = _current;
    if (img == null) {
      _snack('Pick a photo first.');
      return;
    }
    try {
      final Directory dir = await getTemporaryDirectory();
      final bool png = img.length > 3 && img[0] == 0x89 && img[1] == 0x50;
      final File file = File('${dir.path}/penta_canva_${DateTime.now().millisecondsSinceEpoch}.${png ? 'png' : 'jpg'}');
      await file.writeAsBytes(img);
      final bool ok = await Device.shareImage(file.path, 'com.canva.editor');
      if (ok) {
        if (mounted) {
          setState(() => _note =
              'In Canva: tap the photo, then Edit photo → Magic Edit or Background Remover. Save to Gallery, then come back and tap Gallery here.');
        }
      } else {
        if (mounted) _snack('Canva is not installed, so I opened Canva on the web.');
        await Device.openUrl('https://www.canva.com/');
      }
    } catch (e) {
      if (mounted) _snack('Could not send the photo to Canva.');
    }
  }

  Future<void> _createInCanva() async {
    final bool ok = await Device.openUrl('https://www.canva.com/ai-image-generator/');
    if (!ok && mounted) _snack('Could not open Canva.');
  }

  Future<bool> _useAsPenta() async {
    final Uint8List? img = _current;
    if (img == null) {
      if (mounted) _snack('Pick a photo first.');
      return false;
    }
    final String path = await LocalStore.saveImage(img);
    await LocalStore.prefs.setString('avatarPath', path);
    widget.brain.refresh();
    if (mounted) _snack('Done! This is Penta\'s new picture.');
    return true;
  }

  Future<void> _resetPenta() async {
    await LocalStore.prefs.remove('avatarPath');
    widget.brain.refresh();
    if (mounted) _snack('Penta is back to the original picture.');
  }

  void _sendTyped() {
    final String text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    _apply(text);
  }

  Widget _preview() {
    final Uint8List? img = _showOriginal ? (_history.isEmpty ? null : _history.first) : _current;
    if (img == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.white38),
              const SizedBox(height: 12),
              Text(_note, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onLongPressStart: (LongPressStartDetails d) => setState(() => _showOriginal = true),
      onLongPressEnd: (LongPressEndDetails d) => setState(() => _showOriginal = false),
      child: Stack(
        children: [
          Positioned.fill(child: InteractiveViewer(child: Image.memory(img, fit: BoxFit.contain, gaplessPlayback: true))),
          if (_showOriginal)
            const Positioned(
              top: 8,
              left: 8,
              child: Chip(label: Text('Original')),
            ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: const Color(0x99000000),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo editor'),
        actions: [
          IconButton(tooltip: 'Undo', onPressed: _history.length > 1 ? _undo : null, icon: const Icon(Icons.undo)),
          IconButton(tooltip: 'Save', onPressed: _save, icon: const Icon(Icons.save_alt)),
          PopupMenuButton<String>(
            onSelected: (String v) {
              if (v == 'canva') _openInCanva();
              if (v == 'create') _createInCanva();
              if (v == 'avatar') _useAsPenta();
              if (v == 'reset') _resetPenta();
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem<String>(value: 'canva', child: Text('Open in Canva (Magic Edit)')),
              PopupMenuItem<String>(value: 'create', child: Text('Create a picture in Canva')),
              PopupMenuItem<String>(value: 'avatar', child: Text('Use as Penta\'s picture')),
              PopupMenuItem<String>(value: 'reset', child: Text('Reset Penta\'s picture')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.brain,
          builder: (BuildContext context, Widget? child) {
            final String live = widget.brain.liveText;
            return Column(
              children: [
                Expanded(child: _preview()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                  child: Text(
                    live.isNotEmpty ? live : _note,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: live.isNotEmpty ? Colors.white : Colors.white54),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _pickFromPenta,
                          icon: const Icon(Icons.collections),
                          label: const Text('Mine'),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _busy ? null : _openInCanva,
                          icon: const Icon(Icons.brush),
                          label: const Text('Open in Canva'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _busy ? null : _createInCanva,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Create in Canva'),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    children: [
                      for (final String idea in _ideas)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(idea),
                            onPressed: _busy ? null : () => _apply(idea),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          onSubmitted: (String _) => _sendTyped(),
                          decoration: InputDecoration(
                            hintText: 'Tell me what to change',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: widget.brain.toggle,
                        icon: Icon(widget.brain.active ? Icons.mic : Icons.mic_none),
                      ),
                      IconButton.filled(
                        onPressed: _busy ? null : _sendTyped,
                        icon: const Icon(Icons.auto_fix_high),
                        style: IconButton.styleFrom(backgroundColor: neonViolet),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
