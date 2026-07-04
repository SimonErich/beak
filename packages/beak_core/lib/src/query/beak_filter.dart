import 'package:meta/meta.dart';

import '../columns/beak_column.dart';
import '../common/beak_exception.dart';
import '../common/list_equality.dart';
import 'beak_operator.dart';
import 'beak_value.dart';
import '../common/json_support.dart';

/// A typed, losslessly JSON-serializable predicate tree.
///
/// The frontend composes filters from typed column constants; the backend
/// decodes them with [fromJson] and translates each node to the ORM's query
/// builder. The hierarchy is sealed so translators switch exhaustively.
///
/// Build predicates from column constants and combine them with
/// [BeakAndFilter]/[BeakOrFilter]; a backend translator walks the tree with an
/// exhaustive switch:
///
/// ```dart
/// const price = BeakDecimalColumn(key: 'price', label: 'Price');
/// const inStock = BeakBoolColumn(key: 'in_stock', label: 'In stock');
///
/// final BeakFilter predicate = BeakAndFilter([
///   BeakFieldFilter(
///     column: price,
///     operator: BeakOperator.lte,
///     value: BeakValue.of(100.0),
///   ),
///   BeakFieldFilter(
///     column: inStock,
///     operator: BeakOperator.eq,
///     value: BeakValue.of(true),
///   ),
/// ]);
///
/// String describe(BeakFilter filter) => switch (filter) {
///   BeakFieldFilter(:final columnKey, :final operator) =>
///     '$columnKey ${operator.name}',
///   BeakAndFilter(:final filters) => filters.map(describe).join(' AND '),
///   BeakOrFilter(:final filters) => filters.map(describe).join(' OR '),
/// };
/// ```
@immutable
sealed class BeakFilter {
  const BeakFilter();

  /// Collapses [filters] into one predicate: `null` when empty, the single
  /// element alone, otherwise a [BeakAndFilter] — the one way filter lists
  /// combine.
  static BeakFilter? allOf(List<BeakFilter> filters) =>
      switch (filters.length) {
        0 => null,
        1 => filters.single,
        _ => BeakAndFilter(filters),
      };

  /// Decodes [json] (produced by [toJson]) back into a predicate tree.
  ///
  /// Throws a [BeakConfigurationException] on malformed input.
  static BeakFilter fromJson(Map<String, Object?> json) => switch (json) {
    {'type': 'field'} => _fieldFromJson(json),
    {'type': 'and'} => BeakAndFilter(_childrenFromJson(json, 'BeakAndFilter')),
    {'type': 'or'} => BeakOrFilter(_childrenFromJson(json, 'BeakOrFilter')),
    _ => throw BeakConfigurationException('Malformed BeakFilter JSON: $json.'),
  };

  static BeakFieldFilter _fieldFromJson(Map<String, Object?> json) =>
      BeakFieldFilter.forKey(
        requireJsonString(json, 'column', 'BeakFieldFilter'),
        _operatorByName(requireJsonString(json, 'operator', 'BeakFieldFilter')),
        BeakValue.fromJson(requireJsonKey(json, 'value', 'BeakFieldFilter')),
      );

  static List<BeakFilter> _childrenFromJson(
    Map<String, Object?> json,
    String context,
  ) => [
    for (final child in requireJsonMapList(
      requireJsonKey(json, 'filters', context),
      'filters',
      context,
    ))
      BeakFilter.fromJson(child),
  ];

  static BeakOperator _operatorByName(String name) {
    final BeakOperator? operator = BeakOperator.values.asNameMap()[name];
    if (operator == null) {
      throw BeakConfigurationException('"$name" is not a BeakOperator.');
    }
    return operator;
  }

  /// This predicate tree as a plain JSON-encodable object.
  Map<String, Object?> toJson();
}

/// Compares a single column against an operand with a [BeakOperator].
final class BeakFieldFilter extends BeakFilter {
  /// Creates a predicate on [column] — the type-safe path: the column
  /// constant supplies its own [columnKey], so callers never write key
  /// strings.
  BeakFieldFilter({
    required BeakColumn column,
    required this.operator,
    this.value = const BeakNullValue(),
  }) : columnKey = column.key;

  /// Creates a predicate on a raw [columnKey] — the deserialization path
  /// used by [BeakFilter.fromJson]; prefer the default constructor in user
  /// code.
  const BeakFieldFilter.forKey(
    this.columnKey,
    this.operator, [
    this.value = const BeakNullValue(),
  ]);

  /// Key of the column this predicate applies to.
  final String columnKey;

  /// The comparison operator.
  final BeakOperator operator;

  /// The comparison operand; [BeakNullValue] for operand-less operators
  /// ([BeakOperator.isNull], [BeakOperator.isNotNull]).
  final BeakValue value;

  @override
  Map<String, Object?> toJson() => {
    'type': 'field',
    'column': columnKey,
    'operator': operator.name,
    'value': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is BeakFieldFilter &&
      other.columnKey == columnKey &&
      other.operator == operator &&
      other.value == value;

  @override
  int get hashCode => Object.hash(columnKey, operator, value);

  @override
  String toString() => 'BeakFieldFilter($columnKey ${operator.name} $value)';
}

/// Matches records satisfying every child predicate.
final class BeakAndFilter extends BeakFilter {
  /// Creates a conjunction over [filters].
  const BeakAndFilter(this.filters);

  /// The child predicates, all of which must hold.
  final List<BeakFilter> filters;

  @override
  Map<String, Object?> toJson() => {
    'type': 'and',
    'filters': [for (final filter in filters) filter.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is BeakAndFilter && listEquals(other.filters, filters);

  @override
  int get hashCode => Object.hash(BeakAndFilter, Object.hashAll(filters));

  @override
  String toString() => 'BeakAndFilter($filters)';
}

/// Matches records satisfying at least one child predicate.
final class BeakOrFilter extends BeakFilter {
  /// Creates a disjunction over [filters].
  const BeakOrFilter(this.filters);

  /// The child predicates, at least one of which must hold.
  final List<BeakFilter> filters;

  @override
  Map<String, Object?> toJson() => {
    'type': 'or',
    'filters': [for (final filter in filters) filter.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is BeakOrFilter && listEquals(other.filters, filters);

  @override
  int get hashCode => Object.hash(BeakOrFilter, Object.hashAll(filters));

  @override
  String toString() => 'BeakOrFilter($filters)';
}
