/// Shared SQLite execution engine used by both the pooled adapter and
/// its transactional wrapper.
library;

import 'package:sqlite3/common.dart';
import 'package:worm/worm.dart';

import 'compiler/sqlite_compile_result.dart';
import 'compiler/sqlite_compiler.dart';
import 'pool/sqlite_prepared_cache.dart';
import 'sqlite_error_mapper.dart';

export 'pool/sqlite_prepared_cache.dart';
export 'sqlite_error_mapper.dart';

/// Runs worm descriptors against a [CommonDatabase], translating
/// results and errors. Stateless apart from the connection it holds —
/// both [DatabaseAdapter] wrappers delegate every operation here so
/// the transactional path shares identical compilation, statement
/// caching, and mapping.
final class SqliteRunner {
  /// Creates a runner over [database] using [compiler].
  SqliteRunner({required CommonDatabase database, required this.compiler})
    : _db = database,
      _cache = SqlitePreparedCache(database);

  final CommonDatabase _db;
  final SqlitePreparedCache _cache;

  /// The compiler used to translate descriptors to SQLite SQL.
  final SqliteCompiler compiler;

  /// The prepared-statement cache backing this connection.
  SqlitePreparedCache get preparedCache => _cache;

  /// Apply connection-level pragmas. WAL improves write throughput and
  /// lets readers run without blocking writers (no-op for in-memory
  /// databases); foreign keys are enforced; `synchronous = NORMAL` is
  /// the safe, fast companion to WAL.
  void configureConnection() {
    _db
      ..select('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA foreign_keys = ON')
      ..execute('PRAGMA synchronous = NORMAL');
  }

  List<Map<String, Object?>> _cachedSelect(SqliteCompileResult compiled) =>
      _rows(
        _cache.statementFor(compiled.sql).select(_bind(compiled.parameters)),
      );

  int _cachedWrite(SqliteCompileResult compiled) {
    _cache.statementFor(compiled.sql).execute(_bind(compiled.parameters));
    return _db.updatedRows;
  }

  /// Capability matrix shared by both SQLite adapter wrappers.
  static const AdapterCapabilities capabilities = AdapterCapabilities(
    supportsTransactions: true,
    supportsSavepoints: true,
    supportsStreaming: true,
    supportsRawQuery: true,
    supportsJoins: true,
    supportsAggregations: true,
    supportsSchemaIntrospection: true,
    supportsExplain: true,
  );

