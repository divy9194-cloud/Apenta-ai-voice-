import 'dart:math' as math;
import 'package:flutter/material.dart';

enum BoyMood { idle, listening, thinking, speaking, waving, sleeping }

const Color _skin = Color(0xFFF2C49B);
const Color _skinShade = Color(0xFFE2AB80);
const Color _hair = Color(0xFF1B1B2F);
const Color _ink = Color(0xFF20203A);
const Color _shirt = Color(0xFF22D3EE);
const Color _shirtDark = Color(0xFF8B5CF6);
const Color _mouthDark = Color(0xFF5A1E1E);

/// Draws a cartoon boy that reacts to what Penta is doing.
class BoyPainter extends CustomPainter {
  BoyPainter({required this.t, required this.mood, required this.level, required this.blink});
  final double t;
  final BoyMood mood;
  final double level;
  final double blink;

  void _text(Canvas c, String s, Offset center, double size, Color color) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _arm(Canvas c, Offset shoulder, Offset hand, double outward) {
    final Offset mid = Offset((shoulder.dx + hand.dx) / 2, (shoulder.dy + hand.dy) / 2);
    final Offset elbow = Offset(mid.dx + outward * 16, mid.dy + 10);
    final Paint sleeve = Paint()
      ..color = _shirt
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;
    final Paint fore = Paint()
      ..color = _skin
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round;
    c.drawLine(shoulder, elbow, sleeve);
    c.drawLine(elbow, hand, fore);
    c.drawCircle(hand, 12, Paint()..color = _skin);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = math.min(size.width / 280, size.height / 320);
    canvas.save();
    canvas.translate((size.width - 280 * scale) / 2, (size.height - 320 * scale) / 2);
    canvas.scale(scale, scale);

    final double wave = math.sin(t * 2 * math.pi);
    final double fast = math.sin(t * 2 * math.pi * 4);
    final bool asleep = mood == BoyMood.sleeping;
    final double bob = asleep ? 8.0 : wave * 2.5;

    double tilt = wave * 0.01;
    if (mood == BoyMood.listening) {
      tilt = 0.07 + wave * 0.02;
    } else if (mood == BoyMood.thinking) {
      tilt = -0.06;
    } else if (mood == BoyMood.sleeping) {
      tilt = 0.12;
    } else if (mood == BoyMood.speaking) {
      tilt = wave * 0.03;
    }

    Offset leftHand = Offset(56, 292 - wave * 2);
    Offset rightHand = Offset(224, 292 + wave * 2);
    if (mood == BoyMood.listening) {
      rightHand = Offset(216, 128 + wave * 3);
    } else if (mood == BoyMood.thinking) {
      leftHand = const Offset(134, 186);
    } else if (mood == BoyMood.speaking) {
      rightHand = Offset(232 + fast * 8, 172 + wave * 18);
      leftHand = Offset(50 + wave * 4, 262 + fast * 6);
    } else if (mood == BoyMood.waving) {
      rightHand = Offset(240 + fast * 14, 116 + wave * 4);
    } else if (mood == BoyMood.sleeping) {
      leftHand = const Offset(60, 296);
      rightHand = const Offset(220, 296);
    }

    double mouth = 0.0;
    if (mood == BoyMood.speaking) {
      mouth = (0.5 + 0.5 * math.sin(t * 2 * math.pi * 7)).abs() * 0.9;
    }

    Offset look = Offset.zero;
    if (mood == BoyMood.thinking) {
      look = const Offset(4, -5);
    } else if (mood == BoyMood.speaking) {
      look = Offset(wave * 2, 0);
    } else if (mood == BoyMood.listening) {
      look = const Offset(3, 0);
    }

    // Shadow and body
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(140, 316), width: 190, height: 14),
      Paint()..color = const Color(0x55000000),
    );
    final Rect torso = Rect.fromLTWH(66, 206, 148, 114);
    canvas.drawRRect(
      RRect.fromRectAndRadius(torso, const Radius.circular(30)),
      Paint()
        ..shader = const LinearGradient(
          colors: [_shirt, _shirtDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(torso),
    );
    canvas.drawRect(Rect.fromLTWH(124, 184, 32, 28), Paint()..color = _skinShade);
    final Path vNeck = Path()
      ..moveTo(116, 206)
      ..lineTo(164, 206)
      ..lineTo(140, 238)
      ..close();
    canvas.drawPath(vNeck, Paint()..color = _skin);
    _text(canvas, 'P', const Offset(140, 278), 36, Colors.white);

    // Head
    canvas.save();
    canvas.translate(140, 196 + bob);
    canvas.rotate(tilt);
    canvas.translate(-140, -196);

    final Paint skin = Paint()..color = _skin;
    final Paint shade = Paint()..color = _skinShade;
    canvas.drawCircle(const Offset(78, 130), 11, skin);
    canvas.drawCircle(const Offset(202, 130), 11, skin);
    canvas.drawCircle(const Offset(78, 130), 5, shade);
    canvas.drawCircle(const Offset(202, 130), 5, shade);
    canvas.drawCircle(const Offset(140, 125), 62, skin);

    final Path hair = Path()
      ..moveTo(76, 122)
      ..cubicTo(66, 28, 214, 28, 204, 122)
      ..quadraticBezierTo(192, 96, 166, 100)
      ..quadraticBezierTo(140, 76, 114, 100)
      ..quadraticBezierTo(90, 96, 76, 122)
      ..close();
    canvas.drawPath(hair, Paint()..color = _hair);

    final Paint brow = Paint()
      ..color = _hair
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    double leftRaise = 0.0;
    double rightRaise = 0.0;
    if (mood == BoyMood.listening || mood == BoyMood.waving) {
      leftRaise = 5;
      rightRaise = 5;
    } else if (mood == BoyMood.thinking) {
      leftRaise = 9;
      rightRaise = 1;
    } else if (mood == BoyMood.speaking) {
      leftRaise = 2 + wave * 2;
      rightRaise = 2 - wave * 2;
    }
    canvas.drawLine(Offset(100, 112 - leftRaise), Offset(128, 110 - leftRaise), brow);
    canvas.drawLine(Offset(152, 110 - rightRaise), Offset(180, 112 - rightRaise), brow);

    const Offset eyeL = Offset(115, 134);
    const Offset eyeR = Offset(165, 134);
    if (asleep) {
      final Paint closed = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCenter(center: eyeL, width: 22, height: 12), 0, math.pi, false, closed);
      canvas.drawArc(Rect.fromCenter(center: eyeR, width: 22, height: 12), 0, math.pi, false, closed);
    } else {
      final double open = 1.0 - blink;
      for (final Offset e in <Offset>[eyeL, eyeR]) {
        canvas.drawOval(Rect.fromCenter(center: e, width: 24, height: 26 * open + 1), Paint()..color = Colors.white);
        if (open > 0.3) {
          final Offset p = e + look;
          canvas.drawCircle(p, 6.5 * open, Paint()..color = _ink);
          canvas.drawCircle(p + const Offset(-2, -2), 2, Paint()..color = Colors.white);
        }
      }
    }

    final Paint cheek = Paint()..color = const Color(0x40FF5C5C);
    canvas.drawCircle(const Offset(98, 156), 9, cheek);
    canvas.drawCircle(const Offset(182, 156), 9, cheek);
    canvas.drawCircle(const Offset(140, 148), 3.2, shade);

    if (mouth < 0.08) {
      double smile = 4.0;
      if (mood == BoyMood.waving) {
        smile = 11.0;
      } else if (mood == BoyMood.thinking) {
        smile = -5.0;
      } else if (asleep) {
        smile = 1.0;
      }
      final Path m = Path()
        ..moveTo(124, 168)
        ..quadraticBezierTo(140, 168 + smile * 2, 156, 168);
      canvas.drawPath(
        m,
        Paint()
          ..color = _mouthDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final double h = 6 + 24 * mouth;
      final Rect mouthRect = Rect.fromCenter(center: Offset(140, 170 + h / 2 - 3), width: 32, height: h);
      canvas.drawOval(mouthRect, Paint()..color = _mouthDark);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(140, 170 + h * 0.8), width: 18, height: h * 0.4),
        Paint()..color = const Color(0xFFE5737A),
      );
      canvas.drawRect(Rect.fromLTWH(128, 168, 24, 4), Paint()..color = Colors.white);
    }
    canvas.restore();

    // Arms in front
    _arm(canvas, Offset(78, 228 + bob * 0.4), leftHand, -1);
    _arm(canvas, Offset(202, 228 + bob * 0.4), rightHand, 1);

    if (mood == BoyMood.thinking) {
      for (int i = 0; i < 3; i++) {
        final double p = (math.sin(t * 2 * math.pi * 2 - i * 0.9) + 1) / 2;
        canvas.drawCircle(
          Offset(206 + i * 16.0, 66 - i * 8.0),
          3 + 3 * p,
          Paint()..color = Colors.white.withAlpha(120 + (100 * p).round()),
        );
      }
    }
    if (asleep) {
      _text(canvas, 'Z', Offset(214, 70 - wave * 4), 24, Colors.white70);
      _text(canvas, 'z', Offset(236, 46 - wave * 4), 16, Colors.white54);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BoyPainter oldDelegate) => true;
}

/// The animated boy. Tap him to start or stop a conversation.
class BoyAvatar extends StatefulWidget {
  const BoyAvatar({super.key, required this.mood, required this.level, required this.onTap});
  final BoyMood mood;
  final double level;
  final VoidCallback onTap;

  @override
  State<BoyAvatar> createState() => _BoyAvatarState();
}

class _BoyAvatarState extends State<BoyAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? child) {
          final int ms = DateTime.now().millisecondsSinceEpoch % 3600;
          final double blink = ms < 180 ? math.sin(ms / 180 * math.pi) : 0.0;
          return CustomPaint(
            size: const Size(280, 320),
            painter: BoyPainter(t: _c.value, mood: widget.mood, level: widget.level, blink: blink),
          );
        },
      ),
    );
  }
}
