import 'package:test/test.dart';

import 'beak_schema_test.dart' show readSchemas;

const String _imports = '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';
''';

void main() {
  group('a table name', () {
    test('that is not an identifier is a prepare issue, not a crash in the '
        'migration it names', () {
      // The name goes into a file name, a class name and SQL, so a dash used
      // to reach the formatter and take `beak prepare` down with a syntax
      // error in a file nobody wrote.
      final (_, issues) = readSchemas({
        'item.dart':
            '''
$_imports
@Resource(table: 'order-items')
final class Item extends BeakSchema {
  late final String name;
}
''',
      });

      expect(issues.map((issue) => issue.message), [
        allOf(
          contains('Item'),
          contains('order-items'),
          contains('letters, digits and underscores'),
        ),
      ]);
      expect(issues.single.path, 'lib/models/item.dart');
    });

    test('with capitals is fine: a legacy table may have them', () {
      final (schemas, issues) = readSchemas({
        'item.dart':
            '''
$_imports
@Resource(table: 'OrderItems')
final class Item extends BeakSchema {
  late final String name;
}
''',
      });

      expect(issues, isEmpty);
      expect(schemas.single.table, 'OrderItems');
    });

    test('used by two schema classes is reported on the second', () {
      // The registry throws at boot when two models share a table, which is
      // long after `beak prepare` said everything was fine.
      final (_, issues) = readSchemas({
        'note.dart':
            '''
$_imports
@Resource()
final class Note extends BeakSchema {
  late final String title;
}
''',
        'memo.dart':
            '''
$_imports
@Resource(table: 'notes')
final class Memo extends BeakSchema {
  late final String title;
}
''',
      });

      expect(issues.map((issue) => issue.message), [
        allOf(
          contains('Memo'),
          contains('"notes"'),
          contains('Note'),
          contains('exactly one schema class'),
        ),
      ]);
      expect(issues.single.path, 'lib/models/note.dart');
    });
  });

  group('a class named like something the generated code uses', () {
    for (final name in const [
      'List',
      'String',
      'Future',
      'Function',
      'Enum',
      'DateTime',
      'Schema',
      'Migration',
      'BeakSchema',
      'Resource',
      'Column',
      'Display',
    ]) {
      test('$name is an issue, with the way round it', () {
        // Each of these makes the part file, or the create-table migration
        // written for it, fail to compile in a way that never mentions the
        // class name.
        final (_, issues) = readSchemas({
          'thing.dart':
              '''
$_imports
@Resource()
final class $name extends BeakSchema {
  late final String title;
}
''',
        });

        expect(issues.map((issue) => issue.message), [
          allOf(
            contains('$name cannot be the name of a schema class'),
            contains('@Resource(table:'),
          ),
        ]);
        expect(issues.single.path, 'lib/models/thing.dart');
      });
    }

    test('Object, Map and Type are fine: nothing generated uses them', () {
      for (final name in const ['Object', 'Map', 'Type', 'Record', 'Error']) {
        final (_, issues) = readSchemas({
          'thing.dart':
              '''
$_imports
@Resource()
final class $name extends BeakSchema {
  late final String title;
}
''',
        });

        expect(issues, isEmpty, reason: name);
      }
    });
  });

  group('a field named like a column the annotation adds', () {
    test('is an issue when timestamps: true adds created_at', () {
      final (_, issues) = readSchemas({
        'post.dart':
            '''
$_imports
@Resource(timestamps: true)
final class Post extends BeakSchema {
  late final String title;
  late final DateTime createdAt;
}
''',
      });

      expect(issues.map((issue) => issue.message), [
        allOf(
          contains('Post.createdAt'),
          contains('created_at'),
          contains('timestamps: true'),
        ),
      ]);
    });

    test('is an issue when softDeletes: true adds deleted_at', () {
      final (_, issues) = readSchemas({
        'post.dart':
            '''
$_imports
@Resource(softDeletes: true)
final class Post extends BeakSchema {
  late final String title;
  @Column(columnName: 'deleted_at')
  late final DateTime? removed;
}
''',
      });

      expect(issues.map((issue) => issue.message), [
        allOf(
          contains('Post.removed'),
          contains('deleted_at'),
          contains('softDeletes: true'),
        ),
      ]);
    });

    test('is the field\'s own column when the annotation adds none', () {
      final (schemas, issues) = readSchemas({
        'post.dart':
            '''
$_imports
@Resource()
final class Post extends BeakSchema {
  late final String title;
  late final DateTime createdAt;
}
''',
      });

      expect(issues, isEmpty);
      expect(
        schemas.single.columns.map((column) => column.columnKey),
        contains('created_at'),
      );
    });
  });
}
