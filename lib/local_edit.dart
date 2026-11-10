import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Simple photo edits done on the phone: free, instant, no AI key needed.
class LocalEdit {
  static bool _has(String t, String pattern) => RegExp(pattern).hasMatch(t);

  static String _kind(String instruction) {
    final String t = instruction.toLowerCase();
    if (_has(t, r'black and white|black & white|grayscale|greyscale|monochrome|\bb&w\b|\bbw\b')) return 'gray';
    if (_has(t, r'sepia|vintage|old photo')) return 'sepia';
    if (_has(t, r'invert|negative')) return 'invert';
    if (_has(t, r'brighten|brighter|lighter|more light')) return 'bright';
    if (_has(t, r'darken|darker|less light')) return 'dark';
    if (_has(t, r'enhance|improve|vivid|contrast|hdr|sharper|better quality')) return 'enhance';
    if (_has(t, r'\bwarm')) return 'warm';
    if (_has(t, r'\bcool|\bcold')) return 'cool';
    if (_has(t, r'flip|mirror')) return 'flip';
    if (_has(t, r'rotate (left|anti)|counter')) return 'rotateLeft';
    if (_has(t, r'rotate|turn')) return 'rotate';
    return '';
  }

  static bool canHandle(String instruction) => _kind(instruction).isNotEmpty;

  static List<double>? _matrix(String kind) {
    switch (kind) {
      case 'gray':
        return <double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case 'sepia':
        return <double>[
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case 'invert':
        return <double>[
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ];
      case 'bright':
        return <double>[
          1, 0, 0, 0, 40,
          0, 1, 0, 0, 40,
          0, 0, 1, 0, 40,
          0, 0, 0, 1, 0,
        ];
      case 'dark':
        return <double>[
          1, 0, 0, 0, -40,
          0, 1, 0, 0, -40,
          0, 0, 1, 0, -40,
          0, 0, 0, 1, 0,
        ];
      case 'enhance':
        return <double>[
          1.2732, -0.1573, -0.0159, 0, -12.8,
          -0.0468, 1.1627, -0.0159, 0, -12.8,
          -0.0468, -0.1573, 1.3041, 0, -12.8,
          0, 0, 0, 1, 0,
        ];
      case 'warm':
        return <double>[
          1.08, 0, 0, 0, 6,
          0, 1, 0, 0, 0,
          0, 0, 0.9, 0, -6,
          0, 0, 0, 1, 0,
        ];
      case 'cool':
        return <double>[
          0.9, 0, 0, 0, -6,
          0, 1, 0, 0, 0,
          0, 0, 1.08, 0, 6,
          0, 0, 0, 1, 0,
        ];
    }
    return null;
  }

  /// Applies the edit and returns the new picture as PNG bytes.
  static Future<Uint8List> apply(Uint8List bytes, String instruction) async {
    final String kind = _kind(instruction);
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image src = frame.image;
    final int w = src.width;
    final int h = src.height;
    final bool turn = kind == 'rotate' || kind == 'rotateLeft';

    final ui.PictureRecorder rec = ui.PictureRecorder();
    final ui.Canvas c = ui.Canvas(rec);
    final ui.Paint p = ui.Paint()..filterQuality = ui.FilterQuality.high;
    final List<double>? m = _matrix(kind);
    if (m != null) p.colorFilter = ui.ColorFilter.matrix(m);
    if (kind == 'flip') {
      c.translate(w.toDouble(), 0.0);
      c.scale(-1.0, 1.0);
    } else if (kind == 'rotate') {
      c.translate(h.toDouble(), 0.0);
      c.rotate(math.pi / 2);
    } else if (kind == 'rotateLeft') {
      c.translate(0.0, w.toDouble());
      c.rotate(-math.pi / 2);
    }
    c.drawImage(src, ui.Offset.zero, p);
    final ui.Image out = await rec.endRecording().toImage(turn ? h : w, turn ? w : h);
    final ByteData? data = await out.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw Exception('could not save the edit');
    return data.buffer.asUint8List();
  }
}
