/// Contract-suite validation for [MysqlAdapter].
///
/// Gated by the `MYSQL_URL` environment variable. When absent, the suite
/// is skipped gracefully with a single placeholder test so `dart test`
/// still passes without a live MySQL server.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/testing/adapter_contract.dart';
import 'package:worm/worm.dart';
import 'package:worm_mysql/worm_mysql.dart';

void main() {
  final url = Platform.environment['MYSQL_URL'];
  if (url == null || url.isEmpty) {
    test(
      'MysqlAdapter contract suite skipped — MYSQL_URL unset',
      () {},
      skip:
          'Set MYSQL_URL (mysql://user:pass@host:port/db) to '
          'run the MySQL contract suite.',
    );
    return;
  }

  runAdapterContractTests(
    name: 'MysqlAdapter contract',
    capabilities: const AdapterCapabilities(
      supportsTransactions: true,
      supportsSavepoints: true,
      supportsStreaming: true,
      supportsRawQuery: true,
      supportsJoins: true,
      supportsPreparedStatements: true,
      supportsAggregations: true,
      supportsSchemaIntrospection: true,
      supportsExplain: true,
    ),
    adapterFactory: () async {
      final adapter = MysqlAdapter(pool: MysqlConnectionPool.fromUri(url));
      await adapter.executeSchema(
        const SchemaDescriptor.dropTable(table: 'users', ifExists: true),
      );
      return adapter;
    },
  );
}
