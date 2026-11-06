import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';

/// Voice waveform that reacts to the microphone level.
class WaveBars extends StatefulWidget {
  const WaveBars({super.key, required this.level, required this.active});
  final double level;
  final bool active;

  @override
  State<WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends State<WaveBars> with SingleTickerProviderStateMixin {
  late final AnimationController _t;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: AnimatedBuilder(
        animation: _t,
        builder: (BuildContext context, Widget? child) {
          final List<Widget> bars = <Widget>[];
          for (int i = 0; i < 28; i++) {
            final double wave = (0.5 + 0.5 * math.sin(i * 0.6 + _t.value * 4 * math.pi)).abs();
            final double extra = widget.active ? 46.0 * widget.level * wave : 0.0;
            final double barHeight = 5.0 + extra;
            bars.add(
              Container(
                width: 4,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: Color.lerp(neonCyan, neonViolet, i / 28),
                ),
              ),
            );
          }
          return Row(mainAxisAlignment: MainAxisAlignment.center, children: bars);
        },
      ),
    );
  }
}
