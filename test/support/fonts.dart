import 'package:flutter/services.dart';

/// flutter_test renders every font as boxy "Ahem" glyphs (about twice as wide as real text), which makes
/// layout tests report overflows that never happen on a phone. Load the app's real fonts instead.
Future<void> loadAppFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await family('Inter', ['Inter-400.ttf', 'Inter-500.ttf', 'Inter-600.ttf']);
  await family('Manrope', ['Manrope-var.ttf']);
}

/// The Material icon font, which flutter_test also leaves out (icons would be hollow squares in a picture).
Future<void> loadIconFont() async {
  final loader = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await loader.load();
}
