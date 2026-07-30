/// Production-quality in-memory adapter for tests.
library;

import '../exception/unsupported_operation_exception.dart';
import '../logging/explain_runner.dart';
import '../query/adapter_dialect.dart';
import '../query/aggregate_descriptor.dart';
import '../query/delete_descriptor.dart';
import '../query/insert_descriptor.dart';
import '../query/query_descriptor.dart';
import '../query/schema_descriptor.dart';
import '../query/sql_compiler.dart';
import '../query/update_descriptor.dart';
import 'adapter_capabilities.dart';
import 'database_adapter.dart';
import 'in_memory_store.dart';

/// An in-memory [DatabaseAdapter] implementation.
///
/// Intended for unit tests and the adapter contract test suite.
/// Supports CRUD, filtering, sorting, pagination, aggregations, and
/// transactions with snapshot-based rollback.
final class InMemoryAdapter extends DatabaseAdapter with ExplainCapable {
  /// Creates a fresh, empty adapter.
  InMemoryAdapter({AdapterCapabilities? capabilities})
    : _store = InMemoryStore(),
      super(capabilities: capabilities ?? _defaultCapabilities);

  InMemoryAdapter._withStore(this._store, {required super.capabilities});

  /// Capability profile the in-memory adapter opts in to by default.
  /// Transactions, savepoints (nested transactions over the shared
  /// store), streaming, returning clauses, aggregations, and schema
  /// introspection are fully implemented; joins and raw native queries
  /// are not.
  static const AdapterCapabilities _defaultCapabilities = AdapterCapabilities(
    supportsTransactions: true,
    supportsSavepoints: true,
    supportsStreaming: true,
    supportsReturning: true,
    supportsAggregations: true,
    supportsSchemaIntrospection: true,
    supportsExplain: true,
  );

  static const ExplainResult _alwaysIndexed = ExplainResult(
    usesIndex: true,
    raw: 'InMemoryAdapter: synthetic plan (always indexed)',
  );

  @override
  AdapterType get adapterType => AdapterType.inMemory;

  @override
  Future<ExplainResult> explain(QueryDescriptor descriptor) async =>
      _alwaysIndexed;

  final InMemoryStore _store;
  bool _connected = false;

  /// Exposes the underlying store for diagnostics and advanced use.
  InMemoryStore get store => _store;

