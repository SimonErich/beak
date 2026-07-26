/// Pure, stateless compiler from worm descriptors to SQLite SQL.
library;

import 'package:worm/worm.dart';

import 'sqlite_compile_result.dart';

/// Maximum values per `IN (...)` list before chunking. SQLite's
/// default bound-parameter limit is 999; staying under it keeps a
/// single statement valid.
const int kSqliteInListChunkSize = 900;

/// Translates immutable worm descriptors into parameterised SQLite
/// SQL strings. Pure and stateless — safe to reuse as a `const`.
final class SqliteCompiler {
  /// Creates a const compiler.
  const SqliteCompiler();

  /// Compile a [QueryDescriptor] into a `SELECT` statement.
  SqliteCompileResult compileSelect(QueryDescriptor descriptor) {
    final params = <Object?>[];
    final sql = StringBuffer('SELECT ');
    if (descriptor.distinct) sql.write('DISTINCT ');
    sql
      ..write(_projection(descriptor.columns))
      ..write(' FROM ')
      ..write(_quoteIdent(descriptor.table));
    _appendJoins(sql, descriptor.joins);
    _appendWhere(sql, descriptor.where, params);
    _appendGroupBy(sql, descriptor.groupBy);
    _appendHaving(sql, descriptor.having, params);
    _appendOrderBy(sql, descriptor.orderBy);
    _appendLimitOffset(sql, descriptor.limit, descriptor.offset);
    return SqliteCompileResult(sql: sql.toString(), parameters: params);
  }

  /// Compile an [InsertDescriptor] into an `INSERT`.
  SqliteCompileResult compileInsert(InsertDescriptor descriptor) {
    final columns = descriptor.values.keys.toList(growable: false);
    if (columns.isEmpty) {
      return SqliteCompileResult(
        sql: 'INSERT INTO ${_quoteIdent(descriptor.table)} DEFAULT VALUES',
      );
    }
    final params = <Object?>[for (final c in columns) descriptor.values[c]];
    final sql = StringBuffer('INSERT INTO ')
      ..write(_quoteIdent(descriptor.table))
      ..write(' (')
      ..write(columns.map(_quoteIdent).join(', '))
      ..write(') VALUES (')
      ..write(List<String>.filled(columns.length, '?').join(', '))
      ..write(')');
    return SqliteCompileResult(sql: sql.toString(), parameters: params);
  }

  /// Compile an [InsertManyDescriptor] into batched multi-row
  /// `INSERT … VALUES (…), (…)` statements, chunked so each stays
  /// under SQLite's bound-parameter limit. Rows are assumed to share
  /// the first row's column set.
  List<SqliteCompileResult> compileInsertMany(InsertManyDescriptor d) {
    if (d.rows.isEmpty) return const <SqliteCompileResult>[];
    final columns = d.rows.first.keys.toList(growable: false);
    if (columns.isEmpty) {
      return <SqliteCompileResult>[
        for (final _ in d.rows)
          SqliteCompileResult(
            sql: 'INSERT INTO ${_quoteIdent(d.table)} DEFAULT VALUES',
          ),
      ];
    }
    final perRow = columns.length;
    final maxRows = (kSqliteInListChunkSize ~/ perRow).clamp(1, d.rows.length);
    final columnSql = columns.map(_quoteIdent).join(', ');
    final rowPlaceholder = '(${List<String>.filled(perRow, '?').join(', ')})';
    final statements = <SqliteCompileResult>[];
    for (var start = 0; start < d.rows.length; start += maxRows) {
      final end = (start + maxRows).clamp(0, d.rows.length);
      final chunk = d.rows.sublist(start, end);
      final params = <Object?>[
        for (final row in chunk)
          for (final column in columns) row[column],
      ];
      final sql = StringBuffer('INSERT INTO ')
        ..write(_quoteIdent(d.table))
        ..write(' (')
        ..write(columnSql)
        ..write(') VALUES ')
        ..write(List<String>.filled(chunk.length, rowPlaceholder).join(', '));
      statements.add(
        SqliteCompileResult(sql: sql.toString(), parameters: params),
      );
    }
    return statements;
  }

