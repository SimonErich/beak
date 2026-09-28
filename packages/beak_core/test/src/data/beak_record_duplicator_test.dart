import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import '../../support/candidate_graph_fixture.dart';

final class _Cycle extends FixtureModel {
  const _Cycle() : super('cycle');
  @override
  List<BeakRelationship> get relationships => const [
    BeakHasMany(
      key: 'children',
      label: 'Children',
      relatedTable: 'cycle',
      displayColumnKey: 'name',
      foreignKey: 'note_id',
      owned: true,
    ),
  ];
}

void main() {
  late BeakModelRegistry registry;
  late MemorySource source;
  late BeakRecordDuplicator duplicator;
  const model = NoteModel();
  final comments = BeakToManyField(
    model: model,
    target: const CommentModel(),
    relation: model.relationshipByKey('comments')!,
  );
  setUp(() {
    registry = createApiRegistry();
    source = MemorySource(registry);
    duplicator = BeakRecordDuplicator(source: source, registry: registry);
  });

  test(
    'copies selected ownership graph, resets private/history/unique fields and retains references',
    () async {
      final original = await source.create(
        'notes',
        BeakRecord.fromRow({
          'id': 'note',
          'title': 'Original',
          'code': 'UNIQUE',
          'password': 'secret',
          'state': 'published',
          'total': 10,
          'snapshot': 'old',
          'author_id': 'author',
          'created_at': DateTime.utc(2025),
          'updated_at': DateTime.utc(2026),
        }),
      );
      await source.create(
        'comments',
        BeakRecord.fromRow({
          'id': 'comment',
          'note_id': 'note',
          'message': 'Copied',
        }),
      );
      await source.create(
        'profiles',
        BeakRecord.fromRow({
          'id': 'detail',
          'comment_id': 'comment',
          'name': 'Nested',
        }),
      );
      final copy = await duplicator.duplicate(
        model,
        original,
        saveId: 'copy',
        spec: BeakDuplicationSpec(relations: [comments]),
      );
      expect(copy.record.toRow(), {
        'title': 'Original',
        'state': 'draft',
        'author_id': 'author',
      });
      final child = copy.record.relations['comments']!.single;
      expect(child['message']?.raw, 'Copied');
      expect(child['id'], isNull);
      expect(child['note_id'], isNull);
      expect(child.relations['detail']!.single['name']?.raw, 'Nested');
      expect(copy.plan.operations.length, 3);
      expect(copy.plan.operations[1].owner, copy.plan.root);
      expect(source.rows['notes']!.length, 1);
      final reset = await duplicator.duplicate(
        model,
        original,
        saveId: 'reset',
        spec: BeakDuplicationSpec(
          relations: [comments],
          includeNestedOwned: false,
          reset: [
            const BeakScalarField<String>(
              model: model,
              column: NoteColumns.title,
            ),
          ],
        ),
      );
      expect(reset.record['title'], isNull);
      expect(reset.plan.operations.length, 2);
      final plain = await duplicator.duplicate(
        model,
        original,
        saveId: 'plain',
      );
      expect(plain.record.relations, isEmpty);
      expect(plain.plan.operations.length, 1);
    },
  );

  test(
    'rejects unsaved records, non-owned collections and qualified reset fields',
    () async {
      await expectLater(
        duplicator.duplicate(
          model,
          const BeakRecord(values: {}),
          saveId: 'unsaved',
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
      final record = await source.create(
        'notes',
        BeakRecord.fromRow({'id': 'a'}),
      );
      final labels = BeakToManyField(
        model: model,
        target: const LabelModel(),
        relation: model.relationshipByKey('labels')!,
      );
      await expectLater(
        duplicator.duplicate(
          model,
          record,
          saveId: 'shared',
          spec: BeakDuplicationSpec(relations: [labels]),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
      final qualified = BeakScalarField<String>(
        model: model,
        column: NoteColumns.title,
        path: [model.relationshipByKey('author')!],
      );
      await expectLater(
        duplicator.duplicate(
          model,
          record,
          saveId: 'qualified',
          spec: BeakDuplicationSpec(reset: [qualified]),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test(
    'owned cycles are rejected before any write or unbounded recursion',
    () async {
      registry.register(const _Cycle());
      final original = await source.create(
        'cycle',
        BeakRecord.fromRow({'id': 'loop', 'note_id': 'loop'}),
      );
      const cyclic = _Cycle();
      await expectLater(
        duplicator.duplicate(
          cyclic,
          original,
          saveId: 'loop',
          spec: BeakDuplicationSpec(
            relations: [
              BeakToManyField(
                model: cyclic,
                target: cyclic,
                relation: cyclic.relationships.single,
              ),
            ],
          ),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );
}
