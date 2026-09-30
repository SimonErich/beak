import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// An adapter whose database refuses every write to `notes` and `labels` with
/// [error], the way a constraint does: before anything is stored.
final class _RefusingAdapter extends DatabaseAdapter {
  _RefusingAdapter(this.inner, this.error);

  final DatabaseAdapter inner;
  final Object error;

  static bool _refuses(String table) => table == 'notes' || table == 'labels';

  @override
  AdapterCapabilities get capabilities => inner.capabilities;

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      inner.transaction((tx) => action(_RefusingAdapter(tx, error)));

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor insert) =>
      _refuses(insert.table) ? Future.error(error) : inner.insert(insert);

  @override
  Future<int> update(UpdateDescriptor update) =>
      _refuses(update.table) ? Future.error(error) : inner.update(update);

  @override
  Future<int> delete(DeleteDescriptor delete) =>
      _refuses(delete.table) ? Future.error(error) : inner.delete(delete);

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor query) =>
      inner.selectOne(query);

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor query) =>
      inner.select(query);

  @override
  Future<int> count(AggregateDescriptor query) => inner.count(query);

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final DateTime _stamp = DateTime.utc(2026, 1, 2, 3, 4, 5);

BeakSavePlan _plan(
  BeakSaveOperationKind kind, {
  String table = 'notes',
  String id = 'kept',
  DateTime? expectedUpdatedAt,
}) => BeakSavePlan(
  saveId: 'refused-${kind.name}-$table-${expectedUpdatedAt != null}',
  root: kind == BeakSaveOperationKind.create
      ? BeakRecordRef.draft(table, 'draft')
      : BeakRecordRef.existing(table, id),
  operations: [
    BeakSaveOperation(
      id: 'op',
      kind: kind,
      target: kind == BeakSaveOperationKind.create
          ? BeakRecordRef.draft(table, 'draft')
          : BeakRecordRef.existing(table, id),
      values: kind == BeakSaveOperationKind.delete
          ? null
          : BeakRecord.fromRow(
              table == 'labels' ? {'name': 'A name'} : {'title': 'A title'},
            ),
      expectedUpdatedAt: expectedUpdatedAt,
    ),
  ],
);

/// What a client is told when the database itself turns a write down.
void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    await adapter.insert(
      InsertDescriptor(
        table: 'notes',
        values: {'id': 'kept', 'title': 'Kept', 'updated_at': _stamp},
      ),
    );
    await adapter.insert(
      const InsertDescriptor(
        table: 'labels',
        values: {'id': 'label', 'name': 'Label'},
      ),
    );
  });
  tearDown(Worm.reset);

  Future<BeakSaveResult> commitRefusedBy(Object error, BeakSavePlan plan) =>
      BeakGraphCommitService(
        registry: createApiRegistry(),
        source: WormDataSource(
          createApiRegistry(),
          adapter: _RefusingAdapter(adapter, error),
        ),
      ).commit(plan);

  const secret = 'notes_secret_constraint_name';

  group('through the data source', () {
    test('a referenced row that cannot be removed is a conflict', () async {
      final result = await commitRefusedBy(
        const ForeignKeyException(
          table: 'labels',
          column: 'label_id',
          message: secret,
        ),
        _plan(BeakSaveOperationKind.delete, table: 'labels', id: 'label'),
      );

      final outcome = result.outcomes.single;
      expect(outcome.status, BeakWriteOutcome.unapplied);
      expect(outcome.reason, 'rejected');
      expect(outcome.error?.code, 'conflict');
      expect(outcome.error?.message, isNot(contains(secret)));
    });

    test('a value the database cannot hold names its field', () async {
      final result = await commitRefusedBy(
        const DataException(table: 'notes', column: 'title', message: secret),
        _plan(BeakSaveOperationKind.update),
      );

      final outcome = result.outcomes.single;
      expect(outcome.status, BeakWriteOutcome.unapplied);
      expect(outcome.error?.code, 'validation');
      expect(outcome.error?.fieldErrors.keys, ['title']);
      expect(outcome.error?.message, isNot(contains(secret)));
    });
  });

  group('through a version precondition, which writes with SQL of its own', () {
    test('a value the database cannot hold is a validation failure', () async {
      final result = await commitRefusedBy(
        const DataException(table: 'notes', column: 'title', message: secret),
        _plan(BeakSaveOperationKind.update, expectedUpdatedAt: _stamp),
      );

      final outcome = result.outcomes.single;
      expect(outcome.status, BeakWriteOutcome.unapplied);
      expect(outcome.reason, 'rejected');
      expect(outcome.error?.code, 'validation');
      expect(outcome.error?.fieldErrors.keys, ['title']);
      expect(outcome.error?.message, isNot(contains(secret)));
    });

    test('a check that fails names only a column the model has', () async {
      final result = await commitRefusedBy(
        const CheckConstraintException(
          table: 'notes',
          column: 'internal_flag',
          message: secret,
        ),
        _plan(BeakSaveOperationKind.update, expectedUpdatedAt: _stamp),
      );

      expect(result.outcomes.single.error?.code, 'validation');
      expect(result.outcomes.single.error?.fieldErrors, isEmpty);
      expect(result.outcomes.single.error?.message, isNot(contains(secret)));
    });

    test('a foreign key that points nowhere names its field', () async {
      final result = await commitRefusedBy(
        const ForeignKeyException(
          table: 'notes',
          column: 'author_id',
          message: secret,
        ),
        _plan(BeakSaveOperationKind.update, expectedUpdatedAt: _stamp),
      );

      final outcome = result.outcomes.single;
      expect(outcome.status, BeakWriteOutcome.unapplied);
      expect(outcome.error?.code, 'validation');
      expect(outcome.error?.fieldErrors.keys, ['author_id']);
      expect(outcome.error?.message, isNot(contains(secret)));
    });

    test('a delete a foreign key stops is a conflict', () async {
      final result = await commitRefusedBy(
        const ForeignKeyException(
          table: 'notes',
          column: 'author_id',
          message: secret,
        ),
        _plan(BeakSaveOperationKind.delete, expectedUpdatedAt: _stamp),
      );

      final outcome = result.outcomes.single;
      expect(outcome.status, BeakWriteOutcome.unapplied);
      expect(outcome.error?.code, 'conflict');
      expect(outcome.error?.message, isNot(contains(secret)));
    });

    test('a unique value already taken is a conflict', () async {
      final result = await commitRefusedBy(
        const UniqueConstraintException(
          table: 'notes',
          column: 'title',
          message: secret,
        ),
        _plan(BeakSaveOperationKind.update, expectedUpdatedAt: _stamp),
      );

      expect(result.outcomes.single.error?.code, 'conflict');
      expect(result.outcomes.single.error?.message, isNot(contains(secret)));
    });
  });

  test(
    'a failure nobody can classify stays unknown, and is not explained',
    () async {
      final result = await commitRefusedBy(
        StateError(secret),
        _plan(BeakSaveOperationKind.update, expectedUpdatedAt: _stamp),
      );

      final outcome = result.outcomes.single;
      expect(outcome.error?.code, 'unknown');
      expect(outcome.error?.message, isNot(contains(secret)));
    },
  );
}
