/// Adapter-agnostic SQL compiler for query
/// inspection.
library;

import 'join_clause.dart';
import 'operator.dart';
import 'predicate.dart';
import 'predicate_tree.dart';
import 'query_descriptor.dart';
import 'sort_clause.dart';
import 'sort_direction.dart';

/// Compiles a [QueryDescriptor] into a SQL string
/// suitable for `QueryBuilder.toSql()` golden tests.
///
/// The output renders literal values inline (no
/// placeholders) for deterministic snapshots. It is
/// **not** intended for execution — adapters compile
/// descriptors with their own parameterised renderers.
final class SqlCompiler {
  /// Creates a const compiler.
  const SqlCompiler();

  /// Render [descriptor] as a `SELECT` statement.
  String compile(QueryDescriptor descriptor) {
    final buffer = StringBuffer('SELECT ');
    if (descriptor.distinct) buffer.write('DISTINCT ');
    if (descriptor.columns.isEmpty) {
      buffer.write('*');
    } else {
      buffer.write(descriptor.columns.join(', '));
    }
    buffer
      ..write(' FROM ')
      ..write(descriptor.table);
    if (descriptor.tableAlias case final alias?) buffer.write(' AS $alias');
    for (final join in descriptor.joins) {
      buffer
        ..write(' ${join.kind.sql} ')
        ..write(join.table)
        ..write(' ON ')
        ..write('${join.leftColumn} = ${join.rightColumn}');
    }
    final where = descriptor.where;
    if (where != null) {
      buffer
        ..write(' WHERE ')
        ..write(_renderTree(where));
    }
    if (descriptor.groupBy.isNotEmpty) {
      buffer
        ..write(' GROUP BY ')
        ..write(descriptor.groupBy.join(', '));
    }
    if (descriptor.having.isNotEmpty) {
      buffer
        ..write(' HAVING ')
        ..write(_renderHaving(descriptor.having));
    }
    if (descriptor.orderBy.isNotEmpty) {
      buffer
        ..write(' ORDER BY ')
        ..write(_renderOrder(descriptor.orderBy));
    }
    if (descriptor.limit != null) {
      buffer
        ..write(' LIMIT ')
        ..write(descriptor.limit);
    }
    if (descriptor.offset != null) {
      buffer
        ..write(' OFFSET ')
        ..write(descriptor.offset);
    }
    return buffer.toString();
  }

  String _renderHaving(List<HavingClause> clauses) => clauses
      .map(
        (c) => '${c.expression} ${_havingOp(c.operator)} ${_literal(c.value)}',
      )
      .join(' AND ');

  String _havingOp(Operator op) => switch (op) {
    Operator.eq => '=',
    Operator.neq => '!=',
    Operator.gt => '>',
    Operator.gte => '>=',
    Operator.lt => '<',
    Operator.lte => '<=',
    _ => op.name,
  };

  String _renderOrder(List<SortClause> clauses) => clauses
      .map(
        (c) =>
            '${c.fieldName} '
            '${c.direction == SortDirection.desc ? 'DESC' : 'ASC'}',
      )
      .join(', ');

  /// Renders a [PredicateTree] as a SQL fragment.
  String _renderTree(PredicateTree node) => switch (node) {
    LeafNode(:final predicate) => _renderLeaf(predicate),
    AndNode(:final left, :final right) =>
      '${_renderTree(left)} AND ${_renderTree(right)}',
    OrNode(:final left, :final right) =>
      '${_renderTree(left)} OR ${_renderTree(right)}',
    NotNode(:final child) => 'NOT ${_renderTree(child)}',
    GroupNode(:final child) => '(${_renderTree(child)})',
    ColumnNode() => _renderColumn(node),
    ExistsNode() => _renderExists(node),
    RawNode(:final sql) => sql,
  };

  String _renderLeaf(Predicate p) {
    final field = p.qualifiedName;
    return switch (p.operator) {
      Operator.eq => '$field = ${_literal(p.value)}',
      Operator.neq => '$field != ${_literal(p.value)}',
      Operator.gt => '$field > ${_literal(p.value)}',
      Operator.gte => '$field >= ${_literal(p.value)}',
      Operator.lt => '$field < ${_literal(p.value)}',
      Operator.lte => '$field <= ${_literal(p.value)}',
      Operator.like => '$field LIKE ${_literal(p.value)}${_escape(p)}',
      Operator.notLike => '$field NOT LIKE ${_literal(p.value)}${_escape(p)}',
      Operator.ilike => '$field ILIKE ${_literal(p.value)}${_escape(p)}',
      Operator.isNull => '$field IS NULL',
      Operator.isNotNull => '$field IS NOT NULL',
      Operator.inList => '$field IN ${_listLiteral(p.value)}',
      Operator.notInList => '$field NOT IN ${_listLiteral(p.value)}',
      Operator.between => '$field BETWEEN ${_rangeLiteral(p.value)}',
      Operator.notBetween => '$field NOT BETWEEN ${_rangeLiteral(p.value)}',
    };
  }

  String _escape(Predicate p) =>
      p.escape == null ? '' : ' ESCAPE ${_literal(p.escape)}';

  String _renderColumn(ColumnNode node) {
    final left = node.leftTable != null
        ? '${node.leftTable}.${node.leftField}'
        : node.leftField;
    final right = node.rightTable != null
        ? '${node.rightTable}.${node.rightField}'
        : node.rightField;
    final op = _columnOperator(node.operator);
    return '$left $op $right';
  }

  String _columnOperator(Operator op) => switch (op) {
    Operator.eq => '=',
    Operator.neq => '!=',
    Operator.gt => '>',
    Operator.gte => '>=',
    Operator.lt => '<',
    Operator.lte => '<=',
    Operator.like ||
    Operator.notLike ||
    Operator.ilike ||
    Operator.isNull ||
    Operator.isNotNull ||
    Operator.inList ||
    Operator.notInList ||
    Operator.between ||
    Operator.notBetween => op.name,
  };

  String _renderExists(ExistsNode node) {
    final keyword = node.negated ? 'NOT EXISTS' : 'EXISTS';
    return '$keyword (${compile(node.subquery)})';
  }

  String _literal(Object? value) {
    if (value == null) return 'NULL';
    if (value is num) return value.toString();
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    return "'${value.toString().replaceAll("'", "''")}'";
  }

  String _listLiteral(Object? value) {
    if (value is! List) return '()';
    return '(${value.map(_literal).join(', ')})';
  }

  String _rangeLiteral(Object? value) {
    if (value is (Object?, Object?)) {
      return '${_literal(value.$1)} AND ${_literal(value.$2)}';
    }
    if (value is List && value.length == 2) {
      return '${_literal(value[0])} AND ${_literal(value[1])}';
    }
    return 'NULL AND NULL';
  }
}
