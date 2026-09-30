/// A two-model bookshop for the engine suite: Author and Book, camelCase
/// column names like a Serverpod table, and an in-memory schema that carries
/// a `secret` column no model declares.
library;

import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

/// Column constants of [BookModel].
abstract final class BookColumns {
  /// Primary key (uuid string minted by the service).
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Title.
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    rules: [BeakRequired()],
  );

  /// Price in cents.
  static const priceInCents = BeakIntColumn(
    key: 'priceInCents',
    label: 'Price in cents',
  );

  /// Foreign key to the author.
  static const authorId = BeakStringColumn(key: 'authorId', label: 'Author');

  /// All columns, in display order.
  static const List<BeakColumn> values = [id, title, priceInCents, authorId];
}

/// The book model.
final class BookModel extends BeakModel {
  /// Creates the book model.
  const BookModel();

  @override
  String get table => 'book';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => BookColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    BeakBelongsTo(
      key: 'author',
      label: 'Author',
      relatedTable: 'author',
      displayColumnKey: 'name',
      foreignKey: 'authorId',
    ),
  ];
}

/// The author model.
final class AuthorModel extends BeakModel {
  /// Creates the author model.
  const AuthorModel();

  @override
  String get table => 'author';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name', rules: [BeakRequired()]),
  ];
}

/// A registry holding both models.
BeakModelRegistry createBookshopRegistry() => BeakModelRegistry()
  ..register(const AuthorModel())
  ..register(const BookModel());

/// A connected in-memory adapter with the bookshop tables, the commit
/// receipts table as Serverpod's migration would create it, and a `secret`
/// column on `book` that no model declares.
Future<InMemoryAdapter> createBookshopDatabase() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  for (final descriptor in const [
    SchemaDescriptor.createTable(
      table: 'author',
      columns: [
        SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
        SchemaColumn(name: 'name', type: ColumnType.text),
      ],
    ),
    SchemaDescriptor.createTable(
      table: 'book',
      columns: [
        SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
        SchemaColumn(name: 'title', type: ColumnType.text),
        SchemaColumn(name: 'priceInCents', type: ColumnType.integer),
        SchemaColumn(name: 'authorId', type: ColumnType.text, nullable: true),
        SchemaColumn(name: 'secret', type: ColumnType.text, nullable: true),
      ],
    ),
    SchemaDescriptor.createTable(
      table: 'beak_commit_receipt',
      columns: [
        SchemaColumn(
          name: 'id',
          type: ColumnType.integer,
          isPrimaryKey: true,
          autoIncrement: true,
        ),
        SchemaColumn(name: 'receiptKey', type: ColumnType.text, unique: true),
        SchemaColumn(name: 'requestHash', type: ColumnType.text),
        SchemaColumn(name: 'requestJson', type: ColumnType.text),
        SchemaColumn(name: 'resultJson', type: ColumnType.text),
      ],
    ),
  ]) {
    await adapter.executeSchema(descriptor);
  }
  return adapter;
}
