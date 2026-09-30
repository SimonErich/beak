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
///   BeakRelationFilter(:final relationKey, :final filter) =>
///     '$relationKey WHERE ${describe(filter)}',
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
  /// Throws a [BeakConfigurationException] on malformed input, including a
  /// tree nested more than 64 levels deep: a request can be megabytes of
  /// brackets, and decoding it recursively would end in a stack overflow.
  static BeakFilter fromJson(Map<String, Object?> json) => _decode(json, 0);

  static const int _maxNesting = 64;

  // --8<-- [start:fromJson]
  static BeakFilter _decode(Map<String, Object?> json, int depth) {
    if (depth >= _maxNesting) {
      throw const BeakConfigurationException(
        'BeakFilter JSON is nested more than $_maxNesting levels deep.',
      );
    }
    return switch (json) {
      {'type': 'field'} => _fieldFromJson(json),
      {'type': 'and'} => BeakAndFilter(
        _childrenFromJson(json, 'BeakAndFilter', depth),
      ),
      {'type': 'or'} => BeakOrFilter(
        _childrenFromJson(json, 'BeakOrFilter', depth),
      ),
      {'type': 'relation'} => BeakRelationFilter(
        requireJsonString(json, 'relation', 'BeakRelationFilter'),
        _decode(
          requireJsonMap(json, 'filter', 'BeakRelationFilter'),
          depth + 1,
        ),
      ),
      _ => throw BeakConfigurationException(
        'Malformed BeakFilter JSON: $json.',
      ),
    };
  }
  // --8<-- [end:fromJson]

  static BeakFieldFilter _fieldFromJson(Map<String, Object?> json) =>
      BeakFieldFilter.forKey(
        requireJsonString(json, 'column', 'BeakFieldFilter'),
        _operatorByName(requireJsonString(json, 'operator', 'BeakFieldFilter')),
        BeakValue.fromJson(requireJsonKey(json, 'value', 'BeakFieldFilter')),
      );

  static List<BeakFilter> _childrenFromJson(
    Map<String, Object?> json,
    String context,
    int depth,
  ) => [
    for (final child in requireJsonMapList(
      requireJsonKey(json, 'filters', context),
      'filters',
      context,
    ))
      _decode(child, depth + 1),
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

/// Matches an owner when one related record satisfies the complete [filter].
///
/// Keeping the child predicate grouped ensures that a row-level access scope
/// and the user's filter apply to the same child. Generated field references
/// provide this structure without requiring relation-key strings in app code.
final class BeakRelationFilter extends BeakFilter {
  /// Creates an existential predicate over [relationKey].
  const BeakRelationFilter(this.relationKey, this.filter);

  /// Relationship on the current model.
  final String relationKey;

  /// Predicate evaluated against each related record.
  final BeakFilter filter;

  @override
  Map<String, Object?> toJson() => {
    'type': 'relation',
    'relation': relationKey,
    'filter': filter.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is BeakRelationFilter &&
      other.relationKey == relationKey &&
      other.filter == filter;

  @override
  int get hashCode => Object.hash(relationKey, filter);

  @override
  String toString() => 'BeakRelationFilter($relationKey, $filter)';
}

/// Compares a single column against an operand with a [BeakOperator].
final class BeakFieldFilter extends BeakFilter {
  /// Creates a predicate on [column] — the type-safe path: the column
  /// constant supplies its own [columnKey], so callers never write key
  /// strings.
  // --8<-- [start:fieldFilterConstructors]
  const BeakFieldFilter({
    required BeakColumn column,
    required this.operator,
    this.value = const BeakNullValue(),
  }) : _column = column,
       _columnKey = null;

  /// Creates a predicate on a raw [columnKey] — the deserialization path
  /// used by [BeakFilter.fromJson]; prefer the default constructor in user
  /// code.
  const BeakFieldFilter.forKey(
    String columnKey,
    this.operator, [
    this.value = const BeakNullValue(),
  ]) : _columnKey = columnKey,
       _column = null;
  // --8<-- [end:fieldFilterConstructors]

  /// The column this predicate applies to, when built from a constant.
  ///
  /// Held rather than reduced to its key so the constructor can be `const`:
  /// a screen, a dashboard metric and a resource's base filter are all const
  /// expressions, and a filter that could not be one forced them all open.
  final BeakColumn? _column;

  final String? _columnKey;

  /// Key of the column this predicate applies to.
  String get columnKey => _columnKey ?? _column!.key;

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
