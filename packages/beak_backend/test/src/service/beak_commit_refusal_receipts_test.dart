import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// Refuses every write and every read.
final class _DenyAll extends BeakAllowAllPolicy {
  const _DenyAll();

  @override
  bool canView(BeakPrincipal? principal, BeakModel model) => false;

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) => false;

  @override
  bool canUpdate(BeakPrincipal? principal, BeakModel model, Object id) => false;

  @override
  bool canDelete(BeakPrincipal? principal, BeakModel model, Object id) => false;
}

/// An adapter without transactions, over the in-memory one: a graph saved
/// through it is staged, with its receipt in the database.
final class _PlainAdapter extends DatabaseAdapter {
  _PlainAdapter(this.inner);

  final DatabaseAdapter inner;

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor query) =>
      inner.selectOne(query);

  @override
  Future<int> update(UpdateDescriptor update) => inner.update(update);

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor insert) =>
      inner.insert(insert);

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Refuses to create comments and nothing else.
final class _NoComments extends BeakAllowAllPolicy {
  const _NoComments();

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) =>
      model is! CommentModel;
}

BeakSavePlan _noteWithComment(String saveId) => BeakSavePlan(
  saveId: saveId,
  root: const BeakRecordRef.draft('notes', 'note'),
  operations: [
    BeakSaveOperation(
      id: 'note',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('notes', 'note'),
      values: BeakRecord.fromRow({'title': 'A note'}),
    ),
    BeakSaveOperation(
      id: 'comment',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('comments', 'comment'),
      owner: const BeakRecordRef.draft('notes', 'note'),
      relationKey: 'comments',
      values: BeakRecord.fromRow({'message': 'A comment'}),
    ),
  ],
);

/// Admits a comment only when it reads "Visible", and lets a test switch note
/// creation off between two attempts at the same save.
final class _Switchable extends BeakAllowAllPolicy implements BeakRowPolicy {
  _Switchable();

  bool notesMayBeCreated = true;

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) =>
      model is! NoteModel || notesMayBeCreated;

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is CommentModel ? CommentModel.message.eq('Visible') : null;
}

/// Lets signed-in callers write and refuses everyone else.
final class _SignedInOnly extends BeakAllowAllPolicy {
  const _SignedInOnly();

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) =>
      principal != null;
}

BeakSavePlan _note(String saveId, {String title = 'A note'}) => BeakSavePlan(
  saveId: saveId,
  root: const BeakRecordRef.draft('notes', 'note'),
  operations: [
    BeakSaveOperation(
      id: 'note',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('notes', 'note'),
      values: BeakRecord.fromRow({'title': title}),
    ),
  ],
);

