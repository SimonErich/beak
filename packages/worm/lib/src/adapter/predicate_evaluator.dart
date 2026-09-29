/// Stateless evaluator for `PredicateTree`s.
library;

import '../exception/unsupported_operation_exception.dart';
import '../query/operator.dart';
import '../query/predicate.dart';
import '../query/predicate_tree.dart';

/// Evaluates `PredicateTree` instances against
/// `Map<String, Object?>` rows.
///
/// Stateless and const-constructible. Adapters
/// backed by an in-memory store delegate filtering
/// logic here so predicate semantics stay
/// consistent.
final class PredicateEvaluator {
  /// Creates a const evaluator.
  const PredicateEvaluator();

  /// Whether [row] satisfies [tree]. A null tree
  /// matches every row.
  ///
  /// When [existsResolver] is provided, [ExistsNode]
  /// instances delegate to it; otherwise an
  /// [UnsupportedOperationException] is thrown.
  bool matches(
    Map<String, Object?> row,
    PredicateTree? tree, {
    bool Function(ExistsNode node)? existsResolver,
  }) {
    if (tree == null) return true;
    return _evaluateNode(row, tree, existsResolver: existsResolver);
  }

  bool _evaluateNode(
    Map<String, Object?> row,
    PredicateTree node, {
    bool Function(ExistsNode node)? existsResolver,
  }) => switch (node) {
    LeafNode(:final predicate) => _evaluateLeaf(row, predicate),
    AndNode(:final left, :final right) =>
      _evaluateNode(row, left, existsResolver: existsResolver) &&
          _evaluateNode(row, right, existsResolver: existsResolver),
    OrNode(:final left, :final right) =>
      _evaluateNode(row, left, existsResolver: existsResolver) ||
          _evaluateNode(row, right, existsResolver: existsResolver),
    NotNode(:final child) => !_evaluateNode(
      row,
      child,
      existsResolver: existsResolver,
    ),
    GroupNode(:final child) => _evaluateNode(
      row,
      child,
      existsResolver: existsResolver,
    ),
    ColumnNode() => _evaluateColumn(row, node),
    ExistsNode() => _evaluateExists(node, existsResolver),
    RawNode() => throw const UnsupportedOperationException(
      operation: 'whereRaw',
      adapter: 'PredicateEvaluator',
      message: 'RawNode cannot be evaluated against in-memory rows',
    ),
  };

  bool _evaluateColumn(Map<String, Object?> row, ColumnNode node) {
    final leftKey = node.leftTable == null
        ? node.leftField
        : '${node.leftTable}.${node.leftField}';
    final rightKey = node.rightTable == null
        ? node.rightField
        : '${node.rightTable}.${node.rightField}';
    final left = row.containsKey(leftKey) ? row[leftKey] : row[node.leftField];
    final right = row.containsKey(rightKey)
        ? row[rightKey]
        : row[node.rightField];
    return switch (node.operator) {
      Operator.eq => left == right,
      Operator.neq => left != right,
      Operator.gt => compareValues(left, right) > 0,
      Operator.gte => compareValues(left, right) >= 0,
      Operator.lt => compareValues(left, right) < 0,
      Operator.lte => compareValues(left, right) <= 0,
      Operator.like ||
      Operator.notLike ||
      Operator.ilike ||
      Operator.isNull ||
      Operator.isNotNull ||
      Operator.inList ||
      Operator.notInList ||
      Operator.between ||
      Operator.notBetween => throw UnsupportedOperationException(
        operation: 'whereColumn:${node.operator.name}',
        adapter: 'PredicateEvaluator',
        message:
            'Operator ${node.operator.name} is not valid for column-to-column '
            'comparison',
      ),
    };
  }

  bool _evaluateExists(
    ExistsNode node,
    bool Function(ExistsNode node)? resolver,
  ) {
    if (resolver == null) {
      throw const UnsupportedOperationException(
        operation: 'whereExists',
        adapter: 'PredicateEvaluator',
        message:
            'No existsResolver provided; cannot evaluate ExistsNode in '
            'isolation',
      );
    }
    final present = resolver(node);
    return node.negated ? !present : present;
  }

  bool _evaluateLeaf(Map<String, Object?> row, Predicate predicate) {
    final field = row.containsKey(predicate.qualifiedName)
        ? row[predicate.qualifiedName]
        : row[predicate.fieldName];
    return switch (predicate.operator) {
      Operator.eq => field == predicate.value,
      Operator.neq => field != predicate.value,
      Operator.gt => compareValues(field, predicate.value) > 0,
      Operator.gte => compareValues(field, predicate.value) >= 0,
      Operator.lt => compareValues(field, predicate.value) < 0,
      Operator.lte => compareValues(field, predicate.value) <= 0,
      Operator.like => _matchLike(
        field,
        predicate.value,
        escape: predicate.escape,
        caseSensitive: true,
      ),
      Operator.notLike => !_matchLike(
        field,
        predicate.value,
        escape: predicate.escape,
        caseSensitive: true,
      ),
      Operator.ilike => _matchLike(
        field,
        predicate.value,
        escape: predicate.escape,
        caseSensitive: false,
      ),
      Operator.isNull => field == null,
      Operator.isNotNull => field != null,
      Operator.inList => _listContains(predicate.value, field),
      Operator.notInList => !_listContains(predicate.value, field),
      Operator.between => _between(field, predicate.value),
      Operator.notBetween => !_between(field, predicate.value),
    };
  }

  bool _listContains(Object? haystack, Object? needle) {
    if (haystack is List) return haystack.contains(needle);
    return false;
  }

  /// Compare two row values with `NULLS FIRST`
  /// ordering: two nulls are equal, null sorts
  /// before any non-null, non-nulls go through
  /// [Comparable.compare].
  int compareValues(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is Comparable && b is Comparable) {
      return Comparable.compare(a, b);
    }
    throw StateError('Cannot compare ${a.runtimeType} with ${b.runtimeType}');
  }

  bool _between(Object? field, Object? bounds) {
    if (bounds is (Object?, Object?)) {
      return compareValues(field, bounds.$1) >= 0 &&
          compareValues(field, bounds.$2) <= 0;
    }
    if (bounds is List && bounds.length == 2) {
      return compareValues(field, bounds[0]) >= 0 &&
          compareValues(field, bounds[1]) <= 0;
    }
    return false;
  }

  bool _matchLike(
    Object? field,
    Object? pattern, {
    required String? escape,
    required bool caseSensitive,
  }) {
    if (field is! String || pattern is! String) return false;
    return RegExp(
      '^${_likeToRegexSource(pattern, escape)}\$',
      caseSensitive: caseSensitive,
    ).hasMatch(field);
  }

  /// The regular expression source for a SQL `LIKE` [pattern]: `%` is any run
  /// of characters, `_` is one character, and, when [escape] is set, the
  /// character after an [escape] stands for itself (a trailing [escape] stands
  /// for itself too).
  static String _likeToRegexSource(String pattern, String? escape) {
    final buffer = StringBuffer();
    final characters = pattern.split('');
    for (var index = 0; index < characters.length; index++) {
      final character = characters[index];
      if (character == escape) {
        final literal = index + 1 < characters.length
            ? characters[++index]
            : character;
        buffer.write(RegExp.escape(literal));
      } else if (character == '%') {
        buffer.write('.*');
      } else if (character == '_') {
        buffer.write('.');
      } else {
        buffer.write(RegExp.escape(character));
      }
    }
    return buffer.toString();
  }
}
