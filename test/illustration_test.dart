import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/design/design.dart';

void main() {
  test('every illustration file exists and carries only the six placeholder colours', () {
    final allowed = {'#0E5A63', '#CFE6E8', '#C9731A', '#FBEFD9', '#F4F1EC', '#1C1A17'};
    for (final i in Illo.values) {
      final f = File(i.asset);
      expect(f.existsSync(), isTrue, reason: i.asset);
      final hexes = RegExp(r'#[0-9A-Fa-f]{6}').allMatches(f.readAsStringSync()).map((m) => m.group(0)!.toUpperCase()).toSet();
      expect(hexes.difference(allowed), isEmpty, reason: '${i.asset} uses colours outside the placeholder set');
    }
  });

  test('themeSvg swaps the placeholders for the theme colours in one pass', () {
    const svg = '<svg><rect fill="#0E5A63"/><rect fill="#cfe6e8"/><path stroke="#1C1A17"/></svg>';
    final out = themeSvg(svg, brand: const Color(0xFF112233), brandSoft: const Color(0xFF0E5A63), accent: Colors.red, accentSoft: Colors.blue, paper: Colors.white, ink: const Color(0xFF000001));
    expect(out, contains('fill="#112233"'));
    // brand-soft was mapped to the (placeholder-looking) value #0E5A63 and must NOT be re-substituted
    expect(out, contains('fill="#0E5A63"'));
    expect(out, contains('stroke="#000001"'));
  });
}
