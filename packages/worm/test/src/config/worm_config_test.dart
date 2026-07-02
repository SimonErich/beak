import 'package:test/test.dart';
import 'package:worm/src/config/connection_config.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/schema/primary_key_type.dart';
import 'package:worm/src/seeder/environment.dart';

void main() {
  group('WormConfig', () {
    test('has correct defaults', () {
      const config = WormConfig();
      expect(config.poolSize, 10);
      expect(config.primaryKeyType, PrimaryKeyType.uuid);
      expect(config.timestamps, isTrue);
      expect(config.softDeletes, isFalse);
      expect(config.defaultConnection, 'default');
      expect(config.environment, Environment.development);
    });

    test('accepts custom values', () {
      const config = WormConfig(
        defaultConnection: 'analytics',
        poolSize: 20,
        primaryKeyType: PrimaryKeyType.integer,
        timestamps: false,
        softDeletes: true,
        environment: Environment.production,
      );
      expect(config.defaultConnection, 'analytics');
      expect(config.poolSize, 20);
      expect(config.primaryKeyType, PrimaryKeyType.integer);
      expect(config.timestamps, isFalse);
      expect(config.softDeletes, isTrue);
      expect(config.environment, Environment.production);
    });

    test('holds connection configs', () {
      const config = WormConfig(
        connections: {
          'default': ConnectionConfig(
            driver: 'postgres',
            host: 'localhost',
            port: 5432,
            database: 'myapp',
          ),
        },
      );
      expect(config.connections, hasLength(1));
      expect(config.connections['default']?.driver, 'postgres');
    });

    test('is const-constructible', () {
      const config = WormConfig();
      expect(config.poolSize, 10);
    });
  });

  group('ConnectionConfig', () {
    test('stores all connection parameters', () {
      const conn = ConnectionConfig(
        driver: 'postgres',
        host: 'db.example.com',
        port: 5432,
        database: 'myapp',
        username: 'admin',
        password: 'secret',
        poolSize: 20,
        maxTotalConnections: 50,
      );
      expect(conn.driver, 'postgres');
      expect(conn.host, 'db.example.com');
      expect(conn.port, 5432);
      expect(conn.database, 'myapp');
      expect(conn.username, 'admin');
      expect(conn.password, 'secret');
      expect(conn.poolSize, 20);
      expect(conn.maxTotalConnections, 50);
    });

    test('has sensible timeout defaults', () {
      const conn = ConnectionConfig(
        driver: 'postgres',
        host: 'localhost',
        port: 5432,
        database: 'test',
      );
      expect(conn.connectionTimeout, const Duration(seconds: 5));
      expect(conn.idleTimeout, const Duration(seconds: 300));
    });
  });

  group('StrictnessConfig', () {
    test('defaults all flags to false', () {
      const strict = StrictnessConfig();
      expect(strict.preventLazyLoading, isFalse);
      expect(strict.preventFullTableScans, isFalse);
      expect(strict.preventSilentMassAssignment, isFalse);
      expect(strict.warnOnN1Queries, isFalse);
      expect(strict.warnOnMissingIndex, isFalse);
    });

    test('flags are independently toggleable', () {
      const strict = StrictnessConfig(
        preventLazyLoading: true,
        warnOnN1Queries: true,
      );
      expect(strict.preventLazyLoading, isTrue);
      expect(strict.preventFullTableScans, isFalse);
      expect(strict.preventSilentMassAssignment, isFalse);
      expect(strict.warnOnN1Queries, isTrue);
      expect(strict.warnOnMissingIndex, isFalse);
    });

    test('copyWith replaces individual flags', () {
      const original = StrictnessConfig(preventLazyLoading: true);
      final updated = original.copyWith(warnOnN1Queries: true);
      expect(updated.preventLazyLoading, isTrue);
      expect(updated.warnOnN1Queries, isTrue);
      expect(updated.preventFullTableScans, isFalse);
    });

    test('is const-constructible', () {
      const strict = StrictnessConfig(preventFullTableScans: true);
      expect(strict.preventFullTableScans, isTrue);
    });
  });
}
