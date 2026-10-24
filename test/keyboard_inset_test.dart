import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/design/keyboard_inset.dart';

void main() {
  group('KeyboardInset.compute', () {
    test('window not resized by the keyboard: pad by the full keyboard height', () {
      expect(KeyboardInset.compute(inset: 300, height: 800, fullHeight: 800), 300);
    });

    test('window already shrunk by the whole keyboard: nothing more to pad (the double-count bug)', () {
      expect(KeyboardInset.compute(inset: 300, height: 500, fullHeight: 800), 0);
    });

    test('window shrunk by part of it (navigation bar kept): pad only the rest', () {
      expect(KeyboardInset.compute(inset: 300, height: 524, fullHeight: 800), 24);
    });

    test('unknown full height falls back to the reported inset; no keyboard means no padding', () {
      expect(KeyboardInset.compute(inset: 280, height: 700, fullHeight: 0), 280);
      expect(KeyboardInset.compute(inset: 0, height: 700, fullHeight: 800), 0);
    });

    test('never negative and never more than the keyboard', () {
      expect(KeyboardInset.compute(inset: 100, height: 300, fullHeight: 800), 0);
      expect(KeyboardInset.compute(inset: 100, height: 900, fullHeight: 800), 100);
    });
  });

  group('KeyboardInset.of on a real view', () {
    Future<double> padWith(WidgetTester tester, {required double windowHeight, required double keyboard}) async {
      double? pad;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(400, windowHeight);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Builder(builder: (c) {
        pad = KeyboardInset.of(c);
        return const SizedBox();
      })));
      return pad!;
    }

    testWidgets('keyboard overlays the app: the sheet pads by the keyboard height', (tester) async {
      addTearDown(tester.view.reset);
      expect(await padWith(tester, windowHeight: 800, keyboard: 0), 0);
      expect(await padWith(tester, windowHeight: 800, keyboard: 320), 320);
    });

    testWidgets('keyboard already shrank the window (edge-to-edge adjustResize): no second helping', (tester) async {
      addTearDown(tester.view.reset);
      expect(await padWith(tester, windowHeight: 800, keyboard: 0), 0);
      expect(await padWith(tester, windowHeight: 480, keyboard: 320), 0);
      expect(await padWith(tester, windowHeight: 800, keyboard: 0), 0);
    });
  });
}
