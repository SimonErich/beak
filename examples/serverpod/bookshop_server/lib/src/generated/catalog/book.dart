/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_null_comparison

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:bookshop_server/src/generated/protocol.dart' as _idnbhgc5;
import 'package:serverpod/serverpod.dart' as _is;
import '../catalog/author.dart' as _ikaricya;
import '../catalog/book_format.dart' as _ie1s4qve;

/// A title the shop stocks.
abstract class Book implements _is.TableRow<int?>, _is.ProtocolSerialization {
  Book._({
    this.id,
    required this.title,
    required this.isbn,
    required this.format,
    required this.priceInCents,
    int? stock,
    this.publishedOn,
    this.supplierCostInCents,
    required this.authorId,
    this.author,
  }) : stock = stock ?? 0;

  factory Book({
    int? id,
    required String title,
    required String isbn,
    required _ie1s4qve.BookFormat format,
    required int priceInCents,
    int? stock,
    DateTime? publishedOn,
    int? supplierCostInCents,
    required int authorId,
    _ikaricya.Author? author,
  }) = _BookImpl;

  factory Book.fromJson(Map<String, dynamic> jsonSerialization) {
    return Book(
      id: jsonSerialization['id'] as int?,
      title: jsonSerialization['title'] as String,
      isbn: jsonSerialization['isbn'] as String,
      format: _ie1s4qve.BookFormat.fromJson(
        (jsonSerialization['format'] as String),
      ),
      priceInCents: jsonSerialization['priceInCents'] as int,
      stock: jsonSerialization['stock'] as int?,
      publishedOn: jsonSerialization['publishedOn'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['publishedOn'],
            ),
      supplierCostInCents: jsonSerialization['supplierCostInCents'] as int?,
      authorId: jsonSerialization['authorId'] as int,
      author: jsonSerialization['author'] == null
          ? null
          : _idnbhgc5.Protocol().deserialize<_ikaricya.Author>(
              jsonSerialization['author'],
            ),
    );
  }

  static final t = BookTable();

  static const db = BookRepository._();

  @override
  int? id;

  /// The title printed on the cover.
  String title;

  /// The ISBN, unique per edition.
  String isbn;

  /// How the book is bound.
  _ie1s4qve.BookFormat format;

  /// Shelf price in cents.
  int priceInCents;

  /// Copies on the shelf.
  int stock;

  /// First publication date.
  DateTime? publishedOn;

  /// What the shop pays the supplier. Never leaves the server: it is not
  /// in the generated client, and the Beak model does not declare it.
  int? supplierCostInCents;

  int authorId;

  /// Who wrote it.
  _ikaricya.Author? author;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [Book]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Book copyWith({
    int? id,
    String? title,
    String? isbn,
    _ie1s4qve.BookFormat? format,
    int? priceInCents,
    int? stock,
    DateTime? publishedOn,
    int? supplierCostInCents,
    int? authorId,
    _ikaricya.Author? author,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Book',
      if (id != null) 'id': id,
      'title': title,
      'isbn': isbn,
      'format': format.toJson(),
      'priceInCents': priceInCents,
      'stock': stock,
      if (publishedOn != null) 'publishedOn': publishedOn?.toJson(),
      if (supplierCostInCents != null)
        'supplierCostInCents': supplierCostInCents,
      'authorId': authorId,
      if (author != null) 'author': author?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Book',
      if (id != null) 'id': id,
      'title': title,
      'isbn': isbn,
      'format': format.toJson(),
      'priceInCents': priceInCents,
      'stock': stock,
      if (publishedOn != null) 'publishedOn': publishedOn?.toJson(),
      'authorId': authorId,
      if (author != null) 'author': author?.toJsonForProtocol(),
    };
  }

  static BookInclude include({_ikaricya.AuthorInclude? author}) {
    return BookInclude._(author: author);
  }

  static BookIncludeList includeList({
    _is.WhereExpressionBuilder<BookTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BookTable>? orderBy,
    _is.OrderByListBuilder<BookTable>? orderByList,
    BookInclude? include,
  }) {
    return BookIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Book.t),
      orderByList: orderByList?.call(Book.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BookImpl extends Book {
  _BookImpl({
    int? id,
    required String title,
    required String isbn,
    required _ie1s4qve.BookFormat format,
    required int priceInCents,
    int? stock,
    DateTime? publishedOn,
    int? supplierCostInCents,
    required int authorId,
    _ikaricya.Author? author,
  }) : super._(
         id: id,
         title: title,
         isbn: isbn,
         format: format,
         priceInCents: priceInCents,
         stock: stock,
         publishedOn: publishedOn,
         supplierCostInCents: supplierCostInCents,
         authorId: authorId,
         author: author,
       );

  /// Returns a shallow copy of this [Book]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Book copyWith({
    Object? id = _Undefined,
    String? title,
    String? isbn,
    _ie1s4qve.BookFormat? format,
    int? priceInCents,
    int? stock,
    Object? publishedOn = _Undefined,
    Object? supplierCostInCents = _Undefined,
    int? authorId,
    Object? author = _Undefined,
  }) {
    return Book(
      id: id is int? ? id : this.id,
      title: title ?? this.title,
      isbn: isbn ?? this.isbn,
      format: format ?? this.format,
      priceInCents: priceInCents ?? this.priceInCents,
      stock: stock ?? this.stock,
      publishedOn: publishedOn is DateTime? ? publishedOn : this.publishedOn,
      supplierCostInCents: supplierCostInCents is int?
          ? supplierCostInCents
          : this.supplierCostInCents,
      authorId: authorId ?? this.authorId,
      author: author is _ikaricya.Author? ? author : this.author?.copyWith(),
    );
  }
}

