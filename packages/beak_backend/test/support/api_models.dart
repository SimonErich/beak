/// Beak model fixtures for the endpoint suites: a Notes domain with
/// uuid-string primary keys, rich column rules, timestamps, soft deletes,
/// and every attachable relationship kind.
library;

import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

/// Publication states of a note.
enum NoteStatus {
  /// Not yet published.
  draft,

  /// Publicly visible.
  published,
}

/// Column constants of the notes fixture model.
abstract final class NoteColumns {
  /// Primary key (uuid string).
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Title; required, capped, searchable.
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(40)],
  );

  /// Free-form body text.
  static const body = BeakTextColumn(key: 'body', label: 'Body');

  /// Star rating between one and five.
  static const rating = BeakIntColumn(
    key: 'rating',
    label: 'Rating',
    sortable: true,
    rules: [BeakMin(1), BeakMax(5)],
  );

  /// Publication state.
  static const status = BeakEnumColumn<NoteStatus>(
    key: 'status',
    label: 'Status',
    values: NoteStatus.values,
  );

  /// Whether the note shows on the public site.
  static const published = BeakBoolColumn(key: 'published', label: 'Published');

  /// Contact address of the note's author.
  static const authorEmail = BeakStringColumn(
    key: 'author_email',
    label: 'Author email',
    rules: [BeakEmail()],
  );

  /// Foreign key to the owning author.
  static const authorId = BeakStringColumn(
    key: 'author_id',
    label: 'Author id',
  );

  /// Creation timestamp (stamped by the service).
  static const createdAt = BeakDateTimeColumn(
    key: 'created_at',
    label: 'Created at',
  );

  /// Last-update timestamp (stamped by the service).
  static const updatedAt = BeakDateTimeColumn(
    key: 'updated_at',
    label: 'Updated at',
  );

  /// Cover image with rules and a thumbnail rendition.
  static const avatar = BeakImageColumn(
    key: 'avatar',
    label: 'Avatar',
    storagePath: 'avatars',
    maxSizeInBytes: 64 * 1024,
    maxDimensions: BeakDimensions.square(64),
    transforms: [
      BeakThumbnailTransform(size: BeakDimensions.square(2), name: 'thumb'),
    ],
  );

  /// PDF attachment with a tight size cap.
  static const attachment = BeakFileColumn(
    key: 'attachment',
    label: 'Attachment',
    storagePath: 'files',
    maxSizeInBytes: 1024,
    allowedTypes: [BeakFileType.pdf],
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    id,
    title,
    body,
    rating,
    status,
    published,
    authorEmail,
    authorId,
    createdAt,
    updatedAt,
    avatar,
    attachment,
  ];
}

/// The notes fixture model.
final class NoteModel extends BeakModel {
  /// Creates the notes model.
  const NoteModel();

  /// Typed reference to the title.
  static const title = BeakScalarField<String>(
    model: NoteModel(),
    column: NoteColumns.title,
    isRequired: true,
  );

  /// Typed reference to the body.
  static const body = BeakScalarField<String>(
    model: NoteModel(),
    column: NoteColumns.body,
  );

  /// Typed reference to the star rating.
  static const rating = BeakScalarField<int>(
    model: NoteModel(),
    column: NoteColumns.rating,
  );

  /// Typed reference to the publication flag.
  static const published = BeakScalarField<bool>(
    model: NoteModel(),
    column: NoteColumns.published,
  );

  /// Typed reference to the owning author's key.
  static const authorId = BeakScalarField<String>(
    model: NoteModel(),
    column: NoteColumns.authorId,
  );

  /// The has-many relationship to the note's comments.
  static const BeakHasMany commentsRelation = BeakHasMany(
    key: 'comments',
    label: 'Comments',
    relatedTable: 'comments',
    displayColumnKey: 'message',
    foreignKey: 'note_id',
  );

  /// Typed reference to the note's comments.
  static const comments = BeakToManyField(
    model: NoteModel(),
    relation: commentsRelation,
    target: CommentModel(),
  );

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  bool get softDeletes => true;

