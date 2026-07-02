/// Shared fixtures for the InMemoryAdapter contract
/// test suite.
///
/// Prefixed with `_` so the file is treated as an
/// internal test helper and skipped by `dart test`'s
/// default file discovery.
library;

import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/schema/column_type.dart';

/// Canonical `users` table used by CRUD and
/// transaction tests.
Future<InMemoryAdapter> adapterWithUsers() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'users',
      columns: <SchemaColumn>[
        SchemaColumn(name: 'id', type: ColumnType.integer),
        SchemaColumn(name: 'name', type: ColumnType.string),
        SchemaColumn(name: 'age', type: ColumnType.integer),
      ],
    ),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'users',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Alice', 'age': 30},
        <String, Object?>{'id': 2, 'name': 'Bob', 'age': 25},
        <String, Object?>{'id': 3, 'name': 'Carol', 'age': 40},
        <String, Object?>{'id': 4, 'name': 'Dave', 'age': 35},
      ],
    ),
  );
  return adapter;
}
