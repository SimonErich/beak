/// Fixtures for the panel widget suites: three tiny models and a real
/// in-memory data source, so widget tests never touch a network and still
/// exercise real filtering, sorting, paging and eager loading.
library;

import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';

/// Typed relationship constants of the [NoteModel] fixture.
abstract final class NoteRelations {
  /// Many-to-many labels.
  static const labels = BeakBelongsToMany(
    key: 'labels',
    label: 'Labels',
    relatedTable: 'labels',
    displayColumnKey: 'name',
    pivotTable: 'label_note',
    foreignPivotKey: 'note_id',
    relatedPivotKey: 'label_id',
    searchColumnKeys: ['name'],
  );
}

/// The notes fixture model.
final class NoteModel extends BeakModel {
  /// Creates the notes model.
  const NoteModel();

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(
      key: 'title',
      label: 'Title',
      searchable: true,
      sortable: true,
    ),
  ];

  @override
  List<BeakRelationship> get relationships => const [NoteRelations.labels];
}

/// Status values of the [ArticleModel] fixture.
enum ArticleStatus {
  /// Not yet published.
  draft,

  /// Publicly visible.
  published,
}

/// Typed column constants of the [ArticleModel] fixture — the namespaced
/// shape Beak users declare.
abstract final class ArticleColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Required, capped headline.
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    placeholder: 'A headline',
    rules: [BeakRequired(), BeakMaxLength(20)],
  );

  /// Multiline summary.
  static const summary = BeakTextColumn(key: 'summary', label: 'Summary');

  /// Currency-styled decimal.
  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    prefix: '€',
    rules: [BeakMin(0)],
  );

  /// Bounded integer.
  static const stock = BeakIntColumn(
    key: 'stock',
    label: 'Stock',
    min: 0,
    max: 100,
  );

  /// Boolean toggle.
  static const active = BeakBoolColumn(key: 'active', label: 'Active');

  /// Enum select with a create-mode default.
  static const status = BeakEnumColumn<ArticleStatus>(
    key: 'status',
    label: 'Status',
    values: ArticleStatus.values,
    defaultValue: ArticleStatus.draft,
  );

  /// Absolute timestamp.
  static const publishedAt = BeakDateTimeColumn(
    key: 'published_at',
    label: 'Published at',
  );

  /// Hex color swatch.
  static const brandColor = BeakColorColumn(
    key: 'brand_color',
    label: 'Brand color',
  );

  /// Rich-text body.
  static const body = BeakRichTextColumn(key: 'body', label: 'Body');

  /// Structured JSON blob.
  static const meta = BeakJsonColumn(key: 'meta', label: 'Meta');

  /// Image upload with client-checkable rules.
  static const avatar = BeakImageColumn(
    key: 'avatar',
    label: 'Avatar',
    storagePath: 'articles/avatars',
    maxSizeInBytes: 16,
    allowedTypes: [BeakFileType.png],
  );

  /// Generic file upload.
  static const attachment = BeakFileColumn(
    key: 'attachment',
    label: 'Attachment',
    storagePath: 'articles/files',
  );

  /// Custom-rendered column (skipped by auto forms).
  static const badge = BeakCustomColumn(
    key: 'badge',
    label: 'Badge',
    tag: BeakColumnTag('badge'),
  );

  /// Foreign key owned by the `category` belongs-to relationship.
  static const categoryId = BeakStringColumn(
    key: 'category_id',
    label: 'Category id',
    rules: [BeakRequired()],
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    id,
    title,
    summary,
    price,
    stock,
    active,
    status,
    publishedAt,
    brandColor,
    body,
    meta,
    avatar,
    attachment,
    badge,
    categoryId,
  ];
}

/// Typed relationship constants of the [ArticleModel] fixture.
abstract final class ArticleRelations {
  /// Single category picker.
  static const category = BeakBelongsTo(
    key: 'category',
    label: 'Category',
    relatedTable: 'categories',
    displayColumnKey: 'name',
    foreignKey: 'category_id',
    searchColumnKeys: ['name'],
  );

