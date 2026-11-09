import 'package:flutter/services.dart';

import 'gabel_fonts.dart';

/// The bundled font files under `lib/fonts`, by the family that uses them.
final _fontFiles = <String, String>{
  gabelSansFamily: 'MonaSans.ttf',
  gabelSansFallbackFamilies.single: 'MonaSansExtended.ttf',
  gabelMonoFamily: 'JetBrainsMono.ttf',
  gabelMonoFallbackFamilies.single: 'JetBrainsMonoExtended.ttf',
};

/// Registers the bundled fonts with the engine, so a widget test or a golden
/// renders Mona Sans and JetBrains Mono.
///
/// `flutter test` does not load the fonts an app declares. Without them every
/// glyph is the test font's square, as wide as its font size, which makes text
/// roughly twice as wide as on screen and overflows layouts that fit. Call it
/// from `setUpAll`:
///
/// ```dart
/// setUpAll(loadGabelFonts);
/// ```
Future<void> loadGabelFonts() async {
  for (final MapEntry(key: family, value: file) in _fontFiles.entries) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('packages/beak_theme_gabel/lib/fonts/$file'));
    await loader.load();
  }
}
