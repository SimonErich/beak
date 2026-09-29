import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// Allows reading notes but no write of any kind.
final class _ReadOnlyPolicy extends BeakAllowAllPolicy {
  const _ReadOnlyPolicy();

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) => false;

  @override
  bool canUpdate(BeakPrincipal? principal, BeakModel model, Object id) => false;

  @override
  bool canDelete(BeakPrincipal? principal, BeakModel model, Object id) => false;
}

const _reader = BeakPrincipal(id: 'reader');

/// A commit the policy refuses is refused before any app hook runs: the
/// preparer (and whatever non-transactional side effect it has) never
/// executes for a write the principal may not make.
void main() {
  late WormDataSource source;
  late BeakModelRegistry registry;
  var prepared = 0;

  setUp(() async {
    prepared = 0;
    final adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = createApiRegistry();
    source = WormDataSource(registry, adapter: adapter);
  });
  tearDown(Worm.reset);

  BeakGraphCommitService service() => BeakGraphCommitService(
    registry: registry,
    source: source,
    policy: const _ReadOnlyPolicy(),
    preparePlan: (plan, transaction, principal) async {
      prepared += 1;
      return plan;
    },
  );

  Future<void> expectRefusedBeforePreparation(BeakSavePlan plan) async {
    final result = await service().commit(plan, principal: _reader);
    expect(result.complete, isFalse);
    expect(
      result.outcomes.map((outcome) => outcome.error?.code),
      contains('authorization'),
    );
    expect(prepared, 0);
  }

  test('a denied create never reaches preparePlan', () async {
    await expectRefusedBeforePreparation(
      BeakSavePlan(
        saveId: 'denied-create',
        root: const BeakRecordRef.draft('notes', 'note'),
        operations: [
          BeakSaveOperation(
            id: 'note',
            kind: BeakSaveOperationKind.create,
            target: const BeakRecordRef.draft('notes', 'note'),
            values: BeakRecord.fromRow({'title': 'No'}),
          ),
        ],
      ),
    );
  });

  test('a denied update and a denied delete never reach preparePlan', () async {
    await source.adapter.insert(
      const InsertDescriptor(
        table: 'notes',
        values: {'id': 'n1', 'title': 'Kept', 'status': 'draft'},
      ),
    );
    for (final kind in [
      BeakSaveOperationKind.update,
      BeakSaveOperationKind.delete,
    ]) {
      await expectRefusedBeforePreparation(
        BeakSavePlan(
          saveId: 'denied-${kind.name}',
          root: const BeakRecordRef.existing('notes', 'n1'),
          operations: [
            BeakSaveOperation(
              id: 'note',
              kind: kind,
              target: const BeakRecordRef.existing('notes', 'n1'),
              values: kind == BeakSaveOperationKind.update
                  ? BeakRecord.fromRow({'title': 'Changed'})
                  : const BeakRecord(values: {}),
            ),
          ],
        ),
      );
    }
    expect((await source.getOne('notes', 'n1'))?['title']?.raw, 'Kept');
  });
}
