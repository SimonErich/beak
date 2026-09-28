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
    if (descriptor.tableAlias case final alias?) {
      sql.write(' AS ${_quoteIdent(alias)}');
    }
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

  /// Compile a [SchemaDescriptor] into one or more DDL statements.
  ///
  /// Returns a list because a create with non-unique indexes, and an alter
  /// with several steps, are each more than one statement. `sqlite3` needs
  /// them run individually, not joined.
  List<SqliteCompileResult> compileDdl(SchemaDescriptor descriptor) {
    final table = _quoteIdent(descriptor.table);
    return switch (descriptor.operation) {
      SchemaOperation.create => <SqliteCompileResult>[
        SqliteCompileResult(sql: _buildCreateTable(descriptor, table)),
        for (final index in descriptor.indexes)
          if (!index.unique)
            SqliteCompileResult(sql: _createIndexSql(index, table)),
      ],
      SchemaOperation.drop => <SqliteCompileResult>[
        SqliteCompileResult(
          sql: 'DROP TABLE ${descriptor.ifExists ? 'IF EXISTS ' : ''}$table',
        ),
      ],
      SchemaOperation.truncate => <SqliteCompileResult>[
        SqliteCompileResult(sql: 'DELETE FROM $table'),
      ],
      SchemaOperation.alter => _compileAlter(descriptor, table),
    };
  }

  /// The statements an alter compiles to, one per alteration.
  ///
  /// A foreign key over exactly one column the same alter adds is not a
  /// statement of its own: it becomes that column's inline `REFERENCES`
  /// clause. SQLite accepts a reference on `ADD COLUMN`; what it cannot do is
  /// attach a constraint to a column that already exists, which [_alterSql]
  /// still refuses.
  List<SqliteCompileResult> _compileAlter(
    SchemaDescriptor descriptor,
    String table,
  ) {
    final added = <String>{
      for (final alteration in descriptor.alterations)
        if (alteration case SchemaAddColumn(:final column)) column.name,
    };
    final references = <String, SchemaForeignKey>{
      for (final alteration in descriptor.alterations)
        if (alteration case SchemaAddForeignKey(:final foreignKey))
          if (foreignKey case SchemaForeignKey(
            columns: [final column],
            referencedColumns: [_],
          ) when added.contains(column))
            column: foreignKey,
    };
    return <SqliteCompileResult>[
      for (final alteration in descriptor.alterations)
        if (!_isInlined(alteration, references))
          SqliteCompileResult(
            sql: _alterSql(alteration, table, descriptor.table, references),
          ),
    ];
  }

  /// Whether [alteration] is a foreign key carried by the column it names.
  bool _isInlined(
    SchemaAlteration alteration,
    Map<String, SchemaForeignKey> references,
  ) => switch (alteration) {
    SchemaAddForeignKey(:final foreignKey) => references.values.any(
      (inlined) => identical(inlined, foreignKey),
    ),
    _ => false,
  };

  /// The SQL one alteration compiles to.
  ///
  /// SQLite's `ALTER TABLE` is deliberately minimal, and the honest response
  /// to the parts it lacks is to say so. Rebuilding the table behind the
  /// caller's back — the usual workaround — silently drops triggers, views,
  /// generated columns and custom collations that `introspectSchema` cannot
  /// see, so a migration that looked like it added a column would quietly
  /// destroy something else. A named refusal is better than a silent loss.
  ///
  /// [references] are the foreign keys [_compileAlter] folded into the
  /// columns they name, keyed by column.
  String _alterSql(
    SchemaAlteration alteration,
    String table,
    String rawTable,
    Map<String, SchemaForeignKey> references,
  ) {
    switch (alteration) {
      case SchemaAddColumn(:final column, :final ifNotExists):
        if (ifNotExists) {
          throw _unsupported(
            'alter.addColumn.ifNotExists',
            'SQLite has no ADD COLUMN IF NOT EXISTS. Drop the flag, or '
                'guard the migration on introspectSchema.',
          );
        }
        if (column.isPrimaryKey || column.unique) {
          throw _unsupported(
            'alter.addColumn',
            'SQLite cannot add a PRIMARY KEY or UNIQUE column to an existing '
                'table. Add the column, then CREATE UNIQUE INDEX over it.',
          );
        }
        if (!column.nullable && column.defaultValue == null) {
          throw _unsupported(
            'alter.addColumn',
            'SQLite cannot add a NOT NULL column without a default — the '
                'existing rows would have no value. Give it a default, or '
                'make it nullable.',
          );
        }
        final definition = _columnDefinition(column);
        final reference = references[column.name];
        if (reference == null) {
          return 'ALTER TABLE $table ADD COLUMN $definition';
        }
        if (column.defaultValue != null) {
          throw _unsupported(
            'alter.addColumn.foreignKey',
            'SQLite can only add a referencing column with a default of '
                'NULL — every existing row would point at the default. Drop '
                'the default of "${column.name}", or backfill it in a later '
                'migration.',
          );
        }
        return 'ALTER TABLE $table ADD COLUMN $definition '
            '${_references(reference)}';
      case SchemaDropColumn(:final column, :final ifExists):
        if (ifExists) {
          throw _unsupported(
            'alter.dropColumn.ifExists',
            'SQLite has no DROP COLUMN IF EXISTS.',
          );
        }
        return 'ALTER TABLE $table DROP COLUMN ${_quoteIdent(column)}';
      case SchemaChangeColumn(:final column):
        throw _unsupported(
          'alter.changeColumn',
          'SQLite cannot alter the type, nullability or default of an '
              'existing column ("${column.name}" of "$rawTable"). Rebuild the '
              'table with adapter.rawExecute, or point DATABASE_URL at '
              'Postgres.',
        );
      case SchemaAddIndex(:final index, :final ifNotExists):
        return _createIndexSql(index, table, ifNotExists: ifNotExists);
      case SchemaDropIndex(:final name, :final ifExists):
        return 'DROP INDEX ${ifExists ? 'IF EXISTS ' : ''}${_quoteIdent(name)}';
      case SchemaAddForeignKey():
      case SchemaDropForeignKey():
        throw _unsupported(
          'alter.foreignKey',
          'SQLite cannot add or drop a foreign key on an existing column; a '
              'constraint can only be declared in CREATE TABLE, or as the '
              'reference of a single column added in the same alter. Rebuild '
              'the table with adapter.rawExecute, or point DATABASE_URL at '
              'Postgres.',
        );
    }
  }

  UnsupportedOperationException _unsupported(
    String operation,
    String message,
  ) => UnsupportedOperationException(
    operation: operation,
    adapter: 'SqliteAdapter',
    message: message,
  );

  /// The `CREATE INDEX` statement for [index].
  String _createIndexSql(
    SchemaIndex index,
    String table, {
    bool ifNotExists = false,
  }) {
    if (index.kind != IndexKind.btree) {
      throw _unsupported(
        'createIndex.kind',
        'SQLite has only b-tree indexes; it cannot build a '
            '${index.kind.name} index.',
      );
    }
    final columns = index.columns.map(_quoteIdent).join(', ');
    final buffer = StringBuffer('CREATE ')
      ..write(index.unique ? 'UNIQUE INDEX ' : 'INDEX ')
      ..write(ifNotExists ? 'IF NOT EXISTS ' : '')
      ..write('${_quoteIdent(index.name)} ON $table ($columns)');
    if (index.where case final String predicate) {
      buffer.write(' WHERE $predicate');
    }
    return buffer.toString();
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
    return _references(key, prefix: 'FOREIGN KEY ($locals) ');
  }

  /// The optionally named `REFERENCES … ON DELETE …` clause of [key], with
  /// [prefix] between the name and the reference.
  ///
  /// Shared by the table constraint and the inline column reference, so the
  /// two spellings of one foreign key cannot drift apart.
  String _references(SchemaForeignKey key, {String prefix = ''}) {
    final remotes = key.referencedColumns.map(_quoteIdent).join(', ');
    final buffer = StringBuffer();
    if (key.name case final String name) {
      buffer.write('CONSTRAINT ${_quoteIdent(name)} ');
    }
    buffer
      ..write(prefix)
      ..write('REFERENCES ${_quoteIdent(key.referencedTable)} ($remotes)')
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
    if (column.defaultValue case final Object value) {
      buffer
        ..write(' DEFAULT ')
        ..write(_renderDefault(value));
    }
    return buffer.toString();
  }

  /// [value] as a SQLite literal.
  ///
  /// Booleans render as `1`/`0` rather than `TRUE`/`FALSE`: SQLite has no
  /// boolean storage class, and the runner binds a Dart `true` as `1`, so a
  /// `TRUE` keyword default would put a different value in the column than an
  /// explicit write of the same Dart value.
  String _renderDefault(Object value) => switch (value) {
    final String s => "'${s.replaceAll("'", "''")}'",
    final bool b => b ? '1' : '0',
    final num n => n.toString(),
    _ => "'$value'",
  };

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
