import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import '../../support/api_models.dart';

const _note = NoteModel();
const _comment = CommentModel();
const _message = BeakScalarField<String>(
  model: _comment,
  column: BeakTextColumn(key: 'message', label: 'Message'),
);
const _title = BeakScalarField<String>(model: _note, column: NoteColumns.title);
final _comments = BeakToManyField(
  model: _note,
  target: _comment,
  relation: _note.relationships.firstWhere(
    (relation) => relation.key == 'comments',
  ),
);
final _labels = BeakToManyField(
  model: _note,
  target: const LabelModel(),
  relation: _note.relationships.firstWhere(
    (relation) => relation.key == 'labels',
  ),
);
final _author = BeakToOneField(
  model: _note,
  target: const AuthorModel(),
  relation: _note.relationships.firstWhere(
    (relation) => relation.key == 'author',
  ),
);

void main() {
  late InMemoryAdapter adapter;
  late BeakModelRegistry registry;
  late WormDataSource source;
  setUp(() async {
    Worm.seedRandom(8);
    adapter = await createApiTestDatabase();
    registry = createApiRegistry();
    source = WormDataSource(registry, adapter: adapter);
    await source.create('notes', BeakRecord.fromRow({'id': 'a', 'title': 'A'}));
    await source.create('notes', BeakRecord.fromRow({'id': 'b', 'title': 'B'}));
  });
  tearDown(Worm.reset);

  Future<BeakCandidateGraph> graph(
    List<BeakSaveOperation> operations, {
    int maxNodes = 10000,
    Future<void> Function(BeakRecordRef)? authorize,
  }) => BeakCandidateGraph.open(
    plan: BeakSavePlan(
      saveId: 'graph',
      root: const BeakRecordRef.existing('notes', 'a'),
      operations: operations,
    ),
    source: source,
    registry: registry,
    maxNodes: maxNodes,
    authorizeRead: authorize,
  );

  test(
    'final children merge drafts, moves and deletes without any database writes',
    () async {
      for (final id in ['kept', 'removed', 'moved']) {
        await source.create(
          'comments',
          BeakRecord.fromRow({'id': id, 'note_id': 'a', 'message': id}),
        );
      }
      final candidate = await graph([
        BeakSaveOperation(
          id: 'new',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('comments', 'new'),
          owner: const BeakRecordRef.existing('notes', 'a'),
          relationKey: 'comments',
          values: BeakRecord.fromRow({'message': 'New'}),
        ),
        BeakSaveOperation(
          id: 'remove',
          kind: BeakSaveOperationKind.delete,
          target: const BeakRecordRef.existing('comments', 'removed'),
        ),
        BeakSaveOperation(
          id: 'move',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('comments', 'moved'),
          values: BeakRecord.fromRow({'note_id': 'b'}),
        ),
      ]);
      final parent = await candidate.load(
        const BeakRecordRef.existing('notes', 'a'),
      );
      final children = await candidate.children(parent, _comments);
      expect(children.map((node) => node.read(_message)).toSet(), {
        'kept',
        'New',
      });
      expect(
        (await candidate.children(
          parent,
          _comments,
          includeDeleted: true,
        )).length,
        3,
      );
      final other = await candidate.load(
        const BeakRecordRef.existing('notes', 'b'),
      );
      expect(
        (await candidate.children(other, _comments)).single.read(_message),
        'moved',
      );
      expect((await source.getOne('comments', 'moved'))?['note_id']?.raw, 'a');
      expect(
        (await source.query(const BeakQuerySpec(table: 'comments'))).total,
        3,
      );
    },
  );

  test(
    'typed changes merge into original operation and generate stable extra writes',
    () async {
      final candidate = await graph([
        BeakSaveOperation(
          id: 'edit',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('notes', 'a'),
          values: BeakRecord.fromRow({'title': 'Edited'}),
        ),
      ]);
      final a = await candidate.load(
        const BeakRecordRef.existing('notes', 'a'),
      );
      final b = await candidate.load(
        const BeakRecordRef.existing('notes', 'b'),
      );
      expect(a.original(_title), 'A');
      expect(a.hasChanged(_title), isTrue);
      candidate.write(a, _title, 'Prepared');
      candidate.write(b, _title, 'Derived');
      candidate.write(b, _title, 'Final');
      final plan = candidate.build();
      expect(plan.operations.length, 2);
      expect(plan.operations.first.id, 'edit');
      expect(plan.operations.last.values['title']?.raw, 'Final');
      expect(candidate.build().toJson(), plan.toJson());
      expect(
        () => candidate.write(a, _message, 'wrong model'),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect((await source.getOne('notes', 'b'))?['title']?.raw, 'B');
    },
  );

  test(
    'dependency loading distinguishes original and changed linked records',
    () async {
      await source.create(
        'authors',
        BeakRecord.fromRow({'id': 'old', 'name': 'Old'}),
      );
      await source.create(
        'authors',
        BeakRecord.fromRow({'id': 'new', 'name': 'New'}),
      );
      await source.update(
        'notes',
        'a',
        BeakRecord.fromRow({'author_id': 'old'}),
      );
      final candidate = await graph([
        BeakSaveOperation(
          id: 'edit',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('notes', 'a'),
          references: {
            'author_id': const BeakRecordRef.existing('authors', 'new'),
          },
        ),
      ]);
      final node = await candidate.load(
        const BeakRecordRef.existing('notes', 'a'),
      );
      expect(
        node.reference(_author),
        const BeakRecordRef.existing('authors', 'new'),
      );
      expect(
        node.originalReference(_author),
        const BeakRecordRef.existing('authors', 'old'),
      );
      expect(node.hasChanged(_author), isTrue);
      final current = await candidate.materialize(node, fields: [_author]);
      final original = await candidate.materializeInitial(
        node,
        fields: [_author],
      );
      expect(_author.readFrom(current)?['name']?.raw, 'New');
      expect(_author.readFrom(original!)?['name']?.raw, 'Old');
    },
  );

  test('many-to-many final collection applies attach and detach', () async {
    for (final id in ['one', 'two']) {
      await source.create('labels', BeakRecord.fromRow({'id': id, 'name': id}));
    }
    await source.attach('notes', 'a', 'labels', ['one']);
    final candidate = await graph([
      BeakSaveOperation(
        id: 'remove',
        kind: BeakSaveOperationKind.detach,
        target: const BeakRecordRef.existing('notes', 'a'),
        relationKey: 'labels',
        related: const BeakRecordRef.existing('labels', 'one'),
      ),
      BeakSaveOperation(
        id: 'add',
        kind: BeakSaveOperationKind.attach,
        target: const BeakRecordRef.existing('notes', 'a'),
        relationKey: 'labels',
        related: const BeakRecordRef.existing('labels', 'two'),
      ),
    ]);
    final parent = await candidate.load(
      const BeakRecordRef.existing('notes', 'a'),
    );
    expect((await candidate.children(parent, _labels)).single.ref.id, 'two');
  });

  test(
    'children paginate and bounded graph loading rejects oversized candidates',
    () async {
      for (var index = 0; index < 105; index++) {
        await source.create(
          'comments',
          BeakRecord.fromRow({
            'id': '$index',
            'note_id': 'a',
            'message': '$index',
          }),
        );
      }
      final candidate = await graph([]);
      final parent = await candidate.load(
        const BeakRecordRef.existing('notes', 'a'),
      );
      expect((await candidate.children(parent, _comments)).length, 105);
      final bounded = await graph([], maxNodes: 2);
      final boundedParent = await bounded.load(parent.ref);
      await expectLater(
        bounded.children(boundedParent, _comments),
        throwsA(isA<BeakValidationException>()),
      );
    },
  );

  test(
    'every existing read is authorized once and undeclared drafts cannot be loaded',
    () async {
      final reads = <BeakRecordRef>[];
      final candidate = await graph(
        [],
        authorize: (ref) async {
          reads.add(ref);
        },
      );
      const ref = BeakRecordRef.existing('notes', 'a');
      expect(await candidate.load(ref), same(await candidate.load(ref)));
      expect(reads, [ref]);
      await expectLater(
        candidate.load(const BeakRecordRef.draft('notes', 'missing')),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );
}
