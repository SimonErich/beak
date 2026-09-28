import 'package:worm/worm.dart';

/// Internal durable receipts, registered alongside an application's migrations.
final class BeakCommitReceiptsMigration extends Migration {
  /// Creates the migration; applying it remains the migration runner's job.
  const BeakCommitReceiptsMigration();

  /// Private table storing the immutable request and its authoritative receipt.
  static const String table = '_beak_commit_receipts';

  @override
  String get name => '20260926_000000_beak_commit_receipts';

  @override
  Future<void> up(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: table,
      ifNotExists: true,
      columns: [
        SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
        SchemaColumn(name: 'request_hash', type: ColumnType.text),
        SchemaColumn(name: 'request_json', type: ColumnType.text),
        SchemaColumn(name: 'result_json', type: ColumnType.text),
      ],
    ),
  );

  @override
  Future<void> down(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.dropTable(table: table, ifExists: true),
  );
}
