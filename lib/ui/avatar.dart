import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'widgets.dart' show cyan, violet;

class PentaAvatar extends StatefulWidget {
  const PentaAvatar({
    super.key,
    required this.active,
    required this.speaking,
    required this.thinking,
    required this.level,
    required this.onTap,
  });

  final bool active;
  final bool speaking;
  final bool thinking;
  final double level;
  final VoidCallback onTap;

  @override
  State<PentaAvatar> createState() => _PentaAvatarState();
}

class _PentaAvatarState extends State<PentaAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * math.pi * 2;
          final glow = widget.speaking || widget.active ? 0.8 : 0.4;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: (widget.speaking || widget.active ? cyan : violet).withOpacity(glow),
                  blurRadius: widget.speaking || widget.active ? 40 : 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // background
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF0B1228),
                          Color(0xFF070A18),
                        ],
                      ),
                    ),
                  ),

                  // orbit glow
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GlowPainter(
                        phase: t,
                        active: widget.active,
                        speaking: widget.speaking,
                        thinking: widget.thinking,
                      ),
                    ),
                  ),

                  // central face
                  Transform.translate(
                    offset: Offset(
                      math.sin(t * 1.8) * 8,
                      math.cos(t * 1.5) * 6,
                    ),
                    child: Transform.rotate(
                      angle: math.sin(t * 2.2) * 0.08,
                      child: Container(
                        width: 220,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFFf7d9c8), Color(0xFFebc6a9)],
                            radius: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: CustomPaint(
                          painter: _FacePainter(
                            active: widget.active,
                            speaking: widget.speaking,
                            thinking: widget.thinking,
                            level: widget.level,
                            t: t,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.phase,
    required this.active,
    required this.speaking,
    required this.thinking,
  });

  final double phase;
  final bool active;
  final bool speaking;
  final bool thinking;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.screen;

    for (int i = 0; i < 16; i++) {
      final angle = phase + i * (math.pi / 8);
      final radius = 70 + i * 12;
      final x = size.width / 2 + math.cos(angle) * radius;
      final y = size.height / 2 + math.sin(angle) * radius * 0.9;

      final glowColor = speaking
          ? cyan.withOpacity(0.25)
          : active
              ? violet.withOpacity(0.2)
              : Colors.white.withOpacity(0.08);

      paint.color = glowColor;
      canvas.drawCircle(Offset(x, y), 14 + (i % 4) * 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.active != active ||
        oldDelegate.speaking != speaking ||
        oldDelegate.thinking != thinking;
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter({
    required this.active,
    required this.speaking,
    required this.thinking,
    required this.level,
    required this.t,
  });

  final bool active;
  final bool speaking;
  final bool thinking;
  final double level;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bodyPaint = Paint()..color = const Color(0xFF1B244A);

    // shirt/body
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.7),
        width: size.width * 0.55,
        height: size.height * 0.42,
      ),
      const Radius.circular(28),
    );
    canvas.drawRRect(body, bodyPaint);

    // hair
    final hairPaint = Paint()..color = const Color(0xFF1A1A2E);
    final hairRect = Rect.fromCenter(
      center: Offset(center.dx, size.height * 0.28),
      width: size.width * 0.58,
      height: size.height * 0.26,
    );
    canvas.drawOval(hairRect, hairPaint);

    // face features
    final skin = Paint()..color = const Color(0xFFF3C9A6);

    // cheeks
    canvas.drawCircle(Offset(size.width * 0.32, size.height * 0.52), 10, Paint()..color = const Color(0xFFf0a7a7).withOpacity(0.5));
    canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.52), 10, Paint()..color = const Color(0xFFf0a7a7).withOpacity(0.5));

    // face outline
    canvas.drawCircle(center, size.width * 0.28, skin);

    // eyebrows
    final browPaint = Paint()
      ..color = const Color(0xFF2A1C37)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.35),
      Offset(size.width * 0.42, size.height * 0.33),
      browPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.58, size.height * 0.33),
      Offset(size.width * 0.68, size.height * 0.35),
      browPaint,
    );

    // eyes
    final eyePaint = Paint()..color = const Color(0xFF1F1B2E);

    final blink = speaking ? 0.25 + (0.75 * math.sin(t * 10)) : 0.15;
    final eyeRadius = 5.5 * (1 - blink * 0.6);

    canvas.drawCircle(Offset(size.width * 0.36, size.height * 0.45), eyeRadius, eyePaint);
    canvas.drawCircle(Offset(size.width * 0.64, size.height * 0.45), eyeRadius, eyePaint);

    // mouth
    final mouthOpen = speaking ? 12 + (level * 18) : thinking ? 7 : 4;
    final mouthRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.58),
      width: 52,
      height: mouthOpen,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        mouthRect,
        const Radius.circular(12),
      ),
      Paint()..color = const Color(0xFF5B2A3B),
    );

    // butterfly / glowing accent
    final accentPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFB6EAFD), Color(0xFF7DD3FC), Color(0xFF26263E)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.5, size.height * 0.18),
        radius: 80,
      ));

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.18),
      16 + (speaking ? 6 : 0),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) {
    return oldDelegate.active != active ||
        oldDelegate.speaking != speaking ||
        oldDelegate.thinking != thinking ||
        oldDelegate.level != level ||
        oldDelegate.t != t;
  }
}
