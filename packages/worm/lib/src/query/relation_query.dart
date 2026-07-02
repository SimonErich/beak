/// Lightweight predicate builder passed to the constrain callback
/// of `QueryBuilder.withRelation`.
library;

import '../exception/configuration_exception.dart';
import '../model/model.dart';
import 'field.dart';
import 'operator.dart';
import 'predicate.dart';
import 'predicate_tree.dart';

/// Builder accumulating WHERE predicates for a relation's child
/// query.
///
/// Accepts the same call shapes as `QueryBuilder.where`:
///
/// - `where(PredicateTree)` — composed via field operator
///   extensions.
/// - `where(field, value)` — sugar for
///   `where(field, Operator.eq, value)`.
/// - `where(field, operator, value)` — explicit operator.
final class RelationQuery<T extends Model> {
  /// Creates an empty [RelationQuery].
  RelationQuery();

  PredicateTree? _where;

  /// Accumulated predicate, or `null` when no constraints were
  /// added. The eager loader AND-merges this into the relation's
  /// child SELECT.
  PredicateTree? get predicate => _where;

  /// AND a predicate into this query.
  RelationQuery<T> where(Object first, [Object? second, Object? third]) {
    final tree = _coerce(first, second, third);
    _where = _where == null ? tree : _where!.and(tree);
    // ignore: avoid_returning_this — fluent builder
    return this;
  }

  /// OR a predicate into this query.
  RelationQuery<T> orWhere(Object first, [Object? second, Object? third]) {
    final tree = _coerce(first, second, third);
    _where = _where == null ? tree : _where!.or(tree);
    // ignore: avoid_returning_this — fluent builder
    return this;
  }

  PredicateTree _coerce(Object first, Object? second, Object? third) =>
      switch ((first, second, third)) {
        (final PredicateTree tree, null, null) => tree,
        (PredicateTree(), _, _) => throw const ConfigurationException(
          key: 'relationQuery.where.shape',
          message:
              'where(PredicateTree) does not accept additional '
              'positional arguments',
        ),
        (final Field<Object?> field, final Operator op, final Object? value)
            when third != null =>
          LeafNode(
            Predicate(
              fieldName: field.name,
              tableName: field.tableName,
              operator: op,
              value: value,
            ),
          ),
        (Field<Object?>(), _, _) when third != null =>
          throw ArgumentError.value(
            second,
            'operator',
            'where(field, operator, value): expected Operator',
          ),
        (final Field<Object?> field, final Object? value, null) => LeafNode(
          Predicate(
            fieldName: field.name,
            tableName: field.tableName,
            operator: Operator.eq,
            value: value,
          ),
        ),
        (_, _, null) when second != null => throw ArgumentError.value(
          first,
          'field',
          'where(field, value): expected Field',
        ),
        _ => throw ConfigurationException(
          key: 'relationQuery.where.shape',
          message:
              'Invalid where(...) shape — expected PredicateTree, '
              '(field, value) or (field, Operator, value); got '
              '${first.runtimeType}',
        ),
      };
}

/// Callback constraining a relation's child query.
///
/// Receives a fresh [RelationQuery] and returns the (possibly
/// further constrained) builder. The accumulated predicate is read
/// from [RelationQuery.predicate] and AND-merged into the child
/// SELECT issued by the eager loader.
typedef RelationConstrain<T extends Model> =
    RelationQuery<T> Function(RelationQuery<T> q);
