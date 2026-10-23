import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

const String _bookPath = 'M22 8H28A4 4 0 0 1 32 12V44A4 4 0 0 1 28 48H22A16 16 0 0 1 6 32V24A16 16 0 0 1 22 8Z';
const String _syncPath = 'M38 16H42A16 16 0 0 1 58 32V40A16 16 0 0 1 42 56H38A4 4 0 0 1 34 52V20A4 4 0 0 1 38 16Z';

String _hex(Color c) {
  String h(double v) => (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

/// The SchoolSync mark (design/brand/mark.svg): two open pages sliding past each other, a book and a sync.
/// [color] is the book, [accent] the second page (defaults to the product amber). The product mark is not
/// re-themed per school: a school's own logo is user content.
class SchoolSyncMark extends StatelessWidget {
  const SchoolSyncMark({super.key, this.size = 64, this.color, this.accent});

  final double size;
  final Color? color;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final book = color ?? t.brandDefault;
    final sync = accent ?? t.accent;
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
        '<path d="$_bookPath" fill="${_hex(book)}"/><path d="$_syncPath" fill="${_hex(sync)}"/></svg>';
    return SvgPicture.string(svg, width: size, height: size, semanticsLabel: 'SchoolSync');
  }
}

/// The inverse mark (paper + amber) on a flat tile in the product teal: the launcher-icon look.
class BrandTile extends StatelessWidget {
  const BrandTile({super.key, required this.color, this.onColor = const Color(0xFFF4F1EC), this.size = 40});

  final Color color;
  final Color onColor;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * .22)),
    alignment: Alignment.center,
    child: SchoolSyncMark(size: size * .66, color: onColor),
  );
}
