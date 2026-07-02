/// Descriptor-first relation metadata.
///
/// Each [RelationDefinition] is a declarative,
/// adapter-agnostic description of a relation between
/// two models. Definitions carry no load logic —
/// `EagerLoader` interprets them when batching.
library;

import '../adapter/database_adapter.dart';
import '../model/model.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/query_descriptor.dart';
import 'morph.dart';

/// Sealed base for every relation definition shape.
///
/// Pattern matching against a `RelationDefinition`
/// reference is exhaustive across all four morph
/// kinds.
sealed class RelationDefinition {
  /// Const base constructor.
  const RelationDefinition({required this.name});

  /// Stable name of the relation on the parent model.
  final String name;
}

/// Polymorphic one-to-one: the parent owns at most one
/// child where the child carries `<parentMorphName>_type`
/// + `<parentMorphName>_id` columns.
final class MorphOneDefinition<Parent extends Model, Child extends Model>
    extends RelationDefinition {
  /// Creates a [MorphOneDefinition].
  const MorphOneDefinition({
    required super.name,
    required this.childTable,
    required this.morphType,
    required this.parentMorphName,
    required this.hydrateChild,
    this.localKey = 'id',
  });

  /// Table holding the child rows.
  final String childTable;

  /// Morph-type string identifying this parent on the
  /// child row.
  final String morphType;

  /// Morph-name prefix yielding `<name>_type` /
  /// `<name>_id`.
  final String parentMorphName;

  /// Parent-side primary-key column.
  final String localKey;

  /// Hydrator turning a raw row into [Child].
  final Child Function(Map<String, Object?>) hydrateChild;

  /// Column on the child carrying the parent type.
  String get morphTypeColumn => '${parentMorphName}_type';

  /// Column on the child carrying the parent id.
  String get morphIdColumn => '${parentMorphName}_id';
}

/// Polymorphic one-to-many: the parent owns zero or
/// more children sharing the same morph columns.
final class MorphManyDefinition<Parent extends Model, Child extends Model>
    extends RelationDefinition {
  /// Creates a [MorphManyDefinition].
  const MorphManyDefinition({
    required super.name,
    required this.childTable,
    required this.morphType,
    required this.parentMorphName,
    required this.hydrateChild,
    this.localKey = 'id',
  });

  /// Table holding the child rows.
  final String childTable;

  /// Morph-type string identifying this parent on the
  /// child row.
  final String morphType;

  /// Morph-name prefix yielding `<name>_type` /
  /// `<name>_id`.
  final String parentMorphName;

  /// Parent-side primary-key column.
  final String localKey;

  /// Hydrator turning a raw row into [Child].
  final Child Function(Map<String, Object?>) hydrateChild;

  /// Column on the child carrying the parent type.
  String get morphTypeColumn => '${parentMorphName}_type';

  /// Column on the child carrying the parent id.
  String get morphIdColumn => '${parentMorphName}_id';
}

/// Polymorphic inverse: a single child may point at
/// many parent tables. Carries one [MorphBinding] per
/// supported morph type.
final class MorphToDefinition<Child extends Model, S extends Object>
    extends RelationDefinition {
  /// Creates a [MorphToDefinition].
  const MorphToDefinition({
    required super.name,
    required this.morphTypeColumn,
    required this.morphIdColumn,
    required this.hydrateMap,
  });

  /// Column on the child carrying the morph type.
  final String morphTypeColumn;

  /// Column on the child carrying the morph id.
  final String morphIdColumn;

  /// Mapping from morph-type strings to per-type
  /// bindings.
  final Map<String, MorphBinding<S>> hydrateMap;

  /// Loads [child]'s morph target.
  ///
  /// Returns the resolved sealed value [S] when the
  /// child's morph type is registered in [hydrateMap]
  /// and the referenced parent row exists. Returns
  /// null when:
  ///
  /// - the morph-type column is null or absent,
  /// - the morph-type string is unknown,
  /// - the morph-id is null,
  /// - the referenced parent row does not exist.
  ///
  /// The static return type is `Future<S?>` —
  /// callers can pattern match against the sealed
  /// hierarchy [S] without a default arm, giving a
  /// compile-time exhaustiveness check.
  Future<S?> load(DatabaseAdapter adapter, Child child) async {
    final row = child.toRow();
    final type = row[morphTypeColumn];
    if (type is! String) return null;
    final binding = hydrateMap[type];
    if (binding == null) return null;
    final id = row[morphIdColumn];
    if (id == null) return null;
    final field = Field<Object?>(binding.ownerKey);
    final parentRow = await adapter.selectOne(
      QueryDescriptor(table: binding.table, where: field.eq(id)),
    );
    if (parentRow == null) return null;
    return binding.wrap(binding.hydrate(parentRow));
  }
}

/// Polymorphic many-to-many through a pivot whose
/// rows carry `<parentMorphName>_type` /
/// `<parentMorphName>_id` columns.
final class MorphToManyDefinition<Parent extends Model, Related extends Model>
    extends RelationDefinition {
  /// Creates a [MorphToManyDefinition].
  const MorphToManyDefinition({
    required super.name,
    required this.relatedTable,
    required this.pivotTable,
    required this.parentMorphName,
    required this.morphType,
    required this.relatedPivotKey,
    required this.hydrateRelated,
    this.parentKey = 'id',
    this.relatedKey = 'id',
  });

  /// Related rows table.
  final String relatedTable;

  /// Pivot table carrying morph + related FKs.
  final String pivotTable;

  /// Morph-name prefix yielding pivot
  /// `<name>_type` / `<name>_id` columns.
  final String parentMorphName;

  /// Morph-type value identifying this parent.
  final String morphType;

  /// Pivot column referencing the related rows.
  final String relatedPivotKey;

  /// Parent primary-key column.
  final String parentKey;

  /// Related primary-key column.
  final String relatedKey;

  /// Hydrator turning a related row into [Related].
  final Related Function(Map<String, Object?>) hydrateRelated;

  /// Pivot column carrying the parent type.
  String get morphTypeColumn => '${parentMorphName}_type';

  /// Pivot column carrying the parent id.
  String get morphIdColumn => '${parentMorphName}_id';
}
