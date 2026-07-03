import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

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
}
