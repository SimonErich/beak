/// Boolean composition of query predicates.
library;

import 'operator.dart';
import 'predicate.dart';
import 'query_descriptor.dart';

/// A composable tree of query predicates.
///
/// Supports AND, OR, NOT, and grouped conditions.
/// Produced by field operator extensions and
/// combined using [and], [or], and [not].
///
/// ```dart
/// final tree = age.gte(18).and(name.eq('Alice'));
/// ```
sealed class PredicateTree {
  /// Creates a [PredicateTree].
  const PredicateTree();

  /// Combines with [other] using AND.
  PredicateTree and(PredicateTree other) => AndNode(this, other);

  /// Combines with [other] using OR.
  PredicateTree or(PredicateTree other) => OrNode(this, other);

  /// Negates this tree.
  PredicateTree not() => NotNode(this);

  /// Wraps this tree in a group (parentheses).
  PredicateTree group() => GroupNode(this);

  /// Serializes this tree to a map.
  Map<String, Object?> toMap();
}

/// A leaf node containing a single [Predicate].
final class LeafNode extends PredicateTree {
  /// Creates a [LeafNode].
  const LeafNode(this.predicate);

  /// The predicate this leaf represents.
  final Predicate predicate;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'leaf',
    ...predicate.toMap(),
  };
}

/// An AND combination of two sub-trees.
final class AndNode extends PredicateTree {
  /// Creates an [AndNode].
  const AndNode(this.left, this.right);

  /// The left sub-tree.
  final PredicateTree left;

  /// The right sub-tree.
  final PredicateTree right;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'and',
    'left': left.toMap(),
    'right': right.toMap(),
  };
}

/// An OR combination of two sub-trees.
final class OrNode extends PredicateTree {
  /// Creates an [OrNode].
  const OrNode(this.left, this.right);

  /// The left sub-tree.
  final PredicateTree left;

  /// The right sub-tree.
  final PredicateTree right;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'or',
    'left': left.toMap(),
    'right': right.toMap(),
  };
}

/// A NOT negation of a sub-tree.
final class NotNode extends PredicateTree {
  /// Creates a [NotNode].
  const NotNode(this.child);

  /// The negated sub-tree.
  final PredicateTree child;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'not',
    'child': child.toMap(),
  };
}

/// A grouped (parenthesized) sub-tree.
final class GroupNode extends PredicateTree {
  /// Creates a [GroupNode].
  const GroupNode(this.child);

  /// The grouped sub-tree.
  final PredicateTree child;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'group',
    'child': child.toMap(),
  };
}

/// A correlated/uncorrelated EXISTS subquery node.
///
/// Compiles to `EXISTS (...)` in SQL and a `$exists`
/// pipeline element in Mongo. Carries the full
/// subquery descriptor so adapters can render the
/// nested query verbatim.
final class ExistsNode extends PredicateTree {
  /// Creates an [ExistsNode].
  const ExistsNode(this.subquery, {this.negated = false});

  /// Descriptor of the subquery to test for existence.
  final QueryDescriptor subquery;

  /// Whether this is `NOT EXISTS`.
  final bool negated;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'type': negated ? 'notExists' : 'exists',
    'subquery': subquery.toMap(),
  };
}

/// A column-to-column comparison (`a.col1 = b.col2`).
final class ColumnNode extends PredicateTree {
  /// Creates a [ColumnNode].
  const ColumnNode({
    required this.leftField,
    required this.rightField,
    required this.operator,
    this.leftTable,
    this.rightTable,
  });

  /// Left-hand column name.
  final String leftField;

  /// Right-hand column name.
  final String rightField;

  /// Optional table qualifier on the left.
  final String? leftTable;

  /// Optional table qualifier on the right.
  final String? rightTable;

  /// Comparison [Operator] between the two columns.
  final Operator operator;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'column',
    'left': leftTable != null ? '$leftTable.$leftField' : leftField,
    'right': rightTable != null ? '$rightTable.$rightField' : rightField,
    'operator': operator.name,
  };
}

/// A raw SQL escape-hatch predicate node.
///
/// Renders the provided [sql] fragment verbatim in
/// the produced WHERE clause. Adapters that cannot
/// honour raw SQL (Mongo, in-memory) must reject
/// queries containing a [RawNode].
///
/// **Security note:** `toMap()` exposes only the
/// parameter count, never the bound values, so
/// snapshot diagnostics never leak credentials or PII.
final class RawNode extends PredicateTree {
  /// Creates a [RawNode].
  const RawNode(this.sql, {this.parameters = const <Object?>[]});

  /// Raw SQL fragment.
  final String sql;

  /// Bound parameters for the fragment.
  final List<Object?> parameters;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'raw',
    'sql': sql,
    'paramCount': parameters.length,
  };
}
