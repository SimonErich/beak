import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:beak_backend/src/service/beak_resource_service.dart';

final class _Model extends BeakModel {
  const _Model();
  @override
  String get table => 'records';
  @override
  String get displayColumnKey => 'name';
  @override
  bool get softDeletes => true;
  @override
  String get createdAtColumnKey => 'createdAt';
  @override
  String get updatedAtColumnKey => 'updatedAt';
  @override
  String get deletedAtColumnKey => 'deletedAt';
  @override
  String get isDeletedColumnKey => 'isDeleted';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
    BeakIntColumn(
      key: 'version',
      label: 'Version',
      defaultValue: 0,
      rules: [BeakMin(0)],
    ),
    BeakDateTimeColumn(key: 'createdAt', label: 'Created'),
    BeakDateTimeColumn(key: 'updatedAt', label: 'Updated'),
    BeakDateTimeColumn(key: 'deletedAt', label: 'Deleted'),
    BeakBoolColumn(key: 'isDeleted', label: 'Deleted', defaultValue: false),
  ];
}

final class _ServerOwnsVersion extends BeakAllowAllPolicy
    implements BeakReadOnlyFieldPolicy {
  @override
  bool isFieldReadOnly(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) => field.key == 'version';
}

final class _Migration extends Migration {
  const _Migration();
  @override
  String get name => 'custom-lifecycle';
  @override
  Future<void> upSchema(Schema schema) => schema.create(
    'records',
    (table) => BeakBlueprint.defineColumns(table, const _Model()),
  );
  @override
  Future<void> downSchema(Schema schema) => schema.drop('records');
}