class BookUpdateTable extends _is.UpdateTable<BookTable> {
  BookUpdateTable(super.table);

  _is.ColumnValue<String, String> title(String value) => _is.ColumnValue(
    table.title,
    value,
  );

  _is.ColumnValue<String, String> isbn(String value) => _is.ColumnValue(
    table.isbn,
    value,
  );

  _is.ColumnValue<_ie1s4qve.BookFormat, _ie1s4qve.BookFormat> format(
    _ie1s4qve.BookFormat value,
  ) => _is.ColumnValue(
    table.format,
    value,
  );

  _is.ColumnValue<int, int> priceInCents(int value) => _is.ColumnValue(
    table.priceInCents,
    value,
  );

  _is.ColumnValue<int, int> stock(int value) => _is.ColumnValue(
    table.stock,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> publishedOn(DateTime? value) =>
      _is.ColumnValue(
        table.publishedOn,
        value,
      );

  _is.ColumnValue<int, int> supplierCostInCents(int? value) => _is.ColumnValue(
    table.supplierCostInCents,
    value,
  );

  _is.ColumnValue<int, int> authorId(int value) => _is.ColumnValue(
    table.authorId,
    value,
  );
}

class BookTable extends _is.Table<int?> {
  BookTable({super.tableRelation}) : super(tableName: 'book') {
    updateTable = BookUpdateTable(this);
    title = _is.ColumnString(
      'title',
      this,
    );
    isbn = _is.ColumnString(
      'isbn',
      this,
    );
    format = _is.ColumnEnum(
      'format',
      this,
      _is.EnumSerialization.byName,
    );
    priceInCents = _is.ColumnInt(
      'priceInCents',
      this,
    );
    stock = _is.ColumnInt(
      'stock',
      this,
      hasDefault: true,
    );
    publishedOn = _is.ColumnDateTime(
      'publishedOn',
      this,
    );
    supplierCostInCents = _is.ColumnInt(
      'supplierCostInCents',
      this,
    );
    authorId = _is.ColumnInt(
      'authorId',
      this,
    );
  }

  late final BookUpdateTable updateTable;

  /// The title printed on the cover.
  late final _is.ColumnString title;

  /// The ISBN, unique per edition.
  late final _is.ColumnString isbn;

  /// How the book is bound.
  late final _is.ColumnEnum<_ie1s4qve.BookFormat> format;

  /// Shelf price in cents.
  late final _is.ColumnInt priceInCents;

  /// Copies on the shelf.
  late final _is.ColumnInt stock;

  /// First publication date.
  late final _is.ColumnDateTime publishedOn;

  /// What the shop pays the supplier. Never leaves the server: it is not
  /// in the generated client, and the Beak model does not declare it.
  late final _is.ColumnInt supplierCostInCents;

  late final _is.ColumnInt authorId;

  /// Who wrote it.
  _ikaricya.AuthorTable? _author;

  _ikaricya.AuthorTable get author {
    if (_author != null) return _author!;
    _author = _is.createRelationTable(
      relationFieldName: 'author',
      field: Book.t.authorId,
      foreignField: _ikaricya.Author.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _ikaricya.AuthorTable(tableRelation: foreignTableRelation),
    );
    return _author!;
  }

  @override
  List<_is.Column> get columns => [
    id,
    title,
    isbn,
    format,
    priceInCents,
    stock,
    publishedOn,
    supplierCostInCents,
    authorId,
  ];

  @override
  _is.Table? getRelationTable(String relationField) {
    if (relationField == 'author') {
      return author;
    }
    return null;
  }
}

class BookInclude extends _is.IncludeObject {
  BookInclude._({_ikaricya.AuthorInclude? author}) {
    _author = author;
  }

  _ikaricya.AuthorInclude? _author;

  @override
  Map<String, _is.Include?> get includes => {'author': _author};

