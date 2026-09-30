import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

const BeakBelongsTo _authorRelation = BeakBelongsTo(
  key: 'author',
  label: 'Author',
  relatedTable: 'authors',
  displayColumnKey: 'name',
  foreignKey: 'author_id',
);

/// A note whose body is required while its author is called "Ada": a rule that
/// reads a record the note does not own.
final class _RuledNote extends BeakModel {
  const _RuledNote();

  static const body = BeakScalarField<String>(
    model: _RuledNote(),
    column: NoteColumns.body,
  );

  static const authorName = BeakScalarField<String>(
    model: _RuledNote(),
    column: BeakStringColumn(key: 'name', label: 'Name'),
    path: [_authorRelation],
  );

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => NoteColumns.values;

  @override
  List<BeakRelationship> get relationships => const [_authorRelation];

  @override
  List<BeakRecordRule> get validationRules => [
    BeakRequiredIf(body, when: BeakWhen.equals(authorName, 'Ada')),
  ];
}

/// A caller sees only the notes they authored.
final class _OwnNotes extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _OwnNotes();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is _RuledNote && principal != null
      ? BeakFieldFilter.forKey(
          'author_id',
          BeakOperator.eq,
          BeakValue.of(principal.id),
        )
      : null;
}

BeakSavePlan _renameAuthor(String saveId, String authorId, String name) =>
    BeakSavePlan(
      saveId: saveId,
      root: BeakRecordRef.existing('authors', authorId),
      operations: [
        BeakSaveOperation(
          id: 'rename',
          kind: BeakSaveOperationKind.update,
          target: BeakRecordRef.existing('authors', authorId),
          values: BeakRecord.fromRow({'name': name}),
        ),
      ],
    );

/// A rule that reads a shared record is checked again when that record
/// changes, for every record it governs, whoever owns them.
void main() {
  late WormDataSource source;
  late BeakModelRegistry registry;
  const sam = BeakPrincipal(id: 'sam');

  setUp(() async {
    final adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = BeakModelRegistry()
      ..register(const _RuledNote())
      ..register(const AuthorModel());
    source = WormDataSource(registry, adapter: adapter);
    for (final author in [('sam', 'Sam'), ('ada', 'Ada')]) {
      await source.create(
        'authors',
        BeakRecord.fromRow({'id': author.$1, 'name': author.$2}),
      );
    }
    await source.create(
      'notes',
      BeakRecord.fromRow({
        'id': 'ada-note',
        'title': 'Ada writes',
        'body': 'Some words',
        'author_id': 'ada',
      }),
    );
    await source.create(
      'notes',
      BeakRecord.fromRow({
        'id': 'sam-note',
        'title': 'Sam writes',
        'author_id': 'sam',
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

  test(
    'a caller may edit a shared record whose dependents are not theirs',
    () async {
      final result = await serviceFor(
        const _OwnNotes(),
      ).commit(_renameAuthor('rename-ada', 'ada', 'Ada L.'), principal: sam);

      expect(result.complete, isTrue, reason: result.toJson().toString());
      expect((await source.getOne('authors', 'ada'))?['name']?.raw, 'Ada L.');
    },
  );

  test('and a dependent it would break still refuses the change', () async {
    await source.update(
      'notes',
      'ada-note',
      BeakRecord.fromRow({'body': null}),
    );

    final result = await serviceFor(
      const _OwnNotes(),
    ).commit(_renameAuthor('rename-sam', 'sam', 'Ada'), principal: sam);

    expect(result.complete, isFalse);
    expect((await source.getOne('authors', 'sam'))?['name']?.raw, 'Sam');
  });

  test('and refuses it, as a validation failure, when a dependent that is not '
      'the caller\'s would break', () async {
    await source.update('authors', 'ada', BeakRecord.fromRow({'name': 'Zed'}));
    await source.update(
      'notes',
      'ada-note',
      BeakRecord.fromRow({'body': null}),
    );

    final result = await serviceFor(
      const _OwnNotes(),
    ).commit(_renameAuthor('rename-back', 'ada', 'Ada'), principal: sam);

    expect(result.complete, isFalse);
    expect(result.outcomes.single.error?.code, 'validation');
    expect((await source.getOne('authors', 'ada'))?['name']?.raw, 'Zed');
  });
}
