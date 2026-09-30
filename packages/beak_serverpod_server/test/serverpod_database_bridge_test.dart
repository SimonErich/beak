import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:serverpod/serverpod.dart'
    show
        DatabaseException,
        DatabaseForeignKeyViolationException,
        DatabaseQueryException,
        DatabaseUniqueViolationException,
        RollbackToSavepointFailedException,
        UuidValue;
import 'package:test/test.dart';
import 'package:worm/worm.dart';

enum _Speed { express }

void main() {
  group('mapServerpodDatabaseException', () {
    test('a unique violation becomes UniqueConstraintException', () {
      final mapped = mapServerpodDatabaseException(
        DatabaseUniqueViolationException(
          'duplicate key value violates unique constraint "book_isbn"',
          code: '23505',
          tableName: 'book',
          constraintName: 'book__isbn__unique_idx',
        ),
        query: 'INSERT INTO "book" …',
      );
      expect(
        mapped,
        isA<UniqueConstraintException>().having(
          (e) => e.table,
          'table',
          'book',
        ),
      );
    });

    test('a foreign key violation becomes ForeignKeyException', () {
      expect(
        mapServerpodDatabaseException(
          DatabaseForeignKeyViolationException(
            'violates foreign key constraint',
            code: '23503',
            tableName: 'book',
          ),
        ),
        isA<ForeignKeyException>(),
      );
    });

    test(
      'serialization failures and deadlocks become TransactionException',
      () {
        for (final code in ['40001', '40P01']) {
          expect(
            mapServerpodDatabaseException(
              DatabaseQueryException('x', code: code),
            ),
            isA<TransactionException>(),
            reason: code,
          );
        }
      },
    );

    test('a cancelled statement is a QueryException naming the timeout', () {
      expect(
        mapServerpodDatabaseException(
          DatabaseQueryException('canceling statement', code: '57014'),
          query: 'SELECT pg_sleep(9)',
        ),
        isA<QueryException>()
            .having((e) => e.message, 'message', contains('timeout'))
            .having((e) => e.query, 'query', 'SELECT pg_sleep(9)'),
      );
    });

    test('an uncoded database error is a QueryException', () {
      expect(
        mapServerpodDatabaseException(DatabaseException('pool closed')),
        isA<QueryException>(),
      );
      expect(
        mapServerpodDatabaseException(DatabaseQueryException('socket gone')),
        isA<QueryException>(),
      );
    });
  });

  group('guardServerpodDatabase', () {
    test('maps database errors', () {
      expect(
        guardServerpodDatabase<void>(
          () => Future.error(
            DatabaseUniqueViolationException('dup', code: '23505'),
          ),
        ),
        throwsA(isA<UniqueConstraintException>()),
      );
    });

    test('lets every other error through untouched', () {
      final signal = StateError('rollback signal');
      expect(
        guardServerpodDatabase<void>(() => Future.error(signal)),
        throwsA(same(signal)),
      );
    });

    test('a failed savepoint rollback becomes TransactionException', () {
      expect(
        guardServerpodDatabase<void>(
          () => Future.error(RollbackToSavepointFailedException('gone')),
        ),
        throwsA(isA<TransactionException>()),
      );
    });
  });

  group('serverpodParameterValue', () {
    test('sends a local instant as the same instant in UTC', () {
      final local = DateTime(2026, 9, 28, 14, 30, 5, 123, 456);
      final sent = serverpodParameterValue(local);
      expect(sent, isA<DateTime>().having((d) => d.isUtc, 'isUtc', isTrue));
      expect(sent, local.toUtc());
    });

    test('stores Duration as milliseconds, like Serverpod', () {
      expect(
        serverpodParameterValue(const Duration(minutes: 2, milliseconds: 7)),
        120007,
      );
    });

    test('stores UuidValue, Uri and BigInt as text', () {
      const uuid = '0192f5a4-9a2e-7c3a-8f1e-3b1a2c4d5e6f';
      expect(serverpodParameterValue(UuidValue.fromString(uuid)), uuid);
      expect(
        serverpodParameterValue(Uri.parse('https://x.test/a')),
        'https://x.test/a',
      );
      expect(
        serverpodParameterValue(BigInt.parse('123456789012345678901234567890')),
        '123456789012345678901234567890',
      );
    });

    test('leaves enums and plain values alone', () {
      expect(serverpodParameterValue(_Speed.express), _Speed.express);
      for (final Object? value in [null, 1, 2.5, true, 'x']) {
        expect(serverpodParameterValue(value), value);
      }
    });
  });
}
