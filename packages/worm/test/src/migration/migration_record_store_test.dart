/// Unit tests for [MigrationRecordStore] row decoding across adapters.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/migration/migration_record_store.dart';
import 'package:worm/src/query/insert_descriptor.dart';

void main() {
  late InMemoryAdapter adapter;
  late MigrationRecordStore store;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    store = MigrationRecordStore(adapter);
    await store.ensureTable();
  });

  test('decodes applied_at stored as an ISO string', () async {
    await store.insert('20260101_000000_create_users', 1);
    final records = await store.all();
    expect(records.single.name, '20260101_000000_create_users');
    expect(records.single.batch, 1);
  });

  test('decodes applied_at decoded to DateTime by SQL adapters', () async {
    // PostgreSQL (and other SQL drivers) decode timestamp columns to
    // DateTime, unlike the in-memory adapter which echoes the inserted
    // string — the store must accept both or incremental `migrate` fails
    // against every already-migrated SQL database.
    await adapter.insert(
      InsertDescriptor(
        table: migrationsTable,
        values: {
          'name': '20260101_000000_create_users',
          'batch': 1,
          'applied_at': DateTime.utc(2026, 7, 23, 11, 15),
        },
      ),
    );
    final records = await store.all();
    expect(records.single.name, '20260101_000000_create_users');
    expect(records.single.appliedAt, DateTime.utc(2026, 7, 23, 11, 15));
    expect(await store.appliedNames(), {'20260101_000000_create_users'});
  });
}
