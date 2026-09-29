import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

BeakSavePlan _plan() => BeakSavePlan(
  saveId: 'prepared-note',
  root: const BeakRecordRef.draft('notes', 'note'),
  operations: [
    BeakSaveOperation(
      id: 'note',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('notes', 'note'),
      values: BeakRecord.fromRow({'title': 'Client title'}),
    ),
  ],
);

final class _DefaultNote extends BeakModel {
  const _DefaultNote();
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => [
    ...NoteColumns.values.where((column) => column.key != 'status'),
    const BeakEnumColumn<NoteStatus>(
      key: 'status',
      label: 'Status',
      values: NoteStatus.values,
      defaultValue: NoteStatus.draft,
      rules: [BeakRequired()],
    ),
  ];
}

void main() {
  late WormDataSource source;
  setUp(() async {
    final adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    source = WormDataSource(createApiRegistry(), adapter: adapter);
  });
  tearDown(Worm.reset);

  test(
    'graph creation applies model enum defaults before required validation',
    () async {
      final registry = BeakModelRegistry()..register(const _DefaultNote());
      final service = BeakGraphCommitService(
        registry: registry,
        source: WormDataSource(registry, adapter: source.adapter),
      );
      final result = await service.commit(_plan());
      expect(result.complete, isTrue);
      expect(result.rootRecord?['status']?.raw, 'draft');
    },
  );

  test('preparation and added operations share the commit receipt', () async {
    var calls = 0;
    final service = BeakGraphCommitService(
      registry: createApiRegistry(),
      source: source,
      preparePlan: (plan, transaction, principal) async {
        calls++;
        return BeakSavePlan(
          saveId: plan.saveId,
          root: plan.root,
          operations: [
            BeakSaveOperation(
              id: 'note',
              kind: BeakSaveOperationKind.create,
              target: plan.root,
              values: BeakRecord.fromRow({'title': 'Authoritative title'}),
            ),
            BeakSaveOperation(
              id: 'derived-comment',
              kind: BeakSaveOperationKind.create,
              target: const BeakRecordRef.draft('comments', 'comment'),
              owner: plan.root,
              relationKey: 'comments',
              values: BeakRecord.fromRow({'message': 'Calculated'}),
            ),
          ],
        );
      },
    );
    final result = await service.commit(_plan());
    expect(result.complete, isTrue);
    expect(result.rootRecord?['title']?.raw, 'Authoritative title');
    expect((await service.commit(_plan())).toJson(), result.toJson());
    expect((await service.recover('prepared-note')).toJson(), result.toJson());
    expect(calls, 1);
    expect(
      (await source.query(const BeakQuerySpec(table: 'comments'))).total,
      1,
    );
  });

  // --8<-- [start:preparerRollbackTest]
  test('a rejected preparation rolls back its writes as well', () async {
    final service = BeakGraphCommitService(
      registry: createApiRegistry(),
      source: source,
      preparePlan: (plan, transaction, principal) async {
        await transaction.create(
          'notes',
          BeakRecord.fromRow({'id': 'side-effect', 'title': 'Rollback'}),
        );
        throw const BeakValidationException('Invalid invoice');
      },
    );
    final result = await service.commit(_plan());
    expect(result.complete, isFalse);
    expect(result.hasUnknown, isFalse);
    expect(result.outcomes.single.error?.code, 'validation');
    expect((await service.recover('prepared-note')).toJson(), result.toJson());
    expect((await source.query(const BeakQuerySpec(table: 'notes'))).total, 0);
  });
  // --8<-- [end:preparerRollbackTest]

  test('preparers must retain the request identity', () async {
    final service = BeakGraphCommitService(
      registry: createApiRegistry(),
      source: source,
      preparePlan: (plan, transaction, principal) async => BeakSavePlan(
        saveId: 'different-request',
        root: plan.root,
        operations: plan.operations,
      ),
    );
    await expectLater(
      service.commit(_plan()),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect((await source.query(const BeakQuerySpec(table: 'notes'))).total, 0);
  });
}
