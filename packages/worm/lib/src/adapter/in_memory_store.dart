/// Internal in-memory row store used by the
/// in-memory adapter.
library;

import '../query/aggregate_descriptor.dart';
import '../query/predicate_tree.dart';
import '../query/query_descriptor.dart';
import '../query/sort_clause.dart';
import '../query/sort_direction.dart';
import 'predicate_evaluator.dart';

/// Mutable store used by the in-memory adapter.
final class InMemoryStore {
  /// Creates an empty store.
  InMemoryStore();

  static const PredicateEvaluator _evaluator = PredicateEvaluator();

  final Map<String, List<Map<String, Object?>>> _tables =
      <String, List<Map<String, Object?>>>{};
  final Map<String, List<String>> _schemas = <String, List<String>>{};

  /// Names of all registered tables.
  List<String> get tableNames => List<String>.unmodifiable(_tables.keys);

  /// Schema map: table name → declared columns.
  Map<String, List<String>> get schemas => <String, List<String>>{
    for (final entry in _schemas.entries)
      entry.key: List<String>.unmodifiable(entry.value),
  };

  /// Whether [table] is registered.
  bool hasTable(String table) => _tables.containsKey(table);

  /// Declared columns for [table].
  List<String> columnsOf(String table) {
    final columns = _schemas[table];
    if (columns == null) throw StateError('Table "$table" does not exist');
    return List<String>.unmodifiable(columns);
  }

  /// Register an empty table if not present.
  void createTable(
    String table, {
    List<String> columns = const <String>[],
    bool ifNotExists = false,
  }) {
    if (_tables.containsKey(table)) {
      if (ifNotExists) return;
      throw StateError('Table "$table" already exists');
    }
    _tables[table] = <Map<String, Object?>>[];
    _schemas[table] = List<String>.of(columns);
  }

  /// Declare a column on an existing table, and give it to every stored row.
  ///
  /// Rows already stored gain the column holding [defaultValue], which is
  /// what `ALTER TABLE ADD COLUMN` does on every real database.
  void addColumn(
    String table,
    String column, {
    bool ifNotExists = false,
    Object? defaultValue,
  }) {
    final columns = _schemas[_requireDeclared(table)]!;
    if (columns.contains(column)) {
      if (ifNotExists) return;
      throw StateError('Column "$column" of "$table" already exists');
    }
    columns.add(column);
    // A database gives every existing row the new column, holding its
    // default or null. Leaving the key absent here would make a row read
    // back differently in memory than on a server — which is the one thing
    // this store must never do.
    for (final row in _requireTable(table)) {
      row[column] = defaultValue;
    }
  }

  /// Remove a column declaration and drop the value from every stored row.
  void dropColumn(String table, String column, {bool ifExists = false}) {
    final columns = _schemas[_requireDeclared(table)]!;
    if (!columns.remove(column)) {
      if (ifExists) return;
      throw StateError('Column "$column" of "$table" does not exist');
    }
    for (final row in _requireTable(table)) {
      row.remove(column);
    }
  }

  /// The table name, after checking it is declared.
  String _requireDeclared(String table) {
    if (!_schemas.containsKey(table)) {
      throw StateError('Table "$table" does not exist');
    }
    return table;
  }

  /// Remove a table.
  void dropTable(String table, {bool ifExists = false}) {
    if (!_tables.containsKey(table)) {
      if (ifExists) return;
      throw StateError('Table "$table" does not exist');
    }
    _tables.remove(table);
    _schemas.remove(table);
  }

  /// Remove all rows from a table.
  void truncate(String table) {
    _requireTable(table).clear();
  }

  /// Clear every table and schema.
  void clear() {
    _tables.clear();
    _schemas.clear();
  }

  /// Mutable row list for [table].
  List<Map<String, Object?>> rowsOf(String table) => _requireTable(table);