  /// Many-to-many tags.
  static const tags = BeakBelongsToMany(
    key: 'tags',
    label: 'Tags',
    relatedTable: 'tags',
    displayColumnKey: 'name',
    pivotTable: 'article_tag',
    foreignPivotKey: 'article_id',
    relatedPivotKey: 'tag_id',
    searchColumnKeys: ['name'],
  );

  /// Child comments.
  static const comments = BeakHasMany(
    key: 'comments',
    label: 'Comments',
    relatedTable: 'comments',
    displayColumnKey: 'text',
    foreignKey: 'article_id',
  );
}

/// A fixture model exercising every auto-formable column type plus one
/// relationship of each flavor.
final class ArticleModel extends BeakModel {
  /// Creates the articles model.
  const ArticleModel();

  @override
  String get table => 'articles';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => ArticleColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ArticleRelations.category,
    ArticleRelations.tags,
    ArticleRelations.comments,
  ];
}

/// The labels fixture model.
final class LabelModel extends BeakModel {
  /// Creates the labels model.
  const LabelModel();

  @override
  String get table => 'labels';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}

/// A [BeakDataSource] for the panel suites: a real [InMemoryBeakDataSource]
/// under a [BeakRecordingDataSource], so the calls a widget makes are both
/// recorded *and* answered honestly — filters, sorts, paging and eager loads
/// all behave as they do against a server.
///
/// Seed with `records`, keyed by table then id, and pass any [models] the
/// suite declares itself. A row may carry a `relations` map: it is unfolded
/// into what actually stores that relationship — pivot links for a
/// many-to-many, child rows carrying the foreign key for a to-many — so the
/// eager load a widget requests resolves the same way it would against a
/// database. A table without a model gets one synthesised from its rows, so a
/// block test can serve `invoices` without declaring one.
///
/// Extend it to make a single operation fail; everything else keeps working.
base class FakeDataSource extends BeakRecordingDataSource {
  /// Creates a fake serving [records] keyed by table then id, knowing
  /// [models] on top of the shared [fixtureModels].
  FakeDataSource({
    Map<String, Map<Object, BeakRecord>>? records,
    List<BeakModel> models = const [],
  }) : this._(_storeFor(records ?? const {}, models));

  FakeDataSource._(this.store) : super(store);

  /// The source answering the calls — for assertions about what was
  /// persisted, via [InMemoryBeakDataSource.rowsOf].
  final InMemoryBeakDataSource store;

  /// Canned aggregate results; when null, real aggregates are computed.
  num Function(BeakAggregateSpec spec)? aggregateHandler;

  @override
  Future<num> aggregate(BeakAggregateSpec spec) async {
    if (aggregateHandler case final handler?) {
      aggregateCalls.add(spec);
      return handler(spec);
    }
    return super.aggregate(spec);
  }

  /// An in-memory source seeded with [seeds], plus every row and pivot link
  /// the seeds' `relations` maps imply.
  static InMemoryBeakDataSource _storeFor(
    Map<String, Map<Object, BeakRecord>> seeds,
    List<BeakModel> models,
  ) {
    final Map<String, BeakModel> known = {
      for (final model in [...fixtureModels, ...models]) model.table: model,
    };
    final rows = <String, Map<Object, BeakRecord>>{
      for (final entry in seeds.entries)
        entry.key: {
          for (final row in entry.value.entries)
            row.key: _withId(row.key, row.value),
        },
    };
    final links = <(BeakBelongsToMany, Object, List<Object>)>[];
    _unfoldRelations(known, rows, links);

    final registry = BeakModelRegistry();
    known.values.forEach(registry.register);
    void ensure(String table) {
      if (registry.byTable(table) == null) {
        registry.register(_AdHocModel(table, rows[table]?.values.firstOrNull));
      }
    }

    rows.keys.toList().forEach(ensure);
    for (final model in known.values) {
      for (final relation in model.relationships) {
        ensure(relation.relatedTable);
      }
    }

    final store = InMemoryBeakDataSource(registry: registry);
    rows.forEach((table, seeded) {
      store.seed(registry.byTableOrThrow(table), seeded.values.toList());
    });
    for (final (relation, ownerId, relatedIds) in links) {
      store.seedPivot(relation, ownerId, relatedIds);
    }
    return store;
  }

  /// Rewrites every seeded `relations` map into the rows and links that
  /// actually hold the relationship, growing [rows] and [links] in place.
  ///
  /// A to-one writes the foreign key onto the owner, a to-many writes it onto
  /// the children, and a many-to-many becomes a pivot link — the three ways a
  /// database stores what a fixture states as a nested list. Works through a
  /// queue, so a related record may itself carry relations.
  static void _unfoldRelations(
    Map<String, BeakModel> known,
    Map<String, Map<Object, BeakRecord>> rows,
    List<(BeakBelongsToMany, Object, List<Object>)> links,
  ) {
    final pending = <(String, Object)>[
      for (final table in rows.entries)
        for (final id in table.value.keys) (table.key, id),
    ];
    while (pending.isNotEmpty) {
      final (table, ownerId) = pending.removeLast();
      final BeakModel? model = known[table];
      final BeakRecord? record = rows[table]?[ownerId];
      if (model == null || record == null) {
        continue;
      }
      final values = <String, BeakValue>{...record.values};
      record.relations.forEach((key, related) {
        final BeakRelationship? relation = model.relationshipByKey(key);
        if (relation == null) {
          return;
        }
        final List<Object> relatedIds = [
          for (final row in related)
            if (row['id']?.raw case final Object id) id,
        ];
        switch (relation) {
          case final BeakBelongsToMany many:
            links.add((many, ownerId, relatedIds));
          case final BeakBelongsTo belongsTo:
            if (relatedIds.firstOrNull case final Object relatedId) {
              values[belongsTo.foreignKey] = BeakValue.of(relatedId);
            }
          case BeakHasMany() || BeakHasOne():
            break;
        }
        final String? childKey = switch (relation) {
          BeakHasMany(:final foreignKey) => foreignKey,
          BeakHasOne(:final foreignKey) => foreignKey,
          BeakBelongsTo() || BeakBelongsToMany() => null,
        };
        final target = rows.putIfAbsent(relation.relatedTable, () => {});
        for (final row in related) {
          if (row['id']?.raw case final Object id) {
            target[id] = childKey == null
                ? row
                : BeakRecord(
                    values: {...row.values, childKey: BeakValue.of(ownerId)},
                    relations: row.relations,
                  );
            pending.add((relation.relatedTable, id));
          }
        }
      });
      rows[table]![ownerId] = BeakRecord(
        values: values,
        relations: record.relations,
      );
    }
  }

  /// [record] guaranteed to carry the [id] it is keyed by.
  static BeakRecord _withId(Object id, BeakRecord record) =>
      record['id'] == null
      ? BeakRecord(
          values: {'id': BeakStringValue('$id'), ...record.values},
          relations: record.relations,
        )
      : record;
}

/// The models every panel suite can rely on being registered.
const List<BeakModel> fixtureModels = [
  NoteModel(),
  ArticleModel(),
  LabelModel(),
];

/// A model stood up for a table a test seeds without declaring one.
///
/// Columns are inferred from the seeded row, which is all an
/// [InMemoryBeakDataSource] needs: a primary key to store rows under and
/// value keys to filter and sort by.
final class _AdHocModel extends BeakModel {
  const _AdHocModel(this.table, this._sample);

  @override
  final String table;

  final BeakRecord? _sample;

  @override
  String get displayColumnKey => switch (_sample) {
    null => 'id',
    final BeakRecord row => const [
      'name',
      'title',
      'label',
      'text',
    ].firstWhere((key) => row.values.containsKey(key), orElse: () => 'id'),
  };

  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    for (final key in _sample?.values.keys ?? const <String>[])
      if (key != 'id') BeakStringColumn(key: key, label: key),
  ];
}
