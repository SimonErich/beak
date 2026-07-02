/// Timestamp management.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';

import '_fixtures.dart';

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'tests'),
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
    );
  });

  tearDown(Worm.reset);

  Future<Map<String, Object?>> readRow(int id) async {
    final rows = await adapter.select(const QueryDescriptor(table: 'tests'));
    return rows.singleWhere((r) => r['id'] == id);
  }

  group('timestamps', () {
    test('createdAt and updatedAt set on insert', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      final row = await readRow(1);
      expect(row['created_at'], isA<DateTime>());
      expect(row['updated_at'], isA<DateTime>());
      expect(row['created_at'], row['updated_at']);
    });

    test('createdAt stays unchanged on update; updatedAt advances', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      final firstCreated = (await readRow(1))['created_at'];
      await Future<void>.delayed(const Duration(milliseconds: 5));
      model.setAttribute('name', 'Bob');
      await model.save();
      final after = await readRow(1);
      expect(after['created_at'], firstCreated);
      expect(after['updated_at'], isNot(firstCreated));
    });

    test('withoutTimestamps suppresses createdAt and updatedAt', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.withoutTimestamps(model.save);
      final row = await readRow(1);
      expect(row['created_at'], isNull);
      expect(row['updated_at'], isNull);
    });

    test('usesTimestamps = false bypasses both', () async {
      final model =
          TestModel(tableNameOverride: 'tests', usesTimestampsOverride: false)
            ..setAttribute('id', 1)
            ..setAttribute('name', 'Alice');
      await model.save();
      final row = await readRow(1);
      expect(row['created_at'], isNull);
      expect(row['updated_at'], isNull);
    });
  });
}