  @override
  _is.Table<int?> get table => Book.t;
}

class BookIncludeList extends _is.IncludeList {
  BookIncludeList._({
    _is.WhereExpressionBuilder<BookTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Book.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => Book.t;
}

class BookRepository {
  const BookRepository._();

  final attachRow = const BookAttachRowRepository._();

  /// Returns a list of [Book]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<Book>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BookTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BookTable>? orderBy,
    _is.OrderByListBuilder<BookTable>? orderByList,
    _is.Transaction? transaction,
    BookInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Book>(
      where: where?.call(Book.t),
      orderBy: orderBy?.call(Book.t),
      orderByList: orderByList?.call(Book.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Book] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<Book?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BookTable>? where,
    int? offset,
    _is.OrderByBuilder<BookTable>? orderBy,
    _is.OrderByListBuilder<BookTable>? orderByList,
    _is.Transaction? transaction,
    BookInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Book>(
      where: where?.call(Book.t),
      orderBy: orderBy?.call(Book.t),
      orderByList: orderByList?.call(Book.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Book] by its [id] or null if no such row exists.
  Future<Book?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    BookInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Book>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Book]s in the list and returns the inserted rows.
  ///
  /// The returned [Book]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Book>> insert(
    _is.DatabaseSession session,
    List<Book> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Book>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Book] and returns the inserted row.
  ///
  /// The returned [Book] will have its `id` field set.
  Future<Book> insertRow(
    _is.DatabaseSession session,
    Book row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Book>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Book]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [Book]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Book>> upsert(
    _is.DatabaseSession session,
    List<Book> rows, {
    required _is.ColumnSelections<BookTable> conflictColumns,
    _is.ColumnSelections<BookTable>? updateColumns,
    _is.WhereExpressionBuilder<BookTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Book>(
      rows,
      conflictColumns: conflictColumns(Book.t),
      updateColumns: updateColumns?.call(Book.t),
      updateWhere: updateWhere?.call(Book.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Book] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [Book] will have its `id` field set.
  Future<Book?> upsertRow(
    _is.DatabaseSession session,
    Book row, {
    required _is.ColumnSelections<BookTable> conflictColumns,
    _is.ColumnSelections<BookTable>? updateColumns,
    _is.WhereExpressionBuilder<BookTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Book>(
      row,
      conflictColumns: conflictColumns(Book.t),
      updateColumns: updateColumns?.call(Book.t),
      updateWhere: updateWhere?.call(Book.t),
      transaction: transaction,
    );
  }

  /// Updates all [Book]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Book>> update(
    _is.DatabaseSession session,
    List<Book> rows, {
    _is.ColumnSelections<BookTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Book>(
      rows,
      columns: columns?.call(Book.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Book]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Book> updateRow(
    _is.DatabaseSession session,
    Book row, {
    _is.ColumnSelections<BookTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Book>(
      row,
      columns: columns?.call(Book.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Book] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Book?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BookUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Book>(
      id,
      columnValues: columnValues(Book.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Book]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Book>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BookUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<BookTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BookTable>? orderBy,
    _is.OrderByListBuilder<BookTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Book>(
      columnValues: columnValues(Book.t.updateTable),
      where: where(Book.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Book.t),
      orderByList: orderByList?.call(Book.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Book]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Book>> delete(
    _is.DatabaseSession session,
    List<Book> rows, {
    _is.OrderByBuilder<BookTable>? orderBy,
    _is.OrderByListBuilder<BookTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Book>(
      rows,
      orderBy: orderBy?.call(Book.t),
      orderByList: orderByList?.call(Book.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Book].
  Future<Book> deleteRow(
    _is.DatabaseSession session,
    Book row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Book>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Book>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BookTable> where,
    _is.OrderByBuilder<BookTable>? orderBy,
    _is.OrderByListBuilder<BookTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Book>(
      where: where(Book.t),
      orderBy: orderBy?.call(Book.t),
      orderByList: orderByList?.call(Book.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BookTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Book>(
      where: where?.call(Book.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Book] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BookTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Book>(
      where: where(Book.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class BookAttachRowRepository {
  const BookAttachRowRepository._();

  /// Creates a relation between the given [Book] and [Author]
  /// by setting the [Book]'s foreign key `authorId` to refer to the [Author].
  Future<void> author(
    _is.DatabaseSession session,
    Book book,
    _ikaricya.Author author, {
    _is.Transaction? transaction,
  }) async {
    if (book.id == null) {
      throw ArgumentError.notNull('book.id');
    }
    if (author.id == null) {
      throw ArgumentError.notNull('author.id');
    }

    var $book = book.copyWith(authorId: author.id);
    await session.db.updateRow<Book>(
      $book,
      columns: [Book.t.authorId],
      transaction: transaction,
    );
  }
}
