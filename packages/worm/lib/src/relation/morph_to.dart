/// Polymorphic inverse (MorphTo) relationship.
///
/// A child row may point at many different parent
/// tables. Consumers supply a user-defined sealed
/// class hierarchy (one case per parent table) and a
/// [MorphTypeMapping] per type that loads, hydrates,
/// and wraps the parent into the sealed case. The
/// resulting value is accessible from
/// `child.relations[<name>]` and pattern-matchable
/// without `dynamic` or `as` casts.
library;

import '../adapter/database_adapter.dart';
import '../model/model.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/query_descriptor.dart';
import 'relation_base.dart';

/// Per-type mapping for a [MorphToRelation].
final class MorphTypeMapping<Target> {
  /// Creates a [MorphTypeMapping].
  const MorphTypeMapping({
    required this.table,
    required this.hydrate,
    required this.wrap,
    this.ownerKey = 'id',
  });

  /// Parent table for this morph type.
  final String table;

  /// Hydrator turning a parent row into a [Model].
  final Model Function(Map<String, Object?>) hydrate;

  /// Wraps a hydrated parent into a [Target] case.
  final Target Function(Model) wrap;

  /// Primary-key column of the parent.
  final String ownerKey;
}

/// A `MorphTo` relationship.
///
/// Eager loading queries one parent table per
/// distinct morph type observed across loaded
/// children. In the common case (single morph type)
/// this is one query; with N morph types it executes
/// N queries — explicitly documented as the
/// exception to the "1 query per relation path"
/// baseline.
final class MorphToRelation<Child extends Model, Target>
    extends Relation<Child, Model> {
  /// Creates a [MorphToRelation].
  const MorphToRelation({
    required super.name,
    required this.morphTypeColumn,
    required this.morphIdColumn,
    required this.types,
  });

  /// Column on the child carrying the morph type.
  final String morphTypeColumn;

  /// Column on the child carrying the morph id.
  final String morphIdColumn;

  /// Mapping from morph-type strings to [Target]
  /// adapters.
  final Map<String, MorphTypeMapping<Target>> types;

  @override
  Future<RelationLoadResult<Child>> load(
    DatabaseAdapter adapter,
    List<Child> children,
  ) async {
    final byType = <String, List<Child>>{};
    for (final child in children) {
      final row = child.toRow();
      final type = row[morphTypeColumn];
      if (type is String) {
        byType.putIfAbsent(type, () => <Child>[]).add(child);
      }
    }
    final perChild = <Child, Target>{};
    var queries = 0;
    for (final entry in byType.entries) {
      final mapping = types[entry.key];
      if (mapping == null) continue;
      final ids = <Object?>{
        for (final c in entry.value) c.toRow()[morphIdColumn],
      }.whereType<Object>().toList();
      if (ids.isEmpty) continue;
      final field = Field<Object?>(mapping.ownerKey);
      final rows = await adapter.select(
        QueryDescriptor(table: mapping.table, where: field.inList(ids)),
      );
      queries++;
      final byOwner = <Object?, Model>{
        for (final row in rows) row[mapping.ownerKey]: mapping.hydrate(row),
      };
      for (final child in entry.value) {
        final ownerId = child.toRow()[morphIdColumn];
        final parent = byOwner[ownerId];
        if (parent != null) {
          perChild[child] = mapping.wrap(parent);
        }
      }
    }
    return RelationLoadResult<Child>(
      setOnParent: (child) {
        final target = perChild[child];
        if (target != null) {
          child.relations[name] = target;
        } else {
          child.relations[name] = null;
        }
      },
      stats: LoadStats(queriesExecuted: queries),
    );
  }
}
