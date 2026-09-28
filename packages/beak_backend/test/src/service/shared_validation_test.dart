import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_backend/src/service/beak_resource_service.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

final class _Notes extends BeakModel {
  const _Notes({this.collection = false});
  final bool collection;
  static const title = BeakScalarField<String>(
    model: _Notes(),
    column: NoteColumns.title,
  );
  static const author = BeakScalarField<String>(
    model: _Notes(),
    column: NoteColumns.authorId,
  );
  static const authorId = BeakScalarField<String>(
    model: AuthorModel(),
    column: BeakStringColumn(key: 'id', label: 'Id'),
  );
  static const comments = BeakToManyField(
    model: _Notes(),
    target: CommentModel(),
    relation: BeakHasMany(
      key: 'comments',
      label: 'Comments',
      relatedTable: 'comments',
      foreignKey: 'note_id',
      displayColumnKey: 'message',
    ),
  );
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => NoteColumns.values;
  @override
  List<BeakRelationship> get relationships => [comments.relation];
  @override
  List<BeakRecordRule> get validationRules => [
    const BeakUnique(title, scope: [author]),
    const BeakExists(author, authorId),
    if (collection) const BeakCount(comments, min: 1, max: 1),
  ];
}

final class _HiddenComments extends BeakAllowAllPolicy
    implements BeakRowPolicy {
  const _HiddenComments();
  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, String table) =>
      table == 'comments'
      ? const BeakFieldFilter.forKey(
          'message',
          BeakOperator.eq,
          BeakStringValue('Visible'),
        )
      : null;
}

void main() {
  late InMemoryAdapter adapter;
  late WormDataSource source;
  late BeakModelRegistry registry;
  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = BeakModelRegistry()
      ..register(const _Notes())
      ..register(const CommentModel())
      ..register(const AuthorModel());
    source = WormDataSource(registry, adapter: adapter);
    await source.create(
      'authors',
      BeakRecord.fromRow({'id': 'a', 'name': 'Ada'}),
    );
    await source.create(
      'authors',
      BeakRecord.fromRow({'id': 'b', 'name': 'Bea'}),
    );
  });
  tearDown(Worm.reset);

  test(
    'scoped uniqueness and existence preflight repeat on writes and exclude edited id',
    () async {
      final service = BeakResourceService(const _Notes(), source);
      await service.create(
        BeakRecord.fromRow({'id': 'one', 'title': 'Same', 'author_id': 'a'}),
      );
      await service.create(
        BeakRecord.fromRow({'id': 'two', 'title': 'Same', 'author_id': 'b'}),
      );
      await service.update('one', BeakRecord.fromRow({'title': 'Same'}));
      await expectLater(
        service.update('two', BeakRecord.fromRow({'author_id': 'a'})),
        throwsA(
          isA<BeakValidationException>().having(
            (error) => error.fieldErrors.keys,
            'fields',
            ['title'],
          ),
        ),
      );
      await expectLater(
        service.create(
          BeakRecord.fromRow({'title': 'Other', 'author_id': 'missing'}),
        ),
        throwsA(
          isA<BeakValidationException>().having(
            (error) => error.fieldErrors.keys,
            'fields',
            ['author_id'],
          ),
        ),
      );
      final handler = const Pipeline()
          .addMiddleware(beakErrorMappingMiddleware())
          .addHandler(beakApiRouter(registry: registry, dataSource: source));
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/validate'),
          body: jsonEncode(
            BeakValidationRequest.forModel(
              const _Notes(),
              BeakRecord.fromRow({'title': 'Same', 'author_id': 'a'}),
            ).toJson(),
          ),
        ),
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body, {
        'fieldErrors': {
          'title': ['This value is already in use.'],
        },
      });
      expect(
        (await source.query(const BeakQuerySpec(table: 'notes'))).total,
        2,
      );
    },
  );

  test(
    'shared collection limits include siblings hidden by presentation policy',
    () async {
      registry = BeakModelRegistry()
        ..register(const _Notes(collection: true))
        ..register(const CommentModel())
        ..register(const AuthorModel());
      source = WormDataSource(registry, adapter: adapter);
      await source.create(
        'notes',
        BeakRecord.fromRow({
          'id': 'parent',
          'title': 'Original',
          'author_id': 'a',
        }),
      );
      await source.create(
        'comments',
        BeakRecord.fromRow({
          'id': 'visible',
          'note_id': 'parent',
          'message': 'Visible',
        }),
      );
      await source.create(
        'comments',
        BeakRecord.fromRow({
          'id': 'hidden',
          'note_id': 'parent',
          'message': 'Hidden',
        }),
      );
      final service = BeakGraphCommitService(
        registry: registry,
        source: source,
        policy: const _HiddenComments(),
      );
      const parent = BeakRecordRef.existing('notes', 'parent');
      final result = await service.commit(
        BeakSavePlan(
          saveId: 'hidden-check',
          root: parent,
          operations: [
            BeakSaveOperation(
              id: 'update',
              kind: BeakSaveOperationKind.update,
              target: parent,
              values: BeakRecord.fromRow({'title': 'Changed'}),
            ),
          ],
        ),
      );
      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.fieldErrors, {
        'comments': ['Use at most 1 items.'],
      });
      expect(
        (await source.getOne('notes', 'parent'))?['title']?.raw,
        'Original',
      );
    },
  );

  test(
    'collection constraints see the final graph and child deletion rolls back',
    () async {
      registry = BeakModelRegistry()
        ..register(const _Notes(collection: true))
        ..register(const CommentModel())
        ..register(const AuthorModel());
      source = WormDataSource(registry, adapter: adapter);
      final service = BeakGraphCommitService(
        registry: registry,
        source: source,
      );
      const parent = BeakRecordRef.draft('notes', 'parent');
      const child = BeakRecordRef.draft('comments', 'child');
      final created = await service.commit(
        BeakSavePlan(
          saveId: 'create',
          root: parent,
          operations: [
            BeakSaveOperation(
              id: 'parent',
              kind: BeakSaveOperationKind.create,
              target: parent,
              values: BeakRecord.fromRow({'title': 'Parent', 'author_id': 'a'}),
            ),
            BeakSaveOperation(
              id: 'child',
              kind: BeakSaveOperationKind.create,
              target: child,
              owner: parent,
              relationKey: 'comments',
              values: BeakRecord.fromRow({'message': 'Required child'}),
            ),
          ],
        ),
      );
      expect(created.complete, isTrue, reason: created.toJson().toString());
      final handler = const Pipeline()
          .addMiddleware(beakErrorMappingMiddleware())
          .addHandler(beakApiRouter(registry: registry, dataSource: source));
      final bypass = await handler(
        Request(
          'DELETE',
          Uri.parse(
            'http://localhost/api/comments/${created.identities['child']}',
          ),
        ),
      );
      expect(bypass.statusCode, 422);
      final childId = created.identities['child']!;
      final removed = await service.commit(
        BeakSavePlan(
          saveId: 'delete',
          root: BeakRecordRef.existing('comments', childId),
          operations: [
            BeakSaveOperation(
              id: 'child',
              kind: BeakSaveOperationKind.delete,
              target: BeakRecordRef.existing('comments', childId),
            ),
          ],
        ),
      );
      expect(removed.complete, isFalse);
      expect(removed.outcomes.single.status, BeakWriteOutcome.unapplied);
      expect(removed.outcomes.single.error?.fieldErrors.keys, ['comments']);
      expect(await source.getOne('comments', childId), isNotNull);
    },
  );
}
