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
    if (descriptor.tableAlias case final alias?) {
      sql.write(' AS ${_quoteIdent(alias)}');
    }
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

  /// Compile a [SchemaDescriptor] into one or more DDL statements.
  ///
  /// Returns a list because a single descriptor legitimately needs several
  /// statements: a `CREATE TABLE` with two non-unique indexes is three, and
  /// an alter is one per step. Joining them with `;` is not an option —
  /// `package:postgres` rejects a multi-statement string on the extended
  /// protocol.
  ///
  /// Statements are returned in dependency order and must be executed in it.
  List<PostgresCompileResult> compileDdl(SchemaDescriptor descriptor) {
    final table = _quoteIdent(descriptor.table);
    return switch (descriptor.operation) {
      SchemaOperation.create => <PostgresCompileResult>[
        _statement(_buildCreateTable(descriptor, table)),
        // A unique index is already an inline table constraint; only the
        // plain ones need their own statement.
        for (final index in descriptor.indexes)
          if (!index.unique) _statement(_createIndexSql(index, table)),
      ],
      SchemaOperation.drop => <PostgresCompileResult>[
        _statement(
          'DROP TABLE ${descriptor.ifExists ? 'IF EXISTS ' : ''}$table',
        ),
      ],
      SchemaOperation.truncate => <PostgresCompileResult>[
        _statement('TRUNCATE TABLE $table'),
      ],
      SchemaOperation.alter => <PostgresCompileResult>[
        for (final alteration in descriptor.alterations)
          _statement(_alterSql(alteration, table)),
      ],
    };
  }

  PostgresCompileResult _statement(String sql) =>
      PostgresCompileResult(sql: sql, parameters: const <Object?>[]);

  /// The SQL one alteration compiles to.
  ///
  /// Postgres expresses every step this union can describe, so there is no
  /// unsupported arm here — the exhaustive switch is what guarantees a future
  /// variant cannot be added without a decision being made in this file.
  String _alterSql(SchemaAlteration alteration, String table) =>
      switch (alteration) {
        SchemaAddColumn(:final column, :final ifNotExists) =>
          'ALTER TABLE $table ADD COLUMN '
              '${ifNotExists ? 'IF NOT EXISTS ' : ''}'
              '${_columnDefinition(column)}',
        SchemaDropColumn(:final column, :final ifExists) =>
          'ALTER TABLE $table DROP COLUMN '
              '${ifExists ? 'IF EXISTS ' : ''}${_quoteIdent(column)}',
        SchemaChangeColumn() => _changeColumnSql(alteration, table),
        SchemaAddIndex(:final index, :final ifNotExists) => _createIndexSql(
          index,
          table,
          ifNotExists: ifNotExists,
        ),
        SchemaDropIndex(:final name, :final ifExists) =>
          'DROP INDEX ${ifExists ? 'IF EXISTS ' : ''}${_quoteIdent(name)}',
        SchemaAddForeignKey(:final foreignKey) =>
          'ALTER TABLE $table ADD ${_foreignKeyConstraint(foreignKey)}',
        SchemaDropForeignKey(:final name) =>
          'ALTER TABLE $table DROP CONSTRAINT ${_quoteIdent(name)}',
      };

  /// One `ALTER TABLE` per requested facet, joined into one statement.
  ///
  /// Postgres alters type, nullability and default independently, so a change
  /// that only relaxes `NOT NULL` does not restate — and therefore cannot
  /// accidentally rewrite — the column's type or default.
  String _changeColumnSql(SchemaChangeColumn change, String table) {
    final column = change.column;
    final name = _quoteIdent(column.name);
    final clauses = <String>[
      if (change.facets.contains(SchemaColumnFacet.type))
        _typeClause(name, column, change.using),
      if (change.facets.contains(SchemaColumnFacet.nullability))
        'ALTER COLUMN $name ${column.nullable ? 'DROP' : 'SET'} NOT NULL',
      if (change.facets.contains(SchemaColumnFacet.defaultValue))
        if (column.defaultValue case final Object value)
          'ALTER COLUMN $name SET DEFAULT ${_renderDefault(value)}'
        else
          'ALTER COLUMN $name DROP DEFAULT',
    ];
    return 'ALTER TABLE $table ${clauses.join(', ')}';
  }

  /// The `CREATE INDEX` statement for [index].
  ///
  /// Emitting this at all is the point: a non-unique index used to be dropped
  /// on the floor, so every foreign key and every sortable column in every
  /// schema was unindexed.
  String _createIndexSql(
    SchemaIndex index,
    String table, {
    bool ifNotExists = false,
  }) {
    final columns = index.columns.map(_quoteIdent).join(', ');
    final buffer = StringBuffer('CREATE ')
      ..write(index.unique ? 'UNIQUE INDEX ' : 'INDEX ')
      ..write(ifNotExists ? 'IF NOT EXISTS ' : '')
      ..write('${_quoteIdent(index.name)} ON $table ');
    if (index.kind != IndexKind.btree) {
      buffer.write('USING ${index.kind.name} ');
    }
    buffer.write('($columns)');
    if (index.where case final String predicate) {
      buffer.write(' WHERE $predicate');
    }
    return buffer.toString();
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
    // A schema descriptor can be several statements; compileToString is a
    // debug rendering, so joining them is the right shape there and only
    // there.
    final SchemaDescriptor d => PostgresCompileResult(
      sql: [for (final compiled in compileDdl(d)) compiled.sql].join(';\n'),
      parameters: const <Object?>[],
    ),
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
      // Unique indexes and foreign keys become table constraints rather than
      // separate statements, so the table is correct the moment it exists —
      // a row inserted between CREATE TABLE and a follow-up ALTER could
      // otherwise violate a constraint the schema claims to enforce.
      for (final index in descriptor.indexes)
        if (index.unique) _uniqueConstraint(index),
      for (final key in descriptor.foreignKeys) _foreignKeyConstraint(key),
    ];
    sql
      ..write(parts.join(', '))
      ..write(')');
    return sql.toString();
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

  /// The rendered type of [column], including the sizing it declared.
  ///
  /// `pgTypeOf` maps the kind; this adds what the builder recorded about it.
  /// Without it a `VARCHAR(120)` reaches the database as a bare `VARCHAR` and
  /// a `DECIMAL(10,2)` as an unconstrained `NUMERIC` — the length was
  /// declared, carried, and then dropped one step short of the wire.
  String _columnTypeSql(SchemaColumn column) {
    if (column.autoIncrement) {
      return switch (column.type) {
        ColumnType.smallInteger => 'SMALLSERIAL',
        ColumnType.bigInteger => 'BIGSERIAL',
        _ => 'SERIAL',
      };
    }
    final base = pgTypeOf(column.type);
    return switch (column.type) {
      ColumnType.string when column.length != null => '$base(${column.length})',
      ColumnType.decimal when column.precision != null => _decimalType(
        base,
        column,
      ),
      ColumnType.array when column.elementType != null =>
        '${pgTypeOf(column.elementType!)}[]',
      _ => base,
    };
  }

  /// The `ALTER COLUMN … TYPE` clause, with its optional cast expression.
  String _typeClause(String name, SchemaColumn column, String? using) {
    final cast = using == null ? '' : ' USING $using';
    return 'ALTER COLUMN $name TYPE ${_columnTypeSql(column)}$cast';
  }

  /// `NUMERIC(10, 2)` — the scale is omitted when the column declares none.
  String _decimalType(String base, SchemaColumn column) {
    final scale = column.scale == null ? '' : ', ${column.scale}';
    return '$base(${column.precision}$scale)';
  }

  String _columnDefinition(SchemaColumn column) {
    final type = _columnTypeSql(column);
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
    if (node.subquery.tableAlias case final alias?) {
      sub.write(' AS ${_quoteIdent(alias)}');
    }
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
