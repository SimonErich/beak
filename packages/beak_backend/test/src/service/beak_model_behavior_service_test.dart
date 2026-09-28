import 'dart:convert';
import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import '../../support/api_models.dart';

const _model = _WorkflowNote();
const _title = BeakScalarField<String>(
  model: _model,
  column: NoteColumns.title,
);
const _status = BeakScalarField<NoteStatus>(
  model: _model,
  column: NoteColumns.status,
);
const _body = BeakScalarField<String>(model: _model, column: NoteColumns.body);
const _rating = BeakScalarField<int>(model: _model, column: NoteColumns.rating);
const _inputName = BeakScalarField<String>(
  model: LabelModel(),
  column: BeakStringColumn(key: 'name', label: 'Name', rules: [BeakRequired()]),
);
int _evaluations = 0;

final class _WorkflowNote extends BeakModel {
  const _WorkflowNote();
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => NoteColumns.values;
  @override
  List<BeakRelationship> get relationships => const [
    BeakHasMany(
      key: 'comments',
      label: 'Comments',
      relatedTable: 'comments',
      displayColumnKey: 'message',
      foreignKey: 'note_id',
      owned: true,
    ),
  ];
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    editableWhen: (record) => _status.readFrom(record) == NoteStatus.draft,
    deletableWhen: (_) => false,
    values: [
      BeakValueBehavior<NoteStatus>.initial(
        field: _status,
        resolve: (_) => NoteStatus.draft,
      ),
      BeakValueBehavior<int>.derived(
        field: _rating,
        dependencies: [_title],
        resolve: (context) {
          _evaluations++;
          return (context.read(_title)?.length ?? 1).clamp(1, 5);
        },
      ),
      BeakValueBehavior<String>.snapshot(
        field: _body,
        onAction: 'publish',
        dependencies: [_title],
        resolve: (context) => context.read(_title),
      ),
    ],
    actions: [
      BeakModelAction(
        name: 'publish',
        label: 'Publish',
        allowOnCreate: true,
        availableWhen: (record) => _status.readFrom(record) == NoteStatus.draft,
        values: [
          BeakValueBehavior<NoteStatus>.derived(
            field: _status,
            resolve: (_) => NoteStatus.published,
          ),
        ],
      ),
      BeakModelAction(
        name: 'rename',
        label: 'Rename',
        inputModel: const LabelModel(),
        availableWhen: (record) => _status.readFrom(record) == NoteStatus.draft,
        values: [
          BeakValueBehavior<String>.derived(
            field: _title,
            resolve: (context) => context.argument(_inputName),
          ),
        ],
      ),
    ],
  );
}

final class _FieldPolicy extends BeakAllowAllPolicy implements BeakFieldPolicy {
  const _FieldPolicy();
  @override
  bool canReadField(BeakPrincipal? principal, String table, String key) =>
      key != 'body';
  @override
  bool canWriteField(BeakPrincipal? principal, String table, String key) =>
      key != 'body' && key != 'rating';
}

final class _DenyCommand extends BeakAllowAllPolicy
    implements BeakActionPolicy {
  const _DenyCommand();
  @override
  bool canExecuteAction(
    BeakPrincipal? principal,
    String table,
    Object? id,
    String action,
  ) => false;
}

