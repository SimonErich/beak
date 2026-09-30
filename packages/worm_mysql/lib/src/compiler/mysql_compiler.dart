/// Pure, stateless compiler from worm descriptors to MySQL SQL.
library;

import 'package:worm/worm.dart';

import 'mysql_compile_result.dart';

/// Maximum number of values allowed in a single MySQL `IN` list before
/// the compiler chunks it. MySQL's hard ceiling is the 65 535
/// placeholders permitted per prepared statement; chunking well under
/// that keeps statements valid and plans sane. Longer lists are split
/// and combined with `OR` ([Operator.inList]) or `AND`
/// ([Operator.notInList]).
const int kMysqlInListChunkSize = 1000;

/// Translates immutable worm descriptors into parameterised MySQL SQL
/// strings.
///
/// Modelled on the PostgreSQL compiler but emits the MySQL dialect:
///
/// * identifiers are backtick-quoted (`` `name` ``) with embedded
///   backticks doubled;
/// * placeholders are positional `?` markers (bound via server-side
///   prepared statements), not `$N`;
/// * MySQL has no `RETURNING`, so inserts emit no returning clause —
///   the adapter materialises the row from the supplied values plus
///   `LAST_INSERT_ID()`;
/// * `ILIKE` is emulated with `LOWER(col) LIKE LOWER(?)`;
/// * `OFFSET` requires a `LIMIT`, integer primary keys are
///   `AUTO_INCREMENT`, and tables are created `ENGINE=InnoDB
///   DEFAULT CHARSET=utf8mb4`.
///
/// Every compile method accepts an immutable descriptor and returns a
/// [MysqlCompileResult] pairing the SQL with the positional parameter
/// list. The compiler performs no I/O, keeps no state, and is safe to
/// reuse as a `const` instance.
final class MysqlCompiler {
  /// Creates a const compiler.
  const MysqlCompiler();

