import 'dart:async';
import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

const _childRelation = BeakHasMany(
  key: 'children',
  label: 'Children',
  relatedTable: 'children',
  displayColumnKey: 'name',
  foreignKey: 'parent_id',
  owned: true,
);
const _sharedRelation = BeakHasMany(
  key: 'shared',
  label: 'Shared',
  relatedTable: 'children',
  displayColumnKey: 'name',
  foreignKey: 'parent_id',
);
const _oneRelation = BeakHasOne(
  key: 'profile',
  label: 'Profile',
  relatedTable: 'children',
  displayColumnKey: 'name',
  foreignKey: 'parent_id',
  owned: true,
);

final class _Model extends BeakModel {
  const _Model(this.table);
  @override
  final String table;
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
    BeakStringColumn(key: 'parent_id', label: 'Parent'),
  ];
  @override
  List<BeakRelationship> get relationships => table == 'parents'
      ? const [_childRelation, _sharedRelation, _oneRelation]
      : const [];
}

final class _Source implements BeakDataSource {
  final List<String> calls = [];
  Completer<void>? paused;
  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    calls.add('create:$table');
    await paused?.future;
    return BeakRecord(
      values: {...data.values, 'id': BeakStringValue('$table-${calls.length}')},
    );
  }

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async {
    calls.add('update:$table:$id');
    return BeakRecord(values: {...data.values, 'id': BeakValue.of(id)});
  }

  @override
  Future<void> delete(String table, Object id, {bool force = false}) async =>
      calls.add('delete:$table:$id');
  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async => calls.add('attach:$id:${relatedIds.single}');
  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async => calls.add('detach:$id:${relatedIds.single}');
  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BeakModelRegistry _registry() => BeakModelRegistry()
  ..register(const _Model('parents'))
  ..register(const _Model('children'));
Map<String, Object?> _wire(Object value) =>
    switch (jsonDecode(jsonEncode(value))) {
      final Map<String, Object?> map => map,
      _ => fail('Expected a JSON object.'),
    };