  Future<List<Map<String, Object?>>> select(QueryDescriptor d) =>
      SqliteErrorMapper.wrap(
        () async => _cachedSelect(compiler.compileSelect(d)),
        table: d.table,
      );

  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) async {
    final rows = await select(d.copyWith(limit: 1));
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>> insert(InsertDescriptor d) =>
      SqliteErrorMapper.wrap(() async {
        _cachedWrite(compiler.compileInsert(d));
        return _project(d.values, d.returning);
      }, table: d.table);

  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) =>
      SqliteErrorMapper.wrap(() async {
        if (d.rows.isEmpty) return const <Map<String, Object?>>[];
        // Batched multi-row INSERTs (chunked under the param limit)
        // instead of one statement per row — far fewer round trips
        // through the SQLite VM for bulk seeds.
        for (final statement in compiler.compileInsertMany(d)) {
          _cachedWrite(statement);
        }
        return <Map<String, Object?>>[
          for (final row in d.rows) _project(row, d.returning),
        ];
      }, table: d.table);

  Future<int> update(UpdateDescriptor d) => SqliteErrorMapper.wrap(
    () async => _cachedWrite(compiler.compileUpdate(d)),
    table: d.table,
  );

  Future<int> delete(DeleteDescriptor d) => SqliteErrorMapper.wrap(
    () async => _cachedWrite(compiler.compileDelete(d)),
    table: d.table,
  );

  Future<int> count(AggregateDescriptor d) => SqliteErrorMapper.wrap(() async {
    final row = await _aggregateRow(d);
    final value = row['count'];
    return value is int ? value : (value as num?)?.toInt() ?? 0;
  }, table: d.table);

  Future<num?> sum(AggregateDescriptor d) => SqliteErrorMapper.wrap(() async {
    final value = (await _aggregateRow(d))['sum'];
    return value is num ? value : null;
  }, table: d.table);

  Future<double?> avg(AggregateDescriptor d) =>
      SqliteErrorMapper.wrap(() async {
        final value = (await _aggregateRow(d))['avg'];
        if (value is num) return value.toDouble();
        return null;
      }, table: d.table);

  Future<Object?> min(AggregateDescriptor d) =>
      SqliteErrorMapper.wrap(() async => (await _aggregateRow(d))['min']);

  Future<Object?> max(AggregateDescriptor d) =>
      SqliteErrorMapper.wrap(() async => (await _aggregateRow(d))['max']);

  Future<Map<Object?, num>> aggregateGrouped(AggregateDescriptor d) =>
      SqliteErrorMapper.wrap(() async {
        if (d.groupBy == null) {
          return _fallbackGrouped(d);
        }
        final rows = _cachedSelect(compiler.compileGroupedAggregate(d));
        final result = <Object?, num>{};
        for (final row in rows) {
          final value = row['value'];
          if (value is num) result[row['group']] = value;
        }
        return result;
      }, table: d.table);

  Future<Map<Object?, num>> _fallbackGrouped(AggregateDescriptor d) async {
    // No groupBy: behave like the base default (single bucket).
    final rows = await select(QueryDescriptor(table: d.table, where: d.where));
    return <Object?, num>{null: rows.length};
  }

  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) => SqliteErrorMapper.wrap(
    () async => _rows(_db.select(query, _bind(parameters))),
    query: query,
  );

  Future<int> rawExecute(String statement, List<Object?> parameters) =>
      SqliteErrorMapper.wrap(() async {
        _db.execute(statement, _bind(parameters));
        return _db.updatedRows;
      }, query: statement);

  Future<void> executeSchema(SchemaDescriptor d) =>
      SqliteErrorMapper.wrap(() async {
        final compiled = compiler.compileDdl(d);
        // DDL is one-off and can invalidate cached statements that
        // referenced an altered table — run it raw and drop the cache.
        _db.execute(compiled.sql, _bind(compiled.parameters));
        _cache.clear();
      }, table: d.table);

  Future<Map<String, List<String>>> introspectSchema() =>
      SqliteErrorMapper.wrap(() async {
        final tables = _db.select(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        );
        final schema = <String, List<String>>{};
        for (final table in tables) {
          final name = table['name'];
          if (name is! String) continue;
          final columns = _db.select('PRAGMA table_info(${_quote(name)})');
          schema[name] = <String>[
            for (final column in columns)
              if (column['name'] case final String columnName) columnName,
          ];
        }
        return schema;
      });

  Stream<Map<String, Object?>> stream(QueryDescriptor d) async* {
    final compiled = compiler.compileSelect(d);
    final rows = _cache
        .statementFor(compiled.sql)
        .select(_bind(compiled.parameters));
    for (final row in rows) {
      yield <String, Object?>{...row};
    }
  }

  String compileToString(Object descriptor) {
    final compiled = switch (descriptor) {
      final QueryDescriptor d => compiler.compileSelect(d),
      final InsertDescriptor d => compiler.compileInsert(d),
      final UpdateDescriptor d => compiler.compileUpdate(d),
      final DeleteDescriptor d => compiler.compileDelete(d),
      final AggregateDescriptor d => compiler.compileAggregate(d),
      final SchemaDescriptor d => compiler.compileDdl(d),
      _ => SqliteCompileResult(sql: 'SQLite: ${descriptor.runtimeType}'),
    };
    return '${compiled.sql}\n-- Params: ${compiled.parameters}';
  }

  Future<ExplainResult> explain(QueryDescriptor descriptor) =>
      SqliteErrorMapper.wrap(() async {
        final compiled = compiler.compileSelect(descriptor);
        final plan = _cache
            .statementFor('EXPLAIN QUERY PLAN ${compiled.sql}')
            .select(_bind(compiled.parameters));
        final details = <String>[
          for (final row in plan)
            if (row['detail'] case final String detail) detail,
        ];
        final joined = details.join('\n');
        return ExplainResult(
          usesIndex:
              joined.contains('USING INDEX') ||
              joined.contains('USING COVERING INDEX'),
          raw: joined,
          scannedTables: <String>[descriptor.table],
        );
      }, table: descriptor.table);

  /// Run [body] inside `BEGIN … COMMIT`, rolling back on error.
  ///
  /// [body]'s own exception propagates **unchanged** (its operations
  /// already map driver errors), so a caller throwing to trigger a
  /// rollback sees its original exception, not a re-wrapped one.
  Future<T> runInTransaction<T>(Future<T> Function() body) async {
    _begin('BEGIN');
    try {
      final result = await body();
      _db.execute('COMMIT');
      return result;
    } on Object {
      _rollbackQuietly('ROLLBACK');
      rethrow;
    }
  }

  /// Run [body] inside a named SAVEPOINT, rolling back to it on error.
  Future<T> runInSavepoint<T>(String name, Future<T> Function() body) async {
    final quoted = _quote(name);
    _begin('SAVEPOINT $quoted');
    try {
      final result = await body();
      _db.execute('RELEASE SAVEPOINT $quoted');
      return result;
    } on Object {
      _rollbackQuietly('ROLLBACK TO SAVEPOINT $quoted');
      rethrow;
    }
  }

  void _begin(String sql) {
    try {
      _db.execute(sql);
    } on Object catch (error) {
      throw SqliteErrorMapper.map(error, query: sql);
    }
  }

  void _rollbackQuietly(String sql) {
    try {
      _db.execute(sql);
    } on Object {
      // Surface the original failure; a rollback error must not mask it.
    }
  }

  /// Dispose the cached statements and the underlying connection.
  void dispose() {
    _cache.clear();
    _db.dispose();
  }

  Future<Map<String, Object?>> _aggregateRow(AggregateDescriptor d) async {
    final rows = _cachedSelect(compiler.compileAggregate(d));
    return rows.isEmpty ? const <String, Object?>{} : rows.first;
  }

  List<Map<String, Object?>> _rows(ResultSet result) => <Map<String, Object?>>[
    for (final row in result) <String, Object?>{...row},
  ];

  Map<String, Object?> _project(
    Map<String, Object?> values,
    List<String>? returning,
  ) {
    if (returning == null) return <String, Object?>{...values};
    return <String, Object?>{for (final c in returning) c: values[c]};
  }

  /// SQLite binds only int / double / String / Uint8List / null, so
  /// normalise bools to 0/1 and DateTimes to ISO-8601 text.
  List<Object?> _bind(List<Object?> parameters) => <Object?>[
    for (final value in parameters) _bindValue(value),
  ];

  Object? _bindValue(Object? value) => switch (value) {
    final bool b => b ? 1 : 0,
    final DateTime d => d.toIso8601String(),
    _ => value,
  };

  String _quote(String identifier) => '"${identifier.replaceAll('"', '""')}"';
}
