import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class WavingAvatarVideo extends StatefulWidget {
  const WavingAvatarVideo({
    super.key,
    required this.brain,
  });

  final dynamic brain;

  @override
  State<WavingAvatarVideo> createState() => _WavingAvatarVideoState();
}

class _WavingAvatarVideoState extends State<WavingAvatarVideo> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/penta_wave.mp4',
    );

    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.setLooping(true);
      _controller.setVolume(0);
      _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return GestureDetector(
      onTap: widget.brain.toggle,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
