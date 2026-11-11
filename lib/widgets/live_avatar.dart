import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class LiveAvatar extends StatelessWidget {
  const LiveAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModelViewer(
      src: 'assets/penta_avatar.glb',
      alt: 'Penta animated avatar',
      autoPlay: true,
      cameraControls: true,
      autoRotate: false,
      backgroundColor: Colors.transparent,
    );
  }
}
