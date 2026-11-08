import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../assistant_brain.dart';
import 'boy_avatar.dart';
import 'common.dart';

/// The picture's white background is multiplied by this colour so it blends into the card.
const Color _tint = Color(0xFFEAF0FF);

/// Skin colour used for blinking (the picture's skin after the tint). Adjust if the blink looks off.
const Color _skin = Color(0xFFE6C6AF);
const Color _lash = Color(0xFF5A2E1C);

// Positions on the picture, as fractions of its width and height.
const double _boardCX = 0.7875;
const double _boardCY = 0.525;
const double _boardW = 0.370;
const double _boardH = 0.240;
const double _mouthX = 0.369;
const double _mouthY = 0.412;
const double _eyeLX = 0.294;
const double _eyeRX = 0.441;
const double _eyeY = 0.298;
const double _earLX = 0.205;
const double _earRX = 0.525;
const double _earY = 0.330;

class _MouthPainter extends CustomPainter {
  _MouthPainter(this.open);
  final double open;

  @override
  void paint(Canvas canvas, Size size) {
    final Path mouth = Path()..addOval(Offset.zero & size);
    canvas.drawPath(mouth, Paint()..color = const Color(0xFF4A1616));
    canvas.save();
    canvas.clipPath(mouth);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.28), Paint()..color = Colors.white);
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.2, size.height * 0.62, size.width * 0.6, size.height * 0.5),
      Paint()..color = const Color(0xFFE5737A),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MouthPainter oldDelegate) => oldDelegate.open != open;
}

class _BlinkPainter extends CustomPainter {
  const _BlinkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(Offset.zero & size, Paint()..color = _skin);
    final Paint lash = Paint()
      ..color = _lash
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.09
      ..strokeCap = StrokeCap.round;
    final Path p = Path()
      ..moveTo(size.width * 0.12, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.78, size.width * 0.88, size.height * 0.5);
    canvas.drawPath(p, lash);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Penta's character: your picture, with the reply written on his board and gestures while he talks.
class CharacterView extends StatefulWidget {
  const CharacterView({super.key, required this.brain});
  final AssistantBrain brain;

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  String _typingFor = '';
  int _typeStartMs = 0;
  String _sizeKey = '';
  double _sizeValue = 14;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  String _lastReply(AssistantBrain b) {
    for (int i = b.entries.length - 1; i >= 0; i--) {
      if (!b.entries[i].fromUser) return b.entries[i].text;
    }
    return '';
  }

  String _clip(String raw) {
    final String t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= 110) return t;
    final int cut = t.lastIndexOf(' ', 107);
    return '${t.substring(0, cut > 40 ? cut : 107)}…';
  }

