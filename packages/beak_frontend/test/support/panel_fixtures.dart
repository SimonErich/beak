/// Fixtures for the panel widget suites: two tiny models and an in-memory
/// fake data source, so widget tests never touch a network.
library;

import 'package:beak_core/beak_core.dart';

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

/// The categories fixture model (belongs-to target).
final class CategoryModel extends BeakModel {
  /// Creates the categories model.
  const CategoryModel();

  @override
  String get table => 'categories';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name', searchable: true),
  ];
}

/// The comments fixture model (has-many target).
final class CommentModel extends BeakModel {
  /// Creates the comments model.
  const CommentModel();

  @override
  String get table => 'comments';

  @override
  String get displayColumnKey => 'text';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'text', label: 'Text'),
    BeakStringColumn(key: 'article_id', label: 'Article id'),
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

/// An in-memory [BeakDataSource] that records calls and serves canned
/// records — enough for panel, cache, and optimism tests (extend it to
/// override single operations).
base class FakeDataSource implements BeakDataSource {
  /// Creates a fake serving [records] keyed by table then id.
  FakeDataSource({Map<String, Map<Object, BeakRecord>>? records})
    : _recordsByTable = records ?? {};

  final Map<String, Map<Object, BeakRecord>> _recordsByTable;

  /// Every `batchGet` invocation, as `(table, ids)` pairs.
  final List<(String, List<Object>)> batchGetCalls = [];

  /// Every `query` invocation.
  final List<BeakQuerySpec> queryCalls = [];

  /// Every `delete` invocation, as `(table, id)` pairs.
  final List<(String, Object)> deleteCalls = [];

  /// Every `create` invocation, as `(table, data)` pairs.
  final List<(String, BeakRecord)> createCalls = [];

  /// Every `update` invocation, as `(table, id, data)` triples.
  final List<(String, Object, BeakRecord)> updateCalls = [];

  /// Every `attach` invocation, as `(table, id, relationKey, ids)` tuples.
  final List<(String, Object, String, List<Object>)> attachCalls = [];

  /// Every `detach` invocation, as `(table, id, relationKey, ids)` tuples.
  final List<(String, Object, String, List<Object>)> detachCalls = [];

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    queryCalls.add(spec);
    final records = (_recordsByTable[spec.table] ?? {}).values.toList();
    return BeakPage(
      items: records,
      total: records.length,
      page: spec.pagination.page,
      perPage: spec.pagination.perPage,
    );
  }

  @override
  Future<BeakRecord?> getOne(String table, Object id) async =>
      _recordsByTable[table]?[id];

  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    createCalls.add((table, data));
    return data;
  }

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async {
    updateCalls.add((table, id, data));
    return data;
  }

  @override
  Future<void> delete(String table, Object id, {bool force = false}) async {
    deleteCalls.add((table, id));
    _recordsByTable[table]?.remove(id);
  }

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async {
    batchGetCalls.add((table, ids));
    return [
      for (final id in ids)
        if (_recordsByTable[table]?[id] case final BeakRecord record) record,
    ];
  }

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    attachCalls.add((table, id, relationKey, relatedIds));
  }

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    detachCalls.add((table, id, relationKey, relatedIds));
  }

  @override
  Future<num> aggregate(BeakAggregateSpec spec) async => 0;
}
