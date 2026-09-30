import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

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
  group('transitive local UI resolution', () {
    test('links all coordinated UI packages at the application root', () {
      expect(
        obersUiOverridesFor(
          'dependencies:\n  beak:\n    path: ../../packages/beak\n',
        ),
        obersUiPackagePaths.keys.toList(),
      );
      expect(
        obersUiOverridesFor(
          'dependencies:\n  beak_frontend:\n    path: ../beak_frontend\n',
        ),
        obersUiPackagePaths.keys.toList(),
      );
    });
    test('does not introduce Flutter into pure Dart packages', () {
      expect(
        obersUiOverridesFor(
          'dependencies:\n  beak_core:\n    path: ../beak_core\n',
        ),
        isEmpty,
      );
    });
    test('reads dependencies only, not an executable named like a panel', () {
      expect(
        obersUiOverridesFor(
          'name: beak_cli\n'
          'executables:\n  beak: beak\n'
          'dependencies:\n  beak_core:\n    path: ../beak_core\n',
        ),
        isEmpty,
      );
      expect(
        obersUiOverridesFor(
          'executables:\n  beak: beak\n'
          'dev_dependencies:\n  beak_frontend:\n    path: ../beak_frontend\n',
        ),
        obersUiPackagePaths.keys.toList(),
      );
    });
  });
  group('pub workspace roots', () {
    const root = '''
name: _
publish_to: none

workspace:
  - bookshop_client
  # beak members
  - bookshop_server   # the server
  - bookshop_admin

dependency_overrides:
  something:
    path: ../something
''';

    test('lists the members a workspace root names', () {
      expect(workspaceMembersOf(root), [
        'bookshop_client',
        'bookshop_server',
        'bookshop_admin',
      ]);
    });

    test('a package that is not a workspace root has no members', () {
      expect(
        workspaceMembersOf('name: beak_core\ndependencies:\n  meta: ^1.0.0\n'),
        isEmpty,
      );
    });

    test('links the root when any member is a panel', () {
      expect(
        obersUiOverridesForWorkspace([
          'dependencies:\n  serverpod: 4.0.3\n',
          'dependencies:\n  beak:\n    path: ../../../packages/beak\n',
        ]),
        obersUiPackagePaths.keys.toList(),
      );
    });

    test('leaves a workspace without a panel member alone', () {
      expect(
        obersUiOverridesForWorkspace([
          'dependencies:\n  serverpod: 4.0.3\n',
          'dependencies:\n  beak_core:\n    path: ../beak_core\n',
        ]),
        isEmpty,
      );
    });
  });

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

  group('unlinking', () {
    test('leaves no bare dependency_overrides header behind', () {
      final linked = withObersUiBlock(
        withDependencyOverridesHeader(''),
        packages: const ['obers_ui'],
        depthFromRoot: 2,
      );
      expect(linked, startsWith('dependency_overrides:\n'));
      // Nothing else was in the file, so nothing is left: the caller deletes
      // an empty file rather than keeping a header with no entries.
      expect(withoutObersUiBlock(linked).trim(), isEmpty);
    });

    test('keeps the header when other overrides still need it', () {
      const kept =
          'dependency_overrides:\n'
          '  beak_core:\n'
          '    path: ../beak_core\n';
      final linked = withObersUiBlock(
        kept,
        packages: const ['obers_ui'],
        depthFromRoot: 2,
      );
      expect(withoutObersUiBlock(linked), kept);
    });
  });

  group('the melos scripts', () {
    final Object? melos = loadYaml(File('melos.yaml').readAsStringSync());

    /// The `run:` string of the melos script [name].
    String runOf(String name) {
      if (melos is YamlMap) {
        final Object? scripts = melos['scripts'];
        final Object? script = scripts is YamlMap ? scripts[name] : null;
        final Object? run = script is YamlMap ? script['run'] : null;
        if (run is String) {
          return run;
        }
      }
      throw StateError('melos.yaml has no script "$name" with a run string');
    }

    test('link-obers-ui links and then bootstraps', () {
      expect(runOf('link-obers-ui'), contains('tool/link_obers_ui.dart'));
      expect(runOf('link-obers-ui'), isNot(contains('--unlink')));
      expect(runOf('link-obers-ui'), endsWith('melos bootstrap'));
    });

    test('unlink-obers-ui unlinks and then bootstraps', () {
      // Melos 6.3.3 appends `-- --unlink` to the end of the whole script, so
      // `melos run link-obers-ui -- --unlink` reaches `melos bootstrap` and
      // never the tool. Unlinking needs a script of its own.
      expect(
        runOf('unlink-obers-ui'),
        'dart run tool/link_obers_ui.dart --unlink && melos bootstrap',
      );
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
