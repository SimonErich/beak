import 'dart:convert';

import 'package:beak_theme_gabel/beak_theme_gabel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodio_adminpanel/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the panel selects the Gabel theme from the package', () {
    expect(foodioPanel().theme, isA<GabelTheme>());
  });

  test('the fonts reach the app without the app declaring any', () async {
    final manifest = jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    );
    final families = switch (manifest) {
      final List<Object?> entries => [
        for (final entry in entries)
          if (entry case {'family': final String family}) family,
      ],
      _ => const <String>[],
    };

    expect(
      families,
      containsAll([
        gabelSansFamily,
        ...gabelSansFallbackFamilies,
        gabelMonoFamily,
        ...gabelMonoFallbackFamilies,
      ]),
    );
  });

  test('the font licences reach the licence page', () async {
    LicenseRegistry.reset();
    GabelTheme.resetLicenseRegistrationForTesting();

    GabelTheme().registerLicenses();
    final entries = await LicenseRegistry.licenses.toList();

    expect(entries.map((entry) => entry.packages.single), [
      'Mona Sans',
      'JetBrains Mono',
    ]);
    LicenseRegistry.reset();
  });
}