  /// Compile an [UpdateDescriptor] into an `UPDATE`.
  SqliteCompileResult compileUpdate(UpdateDescriptor descriptor) {
    if (descriptor.values.isEmpty) {
      throw QueryException(
        query: 'UPDATE ${_quoteIdent(descriptor.table)}',
        message: 'compileUpdate requires at least one column to set',
      );
    }
    final params = <Object?>[];
    final assignments = descriptor.values.entries
        .map((e) => '${_quoteIdent(e.key)} = ${_placeholder(params, e.value)}')
        .join(', ');
    final sql = StringBuffer('UPDATE ')
      ..write(_quoteIdent(descriptor.table))
      ..write(' SET ')
      ..write(assignments);
    _appendWhere(sql, descriptor.where, params);
    return SqliteCompileResult(sql: sql.toString(), parameters: params);
  }

  /// Compile a [DeleteDescriptor] into a `DELETE`.
  SqliteCompileResult compileDelete(DeleteDescriptor descriptor) {
    final params = <Object?>[];
    final sql = StringBuffer('DELETE FROM ')
      ..write(_quoteIdent(descriptor.table));
    _appendWhere(sql, descriptor.where, params);
    return SqliteCompileResult(sql: sql.toString(), parameters: params);
  }

  /// Compile a scalar [AggregateDescriptor] into a `SELECT <agg>`.
  SqliteCompileResult compileAggregate(AggregateDescriptor descriptor) {
    final params = <Object?>[];
    final sql = StringBuffer('SELECT ')
      ..write(_aggregateExpression(descriptor))
      ..write(' FROM ')
      ..write(_quoteIdent(descriptor.table));
    _appendWhere(sql, descriptor.where, params);
    return SqliteCompileResult(sql: sql.toString(), parameters: params);
  }

  /// Compile a grouped aggregate:
  /// `SELECT group AS "group", COUNT(*)/SUM(col) AS "value" …
  /// GROUP BY group`.
  SqliteCompileResult compileGroupedAggregate(AggregateDescriptor descriptor) {
    final group = descriptor.groupBy;
    if (group == null) {
      throw QueryException(
        query: 'SELECT … FROM ${_quoteIdent(descriptor.table)}',
        message: 'compileGroupedAggregate requires a groupBy column',
      );
    }
    final params = <Object?>[];
    final groupCol = _quoteIdent(group);
    final sql = StringBuffer('SELECT ')
      ..write(groupCol)
      ..write(' AS "group", ')
      ..write(_groupedAggregateExpression(descriptor))
      ..write(' FROM ')
      ..write(_quoteIdent(descriptor.table));
    _appendWhere(sql, descriptor.where, params);
    sql
      ..write(' GROUP BY ')
      ..write(groupCol);
    return SqliteCompileResult(sql: sql.toString(), parameters: params);
  }

  /// Compile a [SchemaDescriptor] into DDL.
  SqliteCompileResult compileDdl(SchemaDescriptor descriptor) {
    if (descriptor is SchemaIndexDescriptor) {
      final unique = descriptor.unique ? 'UNIQUE ' : '';
      final name = _quoteIdent(
        'idx_${descriptor.collection}_${descriptor.field}',
      );
      return SqliteCompileResult(
        sql:
            'CREATE ${unique}INDEX IF NOT EXISTS $name ON '
            '${_quoteIdent(descriptor.collection)} '
            '(${_quoteIdent(descriptor.field)})',
      );
    }
    final table = _quoteIdent(descriptor.table);
    return switch (descriptor.operation) {
      SchemaOperation.create => SqliteCompileResult(
        sql: _buildCreateTable(descriptor, table),
      ),
      SchemaOperation.drop => SqliteCompileResult(
        sql: 'DROP TABLE ${descriptor.ifExists ? 'IF EXISTS ' : ''}$table',
      ),
      SchemaOperation.truncate => SqliteCompileResult(
        sql: 'DELETE FROM $table',
      ),
      SchemaOperation.alter => throw const QueryException(
        query: '',
        message: 'compileDdl(SchemaOperation.alter) is not implemented',
      ),
      SchemaOperation.createIndex => throw const QueryException(
        query: '',
        message: 'compileDdl(createIndex) requires a SchemaIndexDescriptor',
      ),
    };
  }

