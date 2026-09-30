import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import '../../support/candidate_graph_fixture.dart';

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
  late BeakModelRegistry registry;
  late MemorySource source;
  setUp(() async {
    registry = createApiRegistry();
    source = MemorySource(registry);
    await source.create('notes', BeakRecord.fromRow({'id': 'a', 'title': 'A'}));
    await source.create('notes', BeakRecord.fromRow({'id': 'b', 'title': 'B'}));
  });

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

  test(
    'generated links retain draft ordering, patches and explicit unlinking',
    () async {
      const author = BeakRecordRef.draft('authors', 'author');
      final candidate = await graph([
        BeakSaveOperation(
          id: 'edit',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('notes', 'a'),
          values: BeakRecord.fromRow({'title': 'Edited'}),
          expectedUpdatedAt: DateTime.utc(2026),
        ),
        BeakSaveOperation(
          id: 'author',
          kind: BeakSaveOperationKind.create,
          target: author,
          values: BeakRecord.fromRow({'name': 'New author'}),
        ),
      ]);
      final node = await candidate.load(
        const BeakRecordRef.existing('notes', 'a'),
      );
      candidate.link(node, _author, author);
      candidate.link(node, _author, author);
      candidate.write(node, _title, 'Prepared');
      expect(node.reference(_author), author);
      expect((await candidate.linked(node, _author))!.ref, author);
      var plan = candidate.build();
      expect(plan.orderedOperations(registry).map((op) => op.id), [
        'author',
        'edit',
      ]);
      expect(plan.operations.first.expectedUpdatedAt, DateTime.utc(2026));
      expect(plan.operations.first.values['title']?.raw, 'Prepared');
      candidate.link(node, _author, null);
      plan = candidate.build();
      expect(node.reference(_author), isNull);
      expect(plan.operations.first.references, isEmpty);
      expect(plan.operations.first.values['author_id']?.raw, isNull);

      final other = await candidate.load(
        const BeakRecordRef.existing('notes', 'b'),
      );
      candidate.link(
        other,
        _author,
        const BeakRecordRef.existing('authors', 'saved'),
      );
      candidate.link(other, _author, author);
      expect(candidate.build().operations.last.references['author_id'], author);
      expect((await source.getOne('notes', 'a'))?['author_id']?.raw, isNull);

      for (final invalid in [
        const BeakRecordRef.existing('notes', 'a'),
        const BeakRecordRef.draft('authors', 'undeclared'),
      ]) {
        expect(
          () => candidate.link(node, _author, invalid),
          throwsA(isA<BeakConfigurationException>()),
        );
      }
      final inverse = BeakToOneField(
        model: _note,
        target: const FixtureModel('profiles'),
        relation: _note.relationships.firstWhere(
          (value) => value.key == 'profile',
        ),
      );
      expect(
        () => candidate.link(node, inverse, null),
        throwsA(isA<BeakConfigurationException>()),
      );
      final deleting = await graph([
        BeakSaveOperation(
          id: 'delete',
          kind: BeakSaveOperationKind.delete,
          target: const BeakRecordRef.existing('notes', 'a'),
        ),
      ]);
      final deleted = await deleting.load(
        const BeakRecordRef.existing('notes', 'a'),
      );
      expect(
        () => deleting.link(deleted, _author, author),
        throwsA(isA<BeakConfigurationException>()),
      );
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
  test(
    'draft references, one-to-one ownership and unchanged overlays remain typed',
    () async {
      const draft = BeakRecordRef.draft('notes', 'draft');
      const childRef = BeakRecordRef.draft('comments', 'child');
      final candidate = await graph([
        BeakSaveOperation(
          id: 'parent',
          kind: BeakSaveOperationKind.create,
          target: draft,
          values: BeakRecord.fromRow({'title': 'Draft'}),
        ),
        BeakSaveOperation(
          id: 'child',
          kind: BeakSaveOperationKind.create,
          target: childRef,
          owner: draft,
          relationKey: 'comments',
          values: BeakRecord.fromRow({'message': 'Child'}),
        ),
        BeakSaveOperation(
          id: 'profile',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('profiles', 'profile'),
          owner: draft,
          relationKey: 'profile',
          values: BeakRecord.fromRow({'name': 'Profile'}),
        ),
      ]);
      final parent = await candidate.load(draft);
      final child = await candidate.load(childRef);
      final note = BeakToOneField(
        model: _comment,
        target: _note,
        relation: _comment.relationships.firstWhere(
          (relation) => relation.key == 'note',
        ),
      );
      expect(child.reference(note), draft);
      expect(child.originalReference(note), isNull);
      expect(child.original(_message), isNull);
      expect(child.materiallyChanged(), isTrue);
      expect(await candidate.linked(child, note), same(parent));
      expect((await candidate.owners(child)).single, same(parent));
      expect(await candidate.materializeInitial(child), isNull);
      final profile = BeakToOneField(
        model: _note,
        target: const FixtureModel('profiles'),
        relation: _note.relationshipByKey('profile')!,
      );
      expect(
        (await candidate.linked(parent, profile))!.values['name']?.raw,
        'Profile',
      );
      expect(
        (await candidate.owners(
          (await candidate.linked(parent, profile))!,
        )).single,
        same(parent),
      );
      expect(
        () => parent.reference(profile),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => parent.originalReference(profile),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        (await candidate.dependencies(parent, [_comments])).single,
        same(child),
      );
      expect(
        (await candidate.dependencies(child, [note])).single,
        same(parent),
      );
    },
  );

  test(
    'has-many attach/detach overlays and initial nested loads reflect both graph versions',
    () async {
      await source.create(
        'comments',
        BeakRecord.fromRow({'id': 'moved', 'note_id': 'b', 'message': 'M'}),
      );
      await source.create(
        'comments',
        BeakRecord.fromRow({'id': 'removed', 'note_id': 'a', 'message': 'R'}),
      );
      await source.create(
        'authors',
        BeakRecord.fromRow({'id': 'author', 'name': 'Author'}),
      );
      await source.update(
        'notes',
        'a',
        BeakRecord.fromRow({'author_id': 'author'}),
      );
      final candidate = await graph([
        BeakSaveOperation(
          id: 'detach',
          kind: BeakSaveOperationKind.detach,
          target: const BeakRecordRef.existing('notes', 'a'),
          relationKey: 'comments',
          related: const BeakRecordRef.existing('comments', 'removed'),
        ),
        BeakSaveOperation(
          id: 'attach',
          kind: BeakSaveOperationKind.attach,
          target: const BeakRecordRef.existing('notes', 'a'),
          relationKey: 'comments',
          related: const BeakRecordRef.existing('comments', 'moved'),
        ),
      ]);
      final parent = await candidate.load(
        const BeakRecordRef.existing('notes', 'a'),
      );
      expect(
        (await candidate.children(parent, _comments)).single.ref.id,
        'moved',
      );
      expect(
        (await candidate.materializeInitial(
          parent,
          fields: [_comments],
        ))!.relations['comments']!.single['id']?.raw,
        'removed',
      );
      final nestedName = BeakScalarField<String>(
        model: _comment,
        column: const BeakStringColumn(key: 'name', label: 'Name'),
        path: [
          _comment.relationshipByKey('note')!,
          _note.relationshipByKey('author')!,
        ],
      );
      final moved = await candidate.load(
        const BeakRecordRef.existing('comments', 'moved'),
      );
      expect(
        nestedName.readFrom(
          await candidate.materialize(moved, fields: [nestedName]),
        ),
        'Author',
      );
      expect(
        nestedName.readFrom(
          (await candidate.materializeInitial(moved, fields: [nestedName]))!,
        ),
        isNull,
      );
      expect(
        (await candidate.parents(moved)).map((node) => node.ref.id).toSet(),
        {'a', 'b'},
      );
      expect(moved.materiallyChanged(), isTrue);
      const fk = BeakScalarField<String>(
        model: _comment,
        column: BeakStringColumn(key: 'note_id', label: 'Note'),
      );
      expect(moved.materiallyChanged(except: [fk]), isFalse);
    },
  );

  test(
    'patch diagnostics reject missing records, unknown fields and deleted candidates',
    () async {
      final candidate = await graph([
        BeakSaveOperation(
          id: 'delete',
          kind: BeakSaveOperationKind.delete,
          target: const BeakRecordRef.existing('notes', 'b'),
        ),
      ]);
      final deleted = await candidate.load(
        const BeakRecordRef.existing('notes', 'b'),
      );
      expect(deleted.deleted, isTrue);
      expect(
        () => candidate.patch(deleted, BeakRecord.fromRow({'title': 'No'})),
        throwsA(isA<BeakConfigurationException>()),
      );
      final parent = await candidate.load(
        const BeakRecordRef.existing('notes', 'a'),
      );
      expect(parent.changed, isFalse);
      expect(parent.materiallyChanged(), isFalse);
      expect(
        () => candidate.patch(parent, BeakRecord.fromRow({'unknown': true})),
        throwsA(isA<BeakConfigurationException>()),
      );
      await expectLater(
        candidate.load(const BeakRecordRef.existing('notes', 'missing')),
        throwsA(isA<BeakNotFoundException>()),
      );
      expect(await candidate.linked(parent, _author), isNull);
      candidate.patch(parent, parent.record);
      expect(candidate.build().operations.length, 1);
      expect(
        () => parent.values['name'] = const BeakStringValue('readonly'),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'generated operation IDs cannot collide with caller identities',
    () async {
      final candidate = await graph([
        BeakSaveOperation(
          id: 'beak-derived-0',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('notes', 'a'),
        ),
      ]);
      candidate.write(
        await candidate.load(const BeakRecordRef.existing('notes', 'b')),
        _title,
        'Changed',
      );
      expect(candidate.build().operations.last.id, 'beak-derived-1');
    },
  );

  test(
    'unsupported staged behavior has a definite receipt and unrelated models remain usable',
    () async {
      final staged = BeakStagedCommitDataSource(
        source: source,
        registry: registry,
      );
      final invalid = BeakSavePlan(
        saveId: 'behavior',
        root: const BeakRecordRef.existing('notes', 'a'),
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: const BeakRecordRef.existing('notes', 'a'),
            values: BeakRecord.fromRow({'title': 'Changed'}),
          ),
        ],
      );
      final rejected = await staged.commit(invalid);
      expect(rejected.hasUnknown, isFalse);
      expect(rejected.outcomes.single.status, BeakWriteOutcome.unapplied);
      expect((await staged.recover('behavior')).toJson(), rejected.toJson());
      await source.create(
        'authors',
        BeakRecord.fromRow({'id': 'author', 'name': 'Old'}),
      );
      final allowed = await staged.commit(
        BeakSavePlan(
          saveId: 'plain',
          root: const BeakRecordRef.existing('authors', 'author'),
          operations: [
            BeakSaveOperation(
              id: 'edit',
              kind: BeakSaveOperationKind.update,
              target: const BeakRecordRef.existing('authors', 'author'),
              values: BeakRecord.fromRow({'name': 'Changed'}),
            ),
          ],
        ),
      );
      expect(allowed.complete, isTrue);
    },
  );
  test(
    'unchanged and draft relationship identities have precise change tracking',
    () async {
      await source.update(
        'notes',
        'a',
        BeakRecord.fromRow({'author_id': 'existing'}),
      );
      final unchanged = await graph([
        BeakSaveOperation(
          id: 'same',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('notes', 'a'),
          references: {
            'author_id': const BeakRecordRef.existing('authors', 'existing'),
          },
        ),
      ]);
      final before = await unchanged.load(
        const BeakRecordRef.existing('notes', 'a'),
      );
      expect(before.materiallyChanged(), isFalse);
      expect(unchanged.nodes.single, same(before));
      final draft = await graph([
        BeakSaveOperation(
          id: 'author',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('authors', 'author'),
          values: BeakRecord.fromRow({'name': 'Draft'}),
        ),
        BeakSaveOperation(
          id: 'note',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('notes', 'a'),
          references: {
            'author_id': const BeakRecordRef.draft('authors', 'author'),
          },
        ),
      ]);
      final node = await draft.load(const BeakRecordRef.existing('notes', 'a'));
      expect(node.materiallyChanged(), isTrue);
      const foreignKey = BeakScalarField<String>(
        model: _note,
        column: BeakStringColumn(key: 'author_id', label: 'Author'),
      );
      draft.write(node, foreignKey, 'replacement');
      expect(
        node.reference(_author),
        const BeakRecordRef.existing('authors', 'replacement'),
      );
      expect(draft.build().operations.last.references, isEmpty);
      final invalid = await graph([
        BeakSaveOperation(
          id: 'invalid',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('notes', 'a'),
          references: {'author_id': const BeakRecordRef.existing('notes', 'b')},
        ),
      ]);
      expect(
        () => invalid.nodes.single.reference(_author),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );
  test('staged writes reject non-owned live derivation dependencies', () async {
    registry.register(const _LiveParent());
    await source.create(
      'authors',
      BeakRecord.fromRow({'id': 'author', 'name': 'Old'}),
    );
    final staged = BeakStagedCommitDataSource(
      source: source,
      registry: registry,
    );
    final result = await staged.commit(
      BeakSavePlan(
        saveId: 'live',
        root: const BeakRecordRef.existing('authors', 'author'),
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: const BeakRecordRef.existing('authors', 'author'),
            values: BeakRecord.fromRow({'name': 'New'}),
          ),
        ],
      ),
    );
    expect(result.complete, isFalse);
    expect(result.hasUnknown, isFalse);
    expect((await source.getOne('authors', 'author'))?['name']?.raw, 'Old');
    await source.create(
      'labels',
      BeakRecord.fromRow({'id': 'label', 'name': 'Old'}),
    );
    final unrelated = await staged.commit(
      BeakSavePlan(
        saveId: 'unrelated',
        root: const BeakRecordRef.existing('labels', 'label'),
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: const BeakRecordRef.existing('labels', 'label'),
            values: BeakRecord.fromRow({'name': 'New'}),
          ),
        ],
      ),
    );
    expect(unrelated.complete, isTrue);
  });
}

final class _LiveParent extends FixtureModel {
  const _LiveParent() : super('live_parents');
  @override
  List<BeakRelationship> get relationships => const [
    BeakHasMany(
      key: 'authors',
      label: 'Authors',
      relatedTable: 'authors',
      displayColumnKey: 'name',
      foreignKey: 'note_id',
    ),
  ];
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior<int>.derived(
        field: const BeakScalarField<int>(
          model: _LiveParent(),
          column: BeakIntColumn(key: 'total', label: 'Total'),
        ),
        dependencies: [
          BeakToManyField(
            model: this,
            relation: relationships.single,
            target: const AuthorModel(),
          ),
        ],
        resolve: (_) => 0,
      ),
    ],
  );
}