void main() {
  late InMemoryAdapter adapter;
  late BeakModelRegistry registry;
  late WormDataSource source;
  late BeakGraphCommitService service;
  setUp(() async {
    Worm.seedRandom(7);
    adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = BeakModelRegistry()
      ..register(_model)
      ..register(const CommentModel())
      ..register(const LabelModel());
    source = WormDataSource(registry, adapter: adapter);
    service = BeakGraphCommitService(registry: registry, source: source);
    _evaluations = 0;
  });
  tearDown(Worm.reset);

  BeakSavePlan create(
    String save, {
    String? action,
    Map<String, Object?> extra = const {},
  }) => BeakSavePlan(
    saveId: save,
    root: const BeakRecordRef.draft('notes', 'new-note'),
    action: action,
    operations: [
      BeakSaveOperation(
        id: 'note',
        kind: BeakSaveOperationKind.create,
        target: const BeakRecordRef.draft('notes', 'new-note'),
        values: BeakRecord.fromRow({'title': 'Title', ...extra}),
      ),
    ],
  );
  BeakSavePlan update(
    String save,
    Object id, {
    String? action,
    BeakRecord arguments = const BeakRecord(values: {}),
    Map<String, Object?> values = const {},
  }) => BeakSavePlan(
    saveId: save,
    root: BeakRecordRef.existing('notes', id),
    action: action,
    arguments: arguments,
    operations: [
      BeakSaveOperation(
        id: 'note',
        kind: BeakSaveOperationKind.update,
        target: BeakRecordRef.existing('notes', id),
        values: BeakRecord.fromRow(values),
      ),
    ],
  );

  test(
    'creates apply initial and derived fields and block forged state/snapshots',
    () async {
      // Title is action-managed, but supplied at creation: it is ordinary initial input.
      final normal = await service.commit(create('normal'));
      expect(normal.complete, isTrue);
      final row = normal.outcomes.single.record!;
      expect(_status.readFrom(row), NoteStatus.draft);
      expect(_rating.readFrom(row), 5);
      for (final (key, value) in [
        ('status', 'published'),
        ('body', 'forged'),
      ]) {
        final rejected = await service.commit(
          create('bad-$key', extra: {key: value}),
        );
        expect(rejected.complete, isFalse);
        expect(rejected.outcomes.single.error?.code, 'validation');
      }
    },
  );

  test(
    'command, snapshots and receipt execute atomically and replay only once',
    () async {
      final draft = await service.commit(create('draft'));
      final id = draft.identities['new-note']!;
      final plan = update('publish', id, action: 'publish');
      final published = await service.commit(plan);
      expect(published.complete, isTrue);
      expect(_body.readFrom(published.outcomes.single.record!), 'Title');
      expect(
        _status.readFrom(published.outcomes.single.record!),
        NoteStatus.published,
      );
      final evaluations = _evaluations;
      expect((await service.commit(plan)).toJson(), published.toJson());
      expect(_evaluations, evaluations);
      expect((await service.recover('publish')).toJson(), published.toJson());
      final invalid = await service.commit(
        update('revert', id, values: {'status': 'draft'}),
      );
      expect(invalid.complete, isFalse);
      expect(
        _status.readFrom((await source.getOne('notes', id))!),
        NoteStatus.published,
      );
    },
  );

  test(
    'create and publish is a single atomic graph and failure leaves no record',
    () async {
      final result = await service.commit(
        create('create-publish', action: 'publish'),
      );
      expect(result.complete, isTrue);
      expect(_body.readFrom(result.outcomes.single.record!), 'Title');
      final invalid = create(
        'invalid-publish',
        action: 'publish',
        extra: {'title': ''},
      );
      expect((await service.commit(invalid)).complete, isFalse);
      expect(
        (await source.query(const BeakQuerySpec(table: 'notes'))).total,
        1,
      );
    },
  );

  test(
    'action input uses model validation and changes are derived authoritatively',
    () async {
      final draft = await service.commit(create('draft'));
      final id = draft.identities['new-note']!;
      expect(
        (await service.commit(
          update('bad-rename', id, action: 'rename'),
        )).complete,
        isFalse,
      );
      final renamed = await service.commit(
        update(
          'rename',
          id,
          action: 'rename',
          arguments: BeakRecord.fromRow({'name': 'New'}),
        ),
      );
      expect(renamed.complete, isTrue);
      expect(_title.readFrom(renamed.outcomes.single.record!), 'New');
      expect(_rating.readFrom(renamed.outcomes.single.record!), 3);
    },
  );

  test(
    'child direct edits and relationship writes respect locked owning workflow',
    () async {
      final draft = await service.commit(create('draft'));
      final id = draft.identities['new-note']!;
      final child = await source.create(
        'comments',
        BeakRecord.fromRow({
          'id': 'child',
          'note_id': id,
          'message': 'Original',
        }),
      );
      await service.commit(update('publish', id, action: 'publish'));
      final childRef = BeakRecordRef.existing('comments', child['id']!.raw!);
      final result = await service.commit(
        BeakSavePlan(
          saveId: 'child-edit',
          root: childRef,
          operations: [
            BeakSaveOperation(
              id: 'child',
              kind: BeakSaveOperationKind.update,
              target: childRef,
              values: BeakRecord.fromRow({'message': 'Changed'}),
            ),
          ],
        ),
      );
      expect(result.complete, isFalse);
      final unlink = await service.commit(
        BeakSavePlan(
          saveId: 'unlink',
          root: BeakRecordRef.existing('notes', id),
          operations: [
            BeakSaveOperation(
              id: 'unlink',
              kind: BeakSaveOperationKind.detach,
              target: BeakRecordRef.existing('notes', id),
              relationKey: 'comments',
              related: childRef,
            ),
          ],
        ),
      );
      expect(unlink.complete, isFalse);
      expect(
        (await source.getOne('comments', 'child'))?['message']?.raw,
        'Original',
      );
    },
  );

  test(
    'field policy rejects caller writes but permits trusted derivations and redacts receipts',
    () async {
      service = BeakGraphCommitService(
        registry: registry,
        source: source,
        policy: const _FieldPolicy(),
      );
      final published = await service.commit(
        create('publish', action: 'publish'),
      );
      expect(published.complete, isTrue);
      expect(
        published.outcomes.single.record!.values.containsKey('body'),
        isFalse,
      );
      expect(
        _body.readFrom(
          (await source.getOne('notes', published.identities['new-note']!))!,
        ),
        'Title',
      );
      expect(
        (await service.recover(
          'publish',
        )).outcomes.single.record!.values.containsKey('body'),
        isFalse,
      );
      final denied = await service.commit(
        create('spoof', extra: {'rating': 1}),
      );
      expect(denied.hasUnknown, isFalse);
      expect(denied.complete, isFalse);
    },
  );

  test(
    'action policy can deny command independently of ordinary update access',
    () async {
      final draft = await service.commit(create('draft'));
      service = BeakGraphCommitService(
        registry: registry,
        source: source,
        policy: const _DenyCommand(),
      );
      final denied = await service.commit(
        update('denied', draft.identities['new-note']!, action: 'publish'),
      );
      expect(denied.complete, isFalse);
      expect(denied.hasUnknown, isFalse);
    },
  );

  test('direct HTTP CRUD cannot bypass root or owned-child workflow', () async {
    final handler = const Pipeline()
        .addMiddleware(beakErrorMappingMiddleware())
        .addMiddleware(beakJsonMiddleware())
        .addHandler(beakApiRouter(registry: registry, dataSource: source));
    for (final table in ['notes', 'comments']) {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/$table/'),
          body: jsonEncode(
            BeakRecord.fromRow({
              'title': 'Bad',
              'status': 'published',
            }).toJson(),
          ),
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(response.statusCode, 422);
    }
  });
  test(
    'duplicate resets workflow and snapshots, copies only selected owned rows and remains unsaved',
    () async {
      final created = await service.commit(
        create(
          'original',
          action: 'publish',
          extra: {'author_email': 'person@example.com'},
        ),
      );
      final original = created.outcomes.single.record!;
      final id = _model.primaryKeyOf(original)!;
      await source.create(
        'comments',
        BeakRecord.fromRow({
          'id': 'original-child',
          'note_id': id,
          'message': 'Copied',
        }),
      );
      final comments = BeakToManyField(
        model: _model,
        target: const CommentModel(),
        relation: _model.relationships.single,
      );
      final duplicate =
          await BeakRecordDuplicator(
            source: source,
            registry: registry,
          ).duplicate(
            _model,
            original,
            saveId: 'copy',
            spec: BeakDuplicationSpec(relations: [comments]),
          );
      expect(_model.primaryKeyOf(duplicate.record), isNull);
      expect(_status.readFrom(duplicate.record), NoteStatus.draft);
      expect(_body.readFrom(duplicate.record), isNull);
      expect(_rating.readFrom(duplicate.record), isNull);
      expect(duplicate.record['author_email']?.raw, 'person@example.com');
      expect(duplicate.record.relations['comments']!.single['id'], isNull);
      expect(duplicate.record.relations['comments']!.single['note_id'], isNull);
      expect(
        (await source.query(const BeakQuerySpec(table: 'notes'))).total,
        1,
      );
      final saved = await service.commit(duplicate.plan);
      expect(saved.complete, isTrue);
      expect(
        (await source.query(const BeakQuerySpec(table: 'notes'))).total,
        2,
      );
      expect(
        (await source.query(const BeakQuerySpec(table: 'comments'))).total,
        2,
      );
      expect(
        _status.readFrom((await source.getOne('notes', id))!),
        NoteStatus.published,
      );
      final simple = await BeakRecordDuplicator(
        source: source,
        registry: registry,
      ).duplicate(_model, original, saveId: 'simple');
      expect(simple.record.relations, isEmpty);
      expect(simple.plan.operations.length, 1);
    },
  );
  test(
    'capability endpoint exposes create-enabled actions and applies action policy',
    () async {
      final draft = await service.commit(create('capability-draft'));
      final id = draft.identities['new-note']!;
      Future<BeakAccessCapabilities> access(
        BeakPolicy policy, {
        Object? id,
      }) async {
        final handler = const Pipeline()
            .addMiddleware(beakErrorMappingMiddleware())
            .addMiddleware(beakJsonMiddleware())
            .addHandler(
              beakApiRouter(
                registry: registry,
                dataSource: source,
                policy: policy,
              ),
            );
        final response = await handler(
          Request(
            'GET',
            Uri.parse(
              'http://localhost/api/notes/capabilities',
            ).replace(queryParameters: {if (id != null) 'id': '$id'}),
          ),
        );
        expect(response.statusCode, 200);
        return switch (jsonDecode(await response.readAsString())) {
          final Map<String, Object?> json => BeakAccessCapabilities.fromJson(
            json,
          ),
          _ => fail('Expected capability object'),
        };
      }

      expect((await access(const BeakAllowAllPolicy())).executableActions, {
        'publish',
      });
      expect(
        (await access(const BeakAllowAllPolicy(), id: id)).executableActions,
        {'publish', 'rename'},
      );
      expect(
        (await access(const _DenyCommand(), id: id)).executableActions,
        isEmpty,
      );
    },
  );
}
