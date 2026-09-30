import 'dart:io';

import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import 'prepare_command_test.dart' show environmentFor, projectWith, read;

const String _category = '''
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'category.beak.dart';

/// A grouping.
@Resource()
final class Category extends BeakSchema {
  /// Its name.
  @Display()
  @Column()
  late final String name;
}
''';

void main() {
  group('the generated line', () {
    test('counts the schema parts that did not change as files', () {
      final root = projectWith({'lib/models/category.dart': _category});
      runPrepare(environmentFor(root));

      final out = StringBuffer();
      final second = runPrepare(environmentFor(root, out: out));

      // One part beside the schema, and the six files of the wiring and the
      // entrypoints.
      expect(second.written, isEmpty);
      expect(second.unchanged, contains('lib/models/category.beak.dart'));
      expect(second.unchanged, hasLength(8));
      expect(out.toString(), contains('generated  up to date (8 files)'));
    });

    test('names the files written out of every file it considered', () {
      final root = projectWith({'lib/models/category.dart': _category});
      runPrepare(environmentFor(root));
      File('${root.path}/beak.yaml').writeAsStringSync('''
resources:
  categories:
    label: Kinds
''');

      final out = StringBuffer();
      final second = runPrepare(environmentFor(root, out: out));

      expect(second.written, ['lib/beak/panel.g.dart']);
      expect(out.toString(), contains('generated  1 of 8 files'));
    });

    test('counts what a models-only package considered, parts included', () {
      final root = projectWith({
        'lib/models/category.dart': _category.replaceAll(
          'package:beak/',
          'package:beak_core/',
        ),
        'pubspec.yaml': 'name: schemas\ndependencies:\n  beak_core: any\n',
      });
      runPrepare(environmentFor(root));

      final out = StringBuffer();
      runPrepare(environmentFor(root, out: out));

      expect(out.toString(), contains('generated  up to date (2 files)'));
    });
  });

  group('a refused run', () {
    test('says which schema parts it had already written', () {
      final root = projectWith({
        'lib/models/category.dart': _category,
        'beak.yaml': 'resources:\n  notez:\n    icon: bell\n',
      });
      final out = StringBuffer();

      final result = runPrepare(environmentFor(root, out: out));

      expect(result.isSuccess, isFalse);
      expect(result.written, ['lib/models/category.beak.dart']);
      expect(read(root, 'lib/models/category.beak.dart'), isNotEmpty);
      expect(
        File('${root.path}/lib/beak/registry.g.dart').existsSync(),
        isFalse,
      );
      final text = out.toString();
      expect(text, contains('Cannot generate: fix these first:'));
      expect(text, isNot(contains('—')));
      expect(
        text,
        contains(
          'Schema parts written before these were found: '
          'lib/models/category.beak.dart. Nothing else was generated.',
        ),
      );
    });

    test('adds no line when it had written nothing', () {
      final root = projectWith({
        'lib/models/note.dart': '''
import 'package:beak_core/beak_core.dart';

final class NoteModel extends BeakModel {
  NoteModel(this.table);
  @override
  final String table;
}
''',
      });
      final out = StringBuffer();

      runPrepare(environmentFor(root, out: out));

      expect(out.toString(), contains('Cannot generate: fix these first:'));
      expect(out.toString(), isNot(contains('Schema parts written')));
    });
  });

  group('an empty project', () {
    test('says there are no models yet, and succeeds', () {
      final root = projectWith({});
      final out = StringBuffer();

      final result = runPrepare(environmentFor(root, out: out));

      expect(result.isSuccess, isTrue);
      expect(result.exitCode, 0);
      expect(
        out.toString(),
        contains(
          'no models yet: add a @Resource class under lib/, or run '
          '`beak make:resource Product`, then `beak prepare` again',
        ),
      );
    });

    test('stays quiet once a model exists', () {
      final root = projectWith({'lib/models/category.dart': _category});
      final out = StringBuffer();

      runPrepare(environmentFor(root, out: out));

      expect(out.toString(), isNot(contains('no models yet')));
    });
  });
}
