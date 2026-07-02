/// Pure, stateless compiler from worm descriptors to Postgres SQL.
library;

import 'package:worm/worm.dart';

import 'postgres_compile_result.dart';

/// Maximum number of values allowed in a single PostgreSQL `IN`
/// list. Longer lists are auto-chunked and combined with `OR` (for
/// [Operator.inList]) or `AND` (for [Operator.notInList]).
const int kInListChunkSize = 1000;

/// Translates immutable worm descriptors into parameterised
/// Postgres SQL strings.
///
/// Every compile method accepts an immutable descriptor and returns
/// a [PostgresCompileResult] pairing the SQL with the positional
/// parameter list. The compiler performs no I/O, keeps no state,
/// and has no database dependency — it is purely functional and
/// safe to reuse as a `const` instance.
final class PostgresCompiler {
  /// Creates a const compiler.
  const PostgresCompiler();

  /// Compile a [QueryDescriptor] into a `SELECT` statement.
  PostgresCompileResult compileSelect(QueryDescriptor descriptor) {
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
    return _result(sql, params);
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
              '${c.expression} ${_havingOp(c.operator)} '
              '${_placeholder(params, c.value)}',
        )
        .join(' AND ');
    sql
      ..write(' HAVING ')
      ..write(parts);
  }

  /// Quote a possibly-qualified column path (`posts.user_id`) by
  /// quoting each dot-separated identifier.
  String _quotePath(String column) =>
      column.split('.').map(_quoteIdent).join('.');

  String _havingOp(Operator op) => switch (op) {
    Operator.eq => '=',
    Operator.neq => '!=',
    Operator.gt => '>',
    Operator.gte => '>=',
    Operator.lt => '<',
    Operator.lte => '<=',
    _ => op.name,
  };

  /// Compile an [InsertDescriptor] into an `INSERT` statement.
  PostgresCompileResult compileInsert(InsertDescriptor descriptor) {
    if (descriptor.values.isEmpty) {
      throw QueryException(
        query: 'INSERT INTO "${descriptor.table}"',
        message: 'compileInsert requires at least one column value',
      );
    }
    final params = <Object?>[];
    final columns = descriptor.values.keys.toList(growable: false);
    final sql = StringBuffer('INSERT INTO ')
      ..write(_quoteIdent(descriptor.table))
      ..write(' (')
      ..write(columns.map(_quoteIdent).join(', '))
      ..write(') VALUES (')
      ..write(
        columns
            .map((c) => _placeholder(params, descriptor.values[c]))
            .join(', '),
      )
      ..write(')');
    _appendReturning(sql, descriptor.returning);
    return _result(sql, params);
  }

  /// Compile an [InsertManyDescriptor] into a bulk `INSERT`.
  ///
  /// Throws [QueryException] when [InsertManyDescriptor.rows] is
  /// empty — a bulk insert with no rows is never a valid statement.
  PostgresCompileResult compileInsertMany(InsertManyDescriptor descriptor) {
    if (descriptor.rows.isEmpty) {
      throw QueryException(
        query: 'INSERT INTO "${descriptor.table}"',
        message: 'compileInsertMany requires at least one row',
      );
    }
    final columns = descriptor.rows.first.keys.toList(growable: false);
    final params = <Object?>[];
    final tuples = <String>[];
    for (final row in descriptor.rows) {
      final placeholders = columns
          .map((c) => _placeholder(params, row[c]))
          .join(', ');
      tuples.add('($placeholders)');
    }
    final sql = StringBuffer('INSERT INTO ')
      ..write(_quoteIdent(descriptor.table))
      ..write(' (')
      ..write(columns.map(_quoteIdent).join(', '))
      ..write(') VALUES ')
      ..write(tuples.join(', '));
    _appendReturning(sql, descriptor.returning);
    return _result(sql, params);
  }

  /// Compile an [UpdateDescriptor] into an `UPDATE` statement.
  PostgresCompileResult compileUpdate(UpdateDescriptor descriptor) {
    if (descriptor.values.isEmpty) {
      throw QueryException(
        query: 'UPDATE "${descriptor.table}"',
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
    return _result(sql, params);
  }

  /// Compile a [DeleteDescriptor] into a `DELETE` statement.
  PostgresCompileResult compileDelete(DeleteDescriptor descriptor) {
    final params = <Object?>[];
    final sql = StringBuffer('DELETE FROM ')
      ..write(_quoteIdent(descriptor.table));
    _appendWhere(sql, descriptor.where, params);
    return _result(sql, params);
  }

  /// Compile an [AggregateDescriptor] into a `SELECT <agg>(...)`.
  PostgresCompileResult compileAggregate(AggregateDescriptor descriptor) {
    final params = <Object?>[];
    final expression = _aggregateExpression(descriptor);
    final sql = StringBuffer('SELECT ')
      ..write(expression)
      ..write(' FROM ')
      ..write(_quoteIdent(descriptor.table));
    _appendWhere(sql, descriptor.where, params);
    return _result(sql, params);
  }

  /// Compile a grouped aggregate of the form
  /// `SELECT group AS "group", COUNT(*)/SUM(col) AS "value" FROM table`
  /// `WHERE … GROUP BY group`.
  PostgresCompileResult compileGroupedAggregate(
    AggregateDescriptor descriptor,
  ) {
    final group = descriptor.groupBy;
    if (group == null) {
      throw QueryException(
        query: 'SELECT … FROM "${descriptor.table}"',
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
    return _result(sql, params);
  }

  String _groupedAggregateExpression(AggregateDescriptor descriptor) {
    if (descriptor.function == AggregateFunction.sum) {
      final column = descriptor.column;
      if (column == null) {
        throw QueryException(
          query: 'SELECT SUM(…) FROM "${descriptor.table}"',
          message: 'grouped sum requires a column',
        );
      }
      return 'SUM(${_quoteIdent(column)}) AS "value"';
    }
    return 'COUNT(*) AS "value"';
  }

  /// Compile a [SchemaDescriptor] into DDL.
  ///
  /// For [SchemaOperation.create], the descriptor's [SchemaColumn]
  /// entries supply names and [ColumnType]s, which map onto
  /// PostgreSQL native types via [pgTypeOf].
  PostgresCompileResult compileDdl(SchemaDescriptor descriptor) {
    if (descriptor is SchemaIndexDescriptor) {
      final unique = descriptor.unique ? 'UNIQUE ' : '';
      final col = _quoteIdent(descriptor.collection);
      final field = _quoteIdent(descriptor.field);
      return PostgresCompileResult(
        sql: 'CREATE ${unique}INDEX ON $col ($field)',
        parameters: const <Object?>[],
      );
    }
    final table = _quoteIdent(descriptor.table);
    return switch (descriptor.operation) {
      SchemaOperation.create => PostgresCompileResult(
        sql: _buildCreateTable(descriptor, table),
        parameters: const <Object?>[],
      ),
      SchemaOperation.drop => PostgresCompileResult(
        sql:
            'DROP TABLE '
            '${descriptor.ifExists ? 'IF EXISTS ' : ''}'
            '$table',
        parameters: const <Object?>[],
      ),
      SchemaOperation.truncate => PostgresCompileResult(
        sql: 'TRUNCATE TABLE $table',
        parameters: const <Object?>[],
      ),
      SchemaOperation.alter => throw const QueryException(
        query: '',
        message:
            'compileDdl(SchemaOperation.alter) is not implemented '
            'in the V1 compiler',
      ),
      SchemaOperation.createIndex => throw const QueryException(
        query: '',
        message:
            'compileDdl(SchemaOperation.createIndex) requires a '
            'SchemaIndexDescriptor',
      ),
    };
  }

  /// Compile any supported descriptor and render it as a
  /// human-readable string with its parameter list.
  ///
  /// The output has the form:
  /// ```text
  /// <SQL>
  /// -- Params: [v1, v2, ...]
  /// ```
  ///
  /// Throws [QueryException] when [descriptor] is not a recognised
  /// descriptor type.
  String compileToString(Object descriptor) {
    final result = _compileAny(descriptor);
    return '${result.sql}\n-- Params: ${result.parameters}';
  }

  /// Map a logical [ColumnType] to its PostgreSQL type name.
  ///
  /// Exposed publicly so tests — and code generators — can iterate
  /// every [ColumnType] value and confirm the compiler produces a
  /// valid PostgreSQL type string for each.
  static String pgTypeOf(ColumnType type) => switch (type) {
    ColumnType.string => 'VARCHAR',
    ColumnType.smallInteger => 'SMALLINT',
    ColumnType.integer => 'INTEGER',
    ColumnType.bigInteger => 'BIGINT',
    ColumnType.decimal => 'NUMERIC',
    ColumnType.boolean => 'BOOLEAN',
    ColumnType.date => 'DATE',
    ColumnType.dateTime => 'TIMESTAMPTZ',
    ColumnType.uuid => 'UUID',
    ColumnType.json => 'JSON',
    ColumnType.jsonb => 'JSONB',
    ColumnType.text => 'TEXT',
    ColumnType.binary => 'BYTEA',
    ColumnType.doublePrecision => 'DOUBLE PRECISION',
    ColumnType.enumType => 'TEXT',
    ColumnType.tsvector => 'TSVECTOR',
    ColumnType.time => 'TIME',
    ColumnType.interval => 'INTERVAL',
    ColumnType.inet => 'INET',
    ColumnType.macaddr => 'MACADDR',
    ColumnType.point => 'POINT',
    ColumnType.line => 'LINE',
    ColumnType.box => 'BOX',
    ColumnType.money => 'MONEY',
    ColumnType.bit => 'BIT',
    ColumnType.xml => 'XML',
    ColumnType.array => 'TEXT[]',
  };

  PostgresCompileResult _compileAny(Object descriptor) => switch (descriptor) {
    final QueryDescriptor d => compileSelect(d),
    final InsertDescriptor d => compileInsert(d),
    final InsertManyDescriptor d => compileInsertMany(d),
    final UpdateDescriptor d => compileUpdate(d),
    final DeleteDescriptor d => compileDelete(d),
    final AggregateDescriptor d => compileAggregate(d),
    final SchemaDescriptor d => compileDdl(d),
    _ => throw const QueryException(
      query: '',
      message: 'Unsupported descriptor type',
    ),
  };

  String _buildCreateTable(SchemaDescriptor descriptor, String table) {
    final sql = StringBuffer('CREATE TABLE ');
    if (descriptor.ifNotExists) sql.write('IF NOT EXISTS ');
    sql
      ..write(table)
      ..write(' (');
    final parts = <String>[
      for (final column in descriptor.columns) _columnDefinition(column),
    ];
    sql
      ..write(parts.join(', '))
      ..write(')');
    return sql.toString();
  }

  String _columnDefinition(SchemaColumn column) {
    final type = pgTypeOf(column.type);
    final buffer = StringBuffer('${_quoteIdent(column.name)} $type');
    if (!column.nullable) buffer.write(' NOT NULL');
    if (column.isPrimaryKey) buffer.write(' PRIMARY KEY');
    final defaultValue = column.defaultValue;
    if (defaultValue != null) {
      buffer
        ..write(' DEFAULT ')
        ..write(_renderDefault(defaultValue));
    }
    return buffer.toString();
  }

  String _renderDefault(Object value) => switch (value) {
    final String s => "'${s.replaceAll("'", "''")}'",
    final num n => n.toString(),
    final bool b => b ? 'TRUE' : 'FALSE',
    _ => "'$value'",
  };

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

  String _projection(List<String> columns) {
    if (columns.isEmpty) return '*';
    return columns.map(_quoteIdent).join(', ');
  }

  void _appendWhere(
    StringBuffer sql,
    PredicateTree? where,
    List<Object?> params,
  ) {
    if (where == null) return;
    final fragment = _compileTree(where, params);
    sql
      ..write(' WHERE ')
      ..write(fragment);
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
    if (offset != null) sql.write(' OFFSET $offset');
  }

  void _appendReturning(StringBuffer sql, List<String>? returning) {
    if (returning == null) {
      sql.write(' RETURNING *');
      return;
    }
    if (returning.isEmpty) return;
    sql
      ..write(' RETURNING ')
      ..write(returning.map(_quoteIdent).join(', '));
  }

  String _compileTree(PredicateTree tree, List<Object?> params) =>
      switch (tree) {
        LeafNode(:final predicate) => _compilePredicate(predicate, params),
        AndNode(:final left, :final right) =>
          '${_compileTree(left, params)} AND ${_compileTree(right, params)}',
        OrNode(:final left, :final right) =>
          '${_compileTree(left, params)} OR ${_compileTree(right, params)}',
        NotNode(:final child) => 'NOT (${_compileTree(child, params)})',
        GroupNode(:final child) => '(${_compileTree(child, params)})',
        ExistsNode() => _compileExists(tree, params),
        ColumnNode() => _compileColumn(tree),
        RawNode() => _compileRaw(tree, params),
      };

  String _compileExists(ExistsNode node, List<Object?> params) {
    final keyword = node.negated ? 'NOT EXISTS' : 'EXISTS';
    final sub = StringBuffer('SELECT ');
    if (node.subquery.distinct) sub.write('DISTINCT ');
    sub
      ..write(_projection(node.subquery.columns))
      ..write(' FROM ')
      ..write(_quoteIdent(node.subquery.table));
    _appendWhere(sub, node.subquery.where, params);
    _appendOrderBy(sub, node.subquery.orderBy);
    _appendLimitOffset(sub, node.subquery.limit, node.subquery.offset);
    return '$keyword ($sub)';
  }

  String _compileColumn(ColumnNode node) {
    final left = _qualified(node.leftTable, node.leftField);
    final right = _qualified(node.rightTable, node.rightField);
    return switch (node.operator) {
      Operator.eq => '$left = $right',
      Operator.neq => '$left != $right',
      Operator.gt => '$left > $right',
      Operator.gte => '$left >= $right',
      Operator.lt => '$left < $right',
      Operator.lte => '$left <= $right',
      Operator.like => '$left LIKE $right',
      Operator.notLike => '$left NOT LIKE $right',
      Operator.ilike => '$left ILIKE $right',
      _ => throw QueryException(
        query: '',
        message:
            'ColumnNode does not support operator ${node.operator.name} '
            'for column-to-column comparison',
      ),
    };
  }

  String _compileRaw(RawNode node, List<Object?> params) {
    // RawNode SQL uses positional `?` placeholders so it stays
    // dialect-agnostic at the call site. Re-emit them as the
    // Postgres-style `$N` markers, allocating one outer parameter
    // slot per fragment placeholder in order.
    if (node.parameters.isEmpty) return node.sql;
    final buffer = StringBuffer();
    var paramIndex = 0;
    for (final char in node.sql.codeUnits) {
      if (char == 0x3F /* ? */ ) {
        if (paramIndex >= node.parameters.length) {
          throw QueryException(
            query: node.sql,
            message: 'Raw SQL has more ? placeholders than parameters',
          );
        }
        buffer.write(_placeholder(params, node.parameters[paramIndex++]));
      } else {
        buffer.writeCharCode(char);
      }
    }
    if (paramIndex < node.parameters.length) {
      throw QueryException(
        query: node.sql,
        message:
            'Raw SQL has fewer ? placeholders ($paramIndex) than parameters '
            '(${node.parameters.length})',
      );
    }
    return buffer.toString();
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
      Operator.like => '$column LIKE ${_placeholder(params, predicate.value)}',
      Operator.notLike =>
        '$column NOT LIKE ${_placeholder(params, predicate.value)}',
      Operator.ilike =>
        '$column ILIKE ${_placeholder(params, predicate.value)}',
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

  List<Object?> _asList(Object? value) {
    if (value is List) return List<Object?>.from(value);
    throw QueryException(
      query: '',
      message:
          'inList/notInList requires a List value, got ${value.runtimeType}',
    );
  }

  String _compileInList(
    String column,
    List<Object?> items,
    List<Object?> params, {
    required bool negate,
  }) {
    final keyword = negate ? 'NOT IN' : 'IN';
    final connector = negate ? ' AND ' : ' OR ';
    if (items.isEmpty) return negate ? 'TRUE' : 'FALSE';
    if (items.length <= kInListChunkSize) {
      final placeholders = items.map((v) => _placeholder(params, v)).join(', ');
      return '$column $keyword ($placeholders)';
    }
    final chunks = <String>[];
    for (var i = 0; i < items.length; i += kInListChunkSize) {
      final end = i + kInListChunkSize < items.length
          ? i + kInListChunkSize
          : items.length;
      final chunk = items.sublist(i, end);
      final placeholders = chunk.map((v) => _placeholder(params, v)).join(', ');
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
    final keyword = negate ? 'NOT BETWEEN' : 'BETWEEN';
    return '$column $keyword $low AND $high';
  }

  (Object?, Object?) _extractBounds(Object? bounds) {
    if (bounds is (Object?, Object?)) return bounds;
    if (bounds is List && bounds.length == 2) {
      return (bounds[0], bounds[1]);
    }
    throw QueryException(
      query: '',
      message:
          'between/notBetween requires a record or 2-element list, '
          'got ${bounds.runtimeType}',
    );
  }

  String _placeholder(List<Object?> params, Object? value) {
    params.add(value);
    return '\$${params.length}';
  }

  String _quoteIdent(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';

  String _qualified(String? tableName, String fieldName) {
    if (tableName == null || tableName.isEmpty) return _quoteIdent(fieldName);
    return '${_quoteIdent(tableName)}.${_quoteIdent(fieldName)}';
  }

  PostgresCompileResult _result(StringBuffer sql, List<Object?> params) =>
      PostgresCompileResult(
        sql: sql.toString(),
        parameters: List<Object?>.unmodifiable(params),
      );
}
