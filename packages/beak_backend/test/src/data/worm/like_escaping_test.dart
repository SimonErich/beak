import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

/// A table of names that differ only in the characters LIKE treats as
/// wildcards.
final class _NoteModel extends BeakModel {
  const _NoteModel();

  static const title = BeakScalarField<String>(
    model: _NoteModel(),
    column: _title,
  );

  static const BeakColumn _title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
  );

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    _title,
  ];
}

const List<String> _titles = [
  '50% off',
  '50 percent off',
  'a_b',
  'axb',
  r'C:\temp',
  r'C:Xtemp',
  'plain',
];

Future<void> _seed(DatabaseAdapter adapter) async {
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'notes',
      columns: [
        SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
        SchemaColumn(name: 'title', type: ColumnType.text),
      ],
    ),
  );
  await adapter.insertMany(
    InsertManyDescriptor(
      table: 'notes',
      rows: [
        for (final (index, title) in _titles.indexed)
          {'id': index + 1, 'title': title},
      ],
    ),
  );
}

void main() {
  const notes = _NoteModel();
  final registry = BeakModelRegistry()..register(notes);

  Future<void> wildcardsAreLiteral(BeakDataSource source) async {
    Future<List<String>> titles(BeakQuerySpec spec) async {
      final page = await source.query(spec);
      return [for (final record in page.items) '${record['title']?.raw}']
        ..sort();
    }

    Future<List<String>> where(BeakOperator operator, String value) => titles(
      notes.query(
        filter: BeakFieldFilter.forKey(
          'title',
          operator,
          BeakStringValue(value),
        ),
      ),
    );

    // contains, startsWith and endsWith
    expect(await where(BeakOperator.contains, '%'), ['50% off']);
    expect(await where(BeakOperator.contains, '_'), ['a_b']);
    expect(await where(BeakOperator.contains, r'\'), [r'C:\temp']);
    expect(await where(BeakOperator.startsWith, '50%'), ['50% off']);
    expect(await where(BeakOperator.startsWith, 'a_'), ['a_b']);
    expect(await where(BeakOperator.endsWith, r'\temp'), [r'C:\temp']);
    expect(await where(BeakOperator.endsWith, '_b'), ['a_b']);
    // plain text still matches case-insensitively as a substring
    expect(await where(BeakOperator.contains, 'PLAIN'), ['plain']);
    expect(await where(BeakOperator.contains, 'off'), [
      '50 percent off',
      '50% off',
    ]);

    // search
    Future<List<String>> search(String term) =>
        titles(notes.query().searching(term, [_NoteModel.title]));
    expect(await search('%'), ['50% off']);
    expect(await search('_'), ['a_b']);
    expect(await search(r'\'), [r'C:\temp']);
    expect(await search('50%'), ['50% off']);
    expect(await search('PLAIN'), ['plain']);

    // like / ilike operands are patterns, with backslash as their escape
    expect(await where(BeakOperator.like, r'50\% off'), ['50% off']);
    expect(await where(BeakOperator.like, '50% off'), [
      '50 percent off',
      '50% off',
    ]);
    expect(await where(BeakOperator.ilike, r'A\_B'), ['a_b']);
    expect(await where(BeakOperator.like, 'a_b'), ['a_b', 'axb']);
  }

  group('InMemory adapter', () {
    test('%, _ and backslash match literally', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await _seed(adapter);
      await wildcardsAreLiteral(WormDataSource(registry, adapter: adapter));
    });
  });

  group('SQLite adapter', () {
    test('%, _ and backslash match literally', () async {
      final adapter = SqliteAdapter.memory();
      await adapter.connect();
      addTearDown(adapter.disconnect);
      await _seed(adapter);
      await wildcardsAreLiteral(WormDataSource(registry, adapter: adapter));
    });
  });
}
