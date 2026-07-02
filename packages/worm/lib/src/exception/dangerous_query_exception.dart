/// Alias for [FullTableScanException].
library;

import 'full_table_scan_exception.dart';

/// Alias for [FullTableScanException].
///
/// The spec refers to dangerous queries by this
/// name while the code originally named the
/// concrete class [FullTableScanException]; both
/// names resolve to the same class so a `catch`
/// clause on either name catches throws of the
/// other.
typedef DangerousQueryException = FullTableScanException;
