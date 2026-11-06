import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';

class RingPainter extends CustomPainter {
  const RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 8;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0x0022D3EE), neonCyan, neonViolet, Color(0x008B5CF6)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 5);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Big circular Penta button with a continuously rotating glowing ring.
class PentaOrb extends StatefulWidget {
  const PentaOrb({super.key, required this.listening, required this.level, required this.onTap});
  final bool listening;
  final double level;
  final VoidCallback onTap;

  @override
  State<PentaOrb> createState() => _PentaOrbState();
}

class _PentaOrbState extends State<PentaOrb> with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_spin, _pulse]),
        builder: (BuildContext context, Widget? child) {
          final double boost = widget.listening ? 0.18 * widget.level : 0.0;
          final double scale = 1.0 + 0.04 * _pulse.value + boost;
          final double speed = widget.listening ? 2.0 : 1.0;
          final Color glow = widget.listening ? neonCyan : neonViolet;
          return SizedBox(
            width: 270,
            height: 270,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _spin.value * 2 * math.pi * speed,
                  child: const CustomPaint(size: Size(270, 270), painter: RingPainter()),
                ),
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFF67E8F9), neonViolet, Color(0xFF1E1B4B)],
                        stops: [0.0, 0.55, 1.0],
                      ),
                      boxShadow: [BoxShadow(color: glow.withAlpha(140), blurRadius: 40, spreadRadius: 4)],
                    ),
                    child: const Center(
                      child: Text(
                        'PENTA',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 6, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
