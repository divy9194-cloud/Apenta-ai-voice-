import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../assistant_brain.dart';
import '../local_store.dart';
import 'boy_avatar.dart';
import 'common.dart';

/// Floating golden light dust, like the sunlight in the picture.
class _MotesPainter extends CustomPainter {
  const _MotesPainter(this.t, this.boost);
  final double t;
  final double boost;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 16; i++) {
      final double seed = i * 12.9898;
      final double px = math.sin(seed) * 0.5 + 0.5;
      final double speed = 0.015 + 0.01 * (i % 5) / 5;
      final double py = 1.0 - ((t * speed + (math.sin(seed * 1.7) * 0.5 + 0.5)) % 1.0);
      final double x = (px + 0.03 * math.sin(t * 0.8 + i)) * size.width;
      final double y = py * size.height;
      final double a = (0.25 + 0.45 * ((math.sin(t * 1.5 + i) + 1) / 2)) * (0.6 + 0.4 * boost);
      final double r = 1.5 + (i % 3) + 2 * boost;
      final int alpha = (a * 255).round().clamp(0, 255).toInt();
      canvas.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFFFFE9B0).withAlpha(alpha));
    }
  }

  @override
  bool shouldRepaint(covariant _MotesPainter oldDelegate) => true;
}

/// Penta's character: your picture, with gestures and the reply in a speech bubble.
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
  String _pathSeen = '';
  bool _pathOk = false;

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
    if (t.length <= 150) return t;
    final int cut = t.lastIndexOf(' ', 147);
    return '${t.substring(0, cut > 60 ? cut : 147)}…';
  }

  Widget _bars(double s, bool active) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            width: 4,
            height: active ? 6.0 + 14.0 * math.sin(2 * math.pi * 3 * s + i * 1.3).abs() : 5.0,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(color: neonCyan, borderRadius: BorderRadius.circular(2)),
          ),
      ],
    );
  }

  Widget _fallback(BoyMood mood, AssistantBrain brain) {
    return Center(
      child: FittedBox(
        child: SizedBox(
          width: 280,
          height: 320,
          child: BoyAvatar(mood: mood, level: brain.level, onTap: brain.toggle),
        ),
      ),
    );
  }

  /// The picture you chose in the Photo editor, or the built-in boy.jpg.
  Widget _pictureImage(BoyMood mood, AssistantBrain brain) {
    final String path = LocalStore.prefs.getString('avatarPath') ?? '';
    if (path != _pathSeen) {
      _pathSeen = path;
      _pathOk = path.isNotEmpty && File(path).existsSync();
    }
    if (_pathOk) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.5),
        cacheWidth: 1000,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (BuildContext c, Object e, StackTrace? st) => _fallback(mood, brain),
      );
    }
    return Image.asset(
      'assets/boy.jpg',
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.5),
      cacheWidth: 1000,
      filterQuality: FilterQuality.medium,
      errorBuilder: (BuildContext c, Object e, StackTrace? st) => _fallback(mood, brain),
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

    // What is shown in the bubble
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
      final int n = ((nowMs - _typeStartMs) / 1000.0 * 22).floor();
      if (n < full.length) shown = full.substring(0, n < 0 ? 0 : n);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints cs) {
        final double w = cs.maxWidth;
        final double h = cs.maxHeight;
        final double u = math.min(w, h) / 100;

        // Body gestures
        double dx = 0;
        double dy = 0;
        double angle = 0;
        double zoom = 1;
        if (mood == BoyMood.idle) {
          zoom = 1 + 0.006 * math.sin(tau * s / 3.2);
          angle = 0.004 * math.sin(tau * s / 5);
          dy = 0.4 * u * math.sin(tau * s / 3.2);
        } else if (mood == BoyMood.listening) {
          angle = 0.03 + 0.006 * math.sin(tau * s / 1.6);
          zoom = 1.02;
          dx = -0.5 * u;
        } else if (mood == BoyMood.thinking) {
          angle = -0.025;
          dy = 0.5 * u * math.sin(tau * s / 1.5);
        } else if (mood == BoyMood.speaking) {
          final int g = (s / 2.4).floor() % 4;
          zoom = 1 + 0.004 * math.sin(tau * 6 * s);
          if (g == 0) {
            dy = 1.1 * u * math.sin(tau * 2.4 * s);
            angle = 0.01 * math.sin(tau * 1.2 * s);
          } else if (g == 1) {
            angle = 0.035 * math.sin(tau * 1.3 * s);
            dx = 1.2 * u * math.sin(tau * 1.3 * s);
          } else if (g == 2) {
            dy = -1.8 * u * math.sin(tau * 1.6 * s).abs();
          } else {
            zoom += 0.025 * math.sin(tau * 2 * s).abs();
            angle = 0.015 * math.sin(tau * 4 * s);
          }
        } else if (mood == BoyMood.waving) {
          angle = 0.045 * math.sin(tau * 5 * s);
          dy = -0.8 * u * math.sin(tau * 5 * s).abs();
        } else {
          angle = 0.045;
          dy = 1.5 * u + 0.3 * u * math.sin(tau * s / 3);
        }

        Color borderColor = Colors.white12;
        Color glow = neonViolet.withAlpha(70);
        if (mood == BoyMood.listening) {
          final int a = (110 + 60 * math.sin(tau * s / 1.2)).round();
          borderColor = neonCyan.withAlpha(200);
          glow = neonCyan.withAlpha(a);
        } else if (mood == BoyMood.speaking) {
          borderColor = neonViolet.withAlpha(200);
          glow = neonViolet.withAlpha(150);
        }

        final double boost = mood == BoyMood.speaking ? 1.0 : (mood == BoyMood.listening ? 0.5 : 0.0);

        final Widget picture = Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: angle,
            alignment: const Alignment(0, 0.8),
            child: Transform.scale(
              scale: 1.1 * zoom,
              alignment: const Alignment(0, 0.3),
              child: _pictureImage(mood, brain),
            ),
          ),
        );

        return GestureDetector(
          onTap: brain.toggle,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A1030),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [BoxShadow(color: glow, blurRadius: 30, spreadRadius: 1)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  picture,
                  IgnorePointer(child: CustomPaint(painter: _MotesPainter(s, boost))),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: h * 0.45,
                    child: const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x0005060F), Color(0xDD05060F)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (asleep) Positioned.fill(child: IgnorePointer(child: Container(color: const Color(0x990A1030)))),
                  if (asleep)
                    Positioned(
                      top: h * 0.08 - 5 * math.sin(tau * s / 2),
                      right: w * 0.10,
                      child: const Text(
                        'Z z z',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white70),
                      ),
                    ),
                  if (mood == BoyMood.thinking)
                    Positioned(
                      top: h * 0.06 + 6 * math.sin(tau * s),
                      right: w * 0.12,
                      child: const Text('?', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, color: neonViolet)),
                    ),
                  if (mood == BoyMood.waving)
                    Positioned(
                      top: h * 0.07,
                      left: w * 0.10,
                      child: const Text('✨', style: TextStyle(fontSize: 34)),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0A1030),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: neonViolet.withAlpha(150)),
                      ),
                      child: Row(
                        children: [
                          _bars(s, mood == BoyMood.speaking),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              shown,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, height: 1.25, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