/// A save the policy refuses never reached the data, so it earns no receipt:
/// storing one per attempt would let anyone who can reach the endpoint grow the
/// receipt table, and push the receipts of real saves out of a bounded store.
void main() {
  group('over a transactional worm source', () {
    late InMemoryAdapter adapter;
    late WormDataSource source;

    setUp(() async {
      Worm.seedRandom(42);
      adapter = await createApiTestDatabase();
      await const BeakCommitReceiptsMigration().up(adapter);
      source = WormDataSource(createApiRegistry(), adapter: adapter);
    });
    tearDown(Worm.reset);

    Future<int> receiptCount() => adapter.count(
      const AggregateDescriptor.count(table: BeakCommitReceiptsMigration.table),
    );

    BeakGraphCommitService serviceWith(BeakPolicy policy) =>
        BeakGraphCommitService(
          registry: createApiRegistry(),
          source: source,
          policy: policy,
        );

    test('an anonymous refusal is answered and not stored', () async {
      final service = serviceWith(const _DenyAll());

      for (var attempt = 0; attempt < 5; attempt++) {
        final result = await service.commit(_note('flood-$attempt'));

        expect(result.complete, isFalse);
        expect(result.hasUnknown, isFalse);
        expect(result.outcomes.single.reason, 'rejected');
        expect(result.outcomes.single.error?.code, 'authentication');
      }

      expect(await receiptCount(), 0);
    });

    test('nor is the refusal of a signed-in caller', () async {
      final result = await serviceWith(
        const _DenyAll(),
      ).commit(_note('signed-in'), principal: const BeakPrincipal(id: 'sam'));

      expect(result.outcomes.single.error?.code, 'authorization');
      expect(await receiptCount(), 0);
    });

    test(
      'so a refused save id is decided afresh once the rules allow it',
      () async {
        await serviceWith(const _DenyAll()).commit(_note('later'));

        final result = await serviceWith(
          const BeakAllowAllPolicy(),
        ).commit(_note('later'));

        expect(result.complete, isTrue);
        expect(await receiptCount(), 1);
      },
    );

    test('and a save the rules accept but validation rejects is still '
        'stored, for a replay to find', () async {
      final service = serviceWith(const BeakAllowAllPolicy());
      final invalid = _note('too-long', title: 'x' * 41);

      final first = await service.commit(invalid);
      final replay = await service.commit(invalid);

      expect(first.complete, isFalse);
      expect(first.outcomes.single.error?.code, 'validation');
      expect(replay.toJson(), first.toJson());
      expect(await receiptCount(), 1);
    });

    test('a refusal has no receipt to recover', () async {
      final service = serviceWith(const _DenyAll());
      await service.commit(_note('gone'));

      expect(
        () => service.recover('gone'),
        throwsA(isA<BeakNotFoundException>()),
      );
    });
  });

  group('over a source that is not transactional', () {
    late BeakModelRegistry registry;
    late InMemoryBeakDataSource source;

    setUp(() {
      registry = createApiRegistry();
      source = InMemoryBeakDataSource(registry: registry);
    });

    test(
      'a flood of refusals cannot push a real save out of the receipts',
      () async {
        const sam = BeakPrincipal(id: 'sam');
        final service = BeakGraphCommitService(
          registry: registry,
          source: source,
          policy: const _SignedInOnly(),
          maxStagedReceipts: 2,
        );
        final saved = await service.commit(_note('real'), principal: sam);
        expect(saved.complete, isTrue);

        for (var attempt = 0; attempt < 5; attempt++) {
          await service.commit(_note('flood-$attempt'));
        }

        final replay = await service.commit(_note('real'), principal: sam);
        expect(replay.toJson(), saved.toJson());
        expect(source.rowsOf('notes'), hasLength(1));
      },
    );

    test('a resumed save keeps the write it already made', () async {
      final policy = _Switchable();
      final service = BeakGraphCommitService(
        registry: registry,
        source: source,
        policy: policy,
      );
      final partial = await service.commit(_noteWithComment('resume'));
      expect(partial.outcomes.first.status, BeakWriteOutcome.applied);
      expect(partial.outcomes.last.status, BeakWriteOutcome.unapplied);

      policy.notesMayBeCreated = false;
      final resumed = await service.commit(_noteWithComment('resume'));

      expect(resumed.outcomes.first.status, BeakWriteOutcome.applied);
      expect(resumed.identities, partial.identities);
      expect(source.rowsOf('notes'), hasLength(1));
      expect(
        (await service.recover('resume')).outcomes.first.status,
        BeakWriteOutcome.applied,
      );
    });

    test('a refusal is answered, and not kept', () async {
      final service = BeakGraphCommitService(
        registry: registry,
        source: source,
        policy: const _DenyAll(),
      );

      final result = await service.commit(_note('refused'));

      expect(result.outcomes.single.error?.code, 'authentication');
      expect(
        () => service.recover('refused'),
        throwsA(isA<BeakNotFoundException>()),
      );
    });
  });

  group('over a worm source without transactions', () {
    tearDown(Worm.reset);

    test('a refusal is answered before any receipt is written', () async {
      Worm.seedRandom(42);
      final inner = await createApiTestDatabase();
      await const BeakCommitReceiptsMigration().up(inner);
      final service = BeakGraphCommitService(
        registry: createApiRegistry(),
        source: WormDataSource(
          createApiRegistry(),
          adapter: _PlainAdapter(inner),
        ),
        policy: const _DenyAll(),
      );

      final result = await service.commit(_note('plain-flood'));

      expect(result.mode, BeakSaveMode.staged);
      expect(result.hasUnknown, isFalse);
      expect(result.outcomes.single.error?.code, 'authentication');
      expect(
        await inner.count(
          const AggregateDescriptor.count(
            table: BeakCommitReceiptsMigration.table,
          ),
        ),
        0,
      );
    });

    test(
      'a refusal that is not the policy\'s is stored, and retried',
      () async {
        Worm.seedRandom(42);
        final inner = await createApiTestDatabase();
        await const BeakCommitReceiptsMigration().up(inner);
        final service = BeakGraphCommitService(
          registry: createApiRegistry(),
          source: WormDataSource(
            createApiRegistry(),
            adapter: _PlainAdapter(inner),
          ),
          policy: BeakPolicies(
            rules: [
              BeakModelRules(
                const NoteModel(),
                read: BeakAccess.anyone,
                write: BeakAccess.anyone,
                readOnlyFields: {NoteModel.rating},
              ),
            ],
          ),
        );
        final plan = BeakSavePlan(
          saveId: 'read-only',
          root: const BeakRecordRef.draft('notes', 'note'),
          operations: [
            BeakSaveOperation(
              id: 'note',
              kind: BeakSaveOperationKind.create,
              target: const BeakRecordRef.draft('notes', 'note'),
              values: BeakRecord.fromRow({'title': 'A note', 'rating': 5}),
            ),
          ],
        );

        final first = await service.commit(plan);
        final replay = await service.commit(plan);

        expect(first.outcomes.single.error?.code, 'validation');
        expect(replay.outcomes.single.status, BeakWriteOutcome.unapplied);
        expect(replay.outcomes.single.error?.code, 'validation');
        expect(
          await inner.count(
            const AggregateDescriptor.count(
              table: BeakCommitReceiptsMigration.table,
            ),
          ),
          1,
        );
        expect(
          await inner.count(const AggregateDescriptor.count(table: 'notes')),
          0,
        );
      },
    );

    test(
      'a refusal in a later operation leaves the earlier ones unwritten',
      () async {
        Worm.seedRandom(42);
        final inner = await createApiTestDatabase();
        await const BeakCommitReceiptsMigration().up(inner);
        final source = WormDataSource(
          createApiRegistry(),
          adapter: _PlainAdapter(inner),
        );
        final service = BeakGraphCommitService(
          registry: createApiRegistry(),
          source: source,
          policy: const _NoComments(),
        );

        final result = await service.commit(_noteWithComment('all-or-nothing'));

        expect(
          result.outcomes.map((outcome) => outcome.status),
          everyElement(BeakWriteOutcome.unapplied),
        );
        expect(
          await inner.count(const AggregateDescriptor.count(table: 'notes')),
          0,
        );
      },
    );
  });
}
