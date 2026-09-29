import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:serverpod/serverpod.dart'
    show DatabaseUniqueViolationException, Transaction, UuidValue;
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import 'support/fake_serverpod.dart';

/// Database-free checks over a fake Session. The adapter's behaviour against
/// a real Serverpod database is proven in the example project's integration
/// suite.
void main() {
  late FakeSession session;
  late FakeDatabase database;
  late ServerpodSessionAdapter adapter;

  setUp(() {
    session = FakeSession();
    database = session.fakeDatabase;
    adapter = ServerpodSessionAdapter(statementTimeoutInSeconds: 12);
  });

  Future<T> inSession<T>(Future<T> Function() body) =>
      BeakServerpod.runInSession(session, body);

  const bookById = QueryDescriptor(
    table: 'book',
    where: LeafNode(
      Predicate(fieldName: 'priceInCents', operator: Operator.gt, value: 100),
    ),
  );

  group('BeakServerpod zone', () {
    test('has no session outside runInSession', () {
      expect(BeakServerpod.currentSessionOrNull, isNull);
      expect(() => BeakServerpod.currentSession, throwsStateError);
    });

    test('a zone adapter refuses to run without a session', () {
      expect(
        () => adapter.select(bookById),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('runInSession'),
          ),
        ),
      );
    });

    test('the zone carries the session across async gaps', () async {
      await inSession(() async {
        await Future<void>.delayed(Duration.zero);
        expect(BeakServerpod.currentSession, same(session));
      });
    });

    test('sessionOf and transactionOf reject foreign adapters', () {
      expect(
        () => BeakServerpod.sessionOf(InMemoryAdapter()),
        throwsArgumentError,
      );
      expect(
        () => BeakServerpod.transactionOf(adapter),
        throwsArgumentError,
        reason: 'a root adapter is not inside a transaction',
      );
    });

    test('a pinned adapter ignores the zone', () async {
      final other = FakeSession();
      other.fakeDatabase.queryReplies.add([
        {'id': 1},
      ]);

      final rows = await inSession(
        () => ServerpodSessionAdapter.forSession(other).select(bookById),
      );

      expect(rows, [
        {'id': 1},
      ]);
      expect(database.statements, isEmpty);
      expect(other.fakeDatabase.statements, hasLength(1));
    });
  });

  group('statements', () {
    test(
      'compile with quoted identifiers, \$n placeholders and a timeout',
      () async {
        database.queryReplies.add([
          {'id': 7, 'title': 'Moomin'},
        ]);

        final rows = await inSession(() => adapter.select(bookById));

        expect(rows, [
          {'id': 7, 'title': 'Moomin'},
        ]);
        final statement = database.statements.single;
        expect(statement.sql, contains('"book"'));
        expect(statement.sql, contains('"priceInCents"'));
        expect(statement.sql, contains(r'$1'));
        expect(statement.parameters, [100]);
        expect(statement.timeoutInSeconds, 12);
        expect(statement.transaction, isNull);
      },
    );

    test('selectOne asks for one row and answers null for none', () async {
      expect(await inSession(() => adapter.selectOne(bookById)), isNull);
      expect(database.statements.single.sql, contains('LIMIT 1'));
    });

    test('insert returns the row the database sent back', () async {
      database.queryReplies.add([
        {'id': 3},
      ]);

      final row = await inSession(
        () => adapter.insert(
          const InsertDescriptor(table: 'book', values: {'title': 'Moomin'}),
        ),
      );

      expect(row, {'id': 3});
      expect(database.statements.single.sql, contains('INSERT INTO "book"'));
    });

    test('an insert that returns nothing is a QueryException', () {
      expect(
        inSession(
          () => adapter.insert(
            const InsertDescriptor(table: 'book', values: {'title': 'x'}),
          ),
        ),
        throwsA(isA<QueryException>()),
      );
    });

    test('insertMany, update and delete run one statement each', () async {
      database.queryReplies.add([
        {'id': 1},
        {'id': 2},
      ]);
      final inserted = await inSession(
        () => adapter.insertMany(
          const InsertManyDescriptor(
            table: 'book',
            rows: [
              {'title': 'a'},
              {'title': 'b'},
            ],
          ),
        ),
      );
      database.executeReply = 4;
      final updated = await inSession(
        () => adapter.update(
          const UpdateDescriptor(table: 'book', values: {'title': 'c'}),
        ),
      );
      final deleted = await inSession(
        () => adapter.delete(const DeleteDescriptor(table: 'book')),
      );

      expect(inserted, hasLength(2));
      expect(updated, 4);
      expect(deleted, 4);
      expect(database.statements, hasLength(3));
    });

    test('aggregates read the columns the compiler names', () async {
      const count = AggregateDescriptor.count(table: 'book');
      database.queryReplies.add([
        {'count': 3},
      ]);
      expect(await inSession(() => adapter.count(count)), 3);

      const sum = AggregateDescriptor(
        table: 'book',
        function: AggregateFunction.sum,
        column: 'price',
      );
      database.queryReplies.add([
        {'sum': 12},
      ]);
      expect(await inSession(() => adapter.sum(sum)), 12);

      const avg = AggregateDescriptor(
        table: 'book',
        function: AggregateFunction.avg,
        column: 'price',
      );
      database.queryReplies.add([
        {'avg': 2.5},
      ]);
      expect(await inSession(() => adapter.avg(avg)), 2.5);

      database.queryReplies
        ..add([
          {'min': 1},
        ])
        ..add([
          {'max': 9},
        ])
        ..add(const []);
      expect(await inSession(() => adapter.min(sum)), 1);
      expect(await inSession(() => adapter.max(sum)), 9);
      expect(await inSession(() => adapter.min(sum)), isNull);
    });

    test('grouped aggregates map group to value', () async {
      database.queryReplies.add([
        {'group': 'a', 'value': 2},
        {'group': 'b', 'value': 5},
        {'group': 'c', 'value': null},
      ]);

      final grouped = await inSession(
        () => adapter.aggregateGrouped(
          const AggregateDescriptor.count(table: 'book', groupBy: 'author'),
        ),
      );

      expect(grouped, {'a': 2, 'b': 5});
    });

    test('raw statements pass through', () async {
      database.queryReplies.add([
        {'one': 1},
      ]);
      expect(await inSession(() => adapter.rawQuery('SELECT 1', const [])), [
        {'one': 1},
      ]);
      expect(await inSession(() => adapter.rawExecute('DELETE', const [])), 1);
      expect(database.statements.first.parameters, isNull);
    });

    test('a stream yields the rows once listened to', () async {
      database.queryReplies.add([
        {'id': 1},
        {'id': 2},
      ]);

      final rows = await inSession(() => adapter.stream(bookById).toList());

      expect(rows, hasLength(2));
    });

    test('explain hands the plan to the parser as JSON', () async {
      database.queryReplies.add([
        {
          'QUERY PLAN': [
            {
              'Plan': {'Node Type': 'Seq Scan', 'Relation Name': 'book'},
            },
          ],
        },
      ]);

      final plan = await inSession(() => adapter.explain(bookById));

      expect(
        database.statements.single.sql,
        startsWith('EXPLAIN (FORMAT JSON)'),
      );
      expect(plan.usesIndex, isFalse);
      expect(plan.scannedTables, ['book']);
    });

    test('parameters are stored the way Serverpod stores them', () async {
      final local = DateTime(2026, 9, 28, 14, 30);
      await inSession(
        () => adapter.update(
          UpdateDescriptor(
            table: 'book',
            values: {
              'publishedAt': local,
              'loan': const Duration(seconds: 2),
              'ref': UuidValue.fromString(
                '0192f5a4-9a2e-7c3a-8f1e-3b1a2c4d5e6f',
              ),
            },
          ),
        ),
      );

      expect(database.statements.single.parameters, [
        local.toUtc(),
        2000,
        '0192f5a4-9a2e-7c3a-8f1e-3b1a2c4d5e6f',
      ]);
    });

    test('a database error becomes the worm exception Beak catches', () {
      database.failNextStatement = DatabaseUniqueViolationException(
        'duplicate key',
        code: '23505',
        tableName: 'book',
      );

      expect(
        inSession(() => adapter.select(bookById)),
        throwsA(isA<UniqueConstraintException>()),
      );
    });
  });

  group('transactions', () {
    test('open one Serverpod transaction and pin the callback to it', () async {
      await inSession(
        () => adapter.transaction((tx) async {
          expect(BeakServerpod.sessionOf(tx), same(session));
          final transaction = BeakServerpod.transactionOf(tx);
          await tx.update(
            const UpdateDescriptor(table: 'book', values: {'title': 'x'}),
          );
          expect(database.statements.single.transaction, same(transaction));
        }),
      );

      expect(database.transactions, hasLength(1));
    });

    test('a nested transaction is a savepoint, not a flattened one', () async {
      await inSession(
        () => adapter.transaction((outer) async {
          await outer.transaction((inner) async {
            expect(
              BeakServerpod.transactionOf(inner),
              same(BeakServerpod.transactionOf(outer)),
            );
          });
        }),
      );

      expect(database.transactions, hasLength(1));
      final savepoint = database.transactions.single.savepoints.single;
      expect(savepoint.released, isTrue);
      expect(savepoint.rolledBack, isFalse);
    });

    test('a failing nested transaction rolls back only its own work', () async {
      await inSession(
        () => adapter.transaction((outer) async {
          await expectLater(
            outer.transaction<void>((_) => throw StateError('inner')),
            throwsStateError,
          );
        }),
      );

      expect(database.transactions.single.savepoints.single.rolledBack, isTrue);
    });

    test('a savepoint that cannot roll back poisons the transaction', () {
      final future = inSession(
        () => adapter.transaction((outer) async {
          (BeakServerpod.transactionOf(outer) as FakeTransaction)
                  .failSavepointRollback =
              true;
          await outer.transaction<void>((_) => throw StateError('inner'));
        }),
      );

      expect(future, throwsA(isA<TransactionException>()));
    });

    test('an error at COMMIT is mapped like one mid-transaction', () {
      database.failCommit = DatabaseUniqueViolationException(
        'deferred',
        code: '23505',
        tableName: 'beak_commit_receipt',
      );

      expect(
        inSession(() => adapter.transaction((_) async => 'done')),
        throwsA(isA<UniqueConstraintException>()),
      );
    });

    test('the callback\'s own exceptions pass through untouched', () {
      final signal = StateError('rollback signal');

      expect(
        inSession(() => adapter.transaction<void>((_) => throw signal)),
        throwsA(same(signal)),
      );
    });
  });

  group('schema ownership', () {
    test('Serverpod owns DDL and introspection', () {
      expect(
        adapter.executeSchema(const SchemaDescriptor.dropTable(table: 'book')),
        throwsA(isA<UnsupportedOperationException>()),
      );
      expect(
        adapter.introspectSchema(),
        throwsA(isA<UnsupportedOperationException>()),
      );
      expect(adapter.capabilities.supportsSchemaIntrospection, isFalse);
      expect(adapter.capabilities.supportsTransactions, isTrue);
      expect(adapter.capabilities.supportsSavepoints, isTrue);
    });

    test('there is no connection to open or close', () async {
      await adapter.connect();
      await adapter.disconnect();
      expect(database.statements, isEmpty);
    });

    test('compileToString renders quoted identifiers', () {
      expect(adapter.compileToString(bookById), contains('"priceInCents"'));
      expect(adapter.compiler, isNotNull);
    });
  });

  test('typed ORM code reaches the transaction it must join', () async {
    Transaction? seen;
    await inSession(
      () => adapter.transaction((tx) async {
        seen = BeakServerpod.transactionOf(tx);
      }),
    );
    expect(seen, same(database.transactions.single));
  });
}
