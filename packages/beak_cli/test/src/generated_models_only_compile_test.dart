import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/beak_cli_internals.dart';

/// A package of schema classes, prepared by `beak prepare` and nothing else,
/// resolves against `beak_core` alone, passes the repository's strict
/// analysis at Dart 3.12 and builds its registry.
///
/// This is the shape `examples/serverpod/bookshop_beak` has: pure Dart, shared
/// by a server and a Flutter admin, so a Flutter or `dart:io` import in what
/// `prepare` wrote would break one of them.
void main() {
  test(
    'a models-only package prepares, analyzes and registers its models',
    () async {
      final Directory repoRoot = Directory.current.parent.parent;
      final root = Directory.systemTemp.createTempSync('beak_models_only_');
      addTearDown(() => root.deleteSync(recursive: true));
      void write(String path, String source) {
        File(p.join(root.path, path))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(source);
      }

      write('pubspec.yaml', '''
name: shelf_models
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  beak_core:
    path: ${repoRoot.path}/packages/beak_core
dev_dependencies:
  lints: ^6.0.0
''');
      write(
        'analysis_options.yaml',
        File(p.join(repoRoot.path, 'analysis_options.yaml')).readAsStringSync(),
      );
      write('lib/models/author.dart', '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

import 'book.dart';

part 'author.beak.dart';

/// Someone whose books are on the shelf.
@Resource()
final class Author extends BeakSchema {
  /// The name printed on the cover.
  @Display()
  late final String name;

  /// Every book this author wrote.
  @HasMany(foreignKey: 'authorId')
  late final List<Book>? books;
}
''');
      write('lib/models/book.dart', '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

import 'author.dart';

part 'book.beak.dart';

/// A book on the shelf.
@Resource()
final class Book extends BeakSchema {
  /// The title.
  @Display()
  late final String title;

  /// Who wrote it.
  @BelongsTo()
  late final Author author;
}
''');
      write('bin/probe.dart', '''
import 'package:shelf_models/beak/registry.g.dart';
import 'package:shelf_models/models/author.dart';
import 'package:shelf_models/models/book.dart';

void main() {
  final registry = buildBeakRegistry();
  if (registry.all.length != 2 || beakModels.length != 2) {
    throw StateError('models missing from the registry');
  }
  final int nameLength = BookModel.author.name.key.length;
  if (nameLength != 4 || AuthorModel.fields.books.key != 'books') {
    throw StateError('typed references lost');
  }
}
''');

      final out = StringBuffer();
      final int? code = await createBeakRunner(
        BeakCliEnvironment(
          out: out,
          rootDirectory: root,
          now: () => DateTime.utc(2026, 7, 26, 12),
          probe: (host, port) async => false,
        ),
      ).run(['prepare']);
      expect(code, 0, reason: '$out');

      Future<ProcessResult> run(List<String> args) => Process.run(
        Platform.resolvedExecutable,
        args,
        workingDirectory: root.path,
      );
      final resolved = await run(['pub', 'get', '--offline']);
      expect(
        resolved.exitCode,
        0,
        reason: '${resolved.stdout}\n${resolved.stderr}',
      );
      final analyzed = await run([
        'analyze',
        '--fatal-infos',
        '--fatal-warnings',
      ]);
      expect(
        analyzed.exitCode,
        0,
        reason: '${analyzed.stdout}\n${analyzed.stderr}',
      );
      final executed = await run(['run', 'bin/probe.dart']);
      expect(
        executed.exitCode,
        0,
        reason: '${executed.stdout}\n${executed.stderr}',
      );
      final formatted = await run(['format', '--set-exit-if-changed', 'lib']);
      expect(
        formatted.exitCode,
        0,
        reason: '${formatted.stdout}\n${formatted.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