  /// Whether [connect] has been called and [disconnect] has not.
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  /// Close the adapter and clear every stored table and schema.
  /// Unlike [disconnect] this discards all data.
  Future<void> close() async {
    _connected = false;
    _store.clear();
  }

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) async =>
      _store.query(d);

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) async {
    final rows = _store.query(d.copyWith(limit: 1));
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) async {
    final row = <String, Object?>{...d.values};
    _store.rowsOf(d.table).add(row);
    return _project(row, d.returning);
  }

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) async {
    final rows = _store.rowsOf(d.table);
    final inserted = <Map<String, Object?>>[];
    for (final values in d.rows) {
      final row = <String, Object?>{...values};
      rows.add(row);
      inserted.add(_project(row, d.returning));
    }
    return inserted;
  }

  @override
  Future<int> update(UpdateDescriptor d) async {
    var updated = 0;
    for (final row in _store.rowsOf(d.table)) {
      if (!_store.matches(row, d.where)) continue;
      row.addAll(d.values);
      updated++;
    }
    return updated;
  }

  @override
  Future<int> delete(DeleteDescriptor d) async {
    final rows = _store.rowsOf(d.table);
    final before = rows.length;
    rows.removeWhere((row) => _store.matches(row, d.where));
    return before - rows.length;
  }

  @override
  Future<int> count(AggregateDescriptor d) async =>
      _store.rowsForAggregate(d).length;

  @override
  Future<num?> sum(AggregateDescriptor d) async {
    final column = _requireColumn(d);
    final values = _numericValues(d, column);
    if (values.isEmpty) return null;
    return values.fold<num>(0, (a, b) => a + b);
  }

  @override
  Future<double?> avg(AggregateDescriptor d) async {
    final column = _requireColumn(d);
    final values = _numericValues(d, column);
    if (values.isEmpty) return null;
    final total = values.fold<num>(0, (a, b) => a + b);
    return total / values.length;
  }

  List<num> _numericValues(AggregateDescriptor d, String column) => <num>[
    for (final row in _store.rowsForAggregate(d))
      if (row[column] case final num n) n,
  ];

  @override
  Future<Object?> min(AggregateDescriptor d) async =>
      _extremum(d, pickGreater: false);

  @override
  Future<Object?> max(AggregateDescriptor d) async =>
      _extremum(d, pickGreater: true);

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) => throw const UnsupportedOperationException(
    operation: 'rawQuery',
    adapter: 'InMemoryAdapter',
    message: 'InMemoryAdapter does not support raw native queries',
  );

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) =>
      throw const UnsupportedOperationException(
        operation: 'rawExecute',
        adapter: 'InMemoryAdapter',
        message: 'InMemoryAdapter does not support raw native execute',
      );

  @override
  Future<T> transaction<T>(
    Future<T> Function(DatabaseAdapter tx) action,
  ) async {
    final snapshot = _store.snapshot();
    final tx = InMemoryAdapter._withStore(_store, capabilities: capabilities);
    try {
      return await action(tx);
    } catch (_) {
      _store.restore(snapshot);
      rethrow;
    }
  }

  @override
  Future<void> executeSchema(SchemaDescriptor d) async {
    switch (d.operation) {
      case SchemaOperation.create:
        _store.createTable(
          d.table,
          columns: <String>[for (final c in d.columns) c.name],
          ifNotExists: d.ifNotExists,
        );
      case SchemaOperation.drop:
        _store.dropTable(d.table, ifExists: d.ifExists);
      case SchemaOperation.truncate:
        _store.truncate(d.table);
      case SchemaOperation.alter:
        for (final alteration in d.alterations) {
          _applyAlteration(d.table, alteration);
        }
    }
  }

  /// Applies one alteration to the store.
  ///
  /// The store models columns and rows, not indexes or constraints, so index
  /// and foreign-key steps are accepted and have no effect — they are a
  /// storage-engine concern the in-memory adapter has no engine for. Column
  /// steps are applied for real, because a test asserting a migration added a
  /// column must be able to see it.
  void _applyAlteration(String table, SchemaAlteration alteration) {
    switch (alteration) {
      case SchemaAddColumn(:final column, :final ifNotExists):
        _store.addColumn(
          table,
          column.name,
          ifNotExists: ifNotExists,
          defaultValue: column.defaultValue,
        );
      case SchemaDropColumn(:final column, :final ifExists):
        _store.dropColumn(table, column, ifExists: ifExists);
      case SchemaChangeColumn():
      // The store is untyped, so every column already accepts every value.
      case SchemaAddIndex():
      case SchemaDropIndex():
      case SchemaAddForeignKey():
      case SchemaDropForeignKey():
        break;
    }
  }

  @override
  Future<Map<String, List<String>>> introspectSchema() async => _store.schemas;

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) =>
      Stream<Map<String, Object?>>.fromIterable(_store.query(d));

  static const SqlCompiler _sqlCompiler = SqlCompiler();

  @override
  String compileToString(Object descriptor) => switch (descriptor) {
    final QueryDescriptor d => _sqlCompiler.compile(d),
    final InsertDescriptor d =>
      'InMemoryAdapter insert into table="${d.table}"',
    final InsertManyDescriptor d =>
      'InMemoryAdapter insertMany into table="${d.table}"',
    final UpdateDescriptor d => 'InMemoryAdapter update of table="${d.table}"',
    final DeleteDescriptor d =>
      'InMemoryAdapter delete from table="${d.table}"',
    final AggregateDescriptor d =>
      'InMemoryAdapter ${d.function.name} over table="${d.table}"',
    final SchemaDescriptor d =>
      'InMemoryAdapter schema ${d.operation.name} on table="${d.table}"',
    _ => 'InMemoryAdapter compile for ${descriptor.runtimeType}',
  };

  Map<String, Object?> _project(
    Map<String, Object?> row,
    List<String>? returning,
  ) {
    if (returning == null) return <String, Object?>{...row};
    return <String, Object?>{for (final c in returning) c: row[c]};
  }

  Object? _extremum(AggregateDescriptor d, {required bool pickGreater}) {
    final column = _requireColumn(d);
    Object? best;
    for (final row in _store.rowsForAggregate(d)) {
      final value = row[column];
      if (value == null) continue;
      best = _pickExtremum(best, value, pickGreater: pickGreater);
    }
    return best;
  }

  Object? _pickExtremum(
    Object? current,
    Object candidate, {
    required bool pickGreater,
  }) {
    if (current == null) return candidate;
    if (candidate is Comparable && current is Comparable) {
      final cmp = Comparable.compare(candidate, current);
      if (pickGreater ? cmp > 0 : cmp < 0) return candidate;
    }
    return current;
  }

  String _requireColumn(AggregateDescriptor d) {
    final column = d.column;
    if (column == null) {
      throw StateError('${d.function.name} requires a column');
    }
    return column;
  }
}
