import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// A caller sees, and may write, only the notes they authored.
final class _OwnNotes extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _OwnNotes();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is NoteModel && principal != null
      ? NoteModel.authorId.eq(principal.id)
      : null;
}

/// A caller sees every note but the five-star ones: a scope no equality
/// constraint can state.
final class _NotFiveStars extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _NotFiveStars();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is NoteModel ? NoteModel.rating.notEq(5) : null;
}

BeakSavePlan _update(
  String saveId,
  String noteId, {
  Map<String, Object?> row = const {},
  Map<String, BeakRecordRef> references = const {},
  DateTime? expectedUpdatedAt,
}) => BeakSavePlan(
  saveId: saveId,
  root: BeakRecordRef.existing('notes', noteId),
  operations: [
    BeakSaveOperation(
      id: 'edit',
      kind: BeakSaveOperationKind.update,
      target: BeakRecordRef.existing('notes', noteId),
      values: BeakRecord.fromRow(row),
      references: references,
      expectedUpdatedAt: expectedUpdatedAt,
    ),
  ],
);

BeakSavePlan _create(String saveId, Map<String, Object?> row) => BeakSavePlan(
  saveId: saveId,
  root: const BeakRecordRef.draft('notes', 'note'),
  operations: [
    BeakSaveOperation(
      id: 'note',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('notes', 'note'),
      values: BeakRecord.fromRow(row),
    ),
  ],
);

final DateTime _stamp = DateTime.utc(2026, 1, 2, 3, 4, 5);

