import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';

void main() {
  group('BeakEmitters.format', () {
    const source =
        "import 'package:beak_core/beak_core.dart';\n"
        "import '../models/note.dart';\n"
        'void f() {}\n';

    test('formats for Dart 3.13 by default, which groups the imports', () {
      expect(BeakEmitters.defaultLanguageVersion, Version(3, 13, 0));
      expect(
        BeakEmitters.format(source),
        "import 'package:beak_core/beak_core.dart';\n"
        '\n'
        "import '../models/note.dart';\n"
        '\n'
        'void f() {}\n',
      );
    });

    test('formats for the language version it is given', () {
      expect(
        BeakEmitters.format(source, languageVersion: Version(3, 11, 0)),
        "import 'package:beak_core/beak_core.dart';\n"
        "import '../models/note.dart';\n"
        '\n'
        'void f() {}\n',
      );
    });
  });
}
