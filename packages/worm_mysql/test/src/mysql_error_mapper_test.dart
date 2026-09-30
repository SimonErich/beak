import 'package:mysql_client_plus/exception.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_mysql/worm_mysql.dart';

void main() {
  group('MysqlErrorMapper.fromCode', () {
    test('1062 → UniqueConstraintException with non-empty table', () {
      final mapped = MysqlErrorMapper.fromCode(
        1062,
        message: 'duplicate entry',
        constraint: 'users.PRIMARY',
        column: 'id',
      );
      expect(mapped, isA<UniqueConstraintException>());
      final typed = mapped as UniqueConstraintException;
      expect(typed.table, 'users.PRIMARY');
      expect(typed.table, isNotEmpty);
      expect(typed.message, 'duplicate entry');
    });

    test('1169 also maps to UniqueConstraintException', () {
      expect(
        MysqlErrorMapper.fromCode(1169, constraint: 'uq'),
        isA<UniqueConstraintException>(),
      );
    });

    test('every foreign-key code maps to ForeignKeyException', () {
      for (final code in const <int>[1451, 1452, 1216, 1217]) {
        expect(
          MysqlErrorMapper.fromCode(code, message: 'fk'),
          isA<ForeignKeyException>(),
          reason: 'code $code',
        );
      }
    });

    test('a value too long, out of range or malformed → DataException', () {
      for (final code in const <int>[1406, 1264, 1265, 1292, 1366]) {
        expect(
          MysqlErrorMapper.fromCode(code, message: 'bad value', column: 'name'),
          isA<DataException>(),
          reason: 'code $code',
        );
      }
    });

    test('NOT NULL and CHECK violations → CheckConstraintException', () {
      for (final code in const <int>[1048, 3819, 4025]) {
        expect(
          MysqlErrorMapper.fromCode(code, message: 'rule', column: 'price'),
          isA<CheckConstraintException>(),
          reason: 'code $code',
        );
      }
    });

    test('1213 deadlock and 1205 lock-wait map to TransactionException', () {
      expect(
        MysqlErrorMapper.fromCode(1213, message: 'deadlock'),
        isA<TransactionException>(),
      );
      expect(
        MysqlErrorMapper.fromCode(1205, message: 'lock wait timeout'),
        isA<TransactionException>(),
      );
    });

    test('every connection code maps to ConnectionException', () {
      for (final code in const <int>[
        1042,
        1043,
        1045,
        2002,
        2003,
        2006,
        2013,
      ]) {
        final mapped = MysqlErrorMapper.fromCode(
          code,
          host: 'db.example.com',
          port: 3306,
        );
        expect(mapped, isA<ConnectionException>(), reason: 'code $code');
        final typed = mapped as ConnectionException;
        expect(typed.host, 'db.example.com');
        expect(typed.port, 3306);
      }
    });

    test('unknown code → QueryException', () {
      final mapped = MysqlErrorMapper.fromCode(
        9999,
        message: 'weird error',
        query: 'SELECT 1',
      );
      expect(mapped, isA<QueryException>());
      final typed = mapped as QueryException;
      expect(typed.query, 'SELECT 1');
      expect(typed.message, 'weird error');
    });

    test('null code → QueryException', () {
      expect(MysqlErrorMapper.fromCode(null), isA<QueryException>());
    });
  });

  group('MysqlErrorMapper.map(MySQLException …)', () {
    test(
      'server 1062 → UniqueConstraintException, constraint from message',
      () {
        const ex = MySQLServerException(
          "Duplicate entry '1' for key 'users.PRIMARY'",
          1062,
        );
        final mapped = MysqlErrorMapper.map(ex);
        expect(mapped, isA<UniqueConstraintException>());
        // The "for key '…'" key name is parsed out as the table label.
        expect((mapped as UniqueConstraintException).table, 'users.PRIMARY');
      },
    );

    test('server 1452 → ForeignKeyException', () {
      const ex = MySQLServerException('fk fails', 1452);
      expect(MysqlErrorMapper.map(ex), isA<ForeignKeyException>());
    });

    test('server 2006 → ConnectionException (host/port from caller)', () {
      const ex = MySQLServerException('server gone away', 2006);
      final mapped = MysqlErrorMapper.map(ex, host: 'h', port: 3306);
      expect(mapped, isA<ConnectionException>());
      final typed = mapped as ConnectionException;
      expect(typed.host, 'h');
      expect(typed.port, 3306);
    });

    test('client-side exception (no code) → QueryException', () {
      const ex = MySQLClientException('connection closed');
      final mapped = MysqlErrorMapper.map(ex, query: 'SELECT 1');
      expect(mapped, isA<QueryException>());
      expect((mapped as QueryException).query, 'SELECT 1');
    });
  });

  group('MysqlErrorMapper.wrap', () {
    test('rethrows a server exception as the mapped WormException', () {
      expect(
        () => MysqlErrorMapper.wrap<void>(
          () async => throw const MySQLServerException('dup', 1062),
        ),
        throwsA(isA<UniqueConstraintException>()),
      );
    });

    test('non-MySQL errors propagate unchanged', () {
      expect(
        () => MysqlErrorMapper.wrap<void>(() async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );
    });

    test('successful action returns its value unchanged', () async {
      final value = await MysqlErrorMapper.wrap(() async => 42);
      expect(value, 42);
    });
  });

  group('MysqlErrorMapper.codeOf', () {
    test('returns the error number for a server exception', () {
      expect(
        MysqlErrorMapper.codeOf(const MySQLServerException('x', 1062)),
        1062,
      );
    });

    test('returns null for a client exception', () {
      expect(
        MysqlErrorMapper.codeOf(const MySQLClientException('boom')),
        isNull,
      );
    });
  });
}
