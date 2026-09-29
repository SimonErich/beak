import 'package:beak_backend/beak_backend.dart';

/// Beak's graph-commit receipts mapped onto the tool-owned Serverpod model
/// `beak_commit_receipt`:
///
/// ```yaml
/// class: BeakCommitReceipt
/// serverOnly: true
/// table: beak_commit_receipt
/// fields:
///   receiptKey: String, unique
///   requestHash: String
///   requestJson: String
///   resultJson: String
///   createdAt: DateTime, default=now
/// ```
///
/// Serverpod's `create-migration` owns the table, so nothing here runs
/// Beak's own [BeakCommitReceiptsMigration]. The serial `id` and `createdAt`
/// are filled by the database; Beak only ever filters on the unique
/// `receiptKey`.
const BeakFrameworkTables beakServerpodFrameworkTables = BeakFrameworkTables(
  receipts: BeakCommitReceiptTable(
    table: 'beak_commit_receipt',
    keyColumn: 'receiptKey',
    requestHashColumn: 'requestHash',
    requestJsonColumn: 'requestJson',
    resultJsonColumn: 'resultJson',
  ),
);
