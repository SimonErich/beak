import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_mongodb/worm_mongodb.dart';

void main() {
  group('MongoErrorMapper.fromCode', () {
    test('11000 → UniqueConstraintException with the table set', () {
      final mapped = MongoErrorMapper.fromCode(
        11000,
        message: 'E11000 duplicate key error',
        table: 'users',
      );
      expect(mapped, isA<UniqueConstraintException>());
      final typed = mapped as UniqueConstraintException;
      expect(typed.table, 'users');
      expect(typed.message, 'E11000 duplicate key error');
    });

    test('null code → QueryException', () {
      final mapped = MongoErrorMapper.fromCode(null);
      expect(mapped, isA<QueryException>());
    });

    test('unknown code → QueryException', () {
      final mapped = MongoErrorMapper.fromCode(
        42,
        message: 'mystery',
        query: 'find',
      );
      expect(mapped, isA<QueryException>());
      final typed = mapped as QueryException;
      expect(typed.query, 'find');
      expect(typed.message, 'mystery');
    });
  });

  group('MongoErrorMapper.fromWriteCommandError', () {
    test('WriteCommandError with code 11000 → UniqueConstraintException', () {
      final mapped = MongoErrorMapper.fromWriteCommandError(
        code: 11000,
        errmsg: 'duplicate key',
        table: 'users',
      );
      expect(mapped, isA<UniqueConstraintException>());
      expect((mapped as UniqueConstraintException).table, 'users');
    });

    test('non-11000 codes route to QueryException', () {
      final mapped = MongoErrorMapper.fromWriteCommandError(
        code: 26,
        errmsg: 'NamespaceNotFound',
      );
      expect(mapped, isA<QueryException>());
    });
  });

  group('MongoErrorMapper.map', () {
    test('MongoDartError with mongoCode 11000 → '
        'UniqueConstraintException', () {
      final err = MongoDartError(
        'E11000 duplicate key error on users',
        mongoCode: 11000,
      );
      final mapped = MongoErrorMapper.map(err, table: 'users');
      expect(mapped, isA<UniqueConstraintException>());
      final typed = mapped as UniqueConstraintException;
      expect(typed.table, 'users');
      expect(typed.message, contains('duplicate key'));
    });

    test('Generic MongoDartError → QueryException with original message', () {
      final err = MongoDartError('Server unreachable');
      final mapped = MongoErrorMapper.map(err, query: 'find users');
      expect(mapped, isA<QueryException>());
      final typed = mapped as QueryException;
      expect(typed.message, 'Server unreachable');
      expect(typed.query, 'find users');
    });

    test('Arbitrary thrown object → QueryException with toString message', () {
      final mapped = MongoErrorMapper.map(StateError('boom'));
      expect(mapped, isA<QueryException>());
      expect((mapped as QueryException).message, contains('boom'));
    });

    test('WormException passes through unchanged', () {
      const original = QueryException(query: 'X', message: 'Y');
      final mapped = MongoErrorMapper.map(original);
      expect(identical(mapped, original), isTrue);
    });
  });

  group('MongoErrorMapper.wrap', () {
    test('rethrows MongoDartError as the mapped WormException', () {
      expect(
        () => MongoErrorMapper.wrap(
          () async => throw MongoDartError('E11000', mongoCode: 11000),
          table: 'users',
        ),
        throwsA(isA<UniqueConstraintException>()),
      );
    });

    test('successful action returns its value unchanged', () async {
      final value = await MongoErrorMapper.wrap(() async => 42);
      expect(value, 42);
    });

    test('pre-existing WormException passes through untouched', () {
      const original = QueryException(query: 'X', message: 'Y');
      expect(
        () => MongoErrorMapper.wrap<void>(() async => throw original),
        throwsA(same(original)),
      );
    });

    test('non-Mongo error becomes a typed WormException', () {
      expect(
        () =>
            MongoErrorMapper.wrap<void>(() async => throw StateError('plain')),
        throwsA(isA<QueryException>()),
      );
    });
  });
}
