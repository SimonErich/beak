import 'package:flutter/services.dart';

/// Loads the typefaces the panel ships, so widget tests measure real text.
///
/// Without them every glyph is a square as wide as its font size, which makes
/// text roughly twice as wide as on screen and overflows layouts that fit.
Future<void> loadGabelFonts() async {
  for (final (family, asset) in const [
    ('Mona Sans', 'assets/fonts/MonaSans.ttf'),
    ('Mona Sans Extended', 'assets/fonts/MonaSansExtended.ttf'),
    ('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf'),
    ('JetBrains Mono Extended', 'assets/fonts/JetBrainsMonoExtended.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}
