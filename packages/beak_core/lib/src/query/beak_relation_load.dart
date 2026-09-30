import 'package:meta/meta.dart';

import '../common/beak_exception.dart';
import '../common/list_equality.dart';
import 'beak_filter.dart';
import '../common/json_support.dart';

/// An eager-load directive: which relation to load with the main query,
/// optionally constrained and with nested loads of its own.
///
/// Beak never lazy-loads; every relation a surface needs is declared up
/// front through directives like this one (reference-dedup happens in the
/// backend). User code obtains loads through the spec's typed `withRelation`
/// builder, which reads the key from a relationship constant.
///
/// A directive can carry a [filter] to constrain which related rows load and
/// [nested] directives to eager-load the related model's own relations:
///
/// ```dart
/// // Load an order's line items that are still pending, and each item's
/// // product in turn.
/// const load = BeakRelationLoad(
///   'items',
///   filter: BeakFieldFilter.forKey(
///     'status',
///     BeakOperator.eq,
///     BeakStringValue('pending'),
///   ),
///   nested: [BeakRelationLoad('product')],
/// );
/// ```
@immutable
final class BeakRelationLoad {
  /// Creates an eager-load directive for the relation named [relationKey],
  /// optionally constrained by [filter] and loading [nested] relations of
  /// the related model.
  const BeakRelationLoad(
    this.relationKey, {
    this.filter,
    this.nested = const [],
  });

  /// Decodes [json] (produced by [toJson]).
  ///
  /// `relation` is required. `filter` and `nested` are optional: absent or
  /// `null` they mean no constraint and no nested loads, so `{"relation":
  /// "author"}` loads the bare relation.
  ///
  /// Throws a [BeakConfigurationException] on malformed input, including
  /// loads nested more than 64 levels deep.
  static BeakRelationLoad fromJson(Map<String, Object?> json) =>
      _decode(json, 0);

  static const int _maxNesting = 64;

  static BeakRelationLoad _decode(Map<String, Object?> json, int depth) {
    if (depth >= _maxNesting) {
      throw const BeakConfigurationException(
        'BeakRelationLoad JSON is nested more than $_maxNesting levels deep.',
      );
    }
    final Map<String, Object?>? filterJson = optionalJsonMap(
      json,
      'filter',
      'BeakRelationLoad',
    );
    final BeakFilter? filter = filterJson == null
        ? null
        : BeakFilter.fromJson(filterJson);
    return BeakRelationLoad(
      requireJsonString(json, 'relation', 'BeakRelationLoad'),
      filter: filter,
      nested: [
        for (final child in optionalJsonMapList(
          json,
          'nested',
          'BeakRelationLoad',
        ))
          _decode(child, depth + 1),
      ],
    );
  }

  /// Key of the relation to eager-load.
  final String relationKey;

  /// An optional predicate constraining which related records load.
  final BeakFilter? filter;

  /// Relations of the related model to eager-load in turn.
  final List<BeakRelationLoad> nested;

  /// This directive as a plain JSON-encodable object.
  Map<String, Object?> toJson() => {
    'relation': relationKey,
    'filter': filter?.toJson(),
    'nested': [for (final load in nested) load.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is BeakRelationLoad &&
      other.relationKey == relationKey &&
      other.filter == filter &&
      listEquals(other.nested, nested);

  @override
  int get hashCode => Object.hash(relationKey, filter, Object.hashAll(nested));

  @override
  String toString() =>
      'BeakRelationLoad($relationKey, filter: $filter, nested: $nested)';
}
