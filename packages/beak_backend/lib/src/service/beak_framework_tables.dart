import 'beak_commit_receipts_migration.dart';

/// Where [BeakGraphCommitService] keeps its durable receipts.
///
/// The service only ever filters on [keyColumn], so a table may carry more
/// columns (a serial id, a creation timestamp) as long as the database fills
/// them.
final class BeakCommitReceiptTable {
  /// Maps the receipt fields onto [table]'s columns.
  const BeakCommitReceiptTable({
    required this.table,
    required this.keyColumn,
    required this.requestHashColumn,
    required this.requestJsonColumn,
    required this.resultJsonColumn,
  });

  /// Beak's own table, created by [BeakCommitReceiptsMigration].
  static const BeakCommitReceiptTable beak = BeakCommitReceiptTable(
    table: BeakCommitReceiptsMigration.table,
    keyColumn: 'id',
    requestHashColumn: 'request_hash',
    requestJsonColumn: 'request_json',
    resultJsonColumn: 'result_json',
  );

  /// Table name.
  final String table;

  /// Unique text column holding the (principal, saveId) key.
  final String keyColumn;

  /// Text column holding the submitted plan's hash.
  final String requestHashColumn;

  /// Text column holding the prepared plan.
  final String requestJsonColumn;

  /// Text column holding the authoritative result.
  final String resultJsonColumn;

  /// Every column the service reads or writes.
  Set<String> get columns => {
    keyColumn,
    requestHashColumn,
    requestJsonColumn,
    resultJsonColumn,
  };
}

/// The tables Beak's durable machinery writes to.
///
/// A host whose migrations Beak does not own (Serverpod) maps them onto its
/// own models instead of applying [BeakCommitReceiptsMigration].
final class BeakFrameworkTables {
  /// Groups the mappings.
  const BeakFrameworkTables({required this.receipts});

  /// Beak's own tables, created by its migrations.
  static const BeakFrameworkTables beak = BeakFrameworkTables(
    receipts: BeakCommitReceiptTable.beak,
  );

  /// The graph-commit receipt store.
  final BeakCommitReceiptTable receipts;
}