void main() {
  late WormDataSource source;
  late BeakModelRegistry registry;
  const sam = BeakPrincipal(id: 'sam');

  setUp(() async {
    final adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = createApiRegistry();
    source = WormDataSource(registry, adapter: adapter);
    for (final author in ['sam', 'mia']) {
      await source.create(
        'authors',
        BeakRecord.fromRow({'id': author, 'name': author}),
      );
    }
    await source.create(
      'notes',
      BeakRecord.fromRow({
        'id': 'mine',
        'title': 'Mine',
        'author_id': 'sam',
        'rating': 3,
      }),
    );
    await source.create(
      'notes',
      BeakRecord.fromRow({
        'id': 'versioned',
        'title': 'Versioned',
        'author_id': 'sam',
        'rating': 2,
        'updated_at': _stamp,
      }),
    );
    await source.create(
      'notes',
      BeakRecord.fromRow({
        'id': 'five',
        'title': 'Five',
        'author_id': 'mia',
        'rating': 5,
      }),
    );
  });
  tearDown(Worm.reset);

  BeakGraphCommitService serviceFor(BeakPolicy policy) =>
      BeakGraphCommitService(
        registry: registry,
        source: source,
        policy: policy,
      );

  Future<Object?> authorOf(String noteId) async =>
      (await source.getOne('notes', noteId))?['author_id']?.raw;

  group('a row scope holds for the row an update leaves behind', () {
    test('an update keeps applying while the row stays in scope', () async {
      final result = await serviceFor(const _OwnNotes()).commit(
        _update('keep', 'mine', row: {'title': 'Renamed'}),
        principal: sam,
      );

      expect(result.complete, isTrue);
      expect((await source.getOne('notes', 'mine'))?['title']?.raw, 'Renamed');
    });

    test('re-sending the scope column unchanged is not a move', () async {
      final result = await serviceFor(const _OwnNotes()).commit(
        _update('same', 'mine', row: {'author_id': 'sam', 'title': 'Again'}),
        principal: sam,
      );

      expect(result.complete, isTrue);
    });

    test('an update cannot hand a row to another owner', () async {
      final result = await serviceFor(const _OwnNotes()).commit(
        _update('give-away', 'mine', row: {'author_id': 'mia'}),
        principal: sam,
      );

      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.code, 'authorization');
      expect(await authorOf('mine'), 'sam');
    });

    test('a reference cannot hand a row to another owner either', () async {
      final result = await serviceFor(const _OwnNotes()).commit(
        _update(
          'give-away-ref',
          'mine',
          references: {
            'author_id': const BeakRecordRef.existing('authors', 'mia'),
          },
        ),
        principal: sam,
      );

      expect(result.complete, isFalse);
      expect(await authorOf('mine'), 'sam');
    });

    test('a scope equality cannot be dodged by clearing the column', () async {
      final result = await serviceFor(const _OwnNotes()).commit(
        _update('clear', 'mine', row: {'author_id': null}),
        principal: sam,
      );

      expect(result.complete, isFalse);
      expect(await authorOf('mine'), 'sam');
    });

    test('a create outside the scope is still refused', () async {
      final result = await serviceFor(const _OwnNotes()).commit(
        _create('foreign', {'title': 'For Mia', 'author_id': 'mia'}),
        principal: sam,
      );

      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.code, 'authorization');
    });

    test('a scope no equality can state still lets an update leave its '
        'columns alone', () async {
      final result = await serviceFor(const _NotFiveStars()).commit(
        _update('title-only', 'mine', row: {'title': 'Renamed'}),
        principal: sam,
      );

      expect(result.complete, isTrue);
    });

    test('and refuses the update that would cross it', () async {
      final result = await serviceFor(
        const _NotFiveStars(),
      ).commit(_update('to-five', 'mine', row: {'rating': 5}), principal: sam);

      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.code, 'authorization');
      expect((await source.getOne('notes', 'mine'))?['rating']?.raw, 3);
    });

    test('and admits an update that stays across it', () async {
      final result = await serviceFor(
        const _NotFiveStars(),
      ).commit(_update('to-four', 'mine', row: {'rating': 4}), principal: sam);

      expect(result.complete, isTrue);
      expect((await source.getOne('notes', 'mine'))?['rating']?.raw, 4);
    });
  });
  group('a version precondition does not lift the scope', () {
    test('a conditional update cannot hand a row to another owner', () async {
      final result = await serviceFor(const _OwnNotes()).commit(
        _update(
          'cond-give-away',
          'versioned',
          row: {'author_id': 'mia'},
          expectedUpdatedAt: _stamp,
        ),
        principal: sam,
      );

      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.code, 'authorization');
      expect(await authorOf('versioned'), 'sam');
    });

    test('a conditional update inside the scope applies', () async {
      final result = await serviceFor(const _OwnNotes()).commit(
        _update(
          'cond-rename',
          'versioned',
          row: {'title': 'Renamed'},
          expectedUpdatedAt: _stamp,
        ),
        principal: sam,
      );

      expect(result.complete, isTrue);
      expect(
        (await source.getOne('notes', 'versioned'))?['title']?.raw,
        'Renamed',
      );
    });

    test(
      'a conditional update cannot cross a scope no equality states',
      () async {
        final result = await serviceFor(const _NotFiveStars()).commit(
          _update(
            'cond-to-five',
            'versioned',
            row: {'rating': 5},
            expectedUpdatedAt: _stamp,
          ),
          principal: sam,
        );

        expect(result.complete, isFalse);
        expect((await source.getOne('notes', 'versioned'))?['rating']?.raw, 2);
      },
    );
  });

  group('a create meets the scope through what it would insert', () {
    test(
      'a scope written with an inequality admits a record inside it',
      () async {
        final result = await serviceFor(
          const _NotFiveStars(),
        ).commit(_create('create-three', {'title': 'Three', 'rating': 3}));

        expect(result.complete, isTrue);
      },
    );

    test('and refuses one outside it', () async {
      final result = await serviceFor(
        const _NotFiveStars(),
      ).commit(_create('create-five', {'title': 'Five', 'rating': 5}));

      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.code, 'authorization');
    });
  });

  group('over a source that is not transactional', () {
    late InMemoryBeakDataSource staged;

    setUp(() {
      staged = InMemoryBeakDataSource(registry: registry)
        ..seed(const AuthorModel(), [
          BeakRecord.fromRow({'id': 'sam', 'name': 'sam'}),
          BeakRecord.fromRow({'id': 'mia', 'name': 'mia'}),
        ])
        ..seed(const NoteModel(), [
          BeakRecord.fromRow({
            'id': 'mine',
            'title': 'Mine',
            'author_id': 'sam',
            'rating': 3,
          }),
          BeakRecord.fromRow({
            'id': 'hers',
            'title': 'Hers',
            'author_id': 'mia',
          }),
        ]);
    });

    test('an update out of scope is refused before it is written, so the '
        'outcome is a definite rejection', () async {
      final result =
          await BeakGraphCommitService(
            registry: registry,
            source: staged,
            policy: const _OwnNotes(),
          ).commit(
            _update('staged-give-away', 'mine', row: {'author_id': 'mia'}),
            principal: sam,
          );

      expect(result.mode, BeakSaveMode.staged);
      expect(result.hasUnknown, isFalse);
      expect(result.outcomes.single.status, BeakWriteOutcome.unapplied);
      expect(result.outcomes.single.reason, 'rejected');
      expect(result.outcomes.single.error?.code, 'authorization');
      expect(
        staged
            .rowsOf('notes')
            .firstWhere((row) => row['id']?.raw == 'mine')['author_id']
            ?.raw,
        'sam',
      );
    });

    test('a record the caller cannot see refuses the whole save before the '
        'first write', () async {
      final result =
          await BeakGraphCommitService(
            registry: registry,
            source: staged,
            policy: const _OwnNotes(),
          ).commit(
            BeakSavePlan(
              saveId: 'staged-mixed',
              root: const BeakRecordRef.draft('notes', 'fresh'),
              operations: [
                BeakSaveOperation(
                  id: 'fresh',
                  kind: BeakSaveOperationKind.create,
                  target: const BeakRecordRef.draft('notes', 'fresh'),
                  values: BeakRecord.fromRow({
                    'title': 'Fresh',
                    'author_id': 'sam',
                  }),
                ),
                BeakSaveOperation(
                  id: 'theirs',
                  kind: BeakSaveOperationKind.update,
                  target: const BeakRecordRef.existing('notes', 'hers'),
                  values: BeakRecord.fromRow({'title': 'Taken over'}),
                ),
              ],
            ),
            principal: sam,
          );

      expect(
        result.outcomes.map((outcome) => outcome.status),
        everyElement(BeakWriteOutcome.unapplied),
      );
      expect(result.outcomes.first.error?.code, 'not_found');
      expect(staged.rowsOf('notes'), hasLength(2));
    });
  });
}