void main() {
  test(
    'foreign references order drafts and resolve owner keys before writes',
    () async {
      const parent = BeakRecordRef.draft('parents', 'parent');
      const child = BeakRecordRef.draft('children', 'child');
      final createParent = BeakSaveOperation(
        id: 'parent',
        kind: BeakSaveOperationKind.create,
        target: parent,
        values: BeakRecord.fromRow({'name': 'Parent'}),
      );
      final createChild = BeakSaveOperation(
        id: 'child',
        kind: BeakSaveOperationKind.create,
        target: child,
        owner: parent,
        relationKey: 'children',
        references: const {'parent_id': parent},
        values: BeakRecord.fromRow({'name': 'Child'}),
      );
      final plan = BeakSavePlan(
        saveId: 'graph',
        root: parent,
        operations: [createChild, createParent],
      );
      final decoded = BeakSavePlan.fromJson(_wire(plan.toJson()));
      expect(decoded.orderedOperations(_registry()).map((op) => op.id), [
        'parent',
        'child',
      ]);
      final source = _Source();
      final result = await BeakStagedCommitDataSource(
        source: source,
        registry: _registry(),
      ).commit(decoded);
      expect(result.complete, isTrue);
      expect(
        result.outcomes.last.record?['parent_id']?.raw,
        result.identities['parent'],
      );
      expect(result.rootRecord?['name']?.raw, 'Parent');
      final saved = BeakSaveResult.fromJson(_wire(result.toJson()));
      expect(saved.rootRecord?.toJson(), result.rootRecord?.toJson());
      expect(saved.identities, result.identities);
      expect(parent.resolve(saved.identities), saved.identities['parent']);
      expect(const BeakRecordRef.existing('parents', 3).resolve({}), 3);
      expect(
        () => parent.resolve({}),
        throwsA(isA<BeakConfigurationException>()),
      );
      final one = BeakSaveOperation(
        id: 'profile',
        kind: BeakSaveOperationKind.create,
        target: child,
        owner: parent,
        relationKey: 'profile',
      );
      expect(
        one.resolveValues(_registry(), {'parent': 'p'})['parent_id']?.raw,
        'p',
      );
    },
  );

  test(
    'staged updates, links and owned deletes preserve each target identity',
    () async {
      const parent = BeakRecordRef.existing('parents', 'p');
      const child = BeakRecordRef.existing('children', 'c');
      final source = _Source();
      final result =
          await BeakStagedCommitDataSource(
            source: source,
            registry: _registry(),
          ).commit(
            BeakSavePlan(
              saveId: 'changes',
              root: parent,
              operations: [
                BeakSaveOperation(
                  id: 'update',
                  kind: BeakSaveOperationKind.update,
                  target: parent,
                  values: BeakRecord.fromRow({'name': 'Changed'}),
                ),
                BeakSaveOperation(
                  id: 'attach',
                  kind: BeakSaveOperationKind.attach,
                  target: parent,
                  related: child,
                  relationKey: 'children',
                ),
                BeakSaveOperation(
                  id: 'detach',
                  kind: BeakSaveOperationKind.detach,
                  target: parent,
                  related: child,
                  relationKey: 'children',
                ),
                BeakSaveOperation(
                  id: 'delete',
                  kind: BeakSaveOperationKind.delete,
                  target: child,
                  owner: parent,
                  relationKey: 'children',
                ),
              ],
            ),
          );
      expect(result.complete, isTrue);
      expect(source.calls, [
        'update:parents:p',
        'attach:p:c',
        'detach:p:c',
        'delete:children:c',
      ]);
      expect(result.rootRecord?['name']?.raw, 'Changed');
      expect(result.outcomes.map((outcome) => outcome.resolvedId), [
        'p',
        'p',
        'p',
        'c',
      ]);
      final rejected = await executeBeakSaveOperation(
        BeakSaveOperation(
          id: 'delete-shared',
          kind: BeakSaveOperationKind.delete,
          target: child,
          owner: parent,
          relationKey: 'shared',
        ),
        source: source,
        registry: _registry(),
        identities: {},
      );
      expect(rejected.status, BeakWriteOutcome.unapplied);
      expect(rejected.error?.code, 'validation');
      expect(source.calls, hasLength(4));
    },
  );

  test('concurrent duplicate staged commits share one mutation', () async {
    final source = _Source()..paused = Completer<void>();
    final adapter = BeakStagedCommitDataSource(
      source: source,
      registry: _registry(),
    );
    const target = BeakRecordRef.draft('parents', 'p');
    final plan = BeakSavePlan(
      saveId: 'parallel',
      root: target,
      operations: [
        BeakSaveOperation(
          id: 'create',
          kind: BeakSaveOperationKind.create,
          target: target,
        ),
      ],
    );
    expect(adapter.commitCapabilities.atomicGraph, isFalse);
    final first = adapter.commit(plan);
    final second = adapter.commit(plan);
    source.paused!.complete();
    expect((await first).toJson(), (await second).toJson());
    expect(source.calls, ['create:parents']);
    expect(
      () => adapter.recover('missing'),
      throwsA(isA<BeakNotFoundException>()),
    );
  });

  test('invalid graphs fail before dispatching writes', () {
    const parent = BeakRecordRef.existing('parents', 'p');
    const child = BeakRecordRef.existing('children', 'c');
    BeakSaveOperation operation({
      String id = 'update',
      BeakRecordRef target = parent,
      BeakRecord? values,
      Map<String, BeakRecordRef> references = const {},
      List<String> dependsOn = const [],
      BeakRecordRef? owner,
      String? relationKey,
    }) => BeakSaveOperation(
      id: id,
      kind: BeakSaveOperationKind.update,
      target: target,
      values: values,
      references: references,
      dependsOn: dependsOn,
      owner: owner,
      relationKey: relationKey,
    );
    for (final ops in [
      [
        operation(values: BeakRecord.fromRow({'missing': true})),
      ],
      [
        operation(dependsOn: ['missing']),
      ],
      [
        operation(
          references: {
            'parent_id': const BeakRecordRef.draft('parents', 'missing'),
          },
        ),
      ],
      [operation(target: child, owner: parent, relationKey: 'missing')],
      [operation(target: parent, owner: parent, relationKey: 'children')],
    ]) {
      expect(
        () => BeakSavePlan(
          saveId: 'invalid',
          root: parent,
          operations: ops,
        ).orderedOperations(_registry()),
        throwsA(isA<BeakConfigurationException>()),
      );
    }
  });

  test(
    'wire decoders reject malformed identities, outcomes and validation errors',
    () {
      expect(BeakRecordRef.fromJson({'table': 'parents', 'id': 3}).id, 3);
      expect(BeakRecordRef.fromJson({'table': 'parents', 'id': 'p'}).id, 'p');
      for (final json in [
        {'table': '', 'id': 3},
        {'table': 'parents', 'id': <Object?>[]},
        {'table': 'parents', 'id': 'p', 'draftId': 'd'},
      ]) {
        expect(
          () => BeakRecordRef.fromJson(json),
          throwsA(isA<BeakConfigurationException>()),
        );
      }
      final failure = BeakSaveError.fromException(
        const BeakValidationException(
          'Invalid',
          fieldErrors: {
            'name': ['Required'],
          },
        ),
      );
      expect(BeakSaveError.fromJson(_wire(failure.toJson())).fieldErrors, {
        'name': ['Required'],
      });
      expect(
        BeakSaveError.fromException(StateError('secret')).message,
        isNot(contains('secret')),
      );
      expect(
        () => BeakSaveError.fromJson({
          'code': 'validation',
          'message': 'Invalid',
          'fieldErrors': {
            'name': [42],
          },
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakOperationResult.fromJson({
          'id': 'x',
          'status': 'applied',
          'resolvedId': [],
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
      final record = BeakRecord(
        values: const {},
        relations: {
          'children': [
            BeakRecord.fromRow({'id': 'c'}),
          ],
        },
      );
      final receipt = BeakOperationResult(
        id: 'x',
        status: BeakWriteOutcome.applied,
        record: record,
      );
      expect(
        () => receipt.record!.relations['children']!.clear(),
        throwsUnsupportedError,
      );
      final unapplied = BeakSaveResult(
        saveId: 'x',
        mode: BeakSaveMode.atomic,
        rootOperationId: 'x',
        outcomes: [
          BeakOperationResult(
            id: 'x',
            status: BeakWriteOutcome.unapplied,
            record: record,
          ),
        ],
      );
      expect(unapplied.rootRecord, isNull);
    },
  );
}
