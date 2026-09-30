import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import '../../support/api_models.dart';

const _relation = BeakHasMany(
  key: 'comments',
  label: 'Comments',
  relatedTable: 'comments',
  displayColumnKey: 'message',
  foreignKey: 'note_id',
  owned: true,
);
const _children = BeakToManyField(
  model: _AggregateNote(),
  target: _DerivedComment(),
  relation: _relation,
);
const _rating = BeakScalarField<int>(
  model: _AggregateNote(),
  column: NoteColumns.rating,
);
const _message = BeakScalarField<String>(
  model: _DerivedComment(),
  column: BeakTextColumn(key: 'message', label: 'Message'),
);
const _noteId = BeakScalarField<String>(
  model: _DerivedComment(),
  column: BeakStringColumn(key: 'note_id', label: 'Note'),
);

final class _AggregateNote extends BeakModel {
  const _AggregateNote();
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => NoteColumns.values;
  @override
  List<BeakRelationship> get relationships => const [_relation];
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior<int>.derived(
        field: _rating,
        dependencies: [_children],
        resolve: (context) => (context.read(_children) ?? [])
            .fold<int>(
              0,
              (sum, child) => sum + (_message.readFrom(child)?.length ?? 0),
            )
            .clamp(1, 5),
      ),
    ],
  );
}

final class _DerivedComment extends BeakModel {
  const _DerivedComment({this.cyclic = false});
  final bool cyclic;
  @override
  String get table => 'comments';
  @override
  String get displayColumnKey => 'message';
  @override
  List<BeakColumn> get columns => const CommentModel().columns;
  @override
  List<BeakRelationship> get relationships => [if (cyclic) _noteRelation];
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior<String>.derived(
        field: _message,
        dependencies: [if (cyclic) _parent else _noteId],
        resolve: (context) => '${context.read(_noteId)}!?',
      ),
    ],
  );
}

const _noteRelation = BeakBelongsTo(
  key: 'note',
  label: 'Note',
  relatedTable: 'notes',
  displayColumnKey: 'title',
  foreignKey: 'note_id',
);
const _parent = BeakToOneField(
  model: _DerivedComment(cyclic: true),
  target: _AggregateNote(),
  relation: _noteRelation,
);

final class _DenyParentUpdate extends BeakAllowAllPolicy {
  const _DenyParentUpdate();
  @override
  bool canUpdate(BeakPrincipal? principal, BeakModel model, Object id) =>
      model.table != 'notes';
}

final class _SuggestedComment extends BeakModel {
  const _SuggestedComment();
  @override
  String get table => 'comments';
  @override
  String get displayColumnKey => 'message';
  @override
  List<BeakColumn> get columns => const CommentModel().columns;
  @override
  List<BeakRelationship> get relationships => const [_noteRelation];
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.suggested(
        field: _message,
        dependencies: [_parent],
        resolve: (context) => context.read(_parent)?['title']?.raw as String?,
      ),
    ],
  );
}

final class _SuggestedLinkComment extends BeakModel {
  const _SuggestedLinkComment({this.unstable = false});
  final bool unstable;
  @override
  String get table => 'comments';
  @override
  String get displayColumnKey => 'message';
  @override
  List<BeakColumn> get columns => const CommentModel().columns;
  @override
  List<BeakRelationship> get relationships => const [_noteRelation];
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.suggested(field: _noteId, resolve: (_) => 'a'),
      BeakValueBehavior.derived(
        field: _message,
        dependencies: unstable ? const [] : [_parent],
        resolve: (state) => unstable
            ? '${state.read(_message)}x'
            : state.read(_parent)?['title']?.raw as String? ?? '',
      ),
    ],
  );
}

