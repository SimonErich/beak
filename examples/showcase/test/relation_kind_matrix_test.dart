import 'package:beak/beak.dart';
import 'package:showcase/beak/registry.g.dart';
import 'package:test/test.dart';

/// Every relationship kind Beak has, one enum value each.
///
/// [BeakRelationship] is a sealed hierarchy, so [_kindOf] switches over it
/// exhaustively: a new relationship kind stops this file compiling, and the
/// value it forces here then has to be declared by a model in the Aviary.
// --8<-- [start:RelationKind]
enum _RelationKind { belongsTo, hasOne, hasMany, belongsToMany }
// --8<-- [end:RelationKind]

/// The kind of [relationship]. There is no default branch on purpose.
// --8<-- [start:kindOf]
_RelationKind _kindOf(BeakRelationship relationship) => switch (relationship) {
  BeakBelongsTo() => _RelationKind.belongsTo,
  BeakHasOne() => _RelationKind.hasOne,
  BeakHasMany() => _RelationKind.hasMany,
  BeakBelongsToMany() => _RelationKind.belongsToMany,
};
// --8<-- [end:kindOf]

void main() {
  final declared = [for (final model in beakModels) ...model.relationships];

  test('the Aviary declares every relationship kind', () {
    final kinds = {for (final relationship in declared) _kindOf(relationship)};

    final missing = [
      for (final kind in _RelationKind.values)
        if (!kinds.contains(kind)) kind.name,
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'The docs quote the Aviary for every relationship kind. Declare '
          'the missing ones on a schema class and run `beak prepare`.',
    );
  });

  test('a many-to-many relationship joins through a named pivot table', () {
    final pivots = {
      for (final relationship in declared)
        if (relationship case BeakBelongsToMany(:final pivotTable)) pivotTable,
    };

    expect(pivots, {'habitat_keeper'});
  });

  test('every relationship points at a model the Aviary registers', () {
    final tables = {for (final model in beakModels) model.table};

    for (final relationship in declared) {
      expect(tables, contains(relationship.relatedTable));
    }
  });
}
