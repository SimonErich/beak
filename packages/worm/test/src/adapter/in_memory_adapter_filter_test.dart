import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/operator.dart';
import 'package:worm/src/query/predicate.dart';
import 'package:worm/src/query/predicate_tree.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';

const _name = StringField('name');
const _id = ComparableField<int>('id');
const _age = ComparableField<int>('age');
const _note = Field<String?>('note');

Future<InMemoryAdapter> _adapter() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'people'),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'people',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Alice', 'age': 30, 'note': 'hi'},
        <String, Object?>{'id': 2, 'name': 'Bob', 'age': 25, 'note': null},
        <String, Object?>{'id': 3, 'name': 'Carol', 'age': 40, 'note': 'ok'},
        <String, Object?>{'id': 4, 'name': 'Dave', 'age': 35, 'note': null},
        <String, Object?>{'id': 5, 'name': 'alice', 'age': 28, 'note': 'low'},
      ],
    ),
  );
  return adapter;
}

Future<List<Map<String, Object?>>> _where(
  InMemoryAdapter adapter,
  PredicateTree tree,
) async => adapter.select(QueryDescriptor(table: 'people', where: tree));

Set<Object?> _names(List<Map<String, Object?>> rows) =>
    rows.map((r) => r['name']).toSet();

void main() {
  group('scalar equality', () {
    test('eq matches the exact value', () async {
      final adapter = await _adapter();
      final rows = await _where(adapter, _name.eq('Bob'));
      expect(_names(rows), <String>{'Bob'});
    });

    test('neq excludes the exact value', () async {
      final adapter = await _adapter();
      final rows = await _where(adapter, _name.neq('Bob'));
      expect(_names(rows), <String>{'Alice', 'Carol', 'Dave', 'alice'});
    });
  });

  group('relational operators', () {
    test('gt, gte, lt, lte filter numerically', () async {
      final adapter = await _adapter();
      expect(_names(await _where(adapter, _age.gt(30))), {'Carol', 'Dave'});
      expect(_names(await _where(adapter, _age.gte(30))), {
        'Alice',
        'Carol',
        'Dave',
      });
      expect(_names(await _where(adapter, _age.lt(30))), {'Bob', 'alice'});
      expect(_names(await _where(adapter, _age.lte(30))), {
        'Alice',
        'Bob',
        'alice',
      });
    });
  });

  group('range operators', () {
    test('between is inclusive on both bounds', () async {
      final adapter = await _adapter();
      final rows = await _where(adapter, _age.between(28, 35));
      expect(_names(rows), <String>{'Alice', 'Dave', 'alice'});
    });

    test('notBetween excludes the inclusive range', () async {
      final adapter = await _adapter();
      final rows = await _where(adapter, _age.notBetween(28, 35));
      expect(_names(rows), <String>{'Bob', 'Carol'});
    });
  });

  group('list membership', () {
    test('inList returns members', () async {
      final adapter = await _adapter();
      final rows = await _where(adapter, _id.inList(<int>[1, 3, 99]));
      expect(rows.map((r) => r['id']).toSet(), <int>{1, 3});
    });

    test('notInList excludes listed members', () async {
      final adapter = await _adapter();
      final rows = await _where(adapter, _id.notInList(<int>[1, 3]));
      expect(rows.map((r) => r['id']).toSet(), <int>{2, 4, 5});
    });
  });

  group('pattern operators', () {
    test('like is case-sensitive', () async {
      final adapter = await _adapter();
      final rows = await _where(adapter, _name.like('A%'));
      expect(_names(rows), <String>{'Alice'});
    });

    test('ilike is case-insensitive', () async {
      final adapter = await _adapter();
      final rows = await _where(adapter, _name.ilike('a%'));
      expect(_names(rows), <String>{'Alice', 'alice'});
    });

    test('notLike excludes matches', () async {
      final adapter = await _adapter();
      final rows = await _where(adapter, _name.notLike('A%'));
      expect(_names(rows), <String>{'Bob', 'Carol', 'Dave', 'alice'});
    });
  });

  group('patterns over text with line breaks', () {
    test('a % spans a line break and a _ stands for one, as in SQL', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'people'),
      );
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'people',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'name': 'first\nsecond'},
            <String, Object?>{'id': 2, 'name': 'first second'},
            <String, Object?>{'id': 3, 'name': 'other'},
          ],
        ),
      );
      expect(_names(await _where(adapter, _name.like('%second'))), <String>{
        'first\nsecond',
        'first second',
      });
      expect(
        _names(await _where(adapter, _name.like('first_second'))),
        <String>{'first\nsecond', 'first second'},
      );
    });
  });

  group('escaped patterns', () {
    const escapeCharacter = r'\';

    Future<InMemoryAdapter> patternsAdapter() async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'people'),
      );
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'people',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'name': 'a%b'},
            <String, Object?>{'id': 2, 'name': 'axb'},
            <String, Object?>{'id': 3, 'name': 'a_b'},
            <String, Object?>{'id': 4, 'name': r'a\b'},
            <String, Object?>{'id': 5, 'name': 'A%B'},
            <String, Object?>{'id': 6, 'name': r'ab\'},
          ],
        ),
      );
      return adapter;
    }

    PredicateTree leaf(Operator operator, String pattern, {String? escape}) =>
        LeafNode(
          Predicate(
            fieldName: 'name',
            operator: operator,
            value: pattern,
            escape: escape,
          ),
        );

    test('an escaped wildcard matches only itself', () async {
      final adapter = await patternsAdapter();
      Future<Set<Object?>> match(Operator operator, String pattern) async =>
          _names(
            await _where(
              adapter,
              leaf(operator, pattern, escape: escapeCharacter),
            ),
          );
      expect(await match(Operator.like, r'a\%b'), <String>{'a%b'});
      expect(await match(Operator.like, r'a\_b'), <String>{'a_b'});
      expect(await match(Operator.like, r'a\\b'), <String>{r'a\b'});
      expect(await match(Operator.ilike, r'a\%b'), <String>{'a%b', 'A%B'});
      expect(await match(Operator.notLike, r'a\%b'), <String>{
        'axb',
        'a_b',
        r'a\b',
        'A%B',
        r'ab\',
      });
    });

    test('an unescaped wildcard still matches anything', () async {
      final adapter = await patternsAdapter();
      final rows = await _where(
        adapter,
        leaf(Operator.like, 'a%b', escape: escapeCharacter),
      );
      expect(_names(rows), <String>{'a%b', 'axb', 'a_b', r'a\b'});
    });

    test('a trailing escape character stands for itself', () async {
      final adapter = await patternsAdapter();
      final rows = await _where(
        adapter,
        leaf(Operator.like, r'a\b\', escape: escapeCharacter),
      );
      expect(_names(rows), <String>{r'ab\'});
    });

    test('without an escape character a backslash is ordinary', () async {
      final adapter = await patternsAdapter();
      final rows = await _where(adapter, leaf(Operator.like, r'a\b'));
      expect(_names(rows), <String>{r'a\b'});
    });
  });

  group('null operators', () {
    test('isNull returns rows whose column is null', () async {
      final adapter = await _adapter();
      final rows = await _where(adapter, _note.isNull());
      expect(_names(rows), <String>{'Bob', 'Dave'});
    });

    test('isNotNull returns non-null rows', () async {
      final adapter = await _adapter();
      final rows = await _where(adapter, _note.isNotNull());
      expect(_names(rows), <String>{'Alice', 'Carol', 'alice'});
    });
  });

  group('composition', () {
    test('AND of two leaves matches both', () async {
      final adapter = await _adapter();
      final tree = _age.gte(30).and(_note.isNotNull());
      final rows = await adapter.select(
        QueryDescriptor(table: 'people', where: tree),
      );
      expect(_names(rows), <String>{'Alice', 'Carol'});
    });

    test('OR of two leaves matches either', () async {
      final adapter = await _adapter();
      final tree = _name.eq('Bob').or(_name.eq('Carol'));
      final rows = await adapter.select(
        QueryDescriptor(table: 'people', where: tree),
      );
      expect(_names(rows), <String>{'Bob', 'Carol'});
    });

    test('NOT negates a leaf', () async {
      final adapter = await _adapter();
      final tree = _age.gte(30).not();
      final rows = await adapter.select(
        QueryDescriptor(table: 'people', where: tree),
      );
      expect(_names(rows), <String>{'Bob', 'alice'});
    });
  });
}