  /// Map a logical [ColumnType] to its SQLite storage class. SQLite
  /// uses flexible type affinity, so unmapped logical types (uuid,
  /// json, enum, inet, …) safely fall back to `TEXT`.
  static String sqliteTypeOf(ColumnType type) => switch (type) {
    ColumnType.smallInteger ||
    ColumnType.integer ||
    ColumnType.bigInteger ||
    ColumnType.boolean => 'INTEGER',
    ColumnType.decimal => 'NUMERIC',
    ColumnType.doublePrecision => 'REAL',
    ColumnType.binary => 'BLOB',
    _ => 'TEXT',
  };

  String _buildCreateTable(SchemaDescriptor descriptor, String table) {
    final ifNotExists = descriptor.ifNotExists ? 'IF NOT EXISTS ' : '';
    final defs = <String>[
      for (final column in descriptor.columns) _columnDefinition(column),
      // Unique indexes and foreign keys become table constraints rather than
      // separate statements, so the table is correct the moment it exists.
      for (final index in descriptor.indexes)
        if (index.unique) _uniqueConstraint(index),
      for (final key in descriptor.foreignKeys) _foreignKeyConstraint(key),
    ];
    return 'CREATE TABLE $ifNotExists$table (${defs.join(', ')})';
  }

  String _uniqueConstraint(SchemaIndex index) {
    final columns = index.columns.map(_quoteIdent).join(', ');
    return 'CONSTRAINT ${_quoteIdent(index.name)} UNIQUE ($columns)';
  }

  String _foreignKeyConstraint(SchemaForeignKey key) {
    final locals = key.columns.map(_quoteIdent).join(', ');
    final remotes = key.referencedColumns.map(_quoteIdent).join(', ');
    final buffer = StringBuffer();
    if (key.name case final String name) {
      buffer.write('CONSTRAINT ${_quoteIdent(name)} ');
    }
    buffer
      ..write('FOREIGN KEY ($locals) REFERENCES ')
      ..write('${_quoteIdent(key.referencedTable)} ($remotes)')
      ..write(' ON DELETE ${_onDeleteSql(key.onDelete)}');
    return buffer.toString();
  }

  /// The `ON DELETE` action for [onDelete].
  ///
  /// [OnDelete.ormCascade] deliberately renders as `NO ACTION`: the ORM walks
  /// and deletes the children itself so lifecycle hooks and soft-delete
  /// scopes run, and a database-level cascade would remove the rows behind
  /// its back.
  String _onDeleteSql(OnDelete onDelete) => switch (onDelete) {
    OnDelete.cascade => 'CASCADE',
    OnDelete.restrict => 'RESTRICT',
    OnDelete.setNull => 'SET NULL',
    OnDelete.setDefault => 'SET DEFAULT',
    OnDelete.noAction || OnDelete.ormCascade => 'NO ACTION',
  };

  String _columnDefinition(SchemaColumn column) {
    final buffer = StringBuffer(_quoteIdent(column.name))
      ..write(' ')
      ..write(sqliteTypeOf(column.type));
    if (column.isPrimaryKey) buffer.write(' PRIMARY KEY');
    if (!column.nullable && !column.isPrimaryKey) buffer.write(' NOT NULL');
    return buffer.toString();
  }

  void _appendJoins(StringBuffer sql, List<JoinClause> joins) {
    for (final join in joins) {
      sql
        ..write(' ${join.kind.sql} ')
        ..write(_quoteIdent(join.table))
        ..write(' ON ')
        ..write(_quotePath(join.leftColumn))
        ..write(' = ')
        ..write(_quotePath(join.rightColumn));
    }
  }

  void _appendGroupBy(StringBuffer sql, List<String> groupBy) {
    if (groupBy.isEmpty) return;
    sql
      ..write(' GROUP BY ')
      ..write(groupBy.map(_quotePath).join(', '));
  }

