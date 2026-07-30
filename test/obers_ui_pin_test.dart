import 'dart:io';

import 'package:test/test.dart';

import '../tool/link_obers_ui.dart';

/// Every `pubspec.yaml` under `packages/` and `examples/`.
Iterable<File> _workspacePubspecs() sync* {
  for (final dir in ['packages', 'examples']) {
    final root = Directory(dir);
    if (!root.existsSync()) {
      continue;
    }
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final pubspec = File('${entity.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        yield pubspec;
      }
    }
  }
}

void main() {
  group('the obers_ui dependency pin', () {
    // Six refs to the same SHA across two pubspecs is a drift surface.
    // These tests are what make repeating it safe.
    final refPattern = RegExp(
      r'^\s*ref:\s*([0-9a-f]{40})\s*$',
      multiLine: true,
    );

    test('is declared by git ref, never by a path escaping the repo', () {
      for (final pubspec in _workspacePubspecs()) {
        final source = pubspec.readAsStringSync();
        expect(
          source,
          isNot(contains('path: ../../../obers_ui')),
          reason:
              '${pubspec.path} depends on obers_ui by a path above the repo '
              'root, which breaks a fresh clone and blocks publishing',
        );
      }
    });

    test('uses one identical full commit SHA everywhere', () {
      final refsByFile = <String, Set<String>>{};
      for (final pubspec in _workspacePubspecs()) {
        final source = pubspec.readAsStringSync();
        if (obersUiDependenciesOf(source).isEmpty) {
          continue;
        }
        refsByFile[pubspec.path] = refPattern
            .allMatches(source)
            .map((m) => m.group(1)!)
            .toSet();
      }

      expect(
        refsByFile,
        isNotEmpty,
        reason: 'no package declares an obers_ui dependency any more',
      );
      for (final entry in refsByFile.entries) {
        expect(
          entry.value,
          hasLength(1),
          reason: '${entry.key} pins more than one obers_ui commit',
        );
      }
      expect(
        refsByFile.values.expand((refs) => refs).toSet(),
        hasLength(1),
        reason: 'obers_ui is pinned to different commits across $refsByFile',
      );
    });
  });

  group('withObersUiBlock', () {
    test(
      'climbs out of a packages/<name> directory to the sibling checkout',
      () {
        final linked = withObersUiBlock(
          'dependency_overrides:\n',
          packages: const ['obers_ui', 'obers_ui_charts'],
          depthFromRoot: 2,
        );
        expect(linked, contains('    path: ../../../obers_ui\n'));
        expect(
          linked,
          contains('    path: ../../../obers_ui/packages/obers_ui_charts\n'),
        );
      },
    );

    test('preserves melos-managed overrides above it', () {
      const managed =
          '# melos_managed_dependency_overrides: beak_core\n'
          'dependency_overrides:\n'
          '  beak_core:\n'
          '    path: ../beak_core\n';
      final linked = withObersUiBlock(
        managed,
        packages: const ['obers_ui'],
        depthFromRoot: 2,
      );
      expect(linked, startsWith(managed));
      expect(linked, contains(blockMarker));
    });

    test('is idempotent, and unlink restores the original', () {
      const managed =
          '# melos_managed_dependency_overrides: beak_core\n'
          'dependency_overrides:\n'
          '  beak_core:\n'
          '    path: ../beak_core\n';
      final once = withObersUiBlock(
        managed,
        packages: const ['obers_ui'],
        depthFromRoot: 2,
      );
      final twice = withObersUiBlock(
        once,
        packages: const ['obers_ui'],
        depthFromRoot: 2,
      );
      expect(twice, once);
      expect(withoutObersUiBlock(twice), managed);
    });
  });

  group('obersUiDependenciesOf', () {
    test('finds declared obers_ui packages and ignores mentions', () {
      const source = '''
dependencies:
  beak_core:
    path: ../beak_core
  obers_ui:
    git:
      url: https://github.com/SimonErich/obers_ui.git
  obers_ui_charts:
    git:
      url: https://github.com/SimonErich/obers_ui.git
''';
      expect(obersUiDependenciesOf(source), ['obers_ui', 'obers_ui_charts']);
    });

    test('does not match a description that mentions obers_ui', () {
      const source = 'description: Widgets built on obers_ui.\n';
      expect(obersUiDependenciesOf(source), isEmpty);
    });
  });
}
