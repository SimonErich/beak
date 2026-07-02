/// Persistent tracking for executed seeders.
library;

import '../adapter/database_adapter.dart';
import '../query/insert_descriptor.dart';
import '../query/operator.dart';
import '../query/predicate.dart';
import '../query/predicate_tree.dart';
import '../query/query_descriptor.dart';
import '../query/schema_descriptor.dart';
import '../schema/column_type.dart';
import 'seeder_record.dart';

/// Adapter-backed CRUD over the seeder tracking table.
///
/// The store is the source of truth for which seeders have
/// already run. `SeederRunner` consults it via [hasRun] before
/// invoking a seeder and notifies it via [record] afterwards.
///
/// Constructor-injected; never reaches into `Worm.adapter()` —
/// callers wire the adapter explicitly so the store can be used
/// in isolation (tests, batch tools, scripts).
final class SeederRecordStore {
  /// Creates a [SeederRecordStore] writing to [adapter].
  const SeederRecordStore(this.adapter);

  /// Adapter the store reads and writes against.
  final DatabaseAdapter adapter;

  /// Ensure the tracking table exists.
  ///
  /// Idempotent — emits `CREATE TABLE IF NOT EXISTS` so multiple
  /// calls are safe.
  Future<void> ensureTable() => adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: SeederRecord.tableName,
      columns: <SchemaColumn>[
        SchemaColumn(
          name: SeederRecord.columnName,
          type: ColumnType.text,
          isPrimaryKey: true,
        ),
        SchemaColumn(
          name: SeederRecord.columnExecutedAt,
          type: ColumnType.dateTime,
        ),
      ],
      ifNotExists: true,
    ),
  );

  /// Every record currently stored.
  Future<List<SeederRecord>> all() async {
    final rows = await adapter.select(
      const QueryDescriptor(table: SeederRecord.tableName),
    );
    return <SeederRecord>[for (final row in rows) SeederRecord.fromRow(row)];
  }

  /// Whether the seeder identified by [name] has already run.
  Future<bool> hasRun(String name) async {
    final row = await adapter.selectOne(
      QueryDescriptor(
        table: SeederRecord.tableName,
        where: LeafNode(
          Predicate(
            fieldName: SeederRecord.columnName,
            operator: Operator.eq,
            value: name,
          ),
        ),
        limit: 1,
      ),
    );
    return row != null;
  }

  /// Persist a run record for [name].
  ///
  /// Writes `executedAt` as the current UTC time when caller
  /// omits an explicit value.
  Future<void> record(String name, {DateTime? executedAt}) {
    final record = SeederRecord(
      name: name,
      executedAt: executedAt ?? DateTime.now().toUtc(),
    );
    return adapter.insert(
      InsertDescriptor(table: SeederRecord.tableName, values: record.toMap()),
    );
  }
}