  void _appendHaving(
    StringBuffer sql,
    List<HavingClause> having,
    List<Object?> params,
  ) {
    if (having.isEmpty) return;
    final parts = having
        .map(
          (c) =>
              '${c.expression} ${_comparisonOperator(c.operator)} '
              '${_placeholder(params, c.value)}',
        )
        .join(' AND ');
    sql
      ..write(' HAVING ')
      ..write(parts);
  }

  void _appendOrderBy(StringBuffer sql, List<SortClause> orderBy) {
    if (orderBy.isEmpty) return;
    final parts = orderBy
        .map(
          (o) =>
              '${_qualified(o.tableName, o.fieldName)} '
              '${o.direction == SortDirection.desc ? 'DESC' : 'ASC'}',
        )
        .join(', ');
    sql
      ..write(' ORDER BY ')
      ..write(parts);
  }

  void _appendLimitOffset(StringBuffer sql, int? limit, int? offset) {
    if (limit != null) sql.write(' LIMIT $limit');
    if (offset != null) {
      if (limit == null) sql.write(' LIMIT -1');
      sql.write(' OFFSET $offset');
    }
  }

  void _appendWhere(
    StringBuffer sql,
    PredicateTree? where,
    List<Object?> params,
  ) {
    if (where == null) return;
    sql
      ..write(' WHERE ')
      ..write(_compileTree(where, params));
  }

  String _compileTree(PredicateTree node, List<Object?> params) =>
      switch (node) {
        LeafNode(:final predicate) => _compilePredicate(predicate, params),
        AndNode(:final left, :final right) =>
          '${_compileTree(left, params)} AND ${_compileTree(right, params)}',
        OrNode(:final left, :final right) =>
          '${_compileTree(left, params)} OR ${_compileTree(right, params)}',
        NotNode(:final child) => 'NOT ${_compileTree(child, params)}',
        GroupNode(:final child) => '(${_compileTree(child, params)})',
        ColumnNode() => _compileColumn(node),
        ExistsNode() => _compileExists(node, params),
        RawNode() => _compileRaw(node, params),
      };

  String _compileColumn(ColumnNode node) {
    final left = _qualified(node.leftTable, node.leftField);
    final right = _qualified(node.rightTable, node.rightField);
    return '$left ${_comparisonOperator(node.operator)} $right';
  }

  String _compileExists(ExistsNode node, List<Object?> params) {
    final sub = compileSelect(node.subquery);
    params.addAll(sub.parameters);
    final keyword = node.negated ? 'NOT EXISTS' : 'EXISTS';
    return '$keyword (${sub.sql})';
  }

  String _compileRaw(RawNode node, List<Object?> params) {
    params.addAll(node.parameters);
    return node.sql;
  }

  String _compilePredicate(Predicate predicate, List<Object?> params) {
    final column = _qualified(predicate.tableName, predicate.fieldName);
    return switch (predicate.operator) {
      Operator.eq => '$column = ${_placeholder(params, predicate.value)}',
      Operator.neq => '$column != ${_placeholder(params, predicate.value)}',
      Operator.gt => '$column > ${_placeholder(params, predicate.value)}',
      Operator.gte => '$column >= ${_placeholder(params, predicate.value)}',
      Operator.lt => '$column < ${_placeholder(params, predicate.value)}',
      Operator.lte => '$column <= ${_placeholder(params, predicate.value)}',
      // SQLite's LIKE is case-insensitive for ASCII; ILIKE maps to it.
      Operator.like ||
      Operator.ilike => '$column LIKE ${_placeholder(params, predicate.value)}',
      Operator.notLike =>
        '$column NOT LIKE ${_placeholder(params, predicate.value)}',
      Operator.isNull => '$column IS NULL',
      Operator.isNotNull => '$column IS NOT NULL',
      Operator.inList => _compileInList(
        column,
        _asList(predicate.value),
        params,
        negate: false,
      ),
      Operator.notInList => _compileInList(
        column,
        _asList(predicate.value),
        params,
        negate: true,
      ),
      Operator.between => _compileBetween(
        column,
        predicate.value,
        params,
        negate: false,
      ),
      Operator.notBetween => _compileBetween(
        column,
        predicate.value,
        params,
        negate: true,
      ),
    };
  }

