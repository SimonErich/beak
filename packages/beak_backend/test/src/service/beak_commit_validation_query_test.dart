import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// A product whose stock-keeping code is unique and hidden from staff.
final class _Item extends BeakModel {
  const _Item();

  static const sku = BeakScalarField<String>(
    model: _Item(),
    column: _skuColumn,
  );

  static const BeakColumn _skuColumn = BeakStringColumn(
    key: 'sku',
    label: 'SKU',
    unique: true,
  );

  @override
  String get table => 'items';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
    _skuColumn,
  ];
}

/// A note whose author code must name an author the caller may see: a check
/// about what may be pointed at, not about the note itself.
final class _CodedNote extends BeakModel {
  const _CodedNote();

  static const authorCode = BeakScalarField<String>(
    model: _CodedNote(),
    column: NoteColumns.authorId,
  );

  static const authorKey = BeakScalarField<String>(
    model: AuthorModel(),
    column: BeakStringColumn(key: 'id', label: 'Id'),
  );

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => NoteColumns.values;

  @override
  List<BeakRecordRule> get validationRules => [
    const BeakExists(authorCode, authorKey),
  ];
}

/// Shows a caller only the author called "ada".
final class _OnlyAda extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _OnlyAda();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is AuthorModel
      ? BeakFieldFilter.forKey('id', BeakOperator.eq, BeakValue.of('ada'))
      : null;
}

void main() {
  late WormDataSource source;
  late BeakModelRegistry registry;
  late BeakGraphCommitService service;
  const staff = BeakPrincipal(id: 'sam', roles: {'staff'});
  const staffOnly = BeakAccess.role('staff');

  setUp(() async {
    final adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'items',
        columns: [
          SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
          SchemaColumn(name: 'name', type: ColumnType.text),
          SchemaColumn(name: 'sku', type: ColumnType.text),
        ],
      ),
    );
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = BeakModelRegistry()..register(const _Item());
    source = WormDataSource(registry, adapter: adapter);
    await source.create(
      'items',
      BeakRecord.fromRow({'id': 'one', 'name': 'One', 'sku': 'A-1'}),
    );
    service = BeakGraphCommitService(
      registry: registry,
      source: source,
      policy: BeakPolicies(
        rules: [
          BeakModelRules(
            const _Item(),
            read: staffOnly,
            write: staffOnly,
            hiddenFields: {_Item.sku: staffOnly},
          ),
        ],
      ),
    );
  });
  tearDown(Worm.reset);

  test('staff may rename an item whose unique code they cannot see', () async {
    final result = await service.commit(
      BeakSavePlan(
        saveId: 'rename',
        root: const BeakRecordRef.existing('items', 'one'),
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: const BeakRecordRef.existing('items', 'one'),
            values: BeakRecord.fromRow({'name': 'Renamed'}),
          ),
        ],
      ),
      principal: staff,
    );

    expect(result.complete, isTrue, reason: result.toJson().toString());
  });

  test('and may add an item without one', () async {
    final result = await service.commit(
      BeakSavePlan(
        saveId: 'add',
        root: const BeakRecordRef.draft('items', 'item'),
        operations: [
          BeakSaveOperation(
            id: 'item',
            kind: BeakSaveOperationKind.create,
            target: const BeakRecordRef.draft('items', 'item'),
            values: BeakRecord.fromRow({'name': 'Two'}),
          ),
        ],
      ),
      principal: staff,
    );

    expect(result.complete, isTrue, reason: result.toJson().toString());
  });

  group('an existence check still goes through the caller\'s view', () {
    late BeakModelRegistry coded;
    late WormDataSource codedSource;

    setUp(() async {
      final adapter = await createApiTestDatabase();
      await const BeakCommitReceiptsMigration().up(adapter);
      coded = BeakModelRegistry()
        ..register(const _CodedNote())
        ..register(const AuthorModel());
      codedSource = WormDataSource(coded, adapter: adapter);
      for (final author in ['ada', 'mia']) {
        await codedSource.create(
          'authors',
          BeakRecord.fromRow({'id': author, 'name': author}),
        );
      }
    });

    Future<BeakSaveResult> addNoteBy(String author) =>
        BeakGraphCommitService(
          registry: coded,
          source: codedSource,
          policy: const _OnlyAda(),
        ).commit(
          BeakSavePlan(
            saveId: 'note-by-$author',
            root: const BeakRecordRef.draft('notes', 'note'),
            operations: [
              BeakSaveOperation(
                id: 'note',
                kind: BeakSaveOperationKind.create,
                target: const BeakRecordRef.draft('notes', 'note'),
                values: BeakRecord.fromRow({'title': 'T', 'author_id': author}),
              ),
            ],
          ),
          principal: staff,
        );

    test('an author the caller can see is accepted', () async {
      expect((await addNoteBy('ada')).complete, isTrue);
    });

    test('one they cannot see is not available to them', () async {
      final result = await addNoteBy('mia');

      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.fieldErrors, {
        'author_id': ['The selected value is not available.'],
      });
    });
  });
}
