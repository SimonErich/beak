import 'package:postgres/messages.dart';
import 'package:postgres/postgres.dart';
// ignore: implementation_imports
import 'package:postgres/src/exceptions.dart'
    show buildExceptionFromErrorFields;
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

ServerException _serverException({
  required String code,
  String message = 'failure',
  String? table,
  String? column,
  String? constraint,
}) => buildExceptionFromErrorFields(<ErrorField>[
  ErrorField(ErrorFieldId.code, code),
  ErrorField(ErrorFieldId.message, message),
  if (table != null) ErrorField(ErrorFieldId.table, table),
  if (column != null) ErrorField(ErrorFieldId.column, column),
  if (constraint != null) ErrorField(ErrorFieldId.constraint, constraint),
]);

void main() {
  group('PostgresErrorMapper.fromCode', () {
    test('23505 → UniqueConstraintException with non-empty table', () {
      final mapped = PostgresErrorMapper.fromCode(
        '23505',
        message: 'duplicate key',
        table: 'users',
        column: 'email',
      );
      expect(mapped, isA<UniqueConstraintException>());
      final typed = mapped as UniqueConstraintException;
      expect(typed.table, 'users');
      expect(typed.table, isNotEmpty);
      expect(typed.column, 'email');
      expect(typed.message, 'duplicate key');
    });

    test('23505 falls back to constraint name when table missing', () {
      final mapped = PostgresErrorMapper.fromCode(
        '23505',
        constraint: 'users_email_key',
      );
      expect(mapped, isA<UniqueConstraintException>());
      expect((mapped as UniqueConstraintException).table, isNotEmpty);
    });

    test('23503 → ForeignKeyException', () {
      final mapped = PostgresErrorMapper.fromCode(
        '23503',
        message: 'fk violation',
        table: 'orders',
        column: 'customer_id',
      );
      expect(mapped, isA<ForeignKeyException>());
      final typed = mapped as ForeignKeyException;
      expect(typed.table, 'orders');
      expect(typed.column, 'customer_id');
    });

    test('40P01 → TransactionException', () {
      final mapped = PostgresErrorMapper.fromCode(
        '40P01',
        message: 'deadlock detected',
      );
      expect(mapped, isA<TransactionException>());
      expect((mapped as TransactionException).message, 'deadlock detected');
    });

    test('40001 serialisation_failure → TransactionException', () {
      final mapped = PostgresErrorMapper.fromCode('40001');
      expect(mapped, isA<TransactionException>());
    });

    test('08006 → ConnectionException with host and port populated', () {
      final mapped = PostgresErrorMapper.fromCode(
        '08006',
        message: 'connection terminated',
        host: 'db.example.com',
        port: 5432,
      );
      expect(mapped, isA<ConnectionException>());
      final typed = mapped as ConnectionException;
      expect(typed.host, 'db.example.com');
      expect(typed.port, 5432);
      expect(typed.message, 'connection terminated');
    });

    test('every connection-class 08xxx code maps to ConnectionException', () {
      for (final code in const <String>[
        '08000',
        '08001',
        '08003',
        '08004',
        '08006',
        '08P01',
      ]) {
        expect(
          PostgresErrorMapper.fromCode(code, host: 'h', port: 1),
          isA<ConnectionException>(),
          reason: 'code $code',
        );
      }
    });

    test('unknown code → QueryException', () {
      final mapped = PostgresErrorMapper.fromCode(
        '99999',
        message: 'weird error',
        query: 'SELECT 1',
      );
      expect(mapped, isA<QueryException>());
      final typed = mapped as QueryException;
      expect(typed.query, 'SELECT 1');
      expect(typed.message, 'weird error');
    });

    test('null code → QueryException', () {
      final mapped = PostgresErrorMapper.fromCode(null);
      expect(mapped, isA<QueryException>());
    });
  });

  group('PostgresErrorMapper.map(PgException …)', () {
    test('23505 ServerException → UniqueConstraintException', () {
      final pg = _serverException(
        code: '23505',
        table: 'users',
        column: 'email',
      );
      final mapped = PostgresErrorMapper.map(pg);
      expect(mapped, isA<UniqueConstraintException>());
      final typed = mapped as UniqueConstraintException;
      expect(typed.table, 'users');
      expect(typed.column, 'email');
    });

    test('23503 ServerException → ForeignKeyException', () {
      final pg = _serverException(
        code: '23503',
        table: 'orders',
        column: 'customer_id',
      );
      final mapped = PostgresErrorMapper.map(pg);
      expect(mapped, isA<ForeignKeyException>());
    });

    test('40P01 ServerException → TransactionException', () {
      final pg = _serverException(code: '40P01');
      final mapped = PostgresErrorMapper.map(pg);
      expect(mapped, isA<TransactionException>());
    });

    test(
      '08006 ServerException → ConnectionException (host/port from caller)',
      () {
        final pg = _serverException(code: '08006');
        final mapped = PostgresErrorMapper.map(
          pg,
          host: 'db.example.com',
          port: 5432,
        );
        expect(mapped, isA<ConnectionException>());
        final typed = mapped as ConnectionException;
        expect(typed.host, 'db.example.com');
        expect(typed.port, 5432);
      },
    );

    test('unknown code ServerException → QueryException', () {
      final pg = _serverException(code: '99999', message: 'huh');
      final mapped = PostgresErrorMapper.map(pg, query: 'SELECT 1');
      expect(mapped, isA<QueryException>());
      expect((mapped as QueryException).query, 'SELECT 1');
    });

    test('plain PgException (no code) → QueryException', () {
      final pg = PgException('client-side boom');
      final mapped = PostgresErrorMapper.map(pg, query: 'SELECT 1');
      expect(mapped, isA<QueryException>());
    });
  });

  group('PostgresErrorMapper.wrap', () {
    test('rethrows PgException as the mapped WormException', () async {
      final pg = _serverException(
        code: '23505',
        table: 'users',
        column: 'email',
      );
      expect(
        () => PostgresErrorMapper.wrap(() async => throw pg),
        throwsA(isA<UniqueConstraintException>()),
      );
    });

    test('non-PgException errors propagate unchanged', () async {
      expect(
        () => PostgresErrorMapper.wrap<void>(
          () async => throw StateError('boom'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('successful action returns its value unchanged', () async {
      final value = await PostgresErrorMapper.wrap(() async => 42);
      expect(value, 42);
    });
  });

  group('PostgresErrorMapper.codeOf', () {
    test('returns the SQLSTATE for a ServerException', () {
      expect(
        PostgresErrorMapper.codeOf(_serverException(code: '23505')),
        '23505',
      );
    });

    test('returns null for a plain PgException', () {
      expect(PostgresErrorMapper.codeOf(PgException('boom')), isNull);
    });
  });
}
