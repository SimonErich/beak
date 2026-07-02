import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const relation = BeakBelongsToMany(
    key: 'tags',
    label: 'Tags',
    relatedTable: 'tags',
    displayColumnKey: 'name',
    searchColumnKeys: ['name'],
    pivotTable: 'product_tag',
    foreignPivotKey: 'product_id',
    relatedPivotKey: 'tag_id',
    allowCreate: true,
    maxAllowed: 5,
    onDelete: BeakOnDelete.restrict,
  );

  test('stores its configuration', () {
    expect(relation.key, 'tags');
    expect(relation.label, 'Tags');
    expect(relation.relatedTable, 'tags');
    expect(relation.displayColumnKey, 'name');
    expect(relation.searchColumnKeys, const ['name']);
    expect(relation.pivotTable, 'product_tag');
    expect(relation.foreignPivotKey, 'product_id');
    expect(relation.relatedPivotKey, 'tag_id');
    expect(relation.allowCreate, isTrue);
    expect(relation.maxAllowed, 5);
    expect(relation.onDelete, BeakOnDelete.restrict);
  });

  test('defaults: no inline create, no cap, pivot rows cascade', () {
    const bare = BeakBelongsToMany(
      key: 'tags',
      label: 'Tags',
      relatedTable: 'tags',
      displayColumnKey: 'name',
      pivotTable: 'product_tag',
      foreignPivotKey: 'product_id',
      relatedPivotKey: 'tag_id',
    );
    expect(bare.searchColumnKeys, isEmpty);
    expect(bare.allowCreate, isFalse);
    expect(bare.maxAllowed, isNull);
    expect(bare.onDelete, BeakOnDelete.cascade);
  });

  test('resolves to many related records', () {
    expect(relation.cardinality, BeakRelationCardinality.many);
  });

  test('renders as relation badges in every context', () {
    for (final context in BeakContext.values) {
      expect(
        relation.intentFor(context),
        BeakRenderIntent.relationBadges,
        reason: '$context',
      );
    }
  });
}