  String _compileInList(
    String column,
    List<Object?> items,
    List<Object?> params, {
    required bool negate,
  }) {
    final keyword = negate ? 'NOT IN' : 'IN';
    final connector = negate ? ' AND ' : ' OR ';
    if (items.isEmpty) return negate ? '1 = 1' : '1 = 0';
    if (items.length <= kSqliteInListChunkSize) {
      final placeholders = items.map((v) => _placeholder(params, v)).join(', ');
      return '$column $keyword ($placeholders)';
    }
    final chunks = <String>[];
    for (var i = 0; i < items.length; i += kSqliteInListChunkSize) {
      final end = i + kSqliteInListChunkSize < items.length
          ? i + kSqliteInListChunkSize
          : items.length;
      final placeholders = items
          .sublist(i, end)
          .map((v) => _placeholder(params, v))
          .join(', ');
      chunks.add('$column $keyword ($placeholders)');
    }
    return '(${chunks.join(connector)})';
  }

  String _compileBetween(
    String column,
    Object? bounds,
    List<Object?> params, {
    required bool negate,
  }) {
    final pair = _extractBounds(bounds);
    final low = _placeholder(params, pair.$1);
    final high = _placeholder(params, pair.$2);
    return '$column ${negate ? 'NOT BETWEEN' : 'BETWEEN'} $low AND $high';
  }

  (Object?, Object?) _extractBounds(Object? bounds) {
    if (bounds is (Object?, Object?)) return bounds;
    if (bounds is List && bounds.length == 2) return (bounds[0], bounds[1]);
    throw QueryException(
      query: '',
      message:
          'between requires a record or 2-element list, got '
          '${bounds.runtimeType}',
    );
  }

  String _aggregateExpression(AggregateDescriptor descriptor) {
    final function = descriptor.function;
    if (function == AggregateFunction.count && descriptor.column == null) {
      return 'COUNT(*) AS "count"';
    }
    final column = descriptor.column;
    if (column == null) {
      throw QueryException(
        query: 'SELECT ${function.name} FROM "${descriptor.table}"',
        message: '${function.name} requires a column',
      );
    }
    final quoted = _quoteIdent(column);
    return switch (function) {
      AggregateFunction.count => 'COUNT($quoted) AS "count"',
      AggregateFunction.sum => 'SUM($quoted) AS "sum"',
      AggregateFunction.avg => 'AVG($quoted) AS "avg"',
      AggregateFunction.min => 'MIN($quoted) AS "min"',
      AggregateFunction.max => 'MAX($quoted) AS "max"',
    };
  }

  String _groupedAggregateExpression(AggregateDescriptor descriptor) {
    if (descriptor.function == AggregateFunction.sum) {
      final column = descriptor.column;
      if (column == null) {
        throw QueryException(
          query: 'SELECT SUM(…) FROM ${_quoteIdent(descriptor.table)}',
          message: 'grouped sum requires a column',
        );
      }
      return 'SUM(${_quoteIdent(column)}) AS "value"';
    }
    return 'COUNT(*) AS "value"';
  }

  List<Object?> _asList(Object? value) {
    if (value is List) return List<Object?>.from(value);
    throw QueryException(
      query: '',
      message: 'inList requires a List value, got ${value.runtimeType}',
    );
  }

  String _comparisonOperator(Operator operator) => switch (operator) {
    Operator.eq => '=',
    Operator.neq => '!=',
    Operator.gt => '>',
    Operator.gte => '>=',
    Operator.lt => '<',
    Operator.lte => '<=',
    _ => operator.name,
  };

  String _projection(List<String> columns) =>
      columns.isEmpty ? '*' : columns.map(_quotePath).join(', ');

  String _placeholder(List<Object?> params, Object? value) {
    params.add(value);
    return '?';
  }

  String _quoteIdent(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';

  String _quotePath(String column) =>
      column.split('.').map(_quoteIdent).join('.');

  String _qualified(String? tableName, String fieldName) =>
      (tableName == null || tableName.isEmpty)
      ? _quoteIdent(fieldName)
      : '${_quoteIdent(tableName)}.${_quoteIdent(fieldName)}';
}
