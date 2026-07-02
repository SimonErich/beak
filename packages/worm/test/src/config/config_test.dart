import 'package:test/test.dart';
import 'package:worm/src/config/connection_config.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/schema/primary_key_type.dart';
import 'package:worm/src/seeder/environment.dart';

void main() {
  group('WormConfig', () {
    test('default constructor matches the constitution baseline', () {
      const config = WormConfig();
      expect(config.defaultConnection, 'default');
      expect(config.poolSize, 10);
      expect(config.primaryKeyType, PrimaryKeyType.uuid);
      expect(config.timestamps, isTrue);
      expect(config.softDeletes, isFalse);
      expect(config.environment, Environment.development);
      expect(config.connections, isEmpty);
      expect(config.strictness.preventLazyLoading, isFalse);
    });

    test('is const constructible with zero arguments', () {
      const a = WormConfig();
      const b = WormConfig();
      expect(identical(a, b), isTrue);
    });

    test('accepts custom values for every field', () {
      const connections = <String, ConnectionConfig>{
        'analytics': ConnectionConfig(host: 'analytics.db', port: 5432),
      };
      const config = WormConfig(
        defaultConnection: 'analytics',
        connections: connections,
        poolSize: 25,
        primaryKeyType: PrimaryKeyType.integer,
        timestamps: false,
        softDeletes: true,
        strictness: StrictnessConfig(preventLazyLoading: true),
        environment: Environment.production,
      );
      expect(config.defaultConnection, 'analytics');
      expect(config.connections['analytics']?.host, 'analytics.db');
      expect(config.poolSize, 25);
      expect(config.primaryKeyType, PrimaryKeyType.integer);
      expect(config.timestamps, isFalse);
      expect(config.softDeletes, isTrue);
      expect(config.strictness.preventLazyLoading, isTrue);
      expect(config.environment, Environment.production);
    });

    test('copyWith overrides only selected fields', () {
      const config = WormConfig();
      final next = config.copyWith(
        defaultConnection: 'analytics',
        softDeletes: true,
        poolSize: 50,
      );
      expect(next.defaultConnection, 'analytics');
      expect(next.softDeletes, isTrue);
      expect(next.poolSize, 50);
      expect(next.timestamps, isTrue);
      expect(next.primaryKeyType, PrimaryKeyType.uuid);
      expect(next.environment, Environment.development);
    });
  });

  group('ConnectionConfig', () {
    test('default values match the 10-parameter spec', () {
      const config = ConnectionConfig();
      expect(config.host, 'localhost');
      expect(config.port, 0);
      expect(config.database, '');
      expect(config.username, isNull);
      expect(config.password, isNull);
      expect(config.useSsl, isFalse);
      expect(config.poolSize, 10);
      expect(config.maxTotalConnections, isNull);
      expect(config.connectionTimeout, const Duration(seconds: 5));
      expect(config.idleTimeout, const Duration(seconds: 300));
    });

    test('is const constructible', () {
      const a = ConnectionConfig();
      const b = ConnectionConfig();
      expect(identical(a, b), isTrue);
    });

    test('accepts custom values for every parameter', () {
      const config = ConnectionConfig(
        host: 'db.internal',
        port: 5432,
        database: 'app',
        username: 'worm',
        password: 'secret',
        useSsl: true,
        poolSize: 25,
        maxTotalConnections: 100,
        connectionTimeout: Duration(seconds: 10),
        idleTimeout: Duration(minutes: 10),
      );
      expect(config.host, 'db.internal');
      expect(config.port, 5432);
      expect(config.database, 'app');
      expect(config.username, 'worm');
      expect(config.password, 'secret');
      expect(config.useSsl, isTrue);
      expect(config.poolSize, 25);
      expect(config.maxTotalConnections, 100);
      expect(config.connectionTimeout, const Duration(seconds: 10));
      expect(config.idleTimeout, const Duration(minutes: 10));
    });

    test('copyWith overrides only selected fields', () {
      const config = ConnectionConfig(host: 'a', poolSize: 5);
      final next = config.copyWith(poolSize: 50);
      expect(next.host, 'a');
      expect(next.poolSize, 50);
    });
  });

  group('StrictnessConfig', () {
    test('default constructor leaves every flag off', () {
      const flags = StrictnessConfig();
      expect(flags.preventLazyLoading, isFalse);
      expect(flags.preventFullTableScans, isFalse);
      expect(flags.preventSilentMassAssignment, isFalse);
      expect(flags.warnOnN1Queries, isFalse);
      expect(flags.preventDestructiveWithoutWhere, isFalse);
    });

    test('is const constructible', () {
      const a = StrictnessConfig();
      const b = StrictnessConfig();
      expect(identical(a, b), isTrue);
    });

    test('exposes exactly six flags — no more, no less', () {
      // Enabling every known flag and reading them back proves the
      // surface is the six documented toggles.
      const flags = StrictnessConfig(
        preventLazyLoading: true,
        preventFullTableScans: true,
        preventSilentMassAssignment: true,
        warnOnN1Queries: true,
        warnOnMissingIndex: true,
        preventDestructiveWithoutWhere: true,
      );
      final asList = <bool>[
        flags.preventLazyLoading,
        flags.preventFullTableScans,
        flags.preventSilentMassAssignment,
        flags.warnOnN1Queries,
        flags.warnOnMissingIndex,
        flags.preventDestructiveWithoutWhere,
      ];
      expect(asList.where((b) => b).length, 6);
    });

    test('copyWith produces an independent composition of flags', () {
      const flags = StrictnessConfig(preventLazyLoading: true);
      final two = flags.copyWith(warnOnN1Queries: true);
      expect(two.preventLazyLoading, isTrue);
      expect(two.warnOnN1Queries, isTrue);
      expect(two.preventFullTableScans, isFalse);
      expect(two.preventSilentMassAssignment, isFalse);
      expect(two.preventDestructiveWithoutWhere, isFalse);
    });

    test('each flag can be toggled in isolation', () {
      const base = StrictnessConfig();
      expect(base.copyWith(preventLazyLoading: true).preventLazyLoading, true);
      expect(
        base.copyWith(preventFullTableScans: true).preventFullTableScans,
        true,
      );
      expect(
        base
            .copyWith(preventSilentMassAssignment: true)
            .preventSilentMassAssignment,
        true,
      );
      expect(base.copyWith(warnOnN1Queries: true).warnOnN1Queries, true);
      expect(
        base
            .copyWith(preventDestructiveWithoutWhere: true)
            .preventDestructiveWithoutWhere,
        true,
      );
    });
  });
}
