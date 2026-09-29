import 'package:beak_backend/beak_backend.dart';

/// Beak's durable tables mapped onto tool-owned Serverpod models.
///
/// The graph-commit receipts live in `beak_commit_receipt`:
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
/// `receiptKey`, and `BeakGraphCommitService.pruneReceipts` ages receipts out
/// by `createdAt`.
///
/// A project that delivers effects adds the outbox model too, so
/// `BeakOutbox.enqueue`, `BeakOutboxSchedule` and `BeakOutbox.prune` can be
/// given `beakServerpodFrameworkTables.outbox` instead of writing
/// `_beak_outbox`:
///
/// ```yaml
/// class: BeakOutboxEffect
/// serverOnly: true
/// table: beak_outbox
/// fields:
///   effectKey: String, unique
///   effectKind: String
///   payloadJson: String
///   deliveryStatus: String
///   attemptCount: int
///   availableAt: int
///   leaseToken: String
///   lastError: String
/// ```
const BeakFrameworkTables beakServerpodFrameworkTables = BeakFrameworkTables(
  receipts: BeakCommitReceiptTable(
    table: 'beak_commit_receipt',
    keyColumn: 'receiptKey',
    requestHashColumn: 'requestHash',
    requestJsonColumn: 'requestJson',
    resultJsonColumn: 'resultJson',
    createdAtColumn: 'createdAt',
  ),
  outbox: BeakOutboxTable(
    table: 'beak_outbox',
    idColumn: 'effectKey',
    kindColumn: 'effectKind',
    payloadColumn: 'payloadJson',
    statusColumn: 'deliveryStatus',
    attemptColumn: 'attemptCount',
    availableAtColumn: 'availableAt',
    leaseColumn: 'leaseToken',
    lastErrorColumn: 'lastError',
  ),
);
