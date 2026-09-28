/// Current reads that bypass repeatable-read snapshots.
library;

import '../query/query_descriptor.dart';

/// Provides a current, locking read on the adapter's active connection.
///
/// Implementations must observe committed changes newer than a transaction's
/// consistent-read snapshot and retain any acquired row locks until transaction
/// completion. This is an explicit capability: a normal SELECT is not a safe
/// fallback when verifying a conditional mutation on snapshot-based engines.
abstract mixin class CurrentReadCapable {
  /// Reads at most one current row matching [query], with update locking.
  Future<Map<String, Object?>?> selectOneCurrent(QueryDescriptor query);
}
