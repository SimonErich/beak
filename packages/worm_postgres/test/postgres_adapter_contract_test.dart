/// Contract-suite validation for [PostgresAdapter].
///
/// Gated by the `PG_DB` environment variable. When the
/// variable is absent, the suite is skipped gracefully with a
/// single placeholder test so `dart test` still passes without a
/// live PostgreSQL server.
@TestOn('vm')
library;

import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:worm/testing/adapter_contract.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

void main() {
  final url = Platform.environment['PG_DB'];
  if (url == null || url.isEmpty) {
    test(
      'PostgresAdapter contract suite skipped — PG_DB unset',
      () {},
      skip:
          'Set PG_DB (postgres://user:pass@host:port/db) to '
          'run the Postgres contract suite.',
    );
    return;
  }

  runAdapterContractTests(
    name: 'PostgresAdapter contract',
    capabilities: const AdapterCapabilities(
      supportsTransactions: true,
      supportsSavepoints: true,
      supportsStreaming: true,
      supportsRawQuery: true,
      supportsReturning: true,
      supportsJoins: true,
      supportsPreparedStatements: true,
      supportsAggregations: true,
      supportsSchemaIntrospection: true,
      supportsExplain: true,
    ),
    adapterFactory: () async {
      final pool = PostgresConnectionPool(
        pool: Pool<Object?>.withUrl(url),
        maxConnectionCount: 4,
      );
      final adapter = PostgresAdapter(pool: pool);
      await adapter.executeSchema(
        const SchemaDescriptor.dropTable(table: 'users', ifExists: true),
      );
      return adapter;
    },
  );
}
