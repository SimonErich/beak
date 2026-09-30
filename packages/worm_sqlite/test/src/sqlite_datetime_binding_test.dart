import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

/// SQLite keeps an instant as text and compares that text, so every instant
/// has to be written the same way: a local time written without its offset
/// sorts two hours away from the UTC value that names the same moment.
void main() {
  late SqliteAdapter adapter;

  setUp(() async {
    adapter = SqliteAdapter.memory();
    await adapter.connect();
    await adapter.rawExecute(
      'CREATE TABLE events (id INTEGER PRIMARY KEY, at TEXT)',
      const [],
    );
  });

  tearDown(() => adapter.disconnect());

  Future<Object?> stored(int id) async {
    final rows = await adapter.rawQuery('SELECT at FROM events WHERE id = ?', [
      id,
    ]);
    return rows.single['at'];
  }

  test('a local instant is written as the UTC instant it names', () async {
    final local = DateTime(2026, 6, 1, 12, 30, 45, 123);
    await adapter.insert(
      InsertDescriptor(table: 'events', values: {'id': 1, 'at': local}),
    );
    expect(await stored(1), local.toUtc().toIso8601String());
    expect(await stored(1), endsWith('Z'));
  });

  test('a UTC instant is written unchanged', () async {
    final utc = DateTime.utc(2026, 6, 1, 12, 30, 45, 123);
    await adapter.insert(
      InsertDescriptor(table: 'events', values: {'id': 2, 'at': utc}),
    );
    expect(await stored(2), '2026-06-01T12:30:45.123Z');
  });

  test('a filter on a local instant finds the row stored as UTC', () async {
    final utc = DateTime.utc(2026, 6, 1, 12);
    await adapter.insert(
      InsertDescriptor(table: 'events', values: {'id': 3, 'at': utc}),
    );
    final sameMomentLocal = utc.toLocal();
    final rows = await adapter.select(
      QueryDescriptor(
        table: 'events',
        where: const Field<DateTime>('at').eq(sameMomentLocal),
      ),
    );
    expect(rows, hasLength(1));
  });

  test('an update binds the same way', () async {
    await adapter.insert(
      const InsertDescriptor(table: 'events', values: {'id': 4, 'at': null}),
    );
    final local = DateTime(2026, 6, 1, 8);
    await adapter.update(
      UpdateDescriptor(
        table: 'events',
        values: {'at': local},
        where: const Field<int>('id').eq(4),
      ),
    );
    expect(await stored(4), local.toUtc().toIso8601String());
  });
}
