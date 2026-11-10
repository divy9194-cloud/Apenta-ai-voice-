import 'package:flutter/material.dart';

const Color cyan = Color(0xFF22D3EE);
const Color violet = Color(0xFF8B5CF6);

class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.level,
    required this.active,
  });

  final double level;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bars = <Widget>[];
    for (int i = 0; i < 18; i++) {
      final wave = active
          ? (0.25 + ((i % 5) * 0.16) + (level * (1.2 + (i % 3) * 0.2)))
          : 0.12 + (i % 4) * 0.04;
      bars.add(
        Container(
          width: 5,
          height: 22 + wave * 46,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cyan,
                violet,
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: bars,
      ),
    );
  }
}

class DevCredit extends StatelessWidget {
  const DevCredit({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 18, top: 8),
      child: Text(
        'Developed by Divyanshu Kumar',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
