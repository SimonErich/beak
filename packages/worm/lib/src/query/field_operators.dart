/// Type-constrained operator extensions for fields.
library;

import 'field.dart';
import 'operator.dart';
import 'predicate.dart';
import 'predicate_tree.dart';

/// Universal operators available on all fields.
extension FieldOperators<T> on Field<T> {
  /// Equals (`=`).
  PredicateTree eq(T value) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.eq,
      value: value,
    ),
  );

  /// Not equals (`!=`).
  PredicateTree neq(T value) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.neq,
      value: value,
    ),
  );

  /// Is null.
  PredicateTree isNull() => LeafNode(
    Predicate(fieldName: name, tableName: tableName, operator: Operator.isNull),
  );

  /// Is not null.
  PredicateTree isNotNull() => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.isNotNull,
    ),
  );

  /// In a list of values.
  PredicateTree inList(List<T> values) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.inList,
      value: values,
    ),
  );

  /// Not in a list of values.
  PredicateTree notInList(List<T> values) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.notInList,
      value: values,
    ),
  );

  /// Long-form spec alias for [inList].
  ///
  /// `field.whereIn([1, 2, 3])` compiles identically to
  /// `field.inList([1, 2, 3])` and produces the same predicate
  /// tree, so spec examples that use the long-form name compile
  /// against the typed API.
  PredicateTree whereIn(List<T> values) => inList(values);

  /// Long-form spec alias for [notInList].
  PredicateTree whereNotIn(List<T> values) => notInList(values);
}

/// Comparison operators for orderable fields.
extension ComparableFieldOperators<T> on ComparableField<T> {
  /// Greater than (`>`).
  PredicateTree gt(T value) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.gt,
      value: value,
    ),
  );

  /// Greater than or equal to (`>=`).
  PredicateTree gte(T value) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.gte,
      value: value,
    ),
  );

  /// Less than (`<`).
  PredicateTree lt(T value) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.lt,
      value: value,
    ),
  );

  /// Less than or equal to (`<=`).
  PredicateTree lte(T value) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.lte,
      value: value,
    ),
  );

  /// Between [lower] and [upper] inclusive.
  PredicateTree between(T lower, T upper) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.between,
      value: (lower, upper),
    ),
  );

  /// Not between [lower] and [upper].
  PredicateTree notBetween(T lower, T upper) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.notBetween,
      value: (lower, upper),
    ),
  );
}

/// String-specific operators for text fields.
extension StringFieldOperators on StringField {
  /// SQL LIKE pattern match.
  PredicateTree like(String pattern) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.like,
      value: pattern,
    ),
  );

  /// SQL NOT LIKE pattern match.
  PredicateTree notLike(String pattern) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.notLike,
      value: pattern,
    ),
  );

  /// Case-insensitive LIKE pattern match.
  PredicateTree ilike(String pattern) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.ilike,
      value: pattern,
    ),
  );

  /// Contains [substring] anywhere.
  PredicateTree contains(String substring) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.like,
      value: '%$substring%',
    ),
  );

  /// Starts with [prefix].
  PredicateTree startsWith(String prefix) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.like,
      value: '$prefix%',
    ),
  );

  /// Ends with [suffix].
  PredicateTree endsWith(String suffix) => LeafNode(
    Predicate(
      fieldName: name,
      tableName: tableName,
      operator: Operator.like,
      value: '%$suffix',
    ),
  );
}
