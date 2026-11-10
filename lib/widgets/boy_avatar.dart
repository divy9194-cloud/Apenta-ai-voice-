import 'package:flutter/material.dart';

class BoyAvatar extends StatefulWidget {
  final bool isSpeaking;
  final bool isListening;

  const BoyAvatar({
    Key? key,
    this.isSpeaking = false,
    this.isListening = false,
  }) : super(key: key);

  @override
  State<BoyAvatar> createState() => _BoyAvatarState();
}

class _BoyAvatarState extends State<BoyAvatar> with TickerProviderStateMixin {
  late AnimationController _gestureController;
  late AnimationController _faceController;
  late Animation<double> _handMovementAnim;
  late Animation<double> _mouthOpenAnim;
  late Animation<double> _eyeBlinkAnim;

  @override
  void initState() {
    super.initState();

    // Controller for maximum hand gestures and body movement
    _gestureController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _handMovementAnim = Tween<double>(begin: -0.08, end: 0.12).animate(
      CurvedAnimation(parent: _gestureController, curve: Curves.easeInOut),
    );

    // Controller for facial expressions (mouth/eyes)
    _faceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..repeat(reverse: true);

    _mouthOpenAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _faceController, curve: Curves.easeInOut),
    );

    _eyeBlinkAnim = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(parent: _faceController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _gestureController.dispose();
    _faceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_gestureController, _faceController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _handMovementAnim.value * 25),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Base Boy Photo (Butterfly-catching pose reference)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'boy.jpg',
                  height: 280,
                  width: 220,
                  fit: BoxFit.cover,
                ),
              ),

              // Dynamic Gesture tracking indicator overlay
              Positioned(
                bottom: 35,
                child: Transform.rotate(
                  angle: _handMovementAnim.value * 1.5,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withOpacity(
                        widget.isListening ? 0.7 : 0.25,
                      ),
                    ),
                  ),
                ),
              ),

              // Active Speech / Mouth Movement indicator overlay
              if (widget.isSpeaking)
                Positioned(
                  top: 95,
                  child: Container(
                    width: 14 + (_mouthOpenAnim.value * 12),
                    height: 5 + (_mouthOpenAnim.value * 9),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
