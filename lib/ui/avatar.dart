import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'widgets.dart' show cyan, violet;

/// Animated character avatar for Penta (replaces the old orb on the home screen).
/// Coordinates are in source-image pixels (the picture is 1280x720).
const String kAvatarAsset = 'assets/images/penta_avatar.jpg';

const _view = Rect.fromLTWH(320, 0, 640, 720);
const _imgRect = Rect.fromLTWH(0, 0, 1280, 720);
const _neck = Offset(640, 262);
const _headRect = Rect.fromLTRB(440, 0, 840, 300);
const _mouth = Offset(640, 231);
const _eyeL = Offset(599, 165);
const _eyeR = Offset(680, 162);
const _handRect = Rect.fromLTRB(520, 428, 680, 613);
const _wrist = Offset(540, 585);
const _fingerRect = Rect.fromLTRB(600, 452, 682, 545);
const _knuckle = Offset(600, 482);
const _bflyRect = Rect.fromLTRB(596, 315, 702, 440);
const _bflyBody = Offset(618, 408);
const _bflyCenter = Offset(655, 370);

class _Pose {
  double t = 0, energy = 0, mouth = 0, blink = 0, poke = 0;
  Offset touch = Offset.zero;
  Color skin = const Color(0xFFA48BC2);
  Color cloth = const Color(0xFF0E0B24);
}

class PentaAvatar extends StatefulWidget {
  const PentaAvatar({
    super.key,
    required this.active,
    required this.speaking,
    required this.thinking,
    required this.level,
    required this.onTap,
  });
  final bool active, speaking, thinking;
  final double level;
  final VoidCallback onTap;
  @override
  State<PentaAvatar> createState() => _PentaAvatarState();
}

