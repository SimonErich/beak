import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

Map<String, Object?> _jsonObject(Object? value) => switch (value) {
  final Map<String, Object?> object => object,
  _ => fail('Expected a JSON object.'),
};

final class _Model extends BeakModel {
  const _Model();
  @override
  String get table => 'things';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}

final class _Source implements BeakDataSource {
  int writes = 0;
  bool fail = false;
  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    writes++;
    if (fail) throw const BeakConfigurationException('response lost');
    return BeakRecord.fromRow({'id': 'saved-$writes', 'name': 'ok'});
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BeakSavePlan _plan() => BeakSavePlan(
  saveId: 'save-1',
  root: const BeakRecordRef.draft('things', 'one'),
  operations: [
    BeakSaveOperation(
      id: 'first',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('things', 'one'),
    ),
    BeakSaveOperation(
      id: 'second',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('things', 'two'),
      dependsOn: const ['first'],
    ),
  ],
);

void main() {
  test('save plans round trip and freeze their operations', () {
    final plan = _plan();
    final json = _jsonObject(jsonDecode(jsonEncode(plan.toJson())));
    expect(BeakSavePlan.fromJson(json).toJson(), plan.toJson());
    expect(() => plan.operations.clear(), throwsUnsupportedError);
  });

  test(
    'staged writes resolve identities and duplicate submit never replays',
    () async {
      final source = _Source();
      final executor = BeakStagedCommitDataSource(
        source: source,
        registry: BeakModelRegistry()..register(const _Model()),
      );
      final result = await executor.commit(_plan());
      expect(result.complete, isTrue);
      expect(result.identities, {'one': 'saved-1', 'two': 'saved-2'});
      expect((await executor.commit(_plan())).toJson(), result.toJson());
      expect(source.writes, 2);
    },
  );

  test(
    'unknown post-dispatch failure stops descendants and is never replayed',
    () async {
      final source = _Source()..fail = true;
      final executor = BeakStagedCommitDataSource(
        source: source,
        registry: BeakModelRegistry()..register(const _Model()),
      );
      final result = await executor.commit(_plan());
      expect(result.outcomes.first.status, BeakWriteOutcome.unknown);
      expect(result.outcomes.last.status, BeakWriteOutcome.unapplied);
      source.fail = false;
      await executor.commit(_plan());
      expect(source.writes, 1);
      expect((await executor.recover('save-1')).toJson(), result.toJson());
    },
  );

  test('changed content under the same save identity is rejected', () async {
    final executor = BeakStagedCommitDataSource(
      source: _Source(),
      registry: BeakModelRegistry()..register(const _Model()),
    );
    await executor.commit(_plan());
    expect(
      () => executor.commit(
        BeakSavePlan(saveId: 'save-1', root: _plan().root, operations: []),
      ),
      throwsA(isA<BeakConflictException>()),
    );
  });

  test(
    'nested values are snapshotted and cannot mutate a frozen operation',
    () {
      final list = <BeakValue>[const BeakStringValue('original')];
      final op = BeakSaveOperation(
        id: 'one',
        kind: BeakSaveOperationKind.create,
        target: const BeakRecordRef.draft('things', 'one'),
        values: BeakRecord(values: {'name': BeakListValue(list)}),
      );
      list.clear();
      final values = switch (op.values['name']) {
        BeakListValue(:final values) => values,
        _ => fail('Expected the frozen list value.'),
      };
      expect(values, hasLength(1));
      expect(values.clear, throwsUnsupportedError);
    },
  );

  test('cycles and unknown dependencies fail before any write', () async {
    final source = _Source();
    final executor = BeakStagedCommitDataSource(
      source: source,
      registry: BeakModelRegistry()..register(const _Model()),
    );
    final plan = BeakSavePlan(
      saveId: 'cycle',
      root: _plan().root,
      operations: [
        BeakSaveOperation(
          id: 'first',
          kind: BeakSaveOperationKind.create,
          target: _plan().root,
          dependsOn: const ['second'],
        ),
        BeakSaveOperation(
          id: 'second',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('things', 'two'),
          dependsOn: const ['first'],
        ),
      ],
    );
    await expectLater(
      () => executor.commit(plan),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(source.writes, 0);
  });

  test('unsupported conditional writes are explicitly unapplied', () async {
    final source = _Source();
    final executor = BeakStagedCommitDataSource(
      source: source,
      registry: BeakModelRegistry()..register(const _Model()),
    );
    const root = BeakRecordRef.existing('things', 'saved');
    final result = await executor.commit(
      BeakSavePlan(
        saveId: 'conditional',
        root: root,
        operations: [
          BeakSaveOperation(
            id: 'update',
            kind: BeakSaveOperationKind.update,
            target: root,
            expectedUpdatedAt: DateTime.utc(2026),
          ),
        ],
      ),
    );
    expect(result.outcomes.single.status, BeakWriteOutcome.unapplied);
    expect(source.writes, 0);
    expect(
      BeakSaveResult.fromJson(
        _jsonObject(jsonDecode(jsonEncode(result.toJson()))),
      ).toJson(),
      result.toJson(),
    );
  });
}
