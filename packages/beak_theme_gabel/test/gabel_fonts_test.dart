import 'dart:io';

import 'package:beak_theme_gabel/beak_theme_gabel.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _prefix = 'packages/beak_theme_gabel/';

/// The `flutter:` section of the package pubspec.
YamlMap _flutterSection() {
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync());
  if (pubspec case {'flutter': final YamlMap section}) return section;
  throw StateError('pubspec.yaml has no flutter section');
}

/// The `family` and `asset` entries under `flutter: fonts:`.
({Set<String> families, Set<String> assets}) _declaredFonts() {
  final families = <String>{};
  final assets = <String>{};
  if (_flutterSection() case {'fonts': final YamlList fonts}) {
    for (final font in fonts) {
      if (font case {
        'family': final String family,
        'fonts': final YamlList faces,
      }) {
        families.add(family);
        for (final face in faces) {
          if (face case {'asset': final String asset}) assets.add(asset);
        }
      }
    }
  }
  return (families: families, assets: assets);
}

/// Every family a text style names, fallbacks included.
Iterable<String> _familiesOf(TextStyle style) => [
  ?style.fontFamily,
  ...?style.fontFamilyFallback,
];

void main() {
  final declared = _declaredFonts();
  final resolvable = {
    for (final family in declared.families) '$_prefix$family',
  };
  final theme = GabelTheme();

  test('the pubspec declares the four bundled families', () {
    expect(declared.families, {
      'Mona Sans',
      'Mona Sans Extended',
      'JetBrains Mono',
      'JetBrains Mono Extended',
    });
  });

  test('every declared font file exists', () {
    for (final asset in declared.assets) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
    expect(declared.assets, hasLength(4));
  });

  test('the licence texts are declared as assets and exist', () {
    final section = _flutterSection();
    final assets = switch (section['assets']) {
      final YamlList list => [for (final entry in list) '$entry'],
      _ => const <String>[],
    };

    expect(assets, [
      'lib/fonts/MonaSans-OFL.txt',
      'lib/fonts/JetBrainsMono-OFL.txt',
    ]);
    for (final asset in assets) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  test('the exported family constants use the package form and resolve', () {
    final constants = [
      gabelSansFamily,
      ...gabelSansFallbackFamilies,
      gabelMonoFamily,
      ...gabelMonoFallbackFamilies,
    ];

    expect(constants, everyElement(startsWith(_prefix)));
    expect(resolvable, containsAll(constants));
  });

  for (final (name, data) in [('light', theme.light), ('dark', theme.dark)]) {
    test('every family the $name theme references resolves', () {
      final styles = <TextStyle>[
        for (final role in [
          data.textTheme.display,
          data.textTheme.h1,
          data.textTheme.h2,
          data.textTheme.h3,
          data.textTheme.h4,
          data.textTheme.body,
          data.textTheme.bodyStrong,
          data.textTheme.small,
          data.textTheme.smallStrong,
          data.textTheme.tiny,
          data.textTheme.caption,
          data.textTheme.code,
          data.textTheme.overline,
          data.textTheme.link,
        ])
          role,
        ?data.components.button?.textStyle,
        ?data.components.table?.cellTextStyle,
        ?data.components.sidebar?.textStyle,
        ?data.components.badge?.textStyle,
      ];

      final referenced = styles.expand(_familiesOf).toSet();

      expect(referenced, isNotEmpty);
      expect(referenced, everyElement(startsWith(_prefix)));
      expect(resolvable, containsAll(referenced));
    });
  }

  test('the code style is set in JetBrains Mono', () {
    expect(theme.light.textTheme.code.fontFamily, gabelMonoFamily);
    expect(
      theme.light.textTheme.code.fontFamilyFallback,
      gabelMonoFallbackFamilies,
    );
    expect(theme.light.textTheme.body.fontFamily, gabelSansFamily);
  });

  test('the numeric roles name no font of their own', () {
    for (final style in [
      gabelNumericBodyStyle,
      gabelNumericMediumStyle,
      gabelNumericCaptionStyle,
      gabelNumericMetricStyle,
    ]) {
      expect(style.fontFamily, isNull);
    }
    expect(_familiesOf(gabelHeading2Style), everyElement(startsWith(_prefix)));
  });
}
