import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

import '../../../support/test_models.dart';

/// The allowlist against a real SQL dialect, read off the statements the
/// adapter received: an undeclared column is never selected, not merely
/// dropped afterwards (the in-memory adapter cannot tell the two apart).
void main() {
  late SqliteAdapter sqlite;
  late InMemoryQueryLogger queries;
  late WormDataSource source;

  setUp(() async {
    sqlite = SqliteAdapter.memory();
    await sqlite.connect();
    await sqlite.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'categories',
        columns: [
          SchemaColumn(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            autoIncrement: true,
          ),
          SchemaColumn(name: 'name', type: ColumnType.text),
          SchemaColumn(
            name: 'secret',
            type: ColumnType.text,
            defaultValue: 'kept',
          ),
        ],
      ),
    );
    queries = InMemoryQueryLogger();
    source = WormDataSource(
      createTestRegistry(),
      adapter: LoggingAdapter(
        inner: sqlite,
        logger: queries,
        strictness: const StrictnessConfig(),
      ),
    );
  });
  tearDown(() => sqlite.disconnect());

  Iterable<String> statements() => queries.entries.map((e) => e.statement);

  test('create echoes the declared columns and leaves the rest', () async {
    final created = await source.create(
      'categories',
      BeakRecord.fromRow({'name': 'Optics'}),
    );

    expect(created.values.keys.toSet(), {'id', 'name'});
    final stored = await sqlite.selectOne(
      const QueryDescriptor(table: 'categories', columns: ['secret']),
    );
    expect(stored?['secret'], 'kept');
  });

  test('query and getOne SELECT the declared columns only', () async {
    await sqlite.insert(
      const InsertDescriptor(
        table: 'categories',
        values: {'id': 1, 'name': 'Optics', 'secret': 'shh'},
      ),
    );

    final page = await source.query(const BeakQuerySpec(table: 'categories'));
    final one = await source.getOne('categories', 1);

    expect(page.items.single.values.keys.toSet(), {'id', 'name'});
    expect(one?.values.keys.toSet(), {'id', 'name'});
    final selects = statements().where((sql) => sql.startsWith('SELECT'));
    expect(selects, isNotEmpty);
    expect(selects.where((sql) => sql.contains('secret')), isEmpty);
    expect(selects.where((sql) => sql.startsWith('SELECT *')), isEmpty);
  });
}
