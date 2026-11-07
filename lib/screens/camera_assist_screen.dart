import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../assistant_brain.dart';
import '../local_store.dart';
import '../native_bridge.dart';
import '../permission_helper.dart';
import '../vision_client.dart';
import '../widgets/common.dart';

/// Live camera: show something and ask about it, or take a photo.
class CameraAssistScreen extends StatefulWidget {
  const CameraAssistScreen({super.key, required this.brain});
  final AssistantBrain brain;

  @override
  State<CameraAssistScreen> createState() => _CameraAssistScreenState();
}

class _CameraAssistScreenState extends State<CameraAssistScreen> with WidgetsBindingObserver {
  CameraController? _cam;
  List<CameraDescription> _cameras = <CameraDescription>[];
  int _index = 0;
  bool _ready = false;
  bool _busy = false;
  String _answer = '';
  String _error = '';
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.brain.onHeardOverride = _onVoice;
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.brain.onHeardOverride = null;
    _cam?.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? c = _cam;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _ready = false;
    } else if (state == AppLifecycleState.resumed) {
      _start(_index);
    }
  }

  Future<void> _init() async {
    final bool ok = await askPermission(
      Permission.camera,
      'Penta needs the camera to look at what you show it. A picture is sent to the AI only when you ask a question. Nothing is recorded in the background.',
    );
    if (!ok) {
      if (mounted) setState(() => _error = 'Camera permission is needed.');
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found.');
        return;
      }
      final int back = _cameras.indexWhere((CameraDescription d) => d.lensDirection == CameraLensDirection.back);
      _index = back < 0 ? 0 : back;
      await _start(_index);
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera problem: $e');
    }
  }

  Future<void> _start(int i) async {
    final CameraController? old = _cam;
    final CameraController controller = CameraController(_cameras[i], ResolutionPreset.medium, enableAudio: false);
    _cam = controller;
    if (mounted) setState(() => _ready = false);
    try {
      await old?.dispose();
    } catch (_) {}
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _error = '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera problem: $e');
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _busy) return;
    _index = (_index + 1) % _cameras.length;
    await _start(_index);
  }

  Future<void> _ask(String question) async {
    final CameraController? c = _cam;
    if (c == null || !_ready || _busy) return;
    setState(() {
      _busy = true;
      _answer = '';
    });
    String answer;
    try {
      final XFile shot = await c.takePicture();
      final Uint8List bytes = await shot.readAsBytes();
      answer = await VisionClient.ask(question, bytes);
    } catch (e) {
      final String text = e.toString();
      answer = 'Camera problem: ${text.length > 120 ? text.substring(0, 120) : text}';
    }
    widget.brain.addEntry('Camera: $question', true);
    widget.brain.addEntry(answer, false);
    if (!mounted) return;
    setState(() {
      _answer = answer;
      _busy = false;
    });
    await widget.brain.speak(answer);
  }

  Future<void> _snap({bool speakIt = false}) async {
    final CameraController? c = _cam;
    if (c == null || !_ready || _busy) return;
    setState(() => _busy = true);
    String message;
    try {
      final XFile shot = await c.takePicture();
      final Uint8List bytes = await shot.readAsBytes();
      final String path = await LocalStore.saveImage(bytes);
      final bool inGallery = await Device.saveToGallery(path);
      message = inGallery ? 'Photo saved to your Gallery.' : 'Photo saved in Penta, in the Images tab.';
    } catch (e) {
      message = 'Could not take the photo.';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _answer = message;
    });
    widget.brain.refresh();
    if (speakIt) await widget.brain.speak(message);
  }

  Future<void> _onVoice(String text) async {
    final String t = text.toLowerCase();
    if (RegExp(r'\b(take|click|capture|clik)\b.*\b(photo|picture|pic|selfie)\b').hasMatch(t)) {
      await _snap(speakIt: true);
      return;
    }
    if (RegExp(r'\b(switch|flip|change)\b.*\bcamera\b').hasMatch(t)) {
      await _flip();
      return;
    }
    if (RegExp(r'\b(close|exit|go back)\b.*\bcamera\b').hasMatch(t)) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _ask(text);
  }

  void _sendTyped() {
    final String q = _input.text.trim();
    if (q.isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    _ask(q);
  }

  Widget _chip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: _busy ? null : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? c = _cam;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: (_ready && c != null)
                ? Center(child: CameraPreview(c))
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error.isEmpty ? 'Starting camera…' : _error, textAlign: TextAlign.center),
                    ),
                  ),
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  color: Colors.black54,
                  child: Row(
                    children: [
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                      const Expanded(
                        child: Text('Camera assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(onPressed: _flip, icon: const Icon(Icons.cameraswitch)),
                    ],
                  ),
                ),
                const Spacer(),
                ListenableBuilder(
                  listenable: widget.brain,
                  builder: (BuildContext context, Widget? child) {
                    final String live = widget.brain.liveText;
                    final String shown = _busy ? 'Looking…' : (live.isNotEmpty ? live : _answer);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (shown.isNotEmpty)
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 170),
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(190),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SingleChildScrollView(child: Text(shown, style: const TextStyle(fontSize: 16))),
                          ),
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip('What is this?', Icons.help_outline, () => _ask('What is this? Describe what you see.')),
                            _chip('Read the text', Icons.text_fields, () => _ask('Read out any text you can see.')),
                            _chip('Take photo', Icons.camera_alt, () => _snap()),
                          ],
                        ),
                        Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  onSubmitted: (String _) => _sendTyped(),
                                  decoration: InputDecoration(
                                    hintText: 'Ask about what you see',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                                  ),
                                ),
                              ),
                              IconButton.filled(
                                onPressed: widget.brain.toggle,
                                icon: Icon(widget.brain.active ? Icons.mic : Icons.mic_none),
                              ),
                              IconButton.filled(onPressed: _sendTyped, icon: const Icon(Icons.send)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