void main() {
  late BeakModelRegistry registry;
  late WormDataSource source;
  late BeakGraphCommitService service;
  setUp(() async {
    Worm.seedRandom(8);
    final adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = BeakModelRegistry()
      ..register(const _AggregateNote())
      ..register(const _DerivedComment());
    source = WormDataSource(registry, adapter: adapter);
    service = BeakGraphCommitService(registry: registry, source: source);
    await source.create(
      'notes',
      BeakRecord.fromRow({'id': 'a', 'title': 'A', 'rating': 1}),
    );
    await source.create(
      'notes',
      BeakRecord.fromRow({'id': 'b', 'title': 'B', 'rating': 1}),
    );
    await source.create(
      'comments',
      BeakRecord.fromRow({'id': 'c', 'note_id': 'a', 'message': ''}),
    );
  });
  tearDown(Worm.reset);
  BeakSavePlan edit(
    String id, {
    Map<String, Object?> values = const {'message': 'forged'},
  }) => BeakSavePlan(
    saveId: id,
    root: const BeakRecordRef.existing('comments', 'c'),
    operations: [
      BeakSaveOperation(
        id: 'child',
        kind: BeakSaveOperationKind.update,
        target: const BeakRecordRef.existing('comments', 'c'),
        values: BeakRecord.fromRow(values),
      ),
    ],
  );

  test(
    'suggested references hydrate dependants and preserve explicit links',
    () async {
      final models = BeakModelRegistry()
        ..register(const NoteModel())
        ..register(const _SuggestedLinkComment());
      final source = WormDataSource(models, adapter: Worm.adapter());
      final service = BeakGraphCommitService(registry: models, source: source);
      for (final (id, explicit, expected) in [
        ('default', false, 'A'),
        ('override', true, 'B'),
      ]) {
        final ref = BeakRecordRef.draft('comments', id);
        final result = await service.commit(
          BeakSavePlan(
            saveId: id,
            root: ref,
            operations: [
              BeakSaveOperation(
                id: id,
                target: ref,
                kind: BeakSaveOperationKind.create,
                references: {
                  if (explicit)
                    'note_id': const BeakRecordRef.existing('notes', 'b'),
                },
              ),
            ],
          ),
        );
        expect(result.complete, isTrue, reason: '${result.toJson()}');
        expect(result.rootRecord?['message']?.raw, expected);
        expect(result.rootRecord?['note_id']?.raw, explicit ? 'b' : 'a');
      }
    },
  );

  test(
    'undeclared self-dependent values reject within a bounded pass count',
    () async {
      final models = BeakModelRegistry()
        ..register(const NoteModel())
        ..register(const _SuggestedLinkComment(unstable: true));
      final source = WormDataSource(models, adapter: Worm.adapter());
      final service = BeakGraphCommitService(registry: models, source: source);
      final result = await service.commit(edit('unstable', values: {}));
      expect(result.complete, isFalse);
      expect('${result.toJson()}', contains('did not stabilize'));
      expect((await source.getOne('comments', 'c'))?['message']?.raw, '');
    },
  );

  test(
    'direct child edit derives child before recalculating untouched inverse parent',
    () async {
      final result = await service.commit(edit('edit'));
      expect(result.complete, isTrue);
      expect((await source.getOne('comments', 'c'))?['message']?.raw, 'a!?');
      expect((await source.getOne('notes', 'a'))?['rating']?.raw, 3);
      expect(result.outcomes.length, 2);
      expect((await service.recover('edit')).toJson(), result.toJson());
    },
  );

  test(
    'moving a child recalculates original and proposed inverse parents',
    () async {
      await service.commit(edit('derive'));
      final result = await service.commit(
        edit('move', values: {'note_id': 'b'}),
      );
      expect(result.complete, isTrue);
      expect((await source.getOne('notes', 'a'))?['rating']?.raw, 1);
      expect((await source.getOne('notes', 'b'))?['rating']?.raw, 3);
    },
  );

  test(
    'synthetic parent writes still need resource update permission and roll back children',
    () async {
      service = BeakGraphCommitService(
        registry: registry,
        source: source,
        policy: const _DenyParentUpdate(),
      );
      final result = await service.commit(edit('denied'));
      expect(result.complete, isFalse);
      expect((await source.getOne('comments', 'c'))?['message']?.raw, '');
      expect((await source.getOne('notes', 'a'))?['rating']?.raw, 1);
    },
  );

  test('cross-record value cycles reject without writing or hanging', () async {
    final cyclicRegistry = BeakModelRegistry()
      ..register(const _AggregateNote())
      ..register(const _DerivedComment(cyclic: true));
    final cyclicSource = WormDataSource(
      cyclicRegistry,
      adapter: source.adapter,
    );
    final cyclicService = BeakGraphCommitService(
      registry: cyclicRegistry,
      source: cyclicSource,
    );
    final result = await cyclicService.commit(edit('cycle'));
    expect(result.complete, isFalse);
    expect(result.outcomes.single.status, BeakWriteOutcome.unapplied);
    expect(result.outcomes.single.error?.code, 'configuration');
    expect(result.outcomes.single.error?.message, contains('cycle crosses'));
    expect((await source.getOne('comments', 'c'))?['message']?.raw, '');
    expect((await source.getOne('notes', 'a'))?['rating']?.raw, 1);
    expect((await cyclicService.recover('cycle')).toJson(), result.toJson());
  });
  test(
    'suggested related defaults do not rewrite existing referencing records',
    () async {
      final registry = BeakModelRegistry()
        ..register(const NoteModel())
        ..register(const _SuggestedComment());
      final data = WormDataSource(registry, adapter: source.adapter);
      await data.update('comments', 'c', BeakRecord.fromRow({'message': 'A'}));
      final service = BeakGraphCommitService(registry: registry, source: data);
      final result = await service.commit(
        BeakSavePlan(
          saveId: 'suggestion-reference',
          root: const BeakRecordRef.existing('notes', 'a'),
          operations: [
            BeakSaveOperation(
              id: 'note',
              kind: BeakSaveOperationKind.update,
              target: const BeakRecordRef.existing('notes', 'a'),
              values: BeakRecord.fromRow({'title': 'Changed'}),
            ),
          ],
        ),
      );
      expect(result.complete, isTrue, reason: '${result.toJson()}');
      expect(result.outcomes, hasLength(1));
      expect((await data.getOne('comments', 'c'))?['message']?.raw, 'A');
    },
  );
}