  /// Compile a [QueryDescriptor] into a `SELECT` statement.
  MysqlCompileResult compileSelect(QueryDescriptor descriptor) {
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

  /// Compiles a current single-row read, bypassing an InnoDB snapshot and
  /// retaining update locks until the current transaction completes.
  MysqlCompileResult compileCurrentSelect(QueryDescriptor descriptor) {
    final compiled = compileSelect(descriptor.copyWith(limit: 1));
    return MysqlCompileResult(
      sql: '${compiled.sql} FOR UPDATE',
      parameters: compiled.parameters,
    );
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

  /// Compile an [InsertDescriptor] into an `INSERT` statement.
  ///
  /// No `RETURNING` is emitted — MySQL does not support it. The
  /// adapter reconstructs the inserted row from [InsertDescriptor.values]
  /// and the generated key.
  MysqlCompileResult compileInsert(InsertDescriptor descriptor) {
    if (descriptor.values.isEmpty) {
      throw QueryException(
        query: 'INSERT INTO `${descriptor.table}`',
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
    return _result(sql, params);
  }

  /// Compile an [InsertManyDescriptor] into a single bulk `INSERT`.
  ///
  /// Throws [QueryException] when [InsertManyDescriptor.rows] is empty.
  MysqlCompileResult compileInsertMany(InsertManyDescriptor descriptor) {
    if (descriptor.rows.isEmpty) {
      throw QueryException(
        query: 'INSERT INTO `${descriptor.table}`',
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
    return _result(sql, params);
  }

  /// Compile an [UpdateDescriptor] into an `UPDATE` statement.
  MysqlCompileResult compileUpdate(UpdateDescriptor descriptor) {
    if (descriptor.values.isEmpty) {
      throw QueryException(
        query: 'UPDATE `${descriptor.table}`',
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
  MysqlCompileResult compileDelete(DeleteDescriptor descriptor) {
    final params = <Object?>[];
    final sql = StringBuffer('DELETE FROM ')
      ..write(_quoteIdent(descriptor.table));
    _appendWhere(sql, descriptor.where, params);
    return _result(sql, params);
  }

  /// Compile a scalar [AggregateDescriptor] into a `SELECT <agg>(...)`.
  MysqlCompileResult compileAggregate(AggregateDescriptor descriptor) {
    final params = <Object?>[];
    final sql = StringBuffer('SELECT ')
      ..write(_aggregateExpression(descriptor))
      ..write(' FROM ')
      ..write(_quoteIdent(descriptor.table));
    _appendWhere(sql, descriptor.where, params);
    return _result(sql, params);
  }

  /// Compile a grouped aggregate of the form
  /// `` SELECT group AS `group`, COUNT(*)/SUM(col) AS `value` ``
  /// `` FROM table WHERE … GROUP BY group ``.
  MysqlCompileResult compileGroupedAggregate(AggregateDescriptor descriptor) {
    final group = descriptor.groupBy;
    if (group == null) {
      throw QueryException(
        query: 'SELECT … FROM `${descriptor.table}`',
        message: 'compileGroupedAggregate requires a groupBy column',
      );
    }
    final params = <Object?>[];
    final groupCol = _quoteIdent(group);
    final sql = StringBuffer('SELECT ')
      ..write(groupCol)
      ..write(' AS `group`, ')
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
          query: 'SELECT SUM(…) FROM `${descriptor.table}`',
          message: 'grouped sum requires a column',
        );
      }
      return 'SUM(${_quoteIdent(column)}) AS `value`';
    }
    return 'COUNT(*) AS `value`';
  }

  /// Compile a [SchemaDescriptor] into one or more DDL statements.
  ///
  /// Returns a list because a create with non-unique indexes, and an alter
  /// with several steps, are each more than one statement — and the MySQL
  /// client rejects a multi-statement string by default.
  List<MysqlCompileResult> compileDdl(SchemaDescriptor descriptor) {
    final table = _quoteIdent(descriptor.table);
    return switch (descriptor.operation) {
      SchemaOperation.create => <MysqlCompileResult>[
        MysqlCompileResult(sql: _buildCreateTable(descriptor, table)),
        for (final index in descriptor.indexes)
          if (!index.unique)
            MysqlCompileResult(sql: _createIndexSql(index, table)),
      ],
      SchemaOperation.drop => <MysqlCompileResult>[
        MysqlCompileResult(
          sql: 'DROP TABLE ${descriptor.ifExists ? 'IF EXISTS ' : ''}$table',
        ),
      ],
      SchemaOperation.truncate => <MysqlCompileResult>[
        MysqlCompileResult(sql: 'TRUNCATE TABLE $table'),
      ],
      SchemaOperation.alter => <MysqlCompileResult>[
        for (final alteration in descriptor.alterations)
          MysqlCompileResult(sql: _alterSql(alteration, table)),
      ],
    };
  }

  /// The SQL one alteration compiles to.
  ///
  /// MySQL lacks `IF [NOT] EXISTS` on every DDL clause here (MariaDB has
  /// them; MySQL does not). A request carrying one is refused rather than
  /// silently stripped — quietly ignoring a flag is how a non-unique index
  /// came to emit nothing at all.
  String _alterSql(SchemaAlteration alteration, String table) {
    switch (alteration) {
      case SchemaAddColumn(:final column, :final ifNotExists):
        if (ifNotExists) {
          throw _unsupported(
            'alter.addColumn.ifNotExists',
            'MySQL has no ADD COLUMN IF NOT EXISTS.',
          );
        }
        return 'ALTER TABLE $table ADD COLUMN ${_columnDefinition(column)}';
      case SchemaDropColumn(:final column, :final ifExists):
        if (ifExists) {
          throw _unsupported(
            'alter.dropColumn.ifExists',
            'MySQL has no DROP COLUMN IF EXISTS.',
          );
        }
        return 'ALTER TABLE $table DROP COLUMN ${_quoteIdent(column)}';
      // MODIFY COLUMN has no partial form, so the facet set is ignored here
      // by design — which is why SchemaChangeColumn.column is a complete end
      // state rather than a delta.
      case SchemaChangeColumn(:final column):
        return 'ALTER TABLE $table MODIFY COLUMN ${_columnDefinition(column)}';
      case SchemaAddIndex(:final index, :final ifNotExists):
        if (ifNotExists) {
          throw _unsupported(
            'createIndex.ifNotExists',
            'MySQL has no CREATE INDEX IF NOT EXISTS.',
          );
        }
        return _createIndexSql(index, table);
      case SchemaDropIndex(:final name, :final ifExists):
        if (ifExists) {
          throw _unsupported(
            'dropIndex.ifExists',
            'MySQL has no DROP INDEX IF EXISTS.',
          );
        }
        return 'DROP INDEX ${_quoteIdent(name)} ON $table';
      case SchemaAddForeignKey(:final foreignKey):
        return 'ALTER TABLE $table ADD ${_foreignKeyConstraint(foreignKey)}';
      // DROP FOREIGN KEY, not DROP CONSTRAINT: the latter is 8.0.19+ only.
      case SchemaDropForeignKey(:final name):
        return 'ALTER TABLE $table DROP FOREIGN KEY ${_quoteIdent(name)}';
    }
  }

  UnsupportedOperationException _unsupported(
    String operation,
    String message,
  ) => UnsupportedOperationException(
    operation: operation,
    adapter: 'MysqlAdapter',
    message: message,
  );

  /// The `CREATE INDEX` statement for [index].
  String _createIndexSql(SchemaIndex index, String table) {
    if (index.kind != IndexKind.btree) {
      throw _unsupported(
        'createIndex.kind',
        'InnoDB builds a b-tree regardless of the requested '
            '${index.kind.name} index, so the request cannot be honoured.',
      );
    }
    if (index.where != null) {
      throw _unsupported('createIndex.where', 'MySQL has no partial indexes.');
    }
    final columns = index.columns.map(_quoteIdent).join(', ');
    final unique = index.unique ? 'UNIQUE ' : '';
    return 'CREATE ${unique}INDEX ${_quoteIdent(index.name)} ON $table '
        '($columns)';
  }

  /// Compile any supported descriptor and render it as a human-readable
  /// string with its parameter list.
  String compileToString(Object descriptor) {
    final result = _compileAny(descriptor);
    return '${result.sql}\n-- Params: ${result.parameters}';
  }

  /// Map a logical [ColumnType] to its MySQL type name.
  ///
  /// Exposed publicly so tests and code generators can iterate every
  /// [ColumnType] value and confirm a valid MySQL type is produced.
  /// PostgreSQL-only types fall back to the nearest MySQL equivalent or
  /// a portable container type (`TEXT`/`JSON`).
  static String mysqlTypeOf(ColumnType type) => switch (type) {
    ColumnType.string => 'VARCHAR(255)',
    ColumnType.smallInteger => 'SMALLINT',
    ColumnType.integer => 'INT',
    ColumnType.bigInteger => 'BIGINT',
    ColumnType.decimal => 'DECIMAL(38,10)',
    ColumnType.boolean => 'TINYINT(1)',
    ColumnType.date => 'DATE',
    ColumnType.dateTime => 'DATETIME(6)',
    ColumnType.uuid => 'CHAR(36)',
    ColumnType.json => 'JSON',
    ColumnType.jsonb => 'JSON',
    ColumnType.text => 'TEXT',
    ColumnType.binary => 'BLOB',
    ColumnType.doublePrecision => 'DOUBLE',
    ColumnType.enumType => 'VARCHAR(255)',
    ColumnType.tsvector => 'TEXT',
    ColumnType.time => 'TIME(6)',
    ColumnType.interval => 'VARCHAR(64)',
    ColumnType.inet => 'VARCHAR(45)',
    ColumnType.macaddr => 'VARCHAR(17)',
    ColumnType.point => 'POINT',
    ColumnType.line => 'TEXT',
    ColumnType.box => 'TEXT',
    ColumnType.money => 'DECIMAL(19,4)',
    ColumnType.bit => 'BIT(64)',
    ColumnType.xml => 'TEXT',
    ColumnType.array => 'JSON',
  };

  /// Logical integer column types eligible for `AUTO_INCREMENT` when
  /// they are the primary key.
  static const Set<ColumnType> _autoIncrementTypes = <ColumnType>{
    ColumnType.smallInteger,
    ColumnType.integer,
    ColumnType.bigInteger,
  };

  MysqlCompileResult _compileAny(Object descriptor) => switch (descriptor) {
    final QueryDescriptor d => compileSelect(d),
    final InsertDescriptor d => compileInsert(d),
    final InsertManyDescriptor d => compileInsertMany(d),
    final UpdateDescriptor d => compileUpdate(d),
    final DeleteDescriptor d => compileDelete(d),
    final AggregateDescriptor d => compileAggregate(d),
    // A schema descriptor can be several statements; this is a debug
    // rendering, so joining them is right here and only here.
    final SchemaDescriptor d => MysqlCompileResult(
      sql: [for (final compiled in compileDdl(d)) compiled.sql].join(';\n'),
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
      // separate statements, so the table is correct the moment it exists.
      for (final index in descriptor.indexes)
        if (index.unique) _uniqueConstraint(index),
      for (final key in descriptor.foreignKeys) _foreignKeyConstraint(key),
    ];
    sql
      ..write(parts.join(', '))
      // InnoDB for transactions + foreign keys; utf8mb4 for full
      // Unicode (including 4-byte characters / emoji).
      ..write(') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');
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
  /// `mysqlTypeOf` maps the kind and has to pick a default width; this uses
  /// what the builder actually recorded, so a `VARCHAR(40)` does not arrive
  /// as `VARCHAR(255)` and a `DECIMAL(10,2)` not as `DECIMAL(38,10)`.
  String _columnTypeSql(SchemaColumn column) => switch (column.type) {
    ColumnType.string when column.length != null => 'VARCHAR(${column.length})',
    ColumnType.decimal when column.precision != null =>
      'DECIMAL(${column.precision},${column.scale ?? 0})',
    ColumnType.bit when column.length != null => 'BIT(${column.length})',
    _ => mysqlTypeOf(column.type),
  };

  String _columnDefinition(SchemaColumn column) {
    final type = _columnTypeSql(column);
    final buffer = StringBuffer('${_quoteIdent(column.name)} $type');
    if (!column.nullable) buffer.write(' NOT NULL');
    final defaultValue = column.defaultValue;
    if (defaultValue != null) {
      buffer
        ..write(' DEFAULT ')
        ..write(_renderDefault(defaultValue));
    }
    // The descriptor decides, not the shape of the column: `idIncrements()`
    // sets `autoIncrement`, and a plain integer primary key the caller
    // supplies values for does not. The two guards stay because MySQL
    // rejects the DDL outright otherwise — an AUTO_INCREMENT column must be
    // a key, and must hold an integer.
    if (column.autoIncrement &&
        column.isPrimaryKey &&
        _autoIncrementTypes.contains(column.type)) {
      buffer.write(' AUTO_INCREMENT');
    }
    if (column.isPrimaryKey) buffer.write(' PRIMARY KEY');
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
      return 'COUNT(*) AS `count`';
    }
    final column = descriptor.column;
    if (column == null) {
      throw QueryException(
        query: 'SELECT ${function.name} FROM `${descriptor.table}`',
        message: '${function.name} requires a column',
      );
    }
    final quoted = _quoteIdent(column);
    return switch (function) {
      AggregateFunction.count => 'COUNT($quoted) AS `count`',
      AggregateFunction.sum => 'SUM($quoted) AS `sum`',
      AggregateFunction.avg => 'AVG($quoted) AS `avg`',
      AggregateFunction.min => 'MIN($quoted) AS `min`',
      AggregateFunction.max => 'MAX($quoted) AS `max`',
    };
  }

  String _projection(List<String> columns) {
    if (columns.isEmpty) return '*';
    return columns.map(_quotePath).join(', ');
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
    if (limit != null) {
      sql.write(' LIMIT $limit');
      if (offset != null) sql.write(' OFFSET $offset');
      return;
    }
    if (offset != null) {
      // MySQL forbids a bare OFFSET; pair it with the maximum unsigned
      // BIGINT as the limit so every row past the offset is returned.
      sql.write(' LIMIT 18446744073709551615 OFFSET $offset');
    }
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
      // MySQL has no ILIKE; fold both sides to lower case.
      Operator.ilike => 'LOWER($left) LIKE LOWER($right)',
      _ => throw QueryException(
        query: '',
        message:
            'ColumnNode does not support operator ${node.operator.name} '
            'for column-to-column comparison',
      ),
    };
  }

  String _compileRaw(RawNode node, List<Object?> params) {
    // RawNode SQL already uses positional `?` placeholders, which is
    // exactly MySQL's native syntax — append verbatim and record its
    // parameters in left-to-right order.
    params.addAll(node.parameters);
    return node.sql;
  }

  /// The `ESCAPE` clause for [predicate]'s pattern, or nothing when the
  /// pattern keeps MySQL's default escape character. MySQL reads a backslash
  /// in a string literal as its own escape, so it is doubled.
  String _escapeClause(Predicate predicate) {
    final escape = predicate.escape;
    if (escape == null) return '';
    final quoted = escape.replaceAll(r'\', r'\\').replaceAll("'", "''");
    return " ESCAPE '$quoted'";
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
      Operator.like =>
        '$column LIKE ${_placeholder(params, predicate.value)}'
            '${_escapeClause(predicate)}',
      Operator.notLike =>
        '$column NOT LIKE ${_placeholder(params, predicate.value)}'
            '${_escapeClause(predicate)}',
      Operator.ilike =>
        'LOWER($column) LIKE LOWER(${_placeholder(params, predicate.value)})'
            '${_escapeClause(predicate)}',
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
    // MySQL has no empty `IN ()`; emit a constant predicate instead.
    if (items.isEmpty) return negate ? '1 = 1' : '1 = 0';
    if (items.length <= kMysqlInListChunkSize) {
      final placeholders = items.map((v) => _placeholder(params, v)).join(', ');
      return '$column $keyword ($placeholders)';
    }
    final chunks = <String>[];
    for (var i = 0; i < items.length; i += kMysqlInListChunkSize) {
      final end = i + kMysqlInListChunkSize < items.length
          ? i + kMysqlInListChunkSize
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

  String _comparisonOperator(Operator op) => switch (op) {
    Operator.eq => '=',
    Operator.neq => '!=',
    Operator.gt => '>',
    Operator.gte => '>=',
    Operator.lt => '<',
    Operator.lte => '<=',
    _ => op.name,
  };

  String _placeholder(List<Object?> params, Object? value) {
    params.add(value);
    return '?';
  }

  String _quoteIdent(String identifier) =>
      '`${identifier.replaceAll('`', '``')}`';

  String _quotePath(String column) =>
      column.split('.').map(_quoteIdent).join('.');

  String _qualified(String? tableName, String fieldName) {
    if (tableName == null || tableName.isEmpty) return _quoteIdent(fieldName);
    return '${_quoteIdent(tableName)}.${_quoteIdent(fieldName)}';
  }

  MysqlCompileResult _result(StringBuffer sql, List<Object?> params) =>
      MysqlCompileResult(
        sql: sql.toString(),
        parameters: List<Object?>.unmodifiable(params),
      );
}
