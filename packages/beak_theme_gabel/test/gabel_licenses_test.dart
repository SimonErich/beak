import 'dart:io';

import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_theme_gabel/beak_theme_gabel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<LicenseEntry>> _registered() => LicenseRegistry.licenses.toList();

String _text(LicenseEntry entry) =>
    entry.paragraphs.map((paragraph) => paragraph.text).join(' ');

List<String> _words(String text) =>
    text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LicenseRegistry.reset();
    GabelTheme.resetLicenseRegistrationForTesting();
    BeakTheme.resetLicenseRegistrationForTesting();
  });
  tearDown(LicenseRegistry.reset);

  test('registers the OFL text of both font families', () async {
    GabelTheme().registerLicenses();

    final entries = await _registered();

    expect(entries.map((entry) => entry.packages.single), [
      'Mona Sans',
      'JetBrains Mono',
    ]);
    expect(_text(entries.first), contains('The Mona Sans Project Authors'));
    expect(_text(entries.last), contains('The JetBrains Mono Project Authors'));
    for (final entry in entries) {
      expect(_text(entry), contains('SIL OPEN FONT LICENSE Version 1.1'));
    }
  });

  test('registers once however many themes are built', () async {
    GabelTheme().registerLicenses();
    GabelTheme().registerLicenses();
    GabelTheme()
      ..registerLicenses()
      ..registerLicenses();

    expect(await _registered(), hasLength(2));
  });

  test('the registered text is the text of the shipped files', () async {
    GabelTheme().registerLicenses();
    final entries = await _registered();

    for (final (entry, file) in [
      (entries.first, 'lib/fonts/MonaSans-OFL.txt'),
      (entries.last, 'lib/fonts/JetBrainsMono-OFL.txt'),
    ]) {
      expect(
        _words(_text(entry)),
        _words(File(file).readAsStringSync()),
        reason: file,
      );
    }
  });
}
