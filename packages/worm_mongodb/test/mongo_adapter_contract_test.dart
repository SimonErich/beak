/// Contract-suite validation for [MongoAdapter].
///
/// Gated by the `MONGO_URI` environment variable. When the
/// variable is absent, the suite is skipped gracefully with a
/// single placeholder test so `dart test` still passes without a
/// live MongoDB server.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/testing/adapter_contract.dart';
import 'package:worm/worm.dart';
import 'package:worm_mongodb/worm_mongodb.dart';

void main() {
  final url = Platform.environment['MONGO_URI'];
  if (url == null || url.isEmpty) {
    test(
      'MongoAdapter contract suite skipped — MONGO_URI unset',
      () {},
      skip:
          'Set MONGO_URI (mongodb://host:port/db) to run the '
          'Mongo contract suite.',
    );
    return;
  }

  runAdapterContractTests(
    name: 'MongoAdapter contract',
    capabilities: const AdapterCapabilities(
      supportsStreaming: true,
      supportsReturning: true,
      supportsAggregations: true,
      supportsSchemaIntrospection: true,
      supportsExplain: true,
    ),
    adapterFactory: () async {
      final connection = MongoConnection.fromUri(url);
      final adapter = MongoAdapter(connection: connection);
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.dropTable(table: 'users', ifExists: true),
      );
      return adapter;
    },
  );
}
