/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;

/// TOOL-OWNED by Beak. Do not edit.
/// Durable graph-commit receipts: idempotent replay and recovery.
/// Beak's form Save is a graph commit, so any Beak admin needs this table.
abstract class BeakCommitReceipt
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  BeakCommitReceipt._({
    this.id,
    required this.receiptKey,
    required this.requestHash,
    required this.requestJson,
    required this.resultJson,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BeakCommitReceipt({
    int? id,
    required String receiptKey,
    required String requestHash,
    required String requestJson,
    required String resultJson,
    DateTime? createdAt,
  }) = _BeakCommitReceiptImpl;

  factory BeakCommitReceipt.fromJson(Map<String, dynamic> jsonSerialization) {
    return BeakCommitReceipt(
      id: jsonSerialization['id'] as int?,
      receiptKey: jsonSerialization['receiptKey'] as String,
      requestHash: jsonSerialization['requestHash'] as String,
      requestJson: jsonSerialization['requestJson'] as String,
      resultJson: jsonSerialization['resultJson'] as String,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = BeakCommitReceiptTable();

  static const db = BeakCommitReceiptRepository._();

  @override
  int? id;

  /// (principal, saveId) namespace key.
  String receiptKey;

  /// Hash of the submitted plan; a replay with another hash is rejected.
  String requestHash;

  /// The prepared plan, kept for recovery.
  String requestJson;

  /// The authoritative result (a pending marker while in flight).
  String resultJson;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [BeakCommitReceipt]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BeakCommitReceipt copyWith({
    int? id,
    String? receiptKey,
    String? requestHash,
    String? requestJson,
    String? resultJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BeakCommitReceipt',
      if (id != null) 'id': id,
      'receiptKey': receiptKey,
      'requestHash': requestHash,
      'requestJson': requestJson,
      'resultJson': resultJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static BeakCommitReceiptInclude include() {
    return BeakCommitReceiptInclude._();
  }

  static BeakCommitReceiptIncludeList includeList({
    _is.WhereExpressionBuilder<BeakCommitReceiptTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BeakCommitReceiptTable>? orderBy,
    _is.OrderByListBuilder<BeakCommitReceiptTable>? orderByList,
    BeakCommitReceiptInclude? include,
  }) {
    return BeakCommitReceiptIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BeakCommitReceipt.t),
      orderByList: orderByList?.call(BeakCommitReceipt.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BeakCommitReceiptImpl extends BeakCommitReceipt {
  _BeakCommitReceiptImpl({
    int? id,
    required String receiptKey,
    required String requestHash,
    required String requestJson,
    required String resultJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         receiptKey: receiptKey,
         requestHash: requestHash,
         requestJson: requestJson,
         resultJson: resultJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [BeakCommitReceipt]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BeakCommitReceipt copyWith({
    Object? id = _Undefined,
    String? receiptKey,
    String? requestHash,
    String? requestJson,
    String? resultJson,
    DateTime? createdAt,
  }) {
    return BeakCommitReceipt(
      id: id is int? ? id : this.id,
      receiptKey: receiptKey ?? this.receiptKey,
      requestHash: requestHash ?? this.requestHash,
      requestJson: requestJson ?? this.requestJson,
      resultJson: resultJson ?? this.resultJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class BeakCommitReceiptUpdateTable
    extends _is.UpdateTable<BeakCommitReceiptTable> {
  BeakCommitReceiptUpdateTable(super.table);

  _is.ColumnValue<String, String> receiptKey(String value) => _is.ColumnValue(
    table.receiptKey,
    value,
  );

  _is.ColumnValue<String, String> requestHash(String value) => _is.ColumnValue(
    table.requestHash,
    value,
  );

  _is.ColumnValue<String, String> requestJson(String value) => _is.ColumnValue(
    table.requestJson,
    value,
  );

  _is.ColumnValue<String, String> resultJson(String value) => _is.ColumnValue(
    table.resultJson,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class BeakCommitReceiptTable extends _is.Table<int?> {
  BeakCommitReceiptTable({super.tableRelation})
    : super(tableName: 'beak_commit_receipt') {
    updateTable = BeakCommitReceiptUpdateTable(this);
    receiptKey = _is.ColumnString(
      'receiptKey',
      this,
    );
    requestHash = _is.ColumnString(
      'requestHash',
      this,
    );
    requestJson = _is.ColumnString(
      'requestJson',
      this,
    );
    resultJson = _is.ColumnString(
      'resultJson',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
  }

  late final BeakCommitReceiptUpdateTable updateTable;

  /// (principal, saveId) namespace key.
  late final _is.ColumnString receiptKey;

  /// Hash of the submitted plan; a replay with another hash is rejected.
  late final _is.ColumnString requestHash;

  /// The prepared plan, kept for recovery.
  late final _is.ColumnString requestJson;

  /// The authoritative result (a pending marker while in flight).
  late final _is.ColumnString resultJson;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    receiptKey,
    requestHash,
    requestJson,
    resultJson,
    createdAt,
  ];
}

class BeakCommitReceiptInclude extends _is.IncludeObject {
  BeakCommitReceiptInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => BeakCommitReceipt.t;
}

class BeakCommitReceiptIncludeList extends _is.IncludeList {
  BeakCommitReceiptIncludeList._({
    _is.WhereExpressionBuilder<BeakCommitReceiptTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BeakCommitReceipt.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => BeakCommitReceipt.t;
}

class BeakCommitReceiptRepository {
  const BeakCommitReceiptRepository._();

  /// Returns a list of [BeakCommitReceipt]s matching the given query parameters.
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
  Future<List<BeakCommitReceipt>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BeakCommitReceiptTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BeakCommitReceiptTable>? orderBy,
    _is.OrderByListBuilder<BeakCommitReceiptTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BeakCommitReceipt>(
      where: where?.call(BeakCommitReceipt.t),
      orderBy: orderBy?.call(BeakCommitReceipt.t),
      orderByList: orderByList?.call(BeakCommitReceipt.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [BeakCommitReceipt] matching the given query parameters.
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
  Future<BeakCommitReceipt?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BeakCommitReceiptTable>? where,
    int? offset,
    _is.OrderByBuilder<BeakCommitReceiptTable>? orderBy,
    _is.OrderByListBuilder<BeakCommitReceiptTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BeakCommitReceipt>(
      where: where?.call(BeakCommitReceipt.t),
      orderBy: orderBy?.call(BeakCommitReceipt.t),
      orderByList: orderByList?.call(BeakCommitReceipt.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BeakCommitReceipt] by its [id] or null if no such row exists.
  Future<BeakCommitReceipt?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BeakCommitReceipt>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BeakCommitReceipt]s in the list and returns the inserted rows.
  ///
  /// The returned [BeakCommitReceipt]s will have their `id` fields set.
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
  Future<List<BeakCommitReceipt>> insert(
    _is.DatabaseSession session,
    List<BeakCommitReceipt> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BeakCommitReceipt>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BeakCommitReceipt] and returns the inserted row.
  ///
  /// The returned [BeakCommitReceipt] will have its `id` field set.
  Future<BeakCommitReceipt> insertRow(
    _is.DatabaseSession session,
    BeakCommitReceipt row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BeakCommitReceipt>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BeakCommitReceipt]s in the list and returns the resulting rows.
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
  /// The returned [BeakCommitReceipt]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BeakCommitReceipt>> upsert(
    _is.DatabaseSession session,
    List<BeakCommitReceipt> rows, {
    required _is.ColumnSelections<BeakCommitReceiptTable> conflictColumns,
    _is.ColumnSelections<BeakCommitReceiptTable>? updateColumns,
    _is.WhereExpressionBuilder<BeakCommitReceiptTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BeakCommitReceipt>(
      rows,
      conflictColumns: conflictColumns(BeakCommitReceipt.t),
      updateColumns: updateColumns?.call(BeakCommitReceipt.t),
      updateWhere: updateWhere?.call(BeakCommitReceipt.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BeakCommitReceipt] and returns the resulting row.
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
  /// The returned [BeakCommitReceipt] will have its `id` field set.
  Future<BeakCommitReceipt?> upsertRow(
    _is.DatabaseSession session,
    BeakCommitReceipt row, {
    required _is.ColumnSelections<BeakCommitReceiptTable> conflictColumns,
    _is.ColumnSelections<BeakCommitReceiptTable>? updateColumns,
    _is.WhereExpressionBuilder<BeakCommitReceiptTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BeakCommitReceipt>(
      row,
      conflictColumns: conflictColumns(BeakCommitReceipt.t),
      updateColumns: updateColumns?.call(BeakCommitReceipt.t),
      updateWhere: updateWhere?.call(BeakCommitReceipt.t),
      transaction: transaction,
    );
  }

  /// Updates all [BeakCommitReceipt]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BeakCommitReceipt>> update(
    _is.DatabaseSession session,
    List<BeakCommitReceipt> rows, {
    _is.ColumnSelections<BeakCommitReceiptTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BeakCommitReceipt>(
      rows,
      columns: columns?.call(BeakCommitReceipt.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BeakCommitReceipt]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BeakCommitReceipt> updateRow(
    _is.DatabaseSession session,
    BeakCommitReceipt row, {
    _is.ColumnSelections<BeakCommitReceiptTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BeakCommitReceipt>(
      row,
      columns: columns?.call(BeakCommitReceipt.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BeakCommitReceipt] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BeakCommitReceipt?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BeakCommitReceiptUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BeakCommitReceipt>(
      id,
      columnValues: columnValues(BeakCommitReceipt.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BeakCommitReceipt]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BeakCommitReceipt>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BeakCommitReceiptUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<BeakCommitReceiptTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BeakCommitReceiptTable>? orderBy,
    _is.OrderByListBuilder<BeakCommitReceiptTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BeakCommitReceipt>(
      columnValues: columnValues(BeakCommitReceipt.t.updateTable),
      where: where(BeakCommitReceipt.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BeakCommitReceipt.t),
      orderByList: orderByList?.call(BeakCommitReceipt.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BeakCommitReceipt]s in the list and returns the deleted rows.
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
  Future<List<BeakCommitReceipt>> delete(
    _is.DatabaseSession session,
    List<BeakCommitReceipt> rows, {
    _is.OrderByBuilder<BeakCommitReceiptTable>? orderBy,
    _is.OrderByListBuilder<BeakCommitReceiptTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BeakCommitReceipt>(
      rows,
      orderBy: orderBy?.call(BeakCommitReceipt.t),
      orderByList: orderByList?.call(BeakCommitReceipt.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BeakCommitReceipt].
  Future<BeakCommitReceipt> deleteRow(
    _is.DatabaseSession session,
    BeakCommitReceipt row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BeakCommitReceipt>(
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
  Future<List<BeakCommitReceipt>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BeakCommitReceiptTable> where,
    _is.OrderByBuilder<BeakCommitReceiptTable>? orderBy,
    _is.OrderByListBuilder<BeakCommitReceiptTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BeakCommitReceipt>(
      where: where(BeakCommitReceipt.t),
      orderBy: orderBy?.call(BeakCommitReceipt.t),
      orderByList: orderByList?.call(BeakCommitReceipt.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BeakCommitReceiptTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BeakCommitReceipt>(
      where: where?.call(BeakCommitReceipt.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BeakCommitReceipt] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BeakCommitReceiptTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BeakCommitReceipt>(
      where: where(BeakCommitReceipt.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