  @override
  List<BeakColumn> get columns => NoteColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    BeakBelongsTo(
      key: 'author',
      label: 'Author',
      relatedTable: 'authors',
      displayColumnKey: 'name',
      foreignKey: 'author_id',
    ),
    commentsRelation,
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
}

/// The labels fixture model — the "second model" proving the generated
/// surface needs zero per-model code.
final class LabelModel extends BeakModel {
  /// Creates the labels model.
  const LabelModel();

  /// Typed reference to the label name.
  static const name = BeakScalarField<String>(
    model: LabelModel(),
    column: _name,
  );

  static const BeakColumn _name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    rules: [BeakRequired()],
  );

  @override
  String get table => 'labels';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    _name,
  ];
}

/// The comments fixture model.
final class CommentModel extends BeakModel {
  /// Creates the comments model.
  const CommentModel();

  /// Typed reference to the comment text.
  static const message = BeakScalarField<String>(
    model: CommentModel(),
    column: _message,
  );

  static const BeakColumn _message = BeakTextColumn(
    key: 'message',
    label: 'Message',
  );

  @override
  String get table => 'comments';

  @override
  String get displayColumnKey => 'message';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'note_id', label: 'Note id'),
    _message,
  ];
}

/// The authors fixture model.
final class AuthorModel extends BeakModel {
  /// Creates the authors model.
  const AuthorModel();

  @override
  String get table => 'authors';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}

/// A registry holding every endpoint fixture model.
BeakModelRegistry createApiRegistry() => BeakModelRegistry()
  ..register(const NoteModel())
  ..register(const LabelModel())
  ..register(const CommentModel())
  ..register(const AuthorModel());

/// The in-memory schema backing the endpoint fixture domain.
const List<SchemaDescriptor> apiSchema = [
  SchemaDescriptor.createTable(
    table: 'notes',
    columns: [
      SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
      SchemaColumn(name: 'title', type: ColumnType.text),
      SchemaColumn(name: 'body', type: ColumnType.text),
      SchemaColumn(name: 'rating', type: ColumnType.integer),
      SchemaColumn(name: 'status', type: ColumnType.text),
      SchemaColumn(name: 'published', type: ColumnType.boolean),
      SchemaColumn(name: 'author_email', type: ColumnType.text),
      SchemaColumn(name: 'author_id', type: ColumnType.text),
      SchemaColumn(name: 'created_at', type: ColumnType.dateTime),
      SchemaColumn(name: 'updated_at', type: ColumnType.dateTime),
      SchemaColumn(name: 'avatar', type: ColumnType.text),
      SchemaColumn(name: 'attachment', type: ColumnType.text),
      SchemaColumn(name: 'deleted_at', type: ColumnType.dateTime),
    ],
  ),
  SchemaDescriptor.createTable(
    table: 'labels',
    columns: [
      SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
      SchemaColumn(name: 'name', type: ColumnType.text),
    ],
  ),
  SchemaDescriptor.createTable(
    table: 'note_label',
    columns: [
      SchemaColumn(name: 'note_id', type: ColumnType.text),
      SchemaColumn(name: 'label_id', type: ColumnType.text),
    ],
  ),
  SchemaDescriptor.createTable(
    table: 'comments',
    columns: [
      SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
      SchemaColumn(name: 'note_id', type: ColumnType.text),
      SchemaColumn(name: 'message', type: ColumnType.text),
    ],
  ),
  SchemaDescriptor.createTable(
    table: 'authors',
    columns: [
      SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
      SchemaColumn(name: 'name', type: ColumnType.text),
    ],
  ),
];

/// Connects a fresh [InMemoryAdapter], creates the endpoint fixture schema,
/// and initializes worm on it — pair with `tearDown(Worm.reset)`.
// --8<-- [start:createApiTestDatabase]
Future<InMemoryAdapter> createApiTestDatabase() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  for (final descriptor in apiSchema) {
    await adapter.executeSchema(descriptor);
  }
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, DatabaseAdapter>{'default': adapter},
  );
  return adapter;
}

// --8<-- [end:createApiTestDatabase]
