import 'package:beak_core/beak_core.dart';

const fixtureColumns = <BeakColumn>[
  BeakStringColumn(key: 'id', label: 'ID'),
  BeakStringColumn(key: 'name', label: 'Name'),
  BeakStringColumn(key: 'title', label: 'Title'),
  BeakTextColumn(key: 'message', label: 'Message'),
  BeakStringColumn(key: 'note_id', label: 'Note'),
  BeakStringColumn(key: 'comment_id', label: 'Comment'),
  BeakStringColumn(key: 'author_id', label: 'Author'),
  BeakStringColumn(key: 'code', label: 'Code', unique: true),
  BeakStringColumn(
    key: 'password',
    label: 'Password',
    semantic: BeakSemantic.password(),
  ),
  BeakStringColumn(key: 'state', label: 'State', defaultValue: 'draft'),
  BeakIntColumn(key: 'total', label: 'Total'),
  BeakStringColumn(key: 'snapshot', label: 'Snapshot'),
  BeakDateTimeColumn(key: 'created_at', label: 'Created'),
  BeakDateTimeColumn(key: 'updated_at', label: 'Updated'),
];

abstract final class NoteColumns {
  static const title = BeakStringColumn(key: 'title', label: 'Title');
}

base class FixtureModel extends BeakModel {
  const FixtureModel(this.table);
  @override
  final String table;
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => fixtureColumns;
}

final class NoteModel extends FixtureModel {
  const NoteModel() : super('notes');
  @override
  List<BeakRelationship> get relationships => const [
    BeakBelongsTo(
      key: 'author',
      label: 'Author',
      relatedTable: 'authors',
      displayColumnKey: 'name',
      foreignKey: 'author_id',
    ),
    BeakHasMany(
      key: 'comments',
      label: 'Comments',
      relatedTable: 'comments',
      displayColumnKey: 'message',
      foreignKey: 'note_id',
      owned: true,
    ),
    BeakHasOne(
      key: 'profile',
      label: 'Profile',
      relatedTable: 'profiles',
      displayColumnKey: 'name',
      foreignKey: 'note_id',
      owned: true,
    ),
    BeakBelongsToMany(
      key: 'labels',
      label: 'Labels',
      relatedTable: 'labels',
      displayColumnKey: 'name',
      pivotTable: 'note_label',
      foreignPivotKey: 'note_id',
      relatedPivotKey: 'label_id',
    ),
  ];
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior<String>.initial(
        field: stateField,
        resolve: (_) => 'draft',
      ),
      BeakValueBehavior<int>.derived(field: totalField, resolve: (_) => 5),
      BeakValueBehavior<String>.snapshot(
        field: snapshotField,
        onAction: 'publish',
        resolve: (_) => 'frozen',
      ),
    ],
    actions: [
      BeakModelAction(
        name: 'publish',
        label: 'Publish',
        values: [
          BeakValueBehavior<String>.derived(
            field: stateField,
            resolve: (_) => 'published',
          ),
        ],
      ),
    ],
  );
}

final class CommentModel extends FixtureModel {
  const CommentModel() : super('comments');
  @override
  List<BeakRelationship> get relationships => const [
    BeakBelongsTo(
      key: 'note',
      label: 'Note',
      relatedTable: 'notes',
      displayColumnKey: 'name',
      foreignKey: 'note_id',
    ),
    BeakHasOne(
      key: 'detail',
      label: 'Detail',
      relatedTable: 'profiles',
      displayColumnKey: 'name',
      foreignKey: 'comment_id',
      owned: true,
    ),
  ];
}

final class AuthorModel extends FixtureModel {
  const AuthorModel() : super('authors');
}

final class LabelModel extends FixtureModel {
  const LabelModel() : super('labels');
}

const stateField = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(key: 'state', label: 'State', defaultValue: 'draft'),
);
const totalField = BeakScalarField<int>(
  model: NoteModel(),
  column: BeakIntColumn(key: 'total', label: 'Total'),
);
const snapshotField = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(key: 'snapshot', label: 'Snapshot'),
);

BeakModelRegistry createApiRegistry() => BeakModelRegistry()
  ..register(const NoteModel())
  ..register(const CommentModel())
  ..register(const AuthorModel())
  ..register(const LabelModel())
  ..register(const FixtureModel('profiles'));

/// In-memory read fixture with explicit relation storage; not a mutation engine.
final class MemorySource implements BeakDataSource {
  MemorySource(this.registry);
  final BeakModelRegistry registry;
  final Map<String, Map<Object, BeakRecord>> rows = {};
  final Map<String, Set<Object>> links = {};
  @override
  Future<BeakRecord?> getOne(String table, Object id) async => rows[table]?[id];
  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    rows.putIfAbsent(table, () => {})[data['id']!.raw!] = data;
    return data;
  }

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async {
    final record = BeakRecord(
      values: {...rows[table]![id]!.values, ...data.values},
    );
    rows[table]![id] = record;
    return record;
  }

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> ids,
  ) async {
    links.putIfAbsent('$table:$id:$relationKey', () => {}).addAll(ids);
  }

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    final filter = spec.filter;
    final selected = (rows[spec.table]?.values ?? <BeakRecord>[])
        .where(
          (row) =>
              filter is! BeakFieldFilter ||
              row[filter.columnKey]?.raw == filter.value.raw,
        )
        .toList();
    final result = <BeakRecord>[];
    for (final row
        in selected
            .skip((spec.pagination.page - 1) * spec.pagination.perPage)
            .take(spec.pagination.perPage)) {
      final relations = <String, List<BeakRecord>>{};
      for (final load in spec.relationLoads) {
        final relation = registry
            .byTableOrThrow(spec.table)
            .relationshipByKey(load.relationKey)!;
        relations[load.relationKey] = switch (relation) {
          BeakBelongsTo(:final foreignKey) => [
            ?rows[relation.relatedTable]?[row[foreignKey]?.raw],
          ],
          BeakHasMany(:final foreignKey) || BeakHasOne(:final foreignKey) => [
            for (final child
                in rows[relation.relatedTable]?.values ?? <BeakRecord>[])
              if (child[foreignKey]?.raw == row['id']?.raw) child,
          ],
          BeakBelongsToMany() => [
            for (final id
                in links['${spec.table}:${row['id']?.raw}:${relation.key}'] ??
                    <Object>{})
              ?rows[relation.relatedTable]?[id],
          ],
        };
      }
      result.add(BeakRecord(values: row.values, relations: relations));
    }
    return BeakPage(
      items: result,
      total: selected.length,
      page: spec.pagination.page,
      perPage: spec.pagination.perPage,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