  double _fontFor(String text, double bw, double bh) {
    final String key = '$text|${bw.round()}|${bh.round()}';
    if (key == _sizeKey) return _sizeValue;
    double top = bw * 0.14;
    if (top > 26) top = 26;
    double chosen = 9;
    for (double sz = top; sz >= 9; sz -= 1) {
      chosen = sz;
      final TextPainter tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: sz, fontWeight: FontWeight.w700, height: 1.15)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: bw);
      if (tp.height <= bh) break;
    }
    _sizeKey = key;
    _sizeValue = chosen;
    return chosen;
  }

  /// Places a child so that its centre is at (fx, fy) of the picture.
  Widget _at(double side, double fx, double fy, double w, double h, Widget child) {
    return Positioned(left: fx * side - w / 2, top: fy * side - h / 2, width: w, height: h, child: child);
  }

  Widget _ring(double side, double fx, double fy, double p) {
    final double size = side * (0.04 + 0.10 * p);
    return _at(
      side,
      fx,
      fy,
      size,
      size,
      IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: neonViolet.withAlpha(((1 - p) * 200).round()), width: 2.5),
          ),
        ),
      ),
    );
  }

  Widget _sparkle(double side, double fx, double fy, double phase, double s) {
    final double a = (math.sin(2 * math.pi * (s * 1.4 + phase)) + 1) / 2;
    final double size = side * (0.035 + 0.03 * a);
    return _at(
      side,
      fx,
      fy,
      size * 1.5,
      size * 1.5,
      Center(
        child: Icon(Icons.auto_awesome, size: size, color: const Color(0xFFF59E0B).withAlpha((120 + 135 * a).round())),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[widget.brain, _ticker]),
      builder: (BuildContext context, Widget? child) => _scene(),
    );
  }

  Widget _scene() {
    final AssistantBrain brain = widget.brain;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final double s = (nowMs % 600000) / 1000.0;
    const double tau = 2 * math.pi;
    final BoyMood mood = brain.mood;
    final bool asleep = mood == BoyMood.sleeping;

    // What is written on the board
    final String dots = '.' * (1 + (s * 2).floor() % 3);
    String text;
    bool isReply = false;
    if (asleep) {
      text = 'Zzz…';
    } else if (brain.thinking) {
      text = 'Soch raha hoon$dots';
    } else if (brain.speaking && brain.spokenText.isNotEmpty) {
      text = brain.spokenText;
      isReply = true;
    } else if (brain.active) {
      text = brain.liveText.trim().isNotEmpty ? brain.liveText : 'Bol ${brain.callName}, main sun raha hoon…';
    } else {
      final String r = _lastReply(brain);
      if (r.isNotEmpty) {
        text = r;
        isReply = true;
      } else {
        text = 'Namaste ${brain.callName}! Mujhe tap karo.';
      }
    }
    final String full = _clip(text);
    String shown = full;
    if (isReply) {
      if (full != _typingFor) {
        _typingFor = full;
        _typeStartMs = nowMs;
      }
      final int n = ((nowMs - _typeStartMs) / 1000.0 * 14).floor();
      if (n < full.length) shown = full.substring(0, n < 0 ? 0 : n);
    }

    Color glow = neonViolet.withAlpha(70);
    if (mood == BoyMood.listening) {
      glow = neonCyan.withAlpha(140);
    } else if (mood == BoyMood.speaking) {
      glow = neonViolet.withAlpha(150);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints cs) {
        final double cardW = cs.maxWidth;
        final double cardH = cs.maxHeight;
        final double side = math.max(cardW, cardH);
        final double offX = (cardW - side) / 2;
        final double k = side / 360;

        // Body gestures
        double dx = 0;
        double dy = 0;
        double angle = 0;
        double sx = 1;
        double sy = 1;
        switch (mood) {
          case BoyMood.idle:
            {
              sy = 1 + 0.008 * math.sin(tau * s / 3.2);
              angle = 0.006 * math.sin(tau * s / 5);
              break;
            }
          case BoyMood.listening:
            {
              angle = 0.035 + 0.008 * math.sin(tau * s / 1.6);
              sy = 1.01;
              break;
            }
          case BoyMood.thinking:
            {
              angle = -0.03 + 0.01 * math.sin(tau * s / 2);
              dy = 2 * math.sin(tau * s / 1.5);
              break;
            }
          case BoyMood.speaking:
            {
              final int g = (s / 2.4).floor() % 4;
              sy = 1 + 0.006 * math.sin(tau * 6 * s);
              if (g == 0) {
                dy = 5 * math.sin(tau * 2.4 * s);
                angle = 0.012 * math.sin(tau * 1.2 * s);
              } else if (g == 1) {
                angle = 0.04 * math.sin(tau * 1.3 * s);
                dx = 5 * math.sin(tau * 1.3 * s);
              } else if (g == 2) {
                dy = -9 * math.sin(tau * 1.6 * s).abs();
                sx = 1 + 0.01 * math.sin(tau * 1.6 * s).abs();
              } else {
                final double p = math.sin(tau * 2 * s).abs();
                sx = 1 + 0.03 * p;
                sy = 1 + 0.03 * p;
                angle = 0.02 * math.sin(tau * 4 * s);
              }
              break;
            }
          case BoyMood.waving:
            {
              angle = 0.06 * math.sin(tau * 5 * s);
              dy = -4 * math.sin(tau * 5 * s).abs();
              break;
            }
          case BoyMood.sleeping:
            {
              angle = 0.05 + 0.004 * math.sin(tau * s / 3);
              dy = 8 + 1.5 * math.sin(tau * s / 3);
              break;
            }
        }

        // Mouth opening while talking
        double m = 0;
        if (mood == BoyMood.speaking) {
          m = (math.sin(tau * 3.5 * s).abs() * (0.65 + 0.35 * math.sin(tau * 2.3 * s))).clamp(0.0, 1.0).toDouble();
        }
        final bool blinking = asleep || (s % 3.8) < 0.14;

        final double bw = _boardW * side;
        final double bh = _boardH * side;
        final double fs = _fontFor(full, bw, bh);

        final List<Widget> layers = <Widget>[
          Positioned.fill(
            child: Image.asset(
              'assets/boy.jpg',
              fit: BoxFit.fill,
              color: _tint,
              colorBlendMode: BlendMode.multiply,
              cacheWidth: 1000,
              filterQuality: FilterQuality.medium,
              errorBuilder: (BuildContext c, Object e, StackTrace? st) => Center(
                child: FittedBox(
                  child: SizedBox(
                    width: 280,
                    height: 320,
                    child: BoyAvatar(mood: mood, level: brain.level, onTap: brain.toggle),
                  ),
                ),
              ),
            ),
          ),
          if (blinking) _at(side, _eyeLX, _eyeY, side * 0.098, side * 0.080, const CustomPaint(painter: _BlinkPainter())),
          if (blinking) _at(side, _eyeRX, _eyeY, side * 0.098, side * 0.080, const CustomPaint(painter: _BlinkPainter())),
          if (m > 0.15)
            _at(side, _mouthX, _mouthY + 0.004 * m, side * 0.082, side * (0.012 + 0.036 * m),
                CustomPaint(painter: _MouthPainter(m))),
          _at(
            side,
            _boardCX,
            _boardCY,
            bw,
            bh,
            Center(
              child: Text(
                shown,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: fs, fontWeight: FontWeight.w700, height: 1.15, color: const Color(0xFF1B2340)),
              ),
            ),
          ),
          if (mood == BoyMood.listening)
            for (final double ex in <double>[_earLX, _earRX])
              for (int i = 0; i < 2; i++) _ring(side, ex, _earY, ((s * 0.9) + i * 0.5) % 1.0),
          if (mood == BoyMood.speaking) _sparkle(side, 0.80, 0.14, 0.0, s),
          if (mood == BoyMood.speaking) _sparkle(side, 0.68, 0.26, 0.35, s),
          if (mood == BoyMood.speaking) _sparkle(side, 0.92, 0.27, 0.7, s),
          if (mood == BoyMood.thinking)
            _at(
              side,
              0.76,
              0.17 + 0.012 * math.sin(tau * s),
              side * 0.12,
              side * 0.12,
              Center(
                child: Text('?', style: TextStyle(fontSize: side * 0.09, fontWeight: FontWeight.w800, color: neonViolet)),
              ),
            ),
          if (mood == BoyMood.waving)
            _at(
              side,
              0.82,
              0.17,
              side * 0.14,
              side * 0.14,
              Transform.rotate(
                angle: 0.5 * math.sin(tau * 2.5 * s),
                child: Center(child: Text('👋', style: TextStyle(fontSize: side * 0.09))),
              ),
            ),
          if (asleep)
            _at(
              side,
              0.74,
              0.16 - 0.015 * math.sin(tau * s / 2),
              side * 0.22,
              side * 0.12,
              Center(
                child: Text(
                  'Z z z',
                  style: TextStyle(fontSize: side * 0.065, fontWeight: FontWeight.w800, color: const Color(0xFF6B7280)),
                ),
              ),
            ),
        ];

        Widget picture = SizedBox(width: side, height: side, child: Stack(clipBehavior: Clip.none, children: layers));
        picture = Transform.translate(
          offset: Offset(dx * k, dy * k),
          child: Transform.rotate(
            angle: angle,
            alignment: const Alignment(0, 0.7),
            child: Transform.scale(scaleX: sx, scaleY: sy, alignment: const Alignment(0, 0.7), child: picture),
          ),
        );

        return GestureDetector(
          onTap: brain.toggle,
          child: Container(
            decoration: BoxDecoration(
              color: _tint,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: glow, blurRadius: 30, spreadRadius: 1)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  Positioned(left: offX, top: 0, width: side, height: side, child: picture),
                  if (asleep)
                    Positioned.fill(child: IgnorePointer(child: Container(color: const Color(0x880A1030)))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
