import 'dart:io';

import 'package:test/test.dart';

import '../tool/check_examples.dart';

/// A directory holding [packages], each a name and whether it has a pubspec.
Directory _treeWith(Map<String, bool> packages) {
  final root = Directory.systemTemp.createTempSync('beak_examples_');
  addTearDown(() => root.deleteSync(recursive: true));
  final examples = Directory('${root.path}/$examplesDir')
    ..createSync(recursive: true);
  for (final MapEntry(key: name, value: hasPubspec) in packages.entries) {
    final directory = Directory('${examples.path}/$name')..createSync();
    if (hasPubspec) {
      File('${directory.path}/pubspec.yaml').writeAsStringSync('name: $name\n');
    }
  }
  return root;
}

void main() {
  group('examplesIn', () {
    test('finds every directory that is a package, in a stable order', () {
      // Listing order is up to the filesystem, which commonly returns
      // creation order or its reverse. Neither `beta, alpha, gamma` nor
      // `gamma, alpha, beta` is sorted, so without the sort this fails.
      final root = _treeWith({'beta': true, 'alpha': true, 'gamma': true});

      expect(examplesIn(root).map((d) => d.path.split('/').last), <String>[
        'alpha',
        'beta',
        'gamma',
      ]);
    });

    test('skips a directory with no pubspec', () {
      // `build/`, `.dart_tool/` and a half-deleted example are not examples,
      // and running the CLI in one would fail for the wrong reason.
      final root = _treeWith({'alpha': true, 'scratch': false});

      expect(examplesIn(root).map((d) => d.path.split('/').last), <String>[
        'alpha',
      ]);
    });

    test('returns nothing when there is no examples directory', () {
      final root = Directory.systemTemp.createTempSync('beak_no_examples_');
      addTearDown(() => root.deleteSync(recursive: true));

      expect(examplesIn(root), isEmpty);
    });
  });

  group('ExampleHealth', () {
    test('is healthy when nothing failed, warnings notwithstanding', () {
      // A checkout without Flutter's web scaffold, or without a running
      // Postgres, warns — and neither is a defect in the example.
      const health = ExampleHealth(
        name: 'alpha',
        failures: [],
        warnings: ['no web/ scaffold'],
      );

      expect(health.isHealthy, isTrue);
    });

    test('is unhealthy as soon as one check failed', () {
      const health = ExampleHealth(
        name: 'alpha',
        failures: ['generated files out of date (0 missing, 2 stale)'],
        warnings: [],
      );

      expect(health.isHealthy, isFalse);
    });
  });

  group('the repository itself', () {
    test('has the documented examples', () {
      // The gate walks all packages; keep the documented entry points present.
      expect(
        examplesIn(Directory.current).map((d) => d.path.split('/').last),
        containsAll(<String>[
          'clean_beak_config',
          'foodio-adminpanel',
          'quickstart',
        ]),
      );
    });

    test('points at a CLI entrypoint that exists', () {
      expect(File(beakCli).existsSync(), isTrue, reason: '$beakCli is missing');
    });
  });
}
