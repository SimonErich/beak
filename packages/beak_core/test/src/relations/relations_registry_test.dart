import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// Exhaustive mapping over the sealed relationship family: adding a
/// `BeakRelationship` variant breaks compilation here, forcing every
/// consumer (frontend renderer, backend mapper) to be revisited.
String kindOf(BeakRelationship relationship) => switch (relationship) {
  BeakBelongsTo() => 'belongsTo',
  BeakHasOne() => 'hasOne',
  BeakHasMany() => 'hasMany',
  BeakBelongsToMany() => 'belongsToMany',
};

/// One instance of every concrete relationship type.
const List<BeakRelationship> allRelationships = [
  BeakBelongsTo(
    key: 'a',
    label: 'A',
    relatedTable: 'as',
    displayColumnKey: 'name',
    foreignKey: 'a_id',
  ),
  BeakHasOne(
    key: 'b',
    label: 'B',
    relatedTable: 'bs',
    displayColumnKey: 'name',
    foreignKey: 'owner_id',
  ),
  BeakHasMany(
    key: 'c',
    label: 'C',
    relatedTable: 'cs',
    displayColumnKey: 'name',
    foreignKey: 'owner_id',
  ),
  BeakBelongsToMany(
    key: 'd',
    label: 'D',
    relatedTable: 'ds',
    displayColumnKey: 'name',
    pivotTable: 'a_d',
    foreignPivotKey: 'a_id',
    relatedPivotKey: 'd_id',
  ),
];

void main() {
  test('the sealed relationship family switches exhaustively', () {
    expect(allRelationships.map(kindOf), const [
      'belongsTo',
      'hasOne',
      'hasMany',
      'belongsToMany',
    ]);
  });

  test('cardinality is one for single relations, many for lists', () {
    expect(
      allRelationships.map((relationship) => relationship.cardinality),
      const [
        BeakRelationCardinality.one,
        BeakRelationCardinality.one,
        BeakRelationCardinality.many,
        BeakRelationCardinality.many,
      ],
    );
  });

  test('every relationship resolves an intent for every context', () {
    for (final relationship in allRelationships) {
      for (final context in BeakContext.values) {
        expect(
          relationship.intentFor(context),
          isA<BeakRenderIntent>(),
          reason: '${relationship.key}/$context',
        );
      }
    }
  });
}