  /// Deep clone of the current state.
  InMemoryStore snapshot() {
    final copy = InMemoryStore();
    for (final entry in _tables.entries) {
      copy._tables[entry.key] = <Map<String, Object?>>[
        for (final row in entry.value) <String, Object?>{...row},
      ];
    }
    for (final entry in _schemas.entries) {
      copy._schemas[entry.key] = List<String>.of(entry.value);
    }
    return copy;
  }

  /// Restore this store's state from a previously
  /// captured [snapshot].
  void restore(InMemoryStore snapshot) {
    _tables
      ..clear()
      ..addAll(<String, List<Map<String, Object?>>>{
        for (final entry in snapshot._tables.entries)
          entry.key: <Map<String, Object?>>[
            for (final row in entry.value) <String, Object?>{...row},
          ],
      });
    _schemas
      ..clear()
      ..addAll(<String, List<String>>{
        for (final entry in snapshot._schemas.entries)
          entry.key: List<String>.of(entry.value),
      });
  }

  /// Whether [row] matches [where]. Subquery
  /// [ExistsNode]s are resolved against this store.
  bool matches(Map<String, Object?> row, PredicateTree? where) =>
      _evaluator.matches(row, where, existsResolver: _resolveExists);

  bool _resolveExists(ExistsNode node) =>
      query(node.subquery.copyWith(limit: 1)).isNotEmpty;

  /// Apply a [QueryDescriptor]: filter, sort, project,
  /// optionally deduplicate, then paginate.
  List<Map<String, Object?>> query(QueryDescriptor descriptor) {
    final filtered = _filter(_requireTable(descriptor.table), descriptor.where);
    _sortRows(filtered, descriptor.orderBy);
    final columns = descriptor.columns.isEmpty ? null : descriptor.columns;
    final projected = _project(filtered, columns);
    final deduped = descriptor.distinct ? _distinct(projected) : projected;
    return _paginate(deduped, descriptor.offset, descriptor.limit);
  }

  List<Map<String, Object?>> _distinct(List<Map<String, Object?>> rows) {
    final out = <Map<String, Object?>>[];
    final seen = <String>{};
    for (final row in rows) {
      final entries = row.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final key = entries.map((e) => '${e.key}=${e.value}').join('|');
      if (seen.add(key)) out.add(row);
    }
    return out;
  }

  /// Rows matching an [AggregateDescriptor].
  List<Map<String, Object?>> rowsForAggregate(AggregateDescriptor d) =>
      _filter(_requireTable(d.table), d.where);

  List<Map<String, Object?>> _filter(
    List<Map<String, Object?>> rows,
    PredicateTree? where,
  ) => <Map<String, Object?>>[
    for (final row in rows)
      if (_evaluator.matches(row, where, existsResolver: _resolveExists)) row,
  ];

  List<Map<String, Object?>> _project(
    List<Map<String, Object?>> rows,
    List<String>? columns,
  ) {
    if (columns == null) {
      return <Map<String, Object?>>[
        for (final row in rows) <String, Object?>{...row},
      ];
    }
    return <Map<String, Object?>>[
      for (final row in rows)
        <String, Object?>{for (final c in columns) c: row[c]},
    ];
  }

  List<Map<String, Object?>> _requireTable(String table) {
    final rows = _tables[table];
    if (rows == null) {
      throw StateError('Table "$table" does not exist');
    }
    return rows;
  }

  void _sortRows(List<Map<String, Object?>> rows, List<SortClause> orderBy) {
    if (orderBy.isEmpty) return;
    rows.sort((a, b) {
      for (final clause in orderBy) {
        final cmp = _evaluator.compareValues(
          a[clause.fieldName],
          b[clause.fieldName],
        );
        if (cmp != 0) {
          return clause.direction == SortDirection.desc ? -cmp : cmp;
        }
      }
      return 0;
    });
  }

  List<Map<String, Object?>> _paginate(
    List<Map<String, Object?>> rows,
    int? offset,
    int? limit,
  ) {
    final start = offset ?? 0;
    if (start >= rows.length) return const <Map<String, Object?>>[];
    final endExclusive = limit == null
        ? rows.length
        : (start + limit).clamp(start, rows.length);
    return rows.sublist(start, endExclusive);
  }
}
