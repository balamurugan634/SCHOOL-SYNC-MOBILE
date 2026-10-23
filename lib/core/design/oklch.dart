import 'dart:math' as math;
import 'dart:ui';

/// OKLCH colour maths (Bjorn Ottosson's OKLab), used to normalise a school's brand colour.
class Oklch {
  const Oklch(this.l, this.c, this.h);

  /// Lightness 0..1.
  final double l;

  /// Chroma, roughly 0..0.37.
  final double c;

  /// Hue in degrees.
  final double h;

  Oklch copyWith({double? l, double? c, double? h}) => Oklch(l ?? this.l, c ?? this.c, h ?? this.h);

  static double _toLinear(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  static double _fromLinear(double v) => v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;

  factory Oklch.fromColor(Color color) {
    final r = _toLinear(color.r), g = _toLinear(color.g), b = _toLinear(color.b);
    final l = math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3).toDouble();
    final m = math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3).toDouble();
    final s = math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3).toDouble();
    final okL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    final c = math.sqrt(a * a + bb * bb);
    var h = math.atan2(bb, a) * 180 / math.pi;
    if (h < 0) h += 360;
    return Oklch(okL, c, c < 1e-4 ? 0 : h);
  }

  /// The raw sRGB triple, possibly outside 0..1.
  List<double> _rgb() {
    final hr = h * math.pi / 180;
    final a = c * math.cos(hr), b = c * math.sin(hr);
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;
    final ll = l_ * l_ * l_, mm = m_ * m_ * m_, ss = s_ * s_ * s_;
    return [
      4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss,
      -1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss,
      -0.0041960863 * ll - 0.7034186147 * mm + 1.7076147010 * ss,
    ];
  }

  bool get inGamut => _rgb().every((v) => v >= -0.0005 && v <= 1.0005);

  /// An sRGB colour; chroma is reduced until the colour fits the gamut.
  Color toColor() {
    var o = this;
    var guard = 0;
    while (!o.inGamut && guard++ < 60) {
      o = o.copyWith(c: o.c * 0.96);
    }
    final rgb = o._rgb().map((v) => _fromLinear(v.clamp(0.0, 1.0))).toList();
    return Color.from(alpha: 1, red: rgb[0], green: rgb[1], blue: rgb[2]);
  }
}
