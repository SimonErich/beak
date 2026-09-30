import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// Admits only the notes titled "Mine".
final class _MineOnly extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _MineOnly();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is NoteModel ? NoteModel.title.eq('Mine') : null;
}

BeakSavePlan _createMine() => BeakSavePlan(
  saveId: 'prepared',
  root: const BeakRecordRef.draft('notes', 'note'),
  operations: [
    BeakSaveOperation(
      id: 'note',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('notes', 'note'),
      values: BeakRecord.fromRow({'title': 'Mine'}),
    ),
  ],
);

/// What a preparer sees of the source it is handed.
void main() {
  late WormDataSource source;
  late BeakModelRegistry registry;
  const principal = BeakPrincipal(id: 'sam');

  setUp(() async {
    final adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = createApiRegistry();
    source = WormDataSource(registry, adapter: adapter);
    await source.create(
      'notes',
      BeakRecord.fromRow({'id': 'mine', 'title': 'Mine'}),
    );
    await source.create(
      'notes',
      BeakRecord.fromRow({'id': 'theirs', 'title': 'Theirs'}),
    );
  });
  tearDown(Worm.reset);

  BeakGraphCommitService serviceWith(
    Future<void> Function(WormDataSource transaction, BeakSavePlan plan)
    inspect,
  ) => BeakGraphCommitService(
    registry: registry,
    source: source,
    policy: const _MineOnly(),
    preparePlan: (plan, transaction, principal) async {
      await inspect(transaction, plan);
      return plan;
    },
  );

  test('an ordinary source has no read authorization', () {
    expect(source.authorizeRead, isNull);
  });

  test('the transaction handed to a preparer carries the caller\'s', () async {
    WormDataSource? seen;
    final service = serviceWith(
      (transaction, plan) async => seen = transaction,
    );

    await service.commit(_createMine(), principal: principal);

    expect(seen?.authorizeRead, isNotNull);
  });

  test('a candidate graph opened with it refuses a record the caller may not '
      'read', () async {
    final service = serviceWith((transaction, plan) async {
      final graph = await BeakCandidateGraph.open(
        plan: plan,
        source: transaction,
        registry: registry,
        authorizeRead: transaction.authorizeRead,
      );
      await graph.load(const BeakRecordRef.existing('notes', 'theirs'));
    });

    final result = await service.commit(_createMine(), principal: principal);

    expect(result.complete, isFalse);
    expect(result.outcomes.first.error?.code, 'not_found');
    expect(
      (await source.query(const BeakQuerySpec(table: 'notes'))).total,
      2,
      reason: 'the refused save wrote nothing',
    );
  });

  test('and lets it read a record inside its scope', () async {
    final service = serviceWith((transaction, plan) async {
      final graph = await BeakCandidateGraph.open(
        plan: plan,
        source: transaction,
        registry: registry,
        authorizeRead: transaction.authorizeRead,
      );
      await graph.load(const BeakRecordRef.existing('notes', 'mine'));
    });

    final result = await service.commit(_createMine(), principal: principal);

    expect(result.complete, isTrue);
  });

  test(
    'reads without it stay unscoped, for rules that count everything',
    () async {
      var visible = 0;
      final service = serviceWith((transaction, plan) async {
        visible = (await transaction.query(
          const BeakQuerySpec(table: 'notes'),
        )).total;
      });

      await service.commit(_createMine(), principal: principal);

      expect(visible, 2);
    },
  );
}