class _PentaAvatarState extends State<PentaAvatar> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);
  final _pose = _Pose();
  final _rng = math.Random();
  ui.Image? _img;
  double _last = 0, _blinkAt = 1.5, _blinkStart = -1, _pokeAt = -10;
  Offset _touchTarget = Offset.zero;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = createTicker(_tick)..start();
  }

  Future<void> _load() async {
    final data = await rootBundle.load(kAvatarAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final img = (await codec.getNextFrame()).image;
    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes != null) {
      Color px(int x, int y) {
        var r = 0, g = 0, b = 0, n = 0;
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final i = ((y + dy) * img.width + (x + dx)) * 4;
            r += bytes.getUint8(i);
            g += bytes.getUint8(i + 1);
            b += bytes.getUint8(i + 2);
            n++;
          }
        }
        return Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
      }

      _pose.skin = px(612, 205); // cheek color for eyelids / mouth patch
      _pose.cloth = px(575, 380); // dark uniform behind the butterfly
    }
    if (mounted) setState(() => _img = img);
  }

  void _tick(Duration d) {
    final t = d.inMicroseconds / 1e6;
    final dt = (t - _last).clamp(0.0, 0.1);
    _last = t;
    final p = _pose, w = widget;

    final targetEnergy = w.speaking ? 1.0 : (w.active ? 0.7 : (w.thinking ? 0.35 : 0.0));
    p.energy += (targetEnergy - p.energy) * math.min(1, dt * 4);

    double m = 0;
    if (w.speaking) {
      final syl = math.sin(t * 9.5).abs() * (0.55 + 0.45 * math.sin(t * 3.1 + 1.2).abs());
      m = (0.1 + 0.9 * math.pow(syl, 0.8)) * (math.sin(t * 1.3) > -0.85 ? 1.0 : 0.15);
    } else if (w.active) {
      m = (w.level * 0.95).clamp(0.0, 1.0);
    }
    p.mouth += (m - p.mouth) * math.min(1, dt * 18);

    if (_blinkStart < 0 && t >= _blinkAt) _blinkStart = t;
    if (_blinkStart >= 0) {
      final k = (t - _blinkStart) / 0.17;
      if (k >= 1) {
        _blinkStart = -1;
        p.blink = 0;
        _blinkAt = t + 1.8 + _rng.nextDouble() * 3.5;
      } else {
        p.blink = math.sin(math.pi * k);
      }
    }

    p.touch += (_touchTarget - p.touch) * math.min(1, dt * 6);
    p.poke = math.max(0, 1 - (t - _pokeAt) / 1.3);
    p.t = t;
    _clock.value = t;
  }

  void _drag(Offset local, Size s) {
    _touchTarget = Offset(
      ((local.dx / s.width) * 2 - 1).clamp(-1.0, 1.0),
      ((local.dy / s.height) * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _img?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        var w = c.maxWidth;
        var h = w * _view.height / _view.width;
        if (h > c.maxHeight) {
          h = c.maxHeight;
          w = h * _view.width / _view.height;
        }
        final size = Size(w, h);
        return Center(
          child: GestureDetector(
            onTapDown: (_) {
              _pokeAt = _pose.t;
              _blinkStart = _pose.t;
            },
            onTap: widget.onTap,
            onPanUpdate: (d) => _drag(d.localPosition, size),
            onPanEnd: (_) => _touchTarget = Offset.zero,
            onPanCancel: () => _touchTarget = Offset.zero,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: w,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (widget.speaking || widget.active ? cyan : violet).withOpacity(0.45),
                    blurRadius: widget.speaking || widget.active ? 42 : 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _img == null
                    ? const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()))
                    : CustomPaint(size: size, painter: _AvatarPainter(_img!, _pose, _clock)),
              ),
            ),
          ),
        );
      });
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.img, this.p, Listenable repaint) : super(repaint: repaint);
  final ui.Image img;
  final _Pose p;
  final _paint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  void _rotAbout(Canvas c, Offset o, double a) {
    c.translate(o.dx, o.dy);
    c.rotate(a);
    c.translate(-o.dx, -o.dy);
  }

  /// Draws a region of the picture with soft elliptical edges so moved pieces blend in.
  void _crop(Canvas c, Rect r, {double inner = 0.55}) {
    c.saveLayer(r.inflate(1), Paint());
    c.drawImageRect(img, r, r, _paint);
    final k = r.height / r.width;
    final m = Matrix4.translationValues(r.center.dx, r.center.dy, 0)
      ..multiply(Matrix4.diagonal3Values(1, k, 1))
      ..multiply(Matrix4.translationValues(-r.center.dx, -r.center.dy, 0));
    final sh = ui.Gradient.radial(
      r.center,
      r.width / 2,
      const [Colors.white, Colors.white, Colors.transparent],
      [0, inner, 1],
      TileMode.clamp,
      m.storage,
    );
    c.drawRect(r, Paint()..shader = sh..blendMode = BlendMode.dstIn);
    c.restore();
  }

  /// Hair sways in horizontal strips; the lower the strand, the more it moves.
  void _hair(Canvas c, Rect clip, double phase, double amp, double minW) {
    c.save();
    c.clipRect(clip);
    for (double y = clip.top; y < clip.bottom; y += 3) {
      final w = math.max(minW, math.pow(y / 270, 1.3).toDouble());
      final dx = amp * w * (math.sin(y * 0.03 - p.t * 2.1 + phase) + 0.5 * math.sin(y * 0.071 - p.t * 3.4 + phase * 1.7));
      final dy = 0.35 * amp * w * math.sin(p.t * 1.6 + phase);
      final src = Rect.fromLTWH(clip.left - 12, y, clip.width + 24, 3.6);
      c.drawImageRect(img, src, src.shift(Offset(dx, dy)), _paint);
    }
    c.restore();
  }

  void _glow(Canvas c, Offset o, double r, Color col, double a) {
    if (a <= 0.001) return;
    c.drawCircle(
      o,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(o, r, [col.withOpacity(a.clamp(0.0, 1.0)), col.withOpacity(0)]),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = p.t, e = p.energy;
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / _view.width, size.height / _view.height);
    canvas.translate(-_view.left, -_view.top);

    // ---- whole body: breathing, slow sway, touch parallax
    canvas.translate(640, 720);
    canvas.scale(1.025 + 0.008 * math.sin(t * 1.5) + 0.012 * p.poke + 0.006 * e);
    canvas.rotate(0.004 * math.sin(t * 0.9) + p.touch.dx * 0.006);
    canvas.translate(-640 - p.touch.dx * 9, -720 - p.touch.dy * 5);

    // base picture without the head (head is drawn separately below)
    canvas.drawRect(const Rect.fromLTRB(440, 0, 840, 240), Paint()..color = const Color(0xFF05040C));
    canvas.save();
    canvas.clipPath(Path.combine(
      PathOperation.difference,
      Path()..addRect(_imgRect),
      Path()..addRect(const Rect.fromLTRB(440, 0, 840, 238)),
    ));
    canvas.drawImage(img, Offset.zero, _paint);
    canvas.restore();

    // ---- hand + fingers
    final handA = 0.035 * math.sin(t * 1.3) + 0.03 * math.sin(t * 2.9 + 1) + e * 0.055 * math.sin(t * 3.6) + p.poke * 0.05 * math.sin(t * 14);
    final handT = Offset(2.5 * math.sin(t * 0.9), 3 * math.sin(t * 1.1) - e * 4 * math.sin(t * 2.0).abs());
    Offset handMove(Offset pt) {
      final v = pt - _wrist;
      final c = math.cos(handA), s = math.sin(handA);
      return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c) + _wrist + handT - pt;
    }

    canvas.save();
    canvas.translate(handT.dx, handT.dy);
    _rotAbout(canvas, _wrist, handA);
    _crop(canvas, _handRect);
    canvas.save();
    _rotAbout(canvas, _knuckle, 0.06 * math.sin(t * 3.1) * (0.5 + e) + 0.02 * math.sin(t * 7.3));
    _crop(canvas, _fingerRect);
    canvas.restore();
    canvas.restore();

    // ---- butterfly
    final bMove = handMove(const Offset(640, 430));
    final boost = 0.6 + e + p.poke * 1.2;
    final drift = Offset(
          (8 * math.sin(t * 0.9) + 4 * math.sin(t * 2.3)) * boost,
          (6 * math.sin(t * 1.3) + 3 * math.sin(t * 3.1)) * boost,
        ) +
        bMove;
    final flapHz = 14 + 14 * e + 10 * p.poke;
    final flap = 0.62 + 0.38 * math.cos(t * flapHz);

    // hide the still wings so there is no ghost under the moving butterfly
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(652, 368), width: 90, height: 104),
      Paint()
        ..color = p.cloth
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    _glow(canvas, _bflyCenter + drift, 90 + 20 * e, violet, 0.20 + 0.10 * math.sin(t * 3) + 0.15 * e);
    _glow(canvas, _bflyCenter + drift, 55, cyan, 0.10 + 0.12 * e);

    canvas.save();
    canvas.translate(drift.dx, drift.dy - 3 * math.cos(t * flapHz));
    _rotAbout(canvas, _bflyBody, 0.06 * math.sin(t * 1.7) + 0.04 * math.sin(t * flapHz * 0.5));
    canvas.translate(_bflyBody.dx, _bflyBody.dy);
    canvas.scale(flap, 1 + 0.05 * math.sin(t * flapHz));
    canvas.translate(-_bflyBody.dx, -_bflyBody.dy);
    _crop(canvas, _bflyRect, inner: 0.6);
    canvas.restore();

    // sparkles rising from the butterfly
    for (var i = 0; i < 14; i++) {
      final ph = (t * (0.22 + 0.1 * e) + i / 14) % 1.0;
      final o = _bflyCenter +
          drift +
          Offset(math.sin(i * 2.4 + t * 0.8) * (14 + 70 * ph), 25 - ph * (110 + 40 * e));
      final a = math.sin(math.pi * ph) * (0.55 + 0.4 * e);
      canvas.drawCircle(
        o,
        1.1 + 1.6 * (i % 3) / 2,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = (i.isEven ? Colors.white : cyan).withOpacity(a.clamp(0.0, 1.0)),
      );
    }

    // ---- head: nod, tilt, hair, blink, mouth
    final headA = 0.02 * math.sin(t * 0.8) + 0.012 * math.sin(t * 2.1 + 0.5) + e * 0.016 * math.sin(t * 3.3) + p.touch.dx * 0.05 + p.poke * 0.03 * math.sin(t * 9);
    final headT = Offset(
      p.touch.dx * 4,
      1.6 * math.sin(t * 1.5 + 0.3) + e * 2.2 * math.sin(t * 5.2).abs() + p.touch.dy * 3,
    );

    canvas.save();
    canvas.translate(headT.dx, headT.dy);
    _rotAbout(canvas, _neck, headA);
    canvas.saveLayer(_headRect.inflate(30), Paint());

    // static part of the head (everything except the swaying hair)
    const left = Rect.fromLTRB(440, 118, 565, 275);
    const right = Rect.fromLTRB(718, 118, 840, 275);
    const top = Rect.fromLTRB(440, 0, 840, 118);
    canvas.save();
    canvas.clipPath(Path.combine(
      PathOperation.difference,
      Path()..addRect(_headRect),
      Path()
        ..addRect(left)
        ..addRect(right)
        ..addRect(top),
    ));
    canvas.drawImageRect(img, _headRect, _headRect, _paint);
    canvas.restore();

    final amp = 1.6 + 3.2 * e + 2.4 * p.poke + p.touch.dx.abs() * 2;
    _hair(canvas, left, 0, amp, 0.05);
    _hair(canvas, right, 2.0, amp, 0.05);
    _hair(canvas, top, 4.1, amp * 0.55, 0.12);

    // eyes: glow + blink
    final closed = p.blink;
    for (final eye in [_eyeL, _eyeR]) {
      _glow(canvas, eye, 14, cyan, 0.22 * e * (1 - closed));
      if (closed > 0.04) {
        final lidTop = eye.dy - 9, h = 18 * closed;
        canvas.drawOval(Rect.fromLTRB(eye.dx - 21, lidTop, eye.dx + 21, lidTop + h + 2), Paint()..color = p.skin);
        canvas.drawLine(
          Offset(eye.dx - 19, lidTop + h),
          Offset(eye.dx + 19, lidTop + h),
          Paint()
            ..color = const Color(0xFF1A1240)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // mouth
    final m = p.mouth;
    if (m > 0.04) {
      final cover = (m * 6).clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: _mouth.translate(0, -1), width: 50, height: 12), const Radius.circular(6)),
        Paint()
          ..color = p.skin.withOpacity(cover)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      final wide = 11 + 15 * (0.5 + 0.5 * math.sin(t * 6.1)) * m + 4 * m;
      final open = 2 + 11 * m;
      final mouthRect = Rect.fromCenter(center: _mouth.translate(0, open / 2 - 1), width: wide, height: open);
      canvas.drawOval(mouthRect, Paint()..color = const Color(0xFF2A1233));
      canvas.drawOval(
        mouthRect.deflate(open * 0.18).shift(Offset(0, open * 0.18)),
        Paint()..color = const Color(0xFF7A3550).withOpacity(0.55 * cover),
      );
      canvas.drawArc(
        Rect.fromCenter(center: _mouth.translate(0, -1), width: wide + 3, height: 4),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF3B2150).withOpacity(0.8 * cover),
      );
    }

    // fade the bottom of the head into the collar so the neck seam is invisible
    canvas.drawRect(
      _headRect.inflate(30),
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(0, _headRect.top - 30),
          Offset(0, _headRect.bottom + 30),
          const [Colors.white, Colors.white, Colors.transparent, Colors.transparent],
          const [0, 0.745, 0.865, 1],
        ),
    );
    canvas.restore(); // head layer
    canvas.restore(); // head transform
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) => true;
}
