import 'dart:io';

import '../support/beak_cli_internals.dart';
import 'package:test/test.dart';

/// `examples/quickstart` is documented as byte-identical to what
/// `beak create` produces — the 60-second claim, checked in.
///
/// This compares the scaffold's pure file list against the checked-in example,
/// so a change to either without the other fails here rather than in a
/// reader's terminal. The dependency block is exempt: the example resolves
/// Beak by path inside this repo, a real project resolves it by git.
void main() {
  final Directory example = Directory('../../examples/quickstart');

  group('examples/quickstart matches `beak create`', () {
    setUpAll(() {
      if (!example.existsSync()) {
        fail('examples/quickstart is missing — run `beak create quickstart`.');
      }
    });

    test('commits no lockfile, since its path overrides are local', () {
      // A generated app commits its pubspec.lock (the scaffold's .gitignore
      // no longer ignores it), but this copy resolves Beak by path and would
      // record this checkout's absolute paths in it.
      final Iterable<String> ignored = File(
        '../../.gitignore',
      ).readAsLinesSync().map((line) => line.trim());

      expect(ignored, contains('examples/quickstart/pubspec.lock'));
      expect(
        File('${example.path}/.gitignore').readAsStringSync(),
        isNot(contains('pubspec.lock')),
        reason: 'the scaffold commits the lockfile; only the repo ignores it',
      );
    });

    for (final file in [
      ...CreateCommand.scaffoldFiles('quickstart'),
      ...CreateCommand.postScaffoldFiles('quickstart'),
    ]) {
      // The scaffold paths are prefixed with the project name.
      final String relative = file.path.substring('quickstart/'.length);
      test(relative, () {
        final checkedIn = File('${example.path}/$relative');
        expect(
          checkedIn.existsSync(),
          isTrue,
          reason: '$relative is missing from examples/quickstart',
        );
        expect(
          _withoutDependencies(checkedIn.readAsStringSync()),
          _withoutDependencies(file.contents),
          reason:
              'examples/quickstart/$relative has drifted from the scaffold — '
              'run `beak create` into a temp dir and copy it over.',
        );
      });
    }
  });
}

/// [source] with any `dependencies:` block reduced to its keys.
///
/// The example depends on `path: ../../packages/beak`; a scaffolded project
/// depends on the git URL. Everything else about the pubspec must still match.
String _withoutDependencies(String source) {
  final lines = source.split('\n');
  final kept = <String>[];
  var inBlock = false;
  for (final line in lines) {
    if (line.startsWith('dependencies:') ||
        line.startsWith('dev_dependencies:')) {
      inBlock = true;
      kept.add(line);
      continue;
    }
    if (inBlock && line.isNotEmpty && !line.startsWith(' ')) {
      inBlock = false;
    }
    if (inBlock) {
      // Keep only top-level entries of the block, not how they resolve.
      if (RegExp(r'^  \S').hasMatch(line)) {
        kept.add(line);
      }
      continue;
    }
    kept.add(line);
  }
  return kept.join('\n');
}
