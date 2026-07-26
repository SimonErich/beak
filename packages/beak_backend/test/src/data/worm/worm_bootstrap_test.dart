import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

void main() {
  group('postgresConnectionConfig', () {
    test('maps every DATABASE_URL part onto the worm config', () {
      final config = postgresConnectionConfig(
        Uri.parse('postgres://beak:s3cr%40t@db.example:25432/beak_dev'),
      );
      expect(config.driver, 'postgres');
      expect(config.host, 'db.example');
      expect(config.port, 25432);
      expect(config.database, 'beak_dev');
      expect(config.username, 'beak');
      expect(config.password, 's3cr@t');
      expect(config.useSsl, isFalse);
    });

    test('defaults the port and accepts the postgresql scheme', () {
      final config = postgresConnectionConfig(
        Uri.parse('postgresql://beak@localhost/beak'),
      );
      expect(config.port, 5432);
      expect(config.username, 'beak');
      expect(config.password, isNull);
    });

    test('honors sslmode=require', () {
      final config = postgresConnectionConfig(
        Uri.parse('postgres://u:p@h/db?sslmode=require'),
      );
      expect(config.useSsl, isTrue);
    });

    test('applies the pool size', () {
      final config = postgresConnectionConfig(
        Uri.parse('postgres://u:p@h/db'),
        poolSize: 3,
      );
      expect(config.poolSize, 3);
    });

    test('rejects non-postgres schemes', () {
      expect(
        () => postgresConnectionConfig(Uri.parse('mysql://u:p@h/db')),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects a URL without a database name', () {
      expect(
        () => postgresConnectionConfig(Uri.parse('postgres://u:p@h')),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('adapterFromUrl', () {
    test('picks the driver from the scheme', () {
      // One place maps a URL to a driver, so `beak dev`, the migration CLI
      // and a hand-built server cannot disagree about what DATABASE_URL means.
      expect(
        adapterFromUrl(Uri.parse('sqlite::memory:')).adapterType,
        AdapterType.sql,
      );
      expect(
        adapterFromUrl(Uri.parse('postgres://u:p@localhost:5432/beak')),
        isA<PostgresAdapter>(),
      );
    });

    test('an in-memory sqlite adapter answers a query', () async {
      final adapter = adapterFromUrl(Uri.parse('sqlite::memory:'));
      addTearDown(adapter.disconnect);
      await adapter.connect();

      await adapter.executeSchema(
        const SchemaDescriptor.createTable(
          table: 'notes',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
            ),
          ],
        ),
      );

      expect(
        await adapter.select(const QueryDescriptor(table: 'notes')),
        isEmpty,
      );
    });
  });
}
