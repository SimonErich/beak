/// Persistent storage of applied migrations.
library;

import '../adapter/database_adapter.dart';
import '../exception/migration_exception.dart';
import '../query/delete_descriptor.dart';
import '../query/insert_descriptor.dart';
import '../query/operator.dart';
import '../query/predicate.dart';
import '../query/predicate_tree.dart';
import '../query/query_descriptor.dart';
import '../query/schema_descriptor.dart';
import '../schema/column_type.dart';
import 'migration_record.dart';

/// Name of the table used to track applied migrations.
const String migrationsTable = 'worm_migrations';

/// Adapter-backed CRUD over the `worm_migrations` tracking table.
final class MigrationRecordStore {
  /// Creates a [MigrationRecordStore].
  const MigrationRecordStore(this.adapter);

  /// Adapter the store reads and writes against.
  final DatabaseAdapter adapter;

  /// Ensure the tracking table exists.
  Future<void> ensureTable() => adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: migrationsTable,
      columns: <SchemaColumn>[
        SchemaColumn(name: 'name', type: ColumnType.text, isPrimaryKey: true),
        SchemaColumn(name: 'batch', type: ColumnType.integer),
        SchemaColumn(name: 'applied_at', type: ColumnType.dateTime),
      ],
      ifNotExists: true,
    ),
  );

  /// Drop the tracking table.
  Future<void> dropTable() => adapter.executeSchema(
    const SchemaDescriptor.dropTable(table: migrationsTable, ifExists: true),
  );

  /// All applied migration records.
  Future<List<MigrationRecord>> all() async {
    final rows = await adapter.select(
      const QueryDescriptor(table: migrationsTable),
    );
    return <MigrationRecord>[for (final r in rows) _fromRow(r)];
  }

  /// Names of every applied migration.
  Future<Set<String>> appliedNames() async {
    final records = await all();
    return <String>{for (final r in records) r.name};
  }

  /// Highest batch number stored, or `0` when none.
  Future<int> maxBatch() async {
    final records = await all();
    var max = 0;
    for (final r in records) {
      if (r.batch > max) max = r.batch;
    }
    return max;
  }

  /// Names of migrations in [batch], sorted descending so rollback
  /// reverses them in reverse-apply order.
  Future<List<String>> namesInBatch(int batch) async {
    final records = await all();
    final filtered = records.where((r) => r.batch == batch).toList()
      ..sort((a, b) => b.name.compareTo(a.name));
    return <String>[for (final r in filtered) r.name];
  }

  /// Insert one record.
  Future<void> insert(String name, int batch) => adapter.insert(
    InsertDescriptor(
      table: migrationsTable,
      values: <String, Object?>{
        'name': name,
        'batch': batch,
        'applied_at': DateTime.now().toIso8601String(),
      },
    ),
  );

  /// Remove one record by name.
  Future<void> remove(String name) => adapter.delete(
    DeleteDescriptor(
      table: migrationsTable,
      where: LeafNode(
        Predicate(fieldName: 'name', operator: Operator.eq, value: name),
      ),
    ),
  );

  MigrationRecord _fromRow(Map<String, Object?> row) {
    final name = row['name'];
    final batch = row['batch'];
    // Adapters differ on timestamp decoding: the in-memory adapter returns
    // the inserted ISO string verbatim, while SQL drivers (PostgreSQL)
    // decode timestamp columns to DateTime — accept both.
    final appliedAt = switch (row['applied_at']) {
      final DateTime value => value,
      final String value => DateTime.tryParse(value),
      _ => null,
    };
    if (name is! String || batch is! int || appliedAt == null) {
      throw MigrationException(
        migration: name is String ? name : 'unknown',
        message: 'Corrupt $migrationsTable row: $row',
      );
    }
    return MigrationRecord(name: name, batch: batch, appliedAt: appliedAt);
  }
}
