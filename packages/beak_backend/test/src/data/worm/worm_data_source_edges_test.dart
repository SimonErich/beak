import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

import '../../../support/api_models.dart';

/// Requests a real client makes that the data source has to answer properly
/// rather than hand to the database as written.
void main() {
  late SqliteAdapter adapter;
  late WormDataSource source;

  setUp(() async {
    adapter = SqliteAdapter.memory();
    await adapter.connect();
    for (final descriptor in apiSchema) {
      await adapter.executeSchema(
        SchemaDescriptor.createTable(
          table: descriptor.table,
          columns: [
            for (final column in descriptor.columns)
              SchemaColumn(
                name: column.name,
                type: column.type,
                isPrimaryKey: column.isPrimaryKey,
                nullable: !column.isPrimaryKey,
              ),
          ],
        ),
      );
    }
    source = WormDataSource(
      createApiRegistry(),
      adapter: adapter,
      now: () => DateTime(2026, 1, 1, 12),
    );
    await source.create(
      'labels',
      BeakRecord.fromRow({'id': 'l1', 'name': 'first'}),
    );
    await source.create(
      'notes',
      BeakRecord.fromRow({'id': 'n1', 'title': 'Note'}),
    );
  });

  tearDown(() => adapter.disconnect());

  group('an update with nothing to write', () {
    test('answers the record as it is instead of an empty UPDATE', () async {
      final updated = await source.update(
        'labels',
        'l1',
        const BeakRecord(values: {}),
      );
      expect(updated['name'], const BeakStringValue('first'));
    });

    test('treats a body that only repeats the key the same way', () async {
      final updated = await source.update(
        'labels',
        'l1',
        BeakRecord.fromRow({'id': 'l1'}),
      );
      expect(updated['name'], const BeakStringValue('first'));
    });

    test('is still a 404 for a record that is not there', () {
      expect(
        () => source.update('labels', 'ghost', const BeakRecord(values: {})),
        throwsA(isA<BeakNotFoundException>()),
      );
    });
  });

  group('attaching to an owner that is not there', () {
    test('a pivot link is refused and nothing is written', () async {
      await expectLater(
        () => source.attach('notes', 'ghost', 'labels', ['l1']),
        throwsA(isA<BeakNotFoundException>()),
      );
      expect(
        await adapter.select(const QueryDescriptor(table: 'note_label')),
        isEmpty,
      );
    });

    test('a has-many link is refused and nothing is written', () async {
      await adapter.rawExecute(
        "INSERT INTO comments (id, note_id, message) VALUES ('c1', NULL, 'hi')",
        const [],
      );
      await expectLater(
        () => source.attach('notes', 'ghost', 'comments', ['c1']),
        throwsA(isA<BeakNotFoundException>()),
      );
      final rows = await adapter.select(
        const QueryDescriptor(table: 'comments'),
      );
      expect(rows.single['note_id'], isNull);
    });

    test('a trashed owner is still there: it can be restored', () async {
      await source.delete('notes', 'n1');
      await source.attach('notes', 'n1', 'labels', ['l1']);
      expect(
        await adapter.select(const QueryDescriptor(table: 'note_label')),
        hasLength(1),
      );
    });

    test('an owner that exists still attaches', () async {
      await source.attach('notes', 'n1', 'labels', ['l1']);
      expect(
        await adapter.select(const QueryDescriptor(table: 'note_label')),
        hasLength(1),
      );
    });
  });

  group('the soft-delete marker', () {
    test('is a UTC instant whatever zone the clock reads in', () async {
      await source.delete('notes', 'n1');
      final rows = await adapter.select(
        const QueryDescriptor(table: 'notes', columns: ['deleted_at']),
      );
      final stamp = rows.single['deleted_at'];
      expect(stamp, isA<String>());
      expect(stamp, endsWith('Z'));
    });
  });
}
