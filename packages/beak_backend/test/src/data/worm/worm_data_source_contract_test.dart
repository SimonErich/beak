import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../../support/api_models.dart';

/// The fixture authors table, given the has-many back to its notes that the
/// shared fixture leaves out, so the contract can walk `authors -> notes ->
/// comments` and load a relation inside a relation.
final class _AuthorWithNotesModel extends BeakModel {
  const _AuthorWithNotesModel();

  @override
  String get table => 'authors';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const AuthorModel().columns;

  @override
  List<BeakRelationship> get relationships => const [
    BeakHasMany(
      key: 'notes',
      label: 'Notes',
      relatedTable: 'notes',
      displayColumnKey: 'title',
      foreignKey: 'author_id',
    ),
  ];
}

BeakModelRegistry _contractRegistry() => BeakModelRegistry()
  ..register(const NoteModel())
  ..register(const LabelModel())
  ..register(const CommentModel())
  ..register(const _AuthorWithNotesModel());

/// Runs the shared [BeakDataSource] contract against [WormDataSource].
///
/// This is the point of having an executable contract: the same suite that
/// pins `InMemoryBeakDataSource`'s behaviour now holds the real worm-backed
/// source to it. Where the two disagree, one of them is wrong, and until
/// this existed, nothing said which.
void main() {
  late InMemoryAdapter adapter;

  tearDown(Worm.reset);

  // --8<-- [start:contract]
  runBeakDataSourceContract(
    'WormDataSource',
    registry: _contractRegistry(),
    model: const NoteModel(),
    create: () async {
      adapter = await createApiTestDatabase();
      return WormDataSource(_contractRegistry(), adapter: adapter);
    },
    seed: (source, model, records) async {
      for (final record in records) {
        await adapter.insert(
          InsertDescriptor(table: model.table, values: record.toRow()),
        );
      }
    },
    sortableTextColumn: NoteColumns.title,
    numericColumn: NoteColumns.rating,
    relationModels: const [NoteModel(), _AuthorWithNotesModel()],
    seedLinks: (source, relation, ownerId, relatedIds) async {
      for (final relatedId in relatedIds) {
        await adapter.insert(
          InsertDescriptor(
            table: relation.pivotTable,
            values: {
              relation.foreignPivotKey: ownerId,
              relation.relatedPivotKey: relatedId,
            },
          ),
        );
      }
    },
  );
  // --8<-- [end:contract]
}
