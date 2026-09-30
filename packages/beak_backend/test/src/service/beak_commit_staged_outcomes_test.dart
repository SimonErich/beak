import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';

/// A model whose name must be unique: a rule only a query can decide.
final class _Tag extends BeakModel {
  const _Tag();

  @override
  String get table => 'tags';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name', unique: true),
  ];
}

BeakSavePlan _tag(String saveId, String name) => BeakSavePlan(
  saveId: saveId,
  root: const BeakRecordRef.draft('tags', 'tag'),
  operations: [
    BeakSaveOperation(
      id: 'tag',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('tags', 'tag'),
      values: BeakRecord.fromRow({'name': name}),
    ),
  ],
);

/// A graph saved through a source that cannot roll back reports what it knows:
/// a write the server refused before it reached the source is unapplied, and
/// only a write that may have reached it is unknown.
void main() {
  late BeakModelRegistry registry;
  late InMemoryBeakDataSource source;
  late BeakGraphCommitService service;

  setUp(() {
    registry = BeakModelRegistry()..register(const _Tag());
    source = InMemoryBeakDataSource(registry: registry);
    service = BeakGraphCommitService(registry: registry, source: source);
  });

  test('a first save of a unique value applies', () async {
    final result = await service.commit(_tag('first', 'red'));

    expect(result.complete, isTrue);
    expect(source.rowsOf('tags'), hasLength(1));
  });

  test(
    'a duplicate of it is a definite rejection, not an unknown outcome',
    () async {
      await service.commit(_tag('first', 'red'));

      final result = await service.commit(_tag('second', 'red'));

      expect(result.mode, BeakSaveMode.staged);
      expect(result.hasUnknown, isFalse);
      expect(result.outcomes.single.status, BeakWriteOutcome.unapplied);
      expect(result.outcomes.single.reason, 'rejected');
      expect(result.outcomes.single.error?.code, 'validation');
      expect(result.outcomes.single.error?.fieldErrors['name'], [
        'This value is already in use.',
      ]);
      expect(source.rowsOf('tags'), hasLength(1));
    },
  );

  test('and the same save can be sent again once the value is free', () async {
    await service.commit(_tag('first', 'red'));
    final refused = await service.commit(_tag('again', 'red'));
    expect(refused.complete, isFalse);

    await source.delete('tags', source.rowsOf('tags').single['id']!.raw!);
    final retried = await service.commit(_tag('again', 'red'));

    expect(retried.complete, isTrue);
  });

  test('a named action is the caller\'s mistake over a source that cannot run '
      'one, not a broken server', () {
    final plan = BeakSavePlan(
      saveId: 'action',
      root: const BeakRecordRef.draft('tags', 'tag'),
      action: 'archive',
      operations: [
        BeakSaveOperation(
          id: 'tag',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('tags', 'tag'),
          values: BeakRecord.fromRow({'name': 'red'}),
        ),
      ],
    );

    expect(() => service.commit(plan), throwsA(isA<BeakValidationException>()));
    expect(source.rowsOf('tags'), isEmpty);
  });

  test('a version precondition the source cannot keep refuses the whole save '
      'before anything is written', () async {
    final plan = BeakSavePlan(
      saveId: 'precondition',
      root: const BeakRecordRef.draft('tags', 'tag'),
      operations: [
        BeakSaveOperation(
          id: 'tag',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('tags', 'tag'),
          values: BeakRecord.fromRow({'name': 'red'}),
        ),
        BeakSaveOperation(
          id: 'other',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('tags', 'elsewhere'),
          values: BeakRecord.fromRow({'name': 'blue'}),
          expectedUpdatedAt: DateTime.utc(2026),
        ),
      ],
    );

    final result = await service.commit(plan);

    expect(
      result.outcomes.map((outcome) => outcome.status),
      everyElement(BeakWriteOutcome.unapplied),
    );
    expect(result.outcomes.first.error?.code, 'configuration');
    expect(source.rowsOf('tags'), isEmpty);
  });
}
