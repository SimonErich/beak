import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/candidate_graph_fixture.dart';

const _note = NoteModel();
const _comment = CommentModel();
const _title = BeakScalarField<String>(model: _note, column: NoteColumns.title);
const _message = BeakScalarField<String>(
  model: _comment,
  column: BeakTextColumn(key: 'message', label: 'Message'),
);
final _author = BeakToOneField(
  model: _note,
  target: const AuthorModel(),
  relation: _note.relationships.firstWhere(
    (relation) => relation.key == 'author',
  ),
);
final _commentNote = BeakToOneField(
  model: _comment,
  target: _note,
  relation: _comment.relationships.firstWhere(
    (relation) => relation.key == 'note',
  ),
);
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

void main() {
  group('record references', () {
    test('address an existing or draft record of a model', () {
      expect(
        BeakRecordRef.of(_note, 'a'),
        const BeakRecordRef.existing('notes', 'a'),
      );
      expect(
        BeakRecordRef.draftOf(_note, 'new'),
        const BeakRecordRef.draft('notes', 'new'),
      );
    });

    test('know which model they address', () {
      final ref = BeakRecordRef.of(_note, 'a');
      expect(ref.isOf(_note), isTrue);
      expect(ref.isOf(_comment), isFalse);
      expect(BeakRecordRef.draftOf(_comment, 'c').isOf(_comment), isTrue);
    });
  });

  group('typed field values', () {
    test('pair a field with its encoded value', () {
      final value = _title.to('Hello');
      expect(value.field, _title);
      expect(value.value, const BeakStringValue('Hello'));
      expect(_title.to(null).value, const BeakNullValue());
    });

    test('build a record without naming any storage key', () {
      final record = _note.record([_title.to('Hello'), totalField.to(3)]);
      expect(record.toRow(), {'title': 'Hello', 'total': 3});
      expect(_title.readFrom(record), 'Hello');
    });

    test('a record only accepts root fields of its own model', () {
      expect(
        () => _note.record([_message.to('Elsewhere')]),
        throwsA(isA<BeakConfigurationException>()),
      );
      final nested = BeakScalarField<String>(
        model: _note,
        column: NoteColumns.title,
        path: [_note.relationships.first],
      );
      expect(
        () => _note.record([nested.to('Nested')]),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('typed links', () {
    test('pair a belongs-to field with its target', () {
      final link = _author.linkTo(BeakRecordRef.of(const AuthorModel(), 'ann'));
      expect(link.field, _author);
      expect(link.target, const BeakRecordRef.existing('authors', 'ann'));
    });

    test('reject a target of another model or a non belongs-to field', () {
      expect(
        () => _author.linkTo(BeakRecordRef.of(_note, 'a')),
        throwsA(isA<BeakConfigurationException>()),
      );
      final collection = BeakToOneField(
        model: _note,
        target: _comment,
        relation: _note.relationships.firstWhere(
          (relation) => relation.key == 'comments',
        ),
      );
      expect(
        () => collection.linkTo(BeakRecordRef.of(_comment, 'c')),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('field validation failures', () {
    test('attach the message to the scalar field key', () {
      final error = _title.invalid('Enter a title.');
      expect(error.message, 'Enter a title.');
      expect(error.fieldErrors, {
        'title': ['Enter a title.'],
      });
    });

    test('a belongs-to failure is keyed by its foreign key', () {
      expect(_author.invalid('Choose an author.').fieldErrors, {
        'author_id': ['Choose an author.'],
      });
    });

    test('a has-one failure is keyed by its relationship', () {
      final profile = BeakToOneField(
        model: _note,
        target: const FixtureModel('profiles'),
        relation: _note.relationships.firstWhere(
          (relation) => relation.key == 'profile',
        ),
      );
      expect(profile.invalid('Add a profile.').fieldErrors, {
        'profile': ['Add a profile.'],
      });
    });

    test('a collection failure is keyed by its relationship', () {
      expect(_labels.invalid('Too many labels.').fieldErrors, {
        'labels': ['Too many labels.'],
      });
    });
  });

  group('creating a draft operation', () {
    test('writes typed values and links to the model without strings', () {
      final operation = BeakSaveOperation.create(
        id: 'comment',
        model: _comment,
        draftId: 'draft-comment',
        values: [_message.to('Nice')],
        links: [_commentNote.linkTo(BeakRecordRef.of(_note, 'a'))],
      );
      expect(operation.kind, BeakSaveOperationKind.create);
      expect(
        operation.target,
        const BeakRecordRef.draft('comments', 'draft-comment'),
      );
      expect(operation.values.toRow(), {'message': 'Nice'});
      expect(operation.references, {
        'note_id': const BeakRecordRef.existing('notes', 'a'),
      });
    });

    test('creates a row owned through a typed collection', () {
      final nested = BeakSaveOperation.create(
        id: 'comment',
        model: _comment,
        draftId: 'c',
        values: [_message.to('Hi')],
        owner: BeakRecordRef.of(_note, 'a'),
        through: _comments,
      );
      expect(nested.owner, BeakRecordRef.of(_note, 'a'));
      expect(nested.relationKey, 'comments');
      expect(nested.isVia(_comments), isTrue);
    });

    test('an owner and its collection go together', () {
      expect(
        () => BeakSaveOperation.create(
          id: 'comment',
          model: _comment,
          draftId: 'c',
          owner: BeakRecordRef.of(_note, 'a'),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakSaveOperation.create(
          id: 'comment',
          model: _comment,
          draftId: 'c',
          through: _comments,
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test(
      'rejects a link on a field that is not a root belongs-to of the model',
      () {
        expect(
          () => BeakSaveOperation.create(
            id: 'wrong',
            model: _note,
            draftId: 'n',
            links: [_commentNote.linkTo(BeakRecordRef.of(_note, 'a'))],
          ),
          throwsA(isA<BeakConfigurationException>()),
        );
        final collection = BeakToOneField(
          model: _note,
          target: _comment,
          relation: _note.relationships.firstWhere(
            (relation) => relation.key == 'comments',
          ),
        );
        expect(
          () => BeakSaveOperation.create(
            id: 'wrong',
            model: _note,
            draftId: 'n',
            links: [BeakFieldLink(collection, BeakRecordRef.of(_comment, 'c'))],
          ),
          throwsA(isA<BeakConfigurationException>()),
        );
      },
    );

    test('knows the relationship it acts through', () {
      final nested = BeakSaveOperation(
        id: 'nested',
        kind: BeakSaveOperationKind.create,
        target: BeakRecordRef.draftOf(_comment, 'c'),
        owner: BeakRecordRef.of(_note, 'a'),
        relationKey: 'labels',
      );
      expect(nested.isVia(_labels), isTrue);
      expect(nested.isVia(_author), isFalse);
      expect(
        BeakSaveOperation.create(
          id: 'plain',
          model: _note,
          draftId: 'n',
        ).isVia(_labels),
        isFalse,
      );
    });

    test('reports which typed fields it sets', () {
      final operation = BeakSaveOperation.create(
        id: 'note',
        model: _note,
        draftId: 'n',
        values: [_title.to('T')],
      );
      expect(operation.sets(_title), isTrue);
      expect(operation.sets(totalField), isFalse);
      expect(operation.sets(_message), isFalse);
    });
  });

  group('candidate graph helpers', () {
    late BeakModelRegistry registry;
    late MemorySource source;
    setUp(() async {
      registry = createApiRegistry();
      source = MemorySource(registry);
      await source.create(
        'notes',
        BeakRecord.fromRow({'id': 'a', 'title': 'A', 'total': 1}),
      );
      await source.create(
        'comments',
        BeakRecord.fromRow({'id': 'c', 'note_id': 'a', 'message': 'Hi'}),
      );
    });

    Future<BeakCandidateGraph> open(List<BeakSaveOperation> operations) =>
        BeakCandidateGraph.open(
          plan: BeakSavePlan(
            saveId: 'helpers',
            root: BeakRecordRef.of(_note, 'a'),
            operations: operations,
          ),
          source: source,
          registry: registry,
        );

    test('a node knows which model it belongs to', () async {
      final graph = await open([]);
      final node = await graph.load(BeakRecordRef.of(_note, 'a'));
      expect(node.isOf(_note), isTrue);
      expect(node.isOf(_comment), isFalse);
    });

    test('writes several typed values at once', () async {
      final graph = await open([]);
      final node = await graph.load(BeakRecordRef.of(_note, 'a'));
      graph.writeAll(node, [_title.to('Changed'), totalField.to(9)]);
      expect(node.read(_title), 'Changed');
      expect(node.read(totalField), 9);
      final update = graph.build().operations.single;
      expect(update.sets(_title), isTrue);
      expect(update.sets(totalField), isTrue);
    });

    test('rejects values of another model', () async {
      final graph = await open([]);
      final node = await graph.load(BeakRecordRef.of(_note, 'a'));
      expect(
        () => graph.writeAll(node, [_message.to('Wrong')]),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('restores fields to their persisted values', () async {
      final graph = await open([
        BeakSaveOperation(
          id: 'edit',
          kind: BeakSaveOperationKind.update,
          target: BeakRecordRef.of(_note, 'a'),
          values: _note.record([_title.to('Edited'), totalField.to(5)]),
        ),
      ]);
      final node = await graph.load(BeakRecordRef.of(_note, 'a'));
      expect(node.read(_title), 'Edited');
      graph.restore(node, [_title, totalField]);
      expect(node.read(_title), 'A');
      expect(node.read(totalField), 1);
    });

    test('restoring a new record clears the fields', () async {
      final draft = BeakRecordRef.draftOf(_note, 'fresh');
      final graph = await open([
        BeakSaveOperation.create(
          id: 'fresh',
          model: _note,
          draftId: 'fresh',
          values: [_title.to('Fresh')],
        ),
      ]);
      final node = await graph.load(draft);
      graph.restore(node, [_title]);
      expect(node.read(_title), isNull);
    });
  });

  group('data source lookups', () {
    late MemorySource source;
    setUp(() async {
      source = MemorySource(createApiRegistry());
      await source.create(
        'notes',
        BeakRecord.fromRow({'id': 'a', 'title': 'A'}),
      );
      await source.create(
        'notes',
        BeakRecord.fromRow({'id': 'b', 'title': 'B'}),
      );
    });

    test('find reads a record by model and id', () async {
      final found = await source.find(_note, 'a');
      expect(_title.readFrom(found!), 'A');
      expect(await source.find(_note, 'missing'), isNull);
    });

    test('findWhere returns the first match or null', () async {
      final found = await source.findWhere(_note, _title.eq('B'));
      expect(_title.readFrom(found!), 'B');
      expect(await source.findWhere(_note, _title.eq('Z')), isNull);
    });
  });
}
