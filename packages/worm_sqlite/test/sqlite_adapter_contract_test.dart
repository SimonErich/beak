/// Contract-suite validation for [SqliteAdapter].
///
/// SQLite runs in-process, so this suite needs no external server and
/// runs unconditionally on a fresh in-memory database per test.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:worm/testing/adapter_contract.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

void main() {
  runAdapterContractTests(
    name: 'SqliteAdapter contract',
    capabilities: const AdapterCapabilities(
      supportsTransactions: true,
      supportsSavepoints: true,
      supportsStreaming: true,
      supportsRawQuery: true,
      supportsJoins: true,
      supportsAggregations: true,
      supportsSchemaIntrospection: true,
      supportsExplain: true,
    ),
    adapterFactory: SqliteAdapter.memory,
  );
}
