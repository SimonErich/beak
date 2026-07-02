import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/src/pool/postgres_connection_pool.dart';
import 'package:worm_postgres/src/pool/prepared_statement_cache.dart';

void main() {
  group('PreparedStatementCache', () {
    test('missRate is 0.0 when no get calls have been made', () {
      final cache = PreparedStatementCache<int>();
      expect(cache.hitCount, 0);
      expect(cache.missCount, 0);
      expect(cache.missRate, 0.0);
    });

    test('10 unique SQL + 90 repeats produces missRate of 0.1', () {
      final cache = PreparedStatementCache<int>(maxSize: 100);
      final unique = <String>[for (var i = 0; i < 10; i++) 'q$i'];

      for (final sql in unique) {
        expect(cache.get(sql), isNull);
        cache.put(sql, 1);
      }
      for (var i = 0; i < 90; i++) {
        expect(cache.get(unique[i % unique.length]), 1);
      }

      expect(cache.hitCount, 90);
      expect(cache.missCount, 10);
      expect(cache.missRate, 0.1);
    });

    test('evicts the least-recently-used entry when maxSize exceeded', () {
      final cache = PreparedStatementCache<int>(maxSize: 3)
        ..put('a', 1)
        ..put('b', 2)
        ..put('c', 3)
        ..get('a')
        ..put('d', 4);

      expect(cache.contains('a'), isTrue);
      expect(cache.contains('b'), isFalse);
      expect(cache.contains('c'), isTrue);
      expect(cache.contains('d'), isTrue);
      expect(cache.length, 3);
    });

    test('get on a cached entry promotes it to most-recently-used', () {
      final cache = PreparedStatementCache<int>(maxSize: 2)
        ..put('a', 1)
        ..put('b', 2)
        ..get('a')
        ..put('c', 3);

      expect(cache.contains('a'), isTrue);
      expect(cache.contains('b'), isFalse);
      expect(cache.contains('c'), isTrue);
    });

    test('put replacing an existing key updates value without eviction', () {
      final cache = PreparedStatementCache<int>(maxSize: 2)
        ..put('a', 1)
        ..put('b', 2)
        ..put('a', 99);

      expect(cache.get('a'), 99);
      expect(cache.get('b'), 2);
      expect(cache.length, 2);
    });

    test('clear resets hitCount, missCount, and empties the cache', () {
      final cache = PreparedStatementCache<int>(maxSize: 5)
        ..put('a', 1)
        ..get('a')
        ..get('missing');

      expect(cache.hitCount, 1);
      expect(cache.missCount, 1);
      expect(cache.length, 1);

      cache.clear();

      expect(cache.hitCount, 0);
      expect(cache.missCount, 0);
      expect(cache.length, 0);
      expect(cache.contains('a'), isFalse);
      expect(cache.missRate, 0.0);
    });
  });

  group('PostgresConnectionPool.fromConfig', () {
    setUp(PostgresConnectionPool.resetIsolateReservationForTesting);
    tearDown(PostgresConnectionPool.resetIsolateReservationForTesting);

    test('applies ConnectionConfig.poolSize as maxConnectionCount', () async {
      const config = ConnectionConfig(
        host: 'localhost',
        port: 5432,
        database: 'worm_test',
        poolSize: 42,
      );
      final pool = PostgresConnectionPool.fromConfig(config);
      try {
        expect(pool.maxConnectionCount, 42);
      } finally {
        await pool.close();
      }
    });

    test(
      'two pools sharing one cap together respect maxTotalConnections',
      () async {
        const config = ConnectionConfig(
          host: 'localhost',
          port: 5432,
          database: 'worm_test',
          poolSize: 10,
          maxTotalConnections: 15,
        );
        final a = PostgresConnectionPool.fromConfig(config);
        final b = PostgresConnectionPool.fromConfig(config);
        try {
          expect(a.maxConnectionCount, 10);
          // Only 5 slots remained under the 15 cap after pool A.
          expect(b.maxConnectionCount, 5);
          expect(PostgresConnectionPool.isolateReservedSlots, 15);
        } finally {
          await a.close();
          await b.close();
        }
      },
    );

    test('closing a pool returns its slots to the global cap', () async {
      const config = ConnectionConfig(
        host: 'localhost',
        port: 5432,
        database: 'worm_test',
        poolSize: 10,
        maxTotalConnections: 10,
      );
      final a = PostgresConnectionPool.fromConfig(config);
      expect(PostgresConnectionPool.isolateReservedSlots, 10);
      await a.close();
      expect(PostgresConnectionPool.isolateReservedSlots, 0);
      final b = PostgresConnectionPool.fromConfig(config);
      try {
        expect(b.maxConnectionCount, 10);
      } finally {
        await b.close();
      }
    });

    test(
      'fromConfig throws ConfigurationException when cap is fully consumed',
      () async {
        const config = ConnectionConfig(
          host: 'localhost',
          port: 5432,
          database: 'worm_test',
          poolSize: 5,
          maxTotalConnections: 5,
        );
        final a = PostgresConnectionPool.fromConfig(config);
        try {
          expect(
            () => PostgresConnectionPool.fromConfig(config),
            throwsA(isA<ConfigurationException>()),
          );
        } finally {
          await a.close();
        }
      },
    );
  });
}
