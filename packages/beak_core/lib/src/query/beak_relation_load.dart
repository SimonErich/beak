import 'package:meta/meta.dart';

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
  /// Throws a [BeakConfigurationException] on malformed input.
  static BeakRelationLoad fromJson(Map<String, Object?> json) {
    final Map<String, Object?>? filterJson = requireJsonMapOrNull(
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
        for (final child in requireJsonMapList(
          requireJsonKey(json, 'nested', 'BeakRelationLoad'),
          'nested',
          'BeakRelationLoad',
        ))
          BeakRelationLoad.fromJson(child),
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
