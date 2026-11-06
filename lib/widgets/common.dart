import 'package:flutter/material.dart';

const Color neonCyan = Color(0xFF22D3EE);
const Color neonViolet = Color(0xFF8B5CF6);
const Color panelColor = Color(0xFF151A2E);

class CreditLine extends StatelessWidget {
  const CreditLine({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Text(
        'Developed by Divyanshu Kumar',
        style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1),
      ),
    );
  }
}