void main() {
  const model = _Model();
  final now = DateTime.utc(2026, 10, 3);
  late InMemoryAdapter adapter;
  late BeakModelRegistry registry;
  late WormDataSource source;
  late BeakResourceService service;
  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    registry = BeakModelRegistry()..register(model);
    await MigrationRunner(
      adapter: adapter,
      migrations: [const _Migration()],
    ).migrate();
    await const BeakCommitReceiptsMigration().up(adapter);
    source = WormDataSource(registry, adapter: adapter, now: () => now);
    service = BeakResourceService(
      model,
      source,
      now: () => now,
      generateId: () => 'r',
    );
  });
  tearDown(Worm.reset);

  test('create/update stamp configured lifecycle fields', () async {
    final created = await service.create(BeakRecord.fromRow({'name': 'first'}));
    expect(created['createdAt']?.raw, now);
    expect(created['updatedAt']?.raw, now);
    final updated = await service.update(
      'r',
      BeakRecord.fromRow({'name': 'second'}),
    );
    expect(updated['updatedAt']?.raw, isA<DateTime>());
    expect(updated.values.containsKey('updated_at'), isFalse);
  });

  test('soft delete flags govern query/get/summary/restore', () async {
    await service.create(BeakRecord.fromRow({'name': 'first'}));
    await source.delete(model.table, 'r');
    expect(await source.getOne(model.table, 'r'), isNull);
    expect((await source.query(model.query())).total, 0);
    expect(await source.aggregate(model.count()), 0);
    expect(await source.aggregate(model.count(withTrashed: true)), 1);
    expect((await source.query(model.query(withTrashed: true))).total, 1);
    final deleted = await adapter.selectOne(
      const QueryDescriptor(table: 'records'),
    );
    expect(deleted?['isDeleted'], isTrue);
    expect(deleted?['deletedAt'], now);
    await source.restore(model.table, 'r');
    expect((await source.getOne(model.table, 'r'))?['isDeleted']?.raw, isFalse);
    expect((await source.getOne(model.table, 'r'))?['deletedAt']?.raw, isNull);
    await expectLater(
      () => source.restore(model.table, 'r'),
      throwsA(isA<BeakNotFoundException>()),
    );
  });

  test(
    'conditional graph delete writes both configured deletion fields',
    () async {
      await service.create(BeakRecord.fromRow({'name': 'first'}));
      final graph = BeakGraphCommitService(
        registry: registry,
        source: source,
        now: () => now,
      );
      const ref = BeakRecordRef.existing('records', 'r');
      final result = await graph.commit(
        BeakSavePlan(
          saveId: 'delete',
          root: ref,
          operations: [
            BeakSaveOperation(
              id: 'delete',
              kind: BeakSaveOperationKind.delete,
              target: ref,
              values: const BeakRecord(values: {}),
              expectedUpdatedAt: now,
            ),
          ],
        ),
      );
      expect(result.complete, isTrue);
      expect(await source.getOne(model.table, 'r'), isNull);
      final deleted = await adapter.selectOne(
        const QueryDescriptor(table: 'records'),
      );
      expect(deleted?['isDeleted'], isTrue);
      expect(deleted?['deletedAt'], now);
    },
  );

  test(
    'delegated update executes after revision checks and preserves domain output',
    () async {
      await service.create(BeakRecord.fromRow({'name': 'first'}));
      var calls = 0;
      final graph = BeakGraphCommitService(
        registry: registry,
        source: source,
        now: () => now,
        executeOperation: (context) async {
          calls++;
          expect(context.existing?['name']?.raw, 'first');
          final written = await context.transaction.update(
            model.table,
            context.id!,
            BeakRecord.fromRow({
              'name': 'domain output',
              'updatedAt': now.add(const Duration(seconds: 1)),
            }),
          );
          return BeakSaveOperationWrite(record: written);
        },
      );
      const ref = BeakRecordRef.existing('records', 'r');
      final operation = BeakSaveOperation(
        id: 'edit',
        kind: BeakSaveOperationKind.update,
        target: ref,
        values: BeakRecord.fromRow({'name': 'submitted'}),
        expectedUpdatedAt: now,
      );
      expect(
        (await graph.commit(
          BeakSavePlan(saveId: 'delegated', root: ref, operations: [operation]),
        )).complete,
        isTrue,
      );
      expect(
        (await source.getOne(model.table, 'r'))?['name']?.raw,
        'domain output',
      );
      expect(
        (await graph.commit(
          BeakSavePlan(
            saveId: 'stale-domain',
            root: ref,
            operations: [operation],
          ),
        )).complete,
        isFalse,
      );
      expect(calls, 1);
    },
  );

  test('delegated domain updates advance unchanged audit revisions', () async {
    await service.create(BeakRecord.fromRow({'name': 'first'}));
    var calls = 0;
    final graph = BeakGraphCommitService(
      registry: registry,
      source: source,
      now: () => now,
      executeOperation: (context) async {
        calls++;
        final record = await context.transaction.update(
          model.table,
          context.id!,
          BeakRecord.fromRow({'name': 'domain changed'}),
        );
        return BeakSaveOperationWrite(record: record);
      },
    );
    const ref = BeakRecordRef.existing('records', 'r');
    final operation = BeakSaveOperation(
      id: 'edit',
      kind: BeakSaveOperationKind.update,
      target: ref,
      values: BeakRecord.fromRow({'name': 'submitted'}),
      expectedUpdatedAt: now,
    );
    expect(
      (await graph.commit(
        BeakSavePlan(
          saveId: 'domain-audit',
          root: ref,
          operations: [operation],
        ),
      )).complete,
      isTrue,
    );
    final saved = await source.getOne(model.table, 'r');
    expect(saved?['name']?.raw, 'domain changed');
    expect(saved?['updatedAt']?.raw, now.add(const Duration(milliseconds: 1)));
    expect(
      (await graph.commit(
        BeakSavePlan(
          saveId: 'domain-audit-stale',
          root: ref,
          operations: [operation],
        ),
      )).complete,
      isFalse,
    );
    expect(calls, 1);
  });

  test(
    'trusted derivations use stock writes while client-owned fields remain checked',
    () async {
      await service.create(BeakRecord.fromRow({'name': 'first'}));
      var calls = 0;
      final graph = BeakGraphCommitService(
        registry: registry,
        source: source,
        policy: _ServerOwnsVersion(),
        executeOperation: (context) async {
          calls++;
          return BeakSaveOperationWrite.withValues(
            BeakRecord.fromRow({'version': 1}),
          );
        },
      );
      const ref = BeakRecordRef.existing('records', 'r');
      BeakSavePlan edit(String saveId, BeakRecord values) => BeakSavePlan(
        saveId: saveId,
        root: ref,
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: ref,
            values: values,
            expectedUpdatedAt: now,
          ),
        ],
      );
      final plan = edit(
        'trusted-derivation',
        BeakRecord.fromRow({'name': 'second'}),
      );
      final result = await graph.commit(plan);
      expect(result.complete, isTrue);
      final stored = await source.getOne(model.table, 'r');
      expect(stored?['name']?.raw, 'second');
      expect(stored?['version']?.raw, 1);
      expect((await graph.commit(plan)).toJson(), result.toJson());
      expect(calls, 1);
      expect(
        (await graph.commit(
          edit('forged', BeakRecord.fromRow({'version': 99})),
        )).complete,
        isFalse,
      );
      expect(calls, 1);
    },
  );

  test(
    'trusted derivations reject invalid scalars and identity replacement',
    () async {
      await service.create(BeakRecord.fromRow({'name': 'first'}));
      for (final values in [
        BeakRecord.fromRow({'version': -1}),
        BeakRecord.fromRow({'id': 'another'}),
        BeakRecord.fromRow({'unknown': 'value'}),
      ]) {
        final graph = BeakGraphCommitService(
          registry: registry,
          source: source,
          executeOperation: (_) async =>
              BeakSaveOperationWrite.withValues(values),
        );
        const ref = BeakRecordRef.existing('records', 'r');
        final result = await graph.commit(
          BeakSavePlan(
            saveId: 'invalid-${values.values.keys.single}',
            root: ref,
            operations: [
              BeakSaveOperation(
                id: 'edit',
                kind: BeakSaveOperationKind.update,
                target: ref,
                values: BeakRecord.fromRow({'name': 'must roll back'}),
              ),
            ],
          ),
        );
        expect(result.complete, isFalse);
        expect((await source.getOne(model.table, 'r'))?['name']?.raw, 'first');
      }
    },
  );

  test('graph revision guard uses the configured update stamp', () async {
    await service.create(BeakRecord.fromRow({'name': 'first'}));
    final graph = BeakGraphCommitService(
      registry: registry,
      source: source,
      now: () => now,
    );
    const ref = BeakRecordRef.existing('records', 'r');
    final result = await graph.commit(
      BeakSavePlan(
        saveId: 'edit',
        root: ref,
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: ref,
            values: BeakRecord.fromRow({'name': 'changed'}),
            expectedUpdatedAt: now,
          ),
        ],
      ),
    );
    expect(result.complete, isTrue);
    final stale = await graph.commit(
      BeakSavePlan(
        saveId: 'stale',
        root: ref,
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: ref,
            values: BeakRecord.fromRow({'name': 'stale'}),
            expectedUpdatedAt: now,
          ),
        ],
      ),
    );
    expect(stale.complete, isFalse);
    expect(stale.outcomes.single.error?.code, 'conflict');
  });
}
