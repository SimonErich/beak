/// Unit tests for [SeederRecordStore].
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/seeder/seeder_record.dart';
import 'package:worm/src/seeder/seeder_record_store.dart';

void main() {
  late InMemoryAdapter adapter;
  late SeederRecordStore store;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    store = SeederRecordStore(adapter);
  });

  group('ensureTable', () {
    test('creates the tracking table on first call', () async {
      await store.ensureTable();
      // After ensure, an empty select succeeds without throwing.
      final rows = await adapter.select(
        const QueryDescriptor(table: SeederRecord.tableName),
      );
      expect(rows, isEmpty);
    });

    test('is idempotent — multiple calls do not throw', () async {
      await store.ensureTable();
      await store.ensureTable();
      await store.ensureTable();
      final rows = await adapter.select(
        const QueryDescriptor(table: SeederRecord.tableName),
      );
      expect(rows, isEmpty);
    });
  });

  group('hasRun', () {
    test('returns false before any record exists', () async {
      await store.ensureTable();
      expect(await store.hasRun('UserSeeder'), isFalse);
    });

    test('returns true after the seeder is recorded', () async {
      await store.ensureTable();
      await store.record('UserSeeder');
      expect(await store.hasRun('UserSeeder'), isTrue);
    });

    test('returns false for an unrelated seeder name', () async {
      await store.ensureTable();
      await store.record('UserSeeder');
      expect(await store.hasRun('PostSeeder'), isFalse);
    });
  });

  group('record', () {
    test('inserts a row hydrated as a SeederRecord', () async {
      await store.ensureTable();
      final before = DateTime.now().toUtc();
      await store.record('UserSeeder');
      final after = DateTime.now().toUtc();
      final records = await store.all();
      expect(records, hasLength(1));
      final record = records.single;
      expect(record.name, 'UserSeeder');
      expect(
        record.executedAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        record.executedAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('accepts an explicit executedAt timestamp', () async {
      await store.ensureTable();
      final stamp = DateTime.utc(2024, 6, 1, 12);
      await store.record('UserSeeder', executedAt: stamp);
      final record = (await store.all()).single;
      expect(record.executedAt, stamp);
    });
  });
}
